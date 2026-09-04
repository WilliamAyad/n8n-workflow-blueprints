#!/usr/bin/env bash
# ============================================================
#  Bulletproof Self-Hosted n8n - Restore
#  Three modes:
#    A) JSON path (recommended, works even on a brand-new empty instance)
#    B) volume path (put the .n8n data volume back as it was)
#    C) database path (full fidelity: users, execution history, tags)
#
#  Usage:
#    sudo bash 03-restore.sh                       # newest backup (BACKUP_ROOT/latest), guided
#    sudo bash 03-restore.sh /var/backups/n8n/20260901T020000Z
#    MODE=volume sudo bash 03-restore.sh
#    MODE=database sudo bash 03-restore.sh
#    FORCE=1 ... # for scripted drills / automation (skips the YES prompt)
#
#  THE GOLDEN RULE: on the target instance, set N8N_ENCRYPTION_KEY to the
#  key from the backup BEFORE n8n ever starts there. Wrong key + restored
#  credentials = permanently unreadable secrets.
# ============================================================
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/etc/n8n-backup.env}"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

: "${BACKUP_ROOT:=/var/backups/n8n}"
: "${STACK_DIR:=/opt/n8n}"
: "${N8N_SERVICE:=n8n}"
: "${N8N_CONTAINER:=n8n}"
: "${DB_CONTAINER:=n8n-postgres-1}"
: "${DB_USER:=n8n}"
: "${DB_NAME:=n8n}"
: "${MODE:=json}"                          # json | volume | database
: "${FORCE:=0}"

SRC="${1:-$BACKUP_ROOT/latest}"
[ -L "$SRC" ] && SRC="$(readlink -f "$SRC")"
[ -d "$SRC" ] || { echo "[ERROR] backup folder not found: $SRC"; echo "pass a folder path as the first argument, e.g. $BACKUP_ROOT/20260901T020000Z"; exit 1; }

WORK="$(mktemp -d /tmp/n8n-restore.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
go()  { printf '\n  \033[36m$ %s\033[0m\n' "$*"; }

say "restore source"
echo "  $SRC"
ls -1 "$SRC" 2>/dev/null | sed 's/^/    /' || true

# ---- step 0: the archive inside the folder ----
if [ -f "$SRC/backup.tar.gz" ]; then
  say "unpacking archive"
  tar xzf "$SRC/backup.tar.gz" -C "$WORK"
  SRC="$WORK"
fi

# ---- step 1: the key ----
say "1. encryption key (do this FIRST, before starting n8n on the target)"
if [ -f "$SRC/ENCRYPTION_KEY.txt" ] && [ -s "$SRC/ENCRYPTION_KEY.txt" ]; then
  echo "  found in the backup: $(cut -c1-8 "$SRC/ENCRYPTION_KEY.txt")… ($(wc -c < "$SRC/ENCRYPTION_KEY.txt" | tr -d ' ') chars)"
  cp "$SRC/ENCRYPTION_KEY.txt" "$STACK_DIR/RESTORE-ENCRYPTION_KEY.txt" 2>/dev/null \
    && chmod 600 "$STACK_DIR/RESTORE-ENCRYPTION_KEY.txt" \
    && echo "  copied to $STACK_DIR/RESTORE-ENCRYPTION_KEY.txt for you"
  echo
  go "cd $STACK_DIR && printf 'N8N_ENCRYPTION_KEY=%s\n' \"\$(cat RESTORE-ENCRYPTION_KEY.txt)\" >> .env"
  go "docker compose up -d   # so the key is live before anything is imported"
  if [ "$MODE" = "json" ]; then
    echo
    echo "  If this target instance ALREADY has credentials saved under a different key,"
    echo "  imported credentials will fail to decrypt. Restore JSON into an instance that"
    echo "  either has no credentials yet, or runs with the key above."
  fi
else
  echo "  \033[33mno ENCRYPTION_KEY.txt in this backup.\033[0m"
  echo "  Restoring credentials is impossible for this archive - workflows only."
  echo "  Users will have to reconnect every credential once (a few minutes each)."
fi

# ---- mode B: data volume ----
if [ "$MODE" = "volume" ]; then
  say "MODE=volume - replacing the n8n data volume"
  VOL=""
  if docker ps --format '{{.Names}}' | grep -qx "$N8N_CONTAINER"; then
    VOL="$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/home/node/.n8n"}}{{.Name}}{{end}}{{end}}' "$N8N_CONTAINER" 2>/dev/null || true)"
  fi
  [ -n "$VOL" ] || { echo "  could not auto-detect the volume - set DATA_VOLUME=n8n_n8n_data and re-run"; exit 1; }
  if [ ! -f "$SRC/n8n-data.tar.gz" ]; then echo "  n8n-data.tar.gz missing in backup"; exit 1; fi
  echo "  target volume: $VOL   (n8n will be stopped; existing data overwritten)"
  [ "$FORCE" = "1" ] || { printf '  type YES to continue: '; read -r A; [ "$A" = "YES" ] || { echo "  aborted, nothing changed"; exit 0; }; }
  docker compose -f "$STACK_DIR/docker-compose.yml" stop "$N8N_SERVICE" 2>/dev/null || docker stop "$N8N_CONTAINER"
  docker run --rm -v "$VOL":/data alpine sh -c 'rm -rf /data/* /data/..?* 2>/dev/null; true'
  docker run --rm -v "$VOL":/data -v "$SRC":/backup alpine tar xzf /backup/n8n-data.tar.gz -C /data
  docker compose -f "$STACK_DIR/docker-compose.yml" up -d "$N8N_SERVICE" 2>/dev/null || docker start "$N8N_CONTAINER"
  echo "  done - verify a credential opens and one workflow runs."
  exit 0
fi

# ---- mode C: database ----
if [ "$MODE" = "database" ]; then
  say "MODE=database - restoring the PostgreSQL dump"
  DUMP=""
  [ -f "$SRC/database.dump" ] && DUMP="$SRC/database.dump"
  [ -f "$SRC/database.sqlite" ] && DUMP="$SRC/database.sqlite"
  [ -n "$DUMP" ] || { echo "  no database dump in this backup"; exit 1; }
  echo "  This OVERWRITES every workflow, credential, user and setting in '$DB_NAME'."
  [ "$FORCE" = "1" ] || { printf '  type YES to continue: '; read -r A; [ "$A" = "YES" ] || { echo "  aborted"; exit 0; }; }
  if [[ "$DUMP" == *.dump ]]; then
    docker compose -f "$STACK_DIR/docker-compose.yml" stop "$N8N_SERVICE" 2>/dev/null || docker stop "$N8N_CONTAINER" || true
    docker cp "$DUMP" "$DB_CONTAINER":/tmp/restore.dump
    go "docker exec $DB_CONTAINER pg_restore -U $DB_USER -d $DB_NAME --clean --if-exists /tmp/restore.dump"
    docker exec "$DB_CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists /tmp/restore.dump || \
      echo "  (pg_restore reported issues - often the --clean drops on objects that don't exist yet; check the UI)"
    docker exec "$DB_CONTAINER" rm -f /tmp/restore.dump
    docker compose -f "$STACK_DIR/docker-compose.yml" up -d "$N8N_SERVICE" 2>/dev/null || docker start "$N8N_CONTAINER" || true
  else
    echo "  SQLite: copy the file into place and restart:"
    go "docker cp '$DUMP' $N8N_CONTAINER:/home/node/.n8n/database.sqlite"
    go "docker restart $N8N_CONTAINER"
  fi
  echo
  echo "  Final check: open any credential -> if it says 'Credentials could not be decrypted',"
  echo "  the key on this instance is wrong. Put the backup's key in .env and restart."
  exit 0
fi

# ---- mode A (default): JSON path - safest on a fresh instance ----
say "2. importing workflows and credentials (JSON path - additive, nothing is deleted)"
CRED_DIR="$SRC/credentials"; [ -d "$CRED_DIR" ] || CRED_DIR=""
CRED_FILE="$SRC/credentials.json"; [ -f "$CRED_FILE" ] || CRED_FILE=""
WF_DIR="$SRC/workflows"; [ -d "$WF_DIR" ] || WF_DIR=""
WF_FILE="$SRC/workflows.json"; [ -f "$WF_FILE" ] || WF_FILE=""

if [ -n "$CRED_DIR" ] || [ -n "$CRED_FILE" ]; then
  T="$(basename "${CRED_DIR:-$CRED_FILE}")"
  docker cp "${CRED_DIR:-$CRED_FILE}" "$N8N_CONTAINER:/tmp/$T"
  if [ -n "$CRED_DIR" ]; then
    go "docker exec $N8N_CONTAINER n8n import:credentials --separate --input=/tmp/$T"
    docker exec "$N8N_CONTAINER" n8n import:credentials --separate --input="/tmp/$T"
  else
    go "docker exec $N8N_CONTAINER n8n import:credentials --input=/tmp/$T"
    docker exec "$N8N_CONTAINER" n8n import:credentials --input="/tmp/$T"
  fi
  docker exec "$N8N_CONTAINER" rm -rf "/tmp/$T"
else
  echo "  no credentials export in this backup - skipped"
fi

if [ -n "$WF_DIR" ] || [ -n "$WF_FILE" ]; then
  T="$(basename "${WF_DIR:-$WF_FILE}")"
  docker cp "${WF_DIR:-$WF_FILE}" "$N8N_CONTAINER:/tmp/$T"
  if [ -n "$WF_DIR" ]; then
    go "docker exec $N8N_CONTAINER n8n import:workflow --separate --input=/tmp/$T"
    docker exec "$N8N_CONTAINER" n8n import:workflow --separate --input="/tmp/$T"
  else
    go "docker exec $N8N_CONTAINER n8n import:workflow --input=/tmp/$T"
    docker exec "$N8N_CONTAINER" n8n import:workflow --input="/tmp/$T"
  fi
  docker exec "$N8N_CONTAINER" rm -rf "/tmp/$T"
  echo "  imported workflows come in DEACTIVATED on purpose. Open them, check the"
  echo "  credential selector, then activate the ones you want running again."
else
  echo "  no workflow export in this backup - skipped"
fi

say "verification checklist (5 minutes, do it now)"
cat <<'EOF'
  [ ] 1. Open n8n UI -> Credentials -> open any credential -> "Test".
         Success = the key is right. Failure = wrong key, stop and fix .env.
  [ ] 2. Open your most critical workflow -> Execute one node / run it once.
  [ ] 3. Count workflows in the UI vs your records (a spreadsheet, your client list).
  [ ] 4. Confirm each restored workflow points at YOUR credentials, not a
         previous instance's (names can collide; IDs overwrite on import).
  [ ] 5. Delete the temp files:  shred -u RESTORE-ENCRYPTION_KEY.txt  (after saving the key in your password manager)
EOF
echo
echo "Restore finished. If anything above failed, open 03-HOW-RESTORE.md."
