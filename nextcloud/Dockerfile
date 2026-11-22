# Nextcloud + Memories dependencies.
#
# Memories needs ffmpeg/ffprobe (video) and exiftool (fast EXIF parsing), which
# the official image does not ship. Extending the image keeps them across
# updates and container recreation.
#
# Update flow (base image is pulled, packages reinstalled):
#   docker compose build --pull && docker compose up -d
# Base pinned 2026-11-22 (was :stable-apache); bump deliberately (Diun notifies).
FROM nextcloud:34.0.4-apache

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ffmpeg \
        libimage-exiftool-perl \
        procps \
    ; \
    # Extra ImageMagick delegates (HEIC/RAW). Best effort: the package name
    # tracks the Debian release, so don't fail the build if it moves.
    apt-get install -y --no-install-recommends libmagickcore-7.q16-10-extra || true; \
    rm -rf /var/lib/apt/lists/*
