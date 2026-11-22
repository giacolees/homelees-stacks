#!/bin/bash
# homelees nightly backup — restic, encrypted, deduplicated.
#   1. consistent dumps of every database (MariaDB, Postgres, Mongo, SQLite)
#   2. restic snapshots to the local HDD repo and (if configured) Google Drive
#   3. retention + status file + notification
# Docs: /opt/stacks/README.md "Backups". Restore: `restic -r <repo> restore`.
set -Eeuo pipefail
umask 077

export RESTIC_PASSWORD_FILE=/root/.config/restic/password
export RESTIC_CACHE_DIR=/home/backup/restic-cache      # keep cache off / and /var
LOCAL_REPO=/mnt/media/Backups/restic
GDRIVE_REMOTE=gdrive
GDRIVE_REPO="rclone:${GDRIVE_REMOTE}:homelees-restic"
DUMPS=/home/backup/dumps
STATUS=/var/lib/homelees-status/backup.json
EXCLUDES=/etc/homelees/backup-excludes.txt
LOG_TAG=homelees-backup

log()    { echo "[$(date '+%F %T')] $*"; }
notify() { if [ -x /usr/local/sbin/tg-notify ]; then /usr/local/sbin/tg-notify "$1" || true; fi; }
fail()   {
    log "FAILED: $1"
    printf '{"status":"failed","time":"%s","error":%s}\n' "$(date -Is)" "$(printf '%s' "$1" | jq -Rs .)" > "$STATUS"
    notify "❌ homelees backup FAILED: $1"
    exit 1
}
trap 'fail "line $LINENO: $BASH_COMMAND"' ERR

SYSTEM_PATHS=(
    /opt/stacks
    /home/komodo
    /home/beszel /home/ferdium /home/octo-fiesta
    /home/nextcloud/config
    /home/navidrome/data
    /DATA/AppData/jellyfin
    /etc /usr/local/sbin /var/www/html
    /root/.config/rclone
    "$DUMPS"
)
NEXTCLOUD_PATHS=(/mnt/media/Nextcloud/data)
MUSIC_PATHS=(/home/navidrome/music)

mountpoint -q /mnt/media || fail "/mnt/media is not mounted"
mkdir -p "$DUMPS/sqlite" "$RESTIC_CACHE_DIR"

# ---------- 1. database dumps --------------------------------------------
dump() {  # dump <name> <container> <shell command run inside the container>
    local name=$1 ctr=$2 cmd=$3
    if ! docker inspect -f '{{.State.Running}}' "$ctr" 2>/dev/null | grep -q true; then
        log "skip $name: container $ctr not running"; return 0
    fi
    docker exec "$ctr" sh -c "$cmd" > "$DUMPS/$name.tmp"
    mv "$DUMPS/$name.tmp" "$DUMPS/$name"
    log "dumped $name ($(du -h "$DUMPS/$name" | cut -f1))"
}
dump nextcloud-mariadb.sql.gz nextcloud-db \
    'mariadb-dump --single-transaction --quick --routines --events --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD" | gzip'
dump wellness-postgres.sql.gz wellness-db \
    'pg_dumpall -U "$POSTGRES_USER" | gzip'
dump komodo-mongo.archive.gz komodo-mongo-1 \
    'mongodump --quiet --archive --gzip -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin'

# SQLite: online-backup API gives a consistent copy even while the app writes.
while IFS= read -r db; do
    out="$DUMPS/sqlite$(dirname "$db")"; mkdir -p "$out"
    if timeout 120 sqlite3 -readonly "$db" ".backup '$out/$(basename "$db")'" 2>/dev/null; then :; else
        log "warn: sqlite backup failed for $db (raw file still included)"; fi
done < <(find /opt/stacks /home/beszel /home/ferdium /home/navidrome/data /DATA/AppData/jellyfin \
            \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -size +0 \
            -not -name 'logs.db' -not -path '*/node_modules/*' 2>/dev/null)

# ---------- 2. snapshots ---------------------------------------------------
backup_to() {  # backup_to <repo> <include-music:yes|no>
    local repo=$1 music=$2
    log "== repo $repo"
    restic -r "$repo" backup -q --tag system    --exclude-file "$EXCLUDES" --exclude-caches "${SYSTEM_PATHS[@]}"
    restic -r "$repo" backup -q --tag nextcloud --exclude-file "$EXCLUDES" "${NEXTCLOUD_PATHS[@]}"
    if [ "$music" = yes ]; then
        restic -r "$repo" backup -q --tag music "${MUSIC_PATHS[@]}"
    fi
    restic -r "$repo" forget -q --prune --group-by host,tags \
        --keep-daily 7 --keep-weekly 4 --keep-monthly 6
}

backup_to "$LOCAL_REPO" yes
OFFSITE=skipped
if rclone listremotes 2>/dev/null | grep -qx "${GDRIVE_REMOTE}:"; then
    restic -r "$GDRIVE_REPO" cat config >/dev/null 2>&1 || restic -r "$GDRIVE_REPO" init -q
    backup_to "$GDRIVE_REPO" no
    OFFSITE=ok
else
    log "offsite skipped: rclone remote '${GDRIVE_REMOTE}' not configured"
fi

# ---------- 3. status -------------------------------------------------------
SIZE=$(restic -r "$LOCAL_REPO" stats --mode raw-data --json 2>/dev/null | jq -r '.total_size // 0')
printf '{"status":"ok","time":"%s","offsite":"%s","local_repo_bytes":%s}\n' \
    "$(date -Is)" "$OFFSITE" "${SIZE:-0}" > "$STATUS"
chmod 644 "$STATUS"
log "backup OK (offsite: $OFFSITE)"
[ "$OFFSITE" = ok ] || notify "⚠️ homelees backup OK locally, but offsite (Google Drive) is not configured"
