#!/usr/bin/env bash
# ============================================================
#  Bulletproof Self-Hosted n8n - Offsite sync (the independent failure mode)
#
#  Why this file exists: a backup on the same disk as the server is not a
#  backup. Disk death, a deleted folder, a ransomware pass or a terminated
#  VPS account take the server AND its backups together.
#
#  Two layers, and you should use both:
#    1) rclone copy  -> the storage provider's own versioning protects you
#    2) rclone crypt -> nobody else can read your credentials dump, not even
#       the storage provider
#
#  Usage:
#    bash 05-offsite.sh setup            # interactive, configures everything
#    bash 05-offsite.sh             # push latest backups off the server
#    OFFSITE_ENCRYPT_NAME=n8n-crypt: bash 02-backup.sh   # or bake it into 02
# ============================================================
set -euo pipefail

: "${BACKUP_ROOT:=/var/backups/n8n}"
[ -d "$BACKUP_ROOT" ] || BACKUP_ROOT="$HOME/n8n-backups"
: "${OFFSITE_REMOTE:=}"
: "${OFFSITE_ENCRYPT_NAME:=}"

have() { command -v "$1" >/dev/null 2>&1; }

if [ "${1:-sync}" = "setup" ]; then
  echo "== installing rclone if needed =="
  if ! have rclone; then
    echo "  rclone is not installed. Install it with:"
    echo "    curl -sL https://rclone.org/install.sh | sudo bash"
    exit 1
  fi

  echo
  echo "== step 1: choose a bucket =="
  cat <<'EOF'
  Anything that supports S3-compatible or object storage works. Cost is pennies:
    Backblaze B2  ~$0.005 / GB / month  (first 10 GB free)   <- simplest
    Cloudflare R2  free egress, $0.015 / GB / month
    Wasabi         flat, no egress fees
    Hetzner S3     good if your VPS is already there
  Create an app key with *read/write* on a single private bucket named e.g. n8n-backups.
EOF

  echo
  echo "== step 2: rclone config (plaintext remote) =="
  echo "  name: n8n-b2   storage: b2 (or s3)   then paste key id + secret + bucket"
  rclone config
  OFFSITE="${OFFSITE_REMOTE:-n8n-b2:}"

  echo
  echo "== step 3: wrap it in encryption so the provider never sees your secrets =="
  echo "  You will be asked for a password. THIS PASSWORD IS NOW AS IMPORTANT AS"
  echo "  THE ENCRYPTION KEY: without it, your backups are unreadable. Put both"
  echo "  in your password manager, in the same secure note."
  rclone config create n8n-crypt crypt remote="$OFFSITE/n8n" filename_encryption=obfuscate dir_encryption=obfuscate \
    data_encryption=true --interactive 2>/dev/null || rclone config

  cat <<EOF

  Done. Now make these two lines live for the backup script:
    sudo mkdir -p /etc
    printf 'OFFSITE_REMOTE=%s\nOFFSITE_ENCRYPT_NAME=n8n-crypt:\n' "$OFFSITE" | sudo tee -a /etc/n8n-backup.env

  Verify:
    bash 05-offsite.sh
    rclone ls n8n-crypt: | head
EOF
  exit 0
fi

# ------------------------- sync mode -------------------------
if ! have rclone; then
  echo "[skip] rclone not installed - offsite copies are the whole point, install it (see setup mode)"
  exit 0
fi
if [ -z "$OFFSITE_REMOTE" ]; then
  echo "[skip] OFFSITE_REMOTE is empty - run:  bash 05-offsite.sh setup setup"
  exit 0
fi

echo "== syncing $BACKUP_ROOT -> ${OFFSITE_ENCRYPT_NAME:-$OFFSITE_REMOTE} =="
FAILED=0
for d in $(ls -1d "$BACKUP_ROOT"/*/ 2>/dev/null | sort); do
  name="$(basename "${d%/}")"
  case "$name" in latest) continue ;; esac
  dest="${OFFSITE_ENCRYPT_NAME:-$OFFSITE_REMOTE}/$name"
  if rclone check "$d" "$dest" --one-side local >/dev/null 2>&1; then
    echo "  already there: $name"
    continue
  fi
  if rclone copy "$d" "$dest" --transfers 4 --timeout 5m; then
    echo "  uploaded: $name"
  else
    echo "  FAILED: $name (keeping local copy; will retry next run)"
    FAILED=1
  fi
done

if [ "$FAILED" = "1" ]; then
  echo "STATUS=WARN offsite sync had failures $(date -u +%Y%m%dT%H%M%SZ)" >> "$BACKUP_ROOT/n8n-backup.log" 2>/dev/null || true
  exit 1
fi
echo "STATUS=OK offsite sync $(date -u +%Y%m%dT%H%M%SZ)" >> "$BACKUP_ROOT/n8n-backup.log" 2>/dev/null || true
echo "offsite sync complete"
