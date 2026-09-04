#!/usr/bin/env bash
# ============================================================
#  Bulletproof Self-Hosted n8n - Daily Backup
#  Captures the four things that actually matter:
#    1. the database            (workflows, credentials, users)
#    2. the n8n data volume     (custom nodes, binary data, config)
#    3. the encryption key      (without it, credentials are unreadable)
#    4. plain JSON exports      (portable "can't-even-lose-it" copies)
#  Optional: encrypted offsite copy, retention pruning, healthchecks.io ping.
#
#  Run manually:      sudo bash 02-backup.sh
#  Run daily by cron: see ../README-KIT.md step 6
#  Dependencies:      docker, tar, gzip, sha256sum, openssl (optional),
#                     rclone (optional, offsite), curl (optional, monitoring)
# ============================================================
set -euo pipefail

# -------------------------  CONFIG  -------------------------
# Everything can be overridden without editing this file:
#   sudo cp n8n-backup.defaults /etc/n8n-backup.env   # then edit that file
#   BACKUP_ROOT=/data/backups sudo -E bash 02-backup.sh
CONFIG_FILE="${CONFIG_FILE:-/etc/n8n-backup.env}"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

: "${STACK_DIR:=/opt/n8n}"                 # folder holding docker-compose.yml
: "${N8N_SERVICE:=n8n}"                    # service name in compose
: "${N8N_CONTAINER:=n8n}"                  # running container name
: "${DB_CONTAINER:=n8n-postgres-1}"        # postgres container name
: "${DB_USER:=n8n}"
: "${DB_NAME:=n8n}"
: "${DATA_VOLUME:=}"                       # e.g. n8n_n8n_data - auto-detected if empty
: "${BACKUP_ROOT:=/var/backups/n8n}"
: "${RETENTION_DAYS:=14}"
: "${OFFSITE_REMOTE:=}"                     # e.g. b2:n8n-backups  (rclone remote)
: "${OFFSITE_ENCRYPT_NAME:=}"              # rclone crypt wrapper, e.g. n8n-crypt:
: "${HEALTHCHECK_UUID:=}"                  # https://healthchecks.io  -> sends an all-good signal
: "${EXPORT_SEPARATE:=1}"                  # 1 = one JSON file per workflow (nicer in git)
: "${INCLUDE_DECRYPTED:=0}"                # 1 = also store decrypted credentials (see warning below)
# ------------------------------------------------------------

TS="$(date -u +%Y%m%dT%H%M%SZ)"
STAGE="$(mktemp -d /tmp/n8n-backup.XXXXXX)"
OUT="$BACKUP_ROOT/$TS"
trap 'rm -rf "$STAGE"' EXIT
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
die() { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

# ---- safety pre-flight (this whole script exists to PREVENT data loss,
#      so it must never be the thing that corrupts a backup) ----
command -v docker >/dev/null 2>&1 || die "docker not found"
mkdir -p "$OUT" 2>/dev/null || die "cannot write to $OUT - run with sudo, or set BACKUP_ROOT=/home/$USER/n8n-backups"

if ! docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
  die "container '$N8N_CONTAINER' is not running. Start n8n first, or set N8N_CONTAINER."
fi

# ---- 1. the encryption key: recorded FIRST, so the run fails loudly if it is missing ----
log "locating encryption key"
KEY_SRC="none"
if docker exec "$N8N_CONTAINER" printenv N8N_ENCRYPTION_KEY >/dev/null 2>&1; then
  docker exec "$N8N_CONTAINER" printenv N8N_ENCRYPTION_KEY > "$STAGE/ENCRYPTION_KEY.txt"
  KEY_SRC="env var"
elif docker exec "$N8N_CONTAINER" cat /home/node/.n8n/config > "$STAGE/n8n-config.json" 2>/dev/null && \
     grep -q encryptionKey "$STAGE/n8n-config.json"; then
  sed -n 's/.*"encryptionKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STAGE/n8n-config.json" > "$STAGE/ENCRYPTION_KEY.txt"
  KEY_SRC="volume config file"
fi
chmod 600 "$STAGE/ENCRYPTION_KEY.txt" 2>/dev/null || true

if [ ! -s "$STAGE/ENCRYPTION_KEY.txt" ]; then
  cat <<'EOF'

[ERROR] Could not read an encryption key from anywhere.
This usually means n8n wrote a key you have never captured, OR the data volume is not persisted.
Back up the database anyway is USELESS for credentials in that state.

Do this now (read-only, safe):
  docker exec -it n8n cat /home/node/.n8n/config
If that prints an "encryptionKey" value -> copy it to your password manager, then
put it in $STACK_DIR/.env as N8N_ENCRYPTION_KEY and re-run this script.
If it prints nothing -> your volume is not persisted. Fix the compose file
(see 02-HOW-SETUP.md) BEFORE running any more automations in production.

EOF
  exit 1
fi
log "encryption key captured (source: $KEY_SRC)"

# ---- 2. the database ----
DB_MODE="$(docker exec "$N8N_CONTAINER" printenv DB_TYPE 2>/dev/null || echo sqlite)"
if [ "$DB_MODE" = "postgresdb" ]; then
  log "pg_dump (postgres)"
  docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc -f "/tmp/n8n-$TS.dump" \
    || die "pg_dump failed - check DB_CONTAINER / DB_USER / DB_NAME"
  docker cp "$DB_CONTAINER:/tmp/n8n-$TS.dump" "$STAGE/database.dump"
  docker exec "$DB_CONTAINER" rm -f "/tmp/n8n-$TS.dump"
else
  log "sqlite file copy (consistent snapshot via .backup)"
  docker exec "$N8N_CONTAINER" sh -c "mkdir -p /tmp/bk && sqlite3 /home/node/.n8n/database.sqlite '.backup /tmp/bk/database.sqlite'" \
    || die "sqlite3 not available in the image; fallback: docker cp $N8N_CONTAINER:/home/node/.n8n/database.sqlite"
  docker cp "$N8N_CONTAINER:/tmp/bk/database.sqlite" "$STAGE/database.sqlite"
  docker exec "$N8N_CONTAINER" rm -rf /tmp/bk
fi

# ---- 3. the n8n data volume (settings, custom nodes, binary data) ----
if [ -z "$DATA_VOLUME" ]; then
  DATA_VOLUME="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/home/node/.n8n"}}{{.Name}}{{end}}{{end}}' "$N8N_CONTAINER" 2>/dev/null || true)"
fi
if [ -n "$DATA_VOLUME" ] && docker volume inspect "$DATA_VOLUME" >/dev/null 2>&1; then
  log "taring data volume: $DATA_VOLUME"
  docker run --rm -v "$DATA_VOLUME":/data:ro -v "$STAGE":/backup alpine \
    tar czf /backup/n8n-data.tar.gz -C /data . || die "volume tar failed"
else
  log "no named volume detected (bind mount?) - copying /home/node/.n8n straight from the container"
  docker run --rm --volumes-from "$N8N_CONTAINER" -v "$STAGE":/backup alpine \
    tar czf /backup/n8n-data.tar.gz -C /home/node/.n8n . || die "container copy failed"
fi

# ---- 4. stack definition (without secrets) ----
log "copying compose/env files"
for f in docker-compose.yml docker-compose.yaml compose.yml .env; do
  [ -f "$STACK_DIR/$f" ] && cp "$STACK_DIR/$f" "$STAGE/$f" 2>/dev/null || true
done
if [ -f "$STAGE/.env" ]; then
  log "masking secrets in the copied .env (real .env is NOT modified)"
  sed -i -E 's/^((N8N_ENCRYPTION_KEY|DB_POSTGRESDB_PASSWORD|POSTGRES_PASSWORD)[[:alnum:]_]*=).*/\1***MASKED***/' "$STAGE/.env"
fi

# ---- 5. portable JSON exports (these save you when the DB is fine but you just want a diff/duplicate) ----
log "exporting workflows as JSON"
if [ "$EXPORT_SEPARATE" = "1" ]; then
  docker exec "$N8N_CONTAINER" n8n export:workflow --backup --output=/tmp/wf >/dev/null 2>&1 \
    && docker cp "$N8N_CONTAINER:/tmp/wf" "$STAGE/workflows" && docker exec "$N8N_CONTAINER" rm -rf /tmp/wf \
    || log "  (separate export skipped - n8n version may not support --backup; falling back to single file)"
  if [ ! -d "$STAGE/workflows" ]; then
    docker exec "$N8N_CONTAINER" n8n export:workflow --all --output=/tmp/wf.json >/dev/null 2>&1 \
      && docker cp "$N8N_CONTAINER:/tmp/wf.json" "$STAGE/workflows.json" && docker exec "$N8N_CONTAINER" rm -f /tmp/wf.json \
      || log "  (workflow export failed - non-fatal: the database dump is the real backup)"
  fi
else
  docker exec "$N8N_CONTAINER" n8n export:workflow --all --output=/tmp/wf.json >/dev/null 2>&1 \
    && docker cp "$N8N_CONTAINER:/tmp/wf.json" "$STAGE/workflows.json" && docker exec "$N8N_CONTAINER" rm -f /tmp/wf.json || true
fi

log "exporting credentials (encrypted at rest)"
docker exec "$N8N_CONTAINER" n8n export:credentials --backup --output=/tmp/cred >/dev/null 2>&1 \
  && docker cp "$N8N_CONTAINER:/tmp/cred" "$STAGE/credentials" && docker exec "$N8N_CONTAINER" rm -rf /tmp/cred \
  || docker exec "$N8N_CONTAINER" n8n export:credentials --all --output=/tmp/cred.json >/dev/null 2>&1 \
     && docker cp "$N8N_CONTAINER:/tmp/cred.json" "$STAGE/credentials.json" && docker exec "$N8N_CONTAINER" rm -f /tmp/cred.json \
     || log "  (credentials export failed - non-fatal, DB dump already contains them)"

if [ "$INCLUDE_DECRYPTED" = "1" ]; then
  log "INCLUDE_DECRYPTED=1 -> writing PLAINTEXT credentials into $OUT"
  cat >&2 <<'EOF'
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  WARNING: a decrypted credentials file contains every API key,
  OAuth token and password in clear text. Only enable this if you
  encrypt the offsite copy (OFFSITE_ENCRYPT_NAME) or store backups
  on an encrypted disk. Delete the file right after a migration:
     shred -u <backup>/credentials-decrypted.json
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EOF
  docker exec "$N8N_CONTAINER" n8n export:credentials --all --decrypted --output=/tmp/credd.json >/dev/null 2>&1 \
    && docker cp "$N8N_CONTAINER:/tmp/credd.json" "$STAGE/credentials-decrypted.json" \
    && docker exec "$N8N_CONTAINER" rm -f /tmp/credd.json \
    && chmod 600 "$STAGE/credentials-decrypted.json" || log "  (decrypted export failed)"
fi

# ---- 6. manifest + checksum ----
cat > "$STAGE/MANIFEST.txt" <<EOF
n8n backup manifest
===================
created:      $TS
n8n version:  $(docker exec "$N8N_CONTAINER" n8n --version 2>/dev/null || echo unknown)
db type:      $DB_MODE
host:         $(hostname)
key source:   $KEY_SRC
files:
$(cd "$STAGE" && find . -type f | sort | sed 's/^/  /')

RESTORE ORDER MATTERS:
  1) put ENCRYPTION_KEY.txt into .env as N8N_ENCRYPTION_KEY  (before first start!)
  2) restore the database   (database.dump / database.sqlite)
  3) restore the data volume (n8n-data.tar.gz)
  4) start n8n, open one credential, run one test execution
If you restore the DB WITHOUT the matching key, n8n starts happily and every
workflow fails with "Credentials could not be decrypted".
EOF
( cd "$STAGE" && tar czf "$OUT/backup.tar.gz" . )
( cd "$OUT" && sha256sum backup.tar.gz > SHA256SUMS.txt && du -h backup.tar.gz | awk '{print $1}' > SIZE.txt )
log "archive: $OUT/backup.tar.gz ($(cat "$OUT/SIZE.txt"))"

# ---- 7. offsite copy ----
if [ -n "$OFFSITE_REMOTE" ] && command -v rclone >/dev/null 2>&1; then
  DEST="$OFFSITE_REMOTE/$TS"
  [ -n "$OFFSITE_ENCRYPT_NAME" ] && DEST="$OFFSITE_ENCRYPT_NAME/$TS"
  log "uploading to $DEST"
  rclone copy --max-transfer 2G --timeout 10m "$OUT" "$DEST" || log "  offsite upload failed (local copy still saved)"
fi

# ---- 8. retention ----
log "pruning archives older than $RETENTION_DAYS days"
find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -mtime +"$RETENTION_DAYS" -exec rm -rf {} + 2>/dev/null || true
[ -n "${KEEP_LATEST_MARKERS:-1}" ] && ln -sfn "$OUT" "$BACKUP_ROOT/latest"

# ---- 9. monitoring ping ----
if [ -n "$HEALTHCHECK_UUID" ] && command -v curl >/dev/null 2>&1; then
  curl -fsS -m 20 "https://hc-ping.com/$HEALTHCHECK_UUID" >/dev/null 2>&1 || true
fi

echo "STATUS=OK $TS key=$KEY_SRC size=$(cat "$OUT/SIZE.txt") path=$OUT" >> "${BACKUP_ROOT}/n8n-backup.log" 2>/dev/null || true
log "DONE. Backup is at $OUT"
log "Prove it restores:  bash 04-restore-drill.sh"
