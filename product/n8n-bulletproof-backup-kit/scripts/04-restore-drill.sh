#!/usr/bin/env bash
# ============================================================
#  Bulletproof Self-Hosted n8n - RESTORE DRILL
#  Proves your backup actually restores, without touching production.
#  Brings up a throwaway n8n on port 5678 with its own empty database,
#  imports your latest backup into it, verifies it, then destroys it.
#
#  Usage:   sudo bash 04-restore-drill.sh
#  Time:    about 5 minutes. Run it every quarter. Mark your calendar.
#
#  Why:     "untested backups are not backups." The people who lose n8n
#  instances almost always HAD a backup - they had just never restored it.
# ============================================================
set -uo pipefail

DRILL_DIR="${DRILL_DIR:-$HOME/n8n-drill}"
DRILL_PORT="${DRILL_PORT:-5678}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/n8n}"
[ -d "$BACKUP_ROOT" ] || BACKUP_ROOT="$HOME/n8n-backups"
KEY_FILE_HINT=""
DRILL_IMAGE="${DRILL_IMAGE:-docker.n8n.io/n8nio/n8n:latest}"
KEEP="${KEEP:-0}"
PASS=0; FAIL=0

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mOK\033[0m   %s\n' "$*"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }

say "0. pick the backup to test"
if [ ! -d "$BACKUP_ROOT" ]; then echo "  no backup folder at $BACKUP_ROOT - run 02-backup.sh first"; exit 1; fi
LATEST="$(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort | tail -1)"
LATEST="${LATEST%/}"
[ -n "$LATEST" ] || { echo "  no dated backup folders found in $BACKUP_ROOT"; exit 1; }
echo "  testing: $LATEST"
if [ ! -f "$LATEST/backup.tar.gz" ] && [ ! -f "$LATEST/database.dump" ]; then
  echo "  this folder has no archive inside - is the backup script installed correctly?"; exit 1
fi

WORK="$(mktemp -d /tmp/n8n-drill.XXXXXX)"
if [ -f "$LATEST/backup.tar.gz" ]; then
  tar xzf "$LATEST/backup.tar.gz" -C "$WORK" || { echo "  could not unpack backup.tar.gz - is it truncated? check: tar tzf $LATEST/backup.tar.gz"; exit 1; }
else
  echo "  no backup.tar.gz in this folder (older layout?) - reading files directly from the folder"
  cp -a "$LATEST/." "$WORK/" 2>/dev/null
  rm -f "$WORK/n8n-backup.log"          # log file, not part of the payload
fi

say "1. check what the backup contains (a good backup has all four)"
for f in ENCRYPTION_KEY.txt n8n-data.tar.gz; do
  [ -s "$WORK/$f" ] && ok "$f present" || bad "$f missing or empty"
done
if [ -f "$WORK/database.dump" ] || [ -f "$WORK/database.sqlite" ]; then ok "database dump present"; else bad "database dump missing"; fi
if [ -d "$WORK/workflows" ] || [ -f "$WORK/workflows.json" ]; then
  N=$( { find "$WORK/workflows" -name '*.json' 2>/dev/null || ls "$WORK/workflows.json" 2>/dev/null; } | wc -l | tr -d ' ')
  ok "workflow exports present ($N file(s))"
else
  bad "no workflow JSON exports (still restorable from the database dump)"
fi
if [ -d "$WORK/credentials" ] || [ -f "$WORK/credentials.json" ]; then ok "credentials export present"; else bad "credentials export missing"; fi

say "2. prepare a clean, isolated drill folder (production is NOT touched)"
mkdir -p "$DRILL_DIR"
cd "$DRILL_DIR"
KEY="$(cat "$WORK/ENCRYPTION_KEY.txt" 2>/dev/null || true)"
if [ -z "$KEY" ]; then
  echo "  no key in the backup: I'll generate a fresh one. Credentials will import but"
  echo "  cannot be decrypted by n8n - that itself is the lesson of this kit."
  KEY="$(openssl rand -hex 32)"
else
  echo "  using the backup's key (correct behaviour: credentials must decrypt)"
fi

cat > docker-compose.yml <<EOF
name: n8n-drill
services:
  n8n:
    image: $DRILL_IMAGE
    restart: unless-stopped
    ports:
      - "127.0.0.1:$DRILL_PORT:5678"
    environment:
      - N8N_ENCRYPTION_KEY=$KEY
      - N8N_SECURE_COOKIE=false
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n_drill
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=drill_password_not_a_secret
    volumes:
      - n8n_drill_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=drill_password_not_a_secret
      - POSTGRES_DB=n8n_drill
    volumes:
      - postgres_drill:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n_drill"]
      interval: 5s
      timeout: 5s
      retries: 20
volumes:
  n8n_drill_data:
  postgres_drill:
EOF
echo "  wrote $DRILL_DIR/docker-compose.yml"

say "3. start the drill stack (first boot can take a minute)"
docker compose up -d >/dev/null 2>&1 || { echo "  docker compose up failed"; exit 1; }
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:$DRILL_PORT/healthz/readiness" >/dev/null 2>&1; then break; fi
  sleep 2
done
if curl -fsS "http://127.0.0.1:$DRILL_PORT/healthz/readiness" >/dev/null 2>&1; then
  ok "drill instance is ready at http://127.0.0.1:$DRILL_PORT"
else
  bad "drill instance did not become ready - see: docker compose logs --tail=40 n8n"
fi

say "4. restore into it (same commands you'd use on a real new server)"
DC="$(docker compose ps -q n8n 2>/dev/null | head -1)"
if [ -n "${DC:-}" ]; then
  IMPORTED_ANY=0
  if [ -d "$WORK/credentials" ]; then
    docker cp "$WORK/credentials" "$DC:/tmp/cred" >/dev/null 2>&1
    docker exec "$DC" n8n import:credentials --separate --input=/tmp/cred >/dev/null 2>&1 \
      && ok "credentials imported" && IMPORTED_ANY=1 || bad "credentials import failed"
    docker exec "$DC" rm -rf /tmp/cred >/dev/null 2>&1
  elif [ -f "$WORK/credentials.json" ]; then
    docker cp "$WORK/credentials.json" "$DC:/tmp/cred.json" >/dev/null 2>&1
    docker exec "$DC" n8n import:credentials --input=/tmp/cred.json >/dev/null 2>&1 \
      && ok "credentials imported" && IMPORTED_ANY=1 || bad "credentials import failed"
    docker exec "$DC" rm -f /tmp/cred.json >/dev/null 2>&1
  fi
  if [ -d "$WORK/workflows" ]; then
    docker cp "$WORK/workflows" "$DC:/tmp/wf" >/dev/null 2>&1
    docker exec "$DC" n8n import:workflow --separate --input=/tmp/wf >/dev/null 2>&1 \
      && ok "workflows imported" && IMPORTED_ANY=1 || bad "workflow import failed"
    docker exec "$DC" rm -rf /tmp/wf >/dev/null 2>&1
  elif [ -f "$WORK/workflows.json" ]; then
    docker cp "$WORK/workflows.json" "$DC:/tmp/wf.json" >/dev/null 2>&1
    docker exec "$DC" n8n import:workflow --input=/tmp/wf.json >/dev/null 2>&1 \
      && ok "workflows imported" && IMPORTED_ANY=1 || bad "workflow import failed"
    docker exec "$DC" rm -f /tmp/wf.json >/dev/null 2>&1
  fi
  [ "$IMPORTED_ANY" = "1" ] || echo "  nothing importable found; the database-dump path is your fallback (03-HOW-RESTORE.md)"
else
  echo "  could not resolve the drill container id; run the import commands from 03-HOW-RESTORE.md manually"
fi

say "5. verify with your own eyes (60 seconds)"
cat <<EOF
  open  http://127.0.0.1:$DRILL_PORT  in your browser
  [ ] create the owner account (fresh instance - it will ask)
  [ ] Credentials -> open one -> Test -> should connect, NOT "could not be decrypted"
  [ ] Workflows -> your list should be there, deactivated
  [ ] open one workflow -> Execute step on a harmless node -> it should run
  If the credential test fails, the key did not match. That is exactly the
  failure this whole kit exists to prevent - and you found it on a drill,
  not on a Tuesday at 2am with a client waiting.
EOF
read -r -p "  Did the credential test succeed? (y/n) " ANS || ANS=n
if [ "$ANS" = "y" ] || [ "$ANS" = "Y" ]; then ok "human verification passed"; else bad "human verification failed - read 03-HOW-RESTORE.md"; fi

say "6. tear down (nothing of yours stays on this machine)"
if [ "$KEEP" = "1" ]; then
  echo "  KEEP=1 -> leaving the drill stack running. Destroy it later with:"
  echo "     cd $DRILL_DIR && docker compose down -v && rm -rf $DRILL_DIR"
else
  docker compose down -v >/dev/null 2>&1 || true
  rm -rf "$DRILL_DIR" "$WORK"
  echo "  drill containers, volumes and files removed"
fi

if [ "$FAIL" -eq 0 ]; then
  date -u +%Y%m%dT%H%M%SZ > "$HOME/.n8n-last-drill"
  echo
  echo "  \033[32mDRILL PASSED\033[0m  ($(date -u +%Y-%m-%d)) - recorded in ~/.n8n-last-drill"
  echo "  Your preflight check will now show a fresh drill date. Next one: quarter from now."
  echo
  echo "  Optional, and worth it: email the last line of this output to yourself or your"
  echo "  client. A dated proof of a successful restore is the difference between an"
  echo "  opinion and a deliverable."
  exit 0
else
  echo
  echo "  \033[31mDRILL FOUND PROBLEMS\033[0m - fix them while it is cheap. See 04-HOW-RUN-FOREVER.md"
  exit 1
fi
