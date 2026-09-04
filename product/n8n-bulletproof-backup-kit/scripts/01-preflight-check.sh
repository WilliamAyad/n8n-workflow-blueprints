#!/usr/bin/env bash
# ============================================================
#  Bulletproof Self-Hosted n8n - Preflight Check
#  Tells you in 10 seconds whether your instance is safe.
#  Read-only: it changes nothing.
#  Usage:  bash 01-preflight-check.sh
# ============================================================
set -uo pipefail

N8N_DATA_DIR="${N8N_DATA_DIR:-$HOME/.n8n}"
STACK_DIR="${STACK_DIR:-$(pwd)}"
N8N_CONTAINER="${N8N_CONTAINER:-n8n}"
DB_CONTAINER="${DB_CONTAINER:-n8n-postgres-1}"

PASS=0; WARN=0; FAIL=0
RUNNING=0
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "=============================================================="
echo " n8n SURVIVAL CHECK - $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================================="
echo " checked paths: data dir=$N8N_DATA_DIR  stack=$STACK_DIR"
echo

# ---- 1. Docker present and n8n running ----
if ! command -v docker >/dev/null 2>&1; then
  bad "docker is not installed or not in PATH (this kit targets a Docker install)"
else
  ok "docker found: $(docker --version 2>/dev/null | head -1)"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$N8N_CONTAINER"; then
    ok "container '$N8N_CONTAINER' is running"
    RUNNING=1
  else
    warn "no running container named '$N8N_CONTAINER' (set N8N_CONTAINER=... if yours differs)"
    RUNNING=0
  fi
fi

# ---- 2. The encryption key: the one thing that makes credentials unrecoverable ----
echo
echo "[1/5] Encryption key"
KEY_IN_ENV=0
if [ "$RUNNING" = "1" ] && docker exec "$N8N_CONTAINER" printenv N8N_ENCRYPTION_KEY >/dev/null 2>&1; then
  ok "N8N_ENCRYPTION_KEY is set as an environment variable (survives container rebuilds)"
  KEY_IN_ENV=1
fi
if [ -f "$N8N_DATA_DIR/config" ]; then
  if grep -q 'encryptionKey' "$N8N_DATA_DIR/config" 2>/dev/null; then
    ok "encryptionKey found in $N8N_DATA_DIR/config"
  fi
else
  warn "no config file at $N8N_DATA_DIR/config"
fi
if [ "$KEY_IN_ENV" = "0" ] && [ ! -f "$N8N_DATA_DIR/config" ]; then
  bad "KEY ONLY AUTO-GENERATED INSIDE THE CONTAINER - if the volume is lost, every stored credential becomes permanently unreadable"
  echo "        fix: set N8N_ENCRYPTION_KEY in .env BEFORE you create more credentials (see 02-HOW-SETUP.md)"
elif [ "$KEY_IN_ENV" = "0" ]; then
  bad "no N8N_ENCRYPTION_KEY env var (works only while the volume lives; set it explicitly for safety)"
fi

# ---- 3. Volume persistence ----
echo
echo "[2/5] Volume persistence"
if [ "$RUNNING" = "1" ]; then
  MOUNTS=$(docker inspect -f '{{range .Mounts}}{{.Type}} {{.Destination}}{{println}}{{end}}' "$N8N_CONTAINER" 2>/dev/null)
  if echo "$MOUNTS" | grep -q '/home/node/.n8n'; then
    ok "n8n data directory is mounted (won't be wiped by container recreation)"
  else
    bad "/home/node/.n8n is NOT a mount - every restart can erase workflows settings and the key"
  fi
  if echo "$MOUNTS" | grep -qE 'bind|volume'; then
    :
  else
    warn "no bind/volume mounts detected at all"
  fi
else
  warn "skipped (n8n container not running)"
fi

# ---- 4. Database ----
echo
echo "[3/5] Database"
if [ "$RUNNING" = "1" ]; then
  DBMODE=$(docker exec "$N8N_CONTAINER" printenv DB_TYPE 2>/dev/null || echo "")
  case "$DBMODE" in
    postgresdb) ok "using PostgreSQL (recommended for production)" ;;
    ""|sqlite)  warn "using SQLite (default). Fine for one person; see 02-HOW-SETUP.md section 'SQLite mode'" ;;
    *)          warn "DB_TYPE=$DBMODE - check the backup script covers it" ;;
  esac
else
  warn "skipped (n8n container not running)"
fi

# ---- 5. Backups on disk + offsite ----
echo
echo "[4/5] Backups"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/n8n}"
[ -d "$BACKUP_ROOT" ] || BACKUP_ROOT="$HOME/n8n-backups"
if [ -d "$BACKUP_ROOT" ]; then
  CNT=$(find "$BACKUP_ROOT" -maxdepth 2 -type f \( -name '*.tar.gz' -o -name '*.dump' \) 2>/dev/null | wc -l | tr -d ' ')
  NEWEST=$(find "$BACKUP_ROOT" -maxdepth 2 -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  SIZE=$(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
  if [ "${CNT:-0}" -gt 0 ]; then
    ok "$CNT backup file(s), $SIZE total in $BACKUP_ROOT"
    echo "        newest: ${NEWEST:-none}"
    AGE_DAYS=999
    if [ -n "${NEWEST:-}" ]; then
      AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$NEWEST" 2>/dev/null || echo 0) ) / 86400 ))
    fi
    if [ "$AGE_DAYS" -gt 2 ]; then
      bad "newest backup is $AGE_DAYS day(s) old - stale backups are not backups"
    elif [ "$AGE_DAYS" -le 2 ]; then
      ok "newest backup is $AGE_DAYS day(s) old (fresh)"
    fi
  else
    bad "backup folder exists but contains no archives: $BACKUP_ROOT"
  fi
else
  bad "no backup folder found (tried /var/backups/n8n and ~/n8n-backups)"
  echo "        fix: run 02-backup.sh once (see ../README-KIT.md)"
fi

echo
echo "[5/5] Offsite copy + cron + restore drill"
if command -v rclone >/dev/null 2>&1; then
  ok "rclone installed - offsite sync available (OFFSITE_REMOTE in 02-backup.sh)"
else
  warn "rclone not installed - backups live on the SAME disk as the server (one dead disk = total loss)"
  echo "        fix: curl -sL https://rclone.org/install.sh | sudo bash"
fi
if crontab -l 2>/dev/null | grep -qE '(02-backup|n8n-backup)\.sh'; then
  ok "daily cron job registered"
  LASTLOG=$(grep -h 'STATUS=OK' /var/log/n8n-backup.log 2>/dev/null | tail -1 || true)
  [ -n "$LASTLOG" ] && ok "last successful run: $(echo "$LASTLOG" | cut -c1-60)"
else
  warn "no cron entry for n8n-backup yet (see ../README-KIT.md "Fastest possible path")"
fi
if [ -f "$HOME/.n8n-last-drill" ]; then
  DRILL_AGE=$(( ( $(date +%s) - $(stat -c %Y "$HOME/.n8n-last-drill" 2>/dev/null || echo 0) ) / 86400 ))
  if [ "$DRILL_AGE" -le 90 ]; then
    ok "restore drill completed $DRILL_AGE day(s) ago"
  else
    bad "last restore drill was $DRILL_AGE days ago - untested backups are not backups (run 04-restore-drill.sh)"
  fi
else
  bad "you have never proved a restore works - run 04-restore-drill.sh (5 minutes, zero risk)"
fi

echo
echo "=============================================================="
printf " RESULT:  %s OK  /  %s WARN  /  %s FAIL\n" "$PASS" "$WARN" "$FAIL"
echo "=============================================================="
if [ "$FAIL" -gt 0 ]; then
  echo " Fix the FAIL items today. Each one is a way people lose their whole"
  echo " n8n instance. The handbook (02-HOW-SETUP.md) walks through every fix."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo " You are mostly protected. Clear the WARNs when convenient."
  exit 0
else
  echo " Your instance is hardened. Re-run this after any server change."
  exit 0
fi
