"""homelees Telegram status bot — READ-ONLY.

* Answers only the chat id in TG_CHAT_ID; everything else is ignored + logged.
* Containers: Docker API via a socket proxy that only allows GET /containers.
* Host: /proc (container sees host load/mem/uptime) + JSON snapshots written by
  the host's homelees-healthcheck / homelees-backup into /status (read-only).
* No command can change anything on the server.
"""
import json, logging, os, time
from datetime import datetime, timezone
from pathlib import Path

import httpx
from telegram import Update
from telegram.constants import ParseMode
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
logging.getLogger("httpx").setLevel(logging.WARNING)
log = logging.getLogger("homelees-bot")

TOKEN = os.environ["TG_TOKEN"]
CHAT_ID = int(os.environ["TG_CHAT_ID"])
DOCKER = os.environ.get("DOCKER_API", "http://socket-proxy:2375")
STATUS = Path(os.environ.get("STATUS_DIR", "/status"))


def read_json(name):
    try:
        return json.loads((STATUS / name).read_text())
    except Exception:
        return None


def age(iso):
    try:
        s = (datetime.now(timezone.utc) - datetime.fromisoformat(iso)).total_seconds()
    except Exception:
        return "?"
    if s < 90: return f"{int(s)}s ago"
    if s < 5400: return f"{int(s/60)} min ago"
    if s < 172800: return f"{s/3600:.1f} h ago"
    return f"{s/86400:.1f} days ago"


def gb(n): return f"{n/1e9:.0f} GB" if n < 1e12 else f"{n/1e12:.1f} TB"


def bar(pct, width=10):
    full = round(pct / 100 * width)
    return "█" * full + "░" * (width - full)


def meminfo():
    m = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        k, v = line.split(":", 1)
        m[k] = int(v.split()[0]) * 1024
    return m


async def containers():
    async with httpx.AsyncClient(timeout=10) as c:
        r = await c.get(f"{DOCKER}/containers/json", params={"all": "true"})
        r.raise_for_status()
        return r.json()


def allowed(update: Update) -> bool:
    chat = update.effective_chat
    if chat and chat.id == CHAT_ID:
        return True
    u = update.effective_user
    log.warning("ignored message from chat=%s user=%s (%s)", chat.id if chat else None,
                u.id if u else None, u.username if u else None)
    return False


async def reply(update: Update, text: str):
    await update.effective_message.reply_text(text, parse_mode=ParseMode.HTML,
                                              disable_web_page_preview=True)


# ----------------------------------------------------------------- commands
async def cmd_help(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not allowed(update): return
    await reply(update,
        "<b>homelees bot</b> (read-only)\n"
        "/status – overview\n/containers – all containers\n/disk – disk usage\n"
        "/backup – last backup\n/health – active problems\n/smart – disk health\n"
        "/vpn – remote access peers\n/updates – pending updates")


async def cmd_status(update: Update, ctx):
    if not allowed(update): return
    up = float(Path("/proc/uptime").read_text().split()[0])
    l1, l5, l15 = Path("/proc/loadavg").read_text().split()[:3]
    m = meminfo()
    mem_used = m["MemTotal"] - m["MemAvailable"]
    swap_used = m["SwapTotal"] - m["SwapFree"]
    health = read_json("health.json") or {}
    try:
        cs = await containers()
        running = sum(c["State"] == "running" for c in cs)
        unhealthy = [c["Names"][0][1:] for c in cs if "unhealthy" in c.get("Status", "")]
        ctext = f"{running}/{len(cs)} running" + (f", ⚠️ unhealthy: {', '.join(unhealthy)}" if unhealthy else "")
    except Exception as e:
        ctext = f"unavailable ({e.__class__.__name__})"
    b = read_json("backup.json") or {}
    probs = health.get("problems", [])
    lines = [
        f"<b>🖥 homelees</b> — {'✅ all good' if not probs else f'🔴 {len(probs)} problem(s)'}",
        f"⏱ up {up/86400:.1f} days · load {l1} {l5} {l15}",
        f"🧠 RAM {mem_used/2**30:.1f}/{m['MemTotal']/2**30:.1f} GiB · swap {swap_used/2**20:.0f} MiB",
        f"📦 containers: {ctext}",
        f"💾 backup: {b.get('status','?')} {age(b.get('time',''))} (offsite: {b.get('offsite','?')})",
    ]
    met = read_json("metrics.json") or {}
    for d in met.get("disks", []):
        lines.append(f"<code>{d['mount']:<11}{bar(d['pct'])} {d['pct']:>3}%</code>")
    if probs:
        lines.append("\n" + "\n".join(f"• {p}" for p in probs))
    await reply(update, "\n".join(lines))


async def cmd_containers(update: Update, ctx):
    if not allowed(update): return
    try:
        cs = sorted(await containers(), key=lambda c: c["Names"][0])
    except Exception as e:
        return await reply(update, f"Docker API unavailable: {e}")
    out = []
    for c in cs:
        st = c.get("Status", "")
        icon = "🔴" if c["State"] != "running" else ("🟠" if "unhealthy" in st else
               "🟡" if "starting" in st else "🟢")
        out.append(f"{icon} <b>{c['Names'][0][1:]}</b> — {st}")
    await reply(update, "\n".join(out))


async def cmd_disk(update: Update, ctx):
    if not allowed(update): return
    met = read_json("metrics.json")
    if not met: return await reply(update, "No metrics yet.")
    out = [f"<b>💾 Disks</b> ({age(met['time'])})"]
    for d in met["disks"]:
        out.append(f"<code>{d['mount']:<11}{bar(d['pct'])} {d['pct']:>3}%</code>  {gb(d['avail'])} free of {gb(d['size'])}")
    await reply(update, "\n".join(out))


async def cmd_backup(update: Update, ctx):
    if not allowed(update): return
    b = read_json("backup.json")
    if not b: return await reply(update, "No backup has run yet.")
    icon = "✅" if b.get("status") == "ok" else "❌"
    txt = f"{icon} <b>Backup {b.get('status')}</b> — {age(b.get('time',''))}\n"
    if b.get("error"): txt += f"error: <code>{b['error']}</code>\n"
    txt += f"offsite (Google Drive): {b.get('offsite','?')}\n"
    if b.get("local_repo_bytes"): txt += f"local repo: {gb(b['local_repo_bytes'])}\n"
    txt += "next run: nightly 03:30"
    await reply(update, txt)


async def cmd_health(update: Update, ctx):
    if not allowed(update): return
    h = read_json("health.json")
    if not h: return await reply(update, "No health data yet.")
    if h["ok"]:
        return await reply(update, f"✅ No problems (checked {age(h['time'])})")
    await reply(update, f"🔴 <b>Problems</b> (checked {age(h['time'])})\n" +
                "\n".join(f"• {p}" for p in h["problems"]))


async def cmd_smart(update: Update, ctx):
    if not allowed(update): return
    met = read_json("metrics.json")
    if not met: return await reply(update, "No metrics yet.")
    s = met["smart"]
    await reply(update,
        f"<b>🩺 Disk health</b> ({age(met['time'])})\n"
        f"NVMe (system): {s['nvme']['health']} · wear {s['nvme']['wear']} · {s['nvme']['temp']}\n"
        f"18 TB USB HDD: {s['hdd']['health']}\n<i>{s['hdd']['note']}; I/O errors are watched every 10 min.</i>")


async def cmd_vpn(update: Update, ctx):
    if not allowed(update): return
    met = read_json("metrics.json") or {}
    v = met.get("vpn", {})
    out = []
    ts = v.get("tailscale")
    if ts:
        out.append(f"<b>Tailscale</b>: {ts.get('state')}")
        for p in ts.get("peers", []):
            out.append(f"  {'🟢' if p.get('online') else '⚪️'} {p.get('name')} ({p.get('os')})")
    if v.get("netbird"):
        out.append("<b>NetBird</b>:\n<code>" + v["netbird"][:1500] + "</code>")
    await reply(update, "\n".join(out) or "No VPN data.")


async def cmd_updates(update: Update, ctx):
    if not allowed(update): return
    met = read_json("metrics.json")
    if not met: return await reply(update, "No metrics yet.")
    u = met["updates"]
    txt = (f"<b>⬆️ Updates</b>\napt: {u['apt']} pending ({u['security']} security; "
           f"security updates install automatically)\n")
    if u["reboot_needed"]:
        txt += f"🔁 reboot needed: running kernel {u['kernel_running']}, installed {u['kernel_installed']}\n"
    img = read_json("images.json")
    if not img:
        txt += "Docker images: no check yet (homelees-image-updates, daily 08:45)."
    else:
        ups = [i for i in img["images"] if i.get("update")]
        txt += f"\n<b>🐳 Docker images</b> (checked {age(img['time'])})\n"
        if not ups:
            txt += "all pinned images are current ✅\n"
        for i in sorted(ups, key=lambda i: i["stack"]):
            warn = " ⚠️ major" if i.get("major") else ""
            txt += (f"• <b>{i['repo'].split('/')[-1]}</b> ({i['stack']}): "
                    f"<code>{i['current']}</code> → <code>{i['newest']}</code>{warn}\n")
        if img.get("errors"):
            txt += f"⚠️ {len(img['errors'])} image(s) could not be checked\n"
        if ups:
            txt += "Update: bump the tag in the stack + diun/images.yml, then compose pull &amp;&amp; up -d."
    await reply(update, txt)


async def unknown(update: Update, ctx):
    if not allowed(update): return
    await cmd_help(update, ctx)


def main():
    app = Application.builder().token(TOKEN).build()
    for name, fn in {"start": cmd_help, "help": cmd_help, "status": cmd_status,
                     "containers": cmd_containers, "disk": cmd_disk, "backup": cmd_backup,
                     "health": cmd_health, "smart": cmd_smart, "vpn": cmd_vpn,
                     "updates": cmd_updates}.items():
        app.add_handler(CommandHandler(name, fn))
    app.add_handler(MessageHandler(filters.ALL, unknown))

    async def post_init(a):
        await a.bot.set_my_commands([
            ("status", "Overview"), ("containers", "All containers"), ("disk", "Disk usage"),
            ("backup", "Last backup"), ("health", "Active problems"), ("smart", "Disk health"),
            ("vpn", "Remote access peers"), ("updates", "Pending updates"), ("help", "Help")])
    app.post_init = post_init
    log.info("starting; authorised chat id %s", CHAT_ID)
    app.run_polling(allowed_updates=Update.ALL_TYPES, drop_pending_updates=True)


if __name__ == "__main__":
    main()
