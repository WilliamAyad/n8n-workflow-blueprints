# Scripts reference

All scripts read `/etc/n8n-backup.env` if it exists (copy `n8n-backup.defaults` there), so you never edit a script to configure it. Every script is safe to re-run.

| File | Does | Needs sudo? |
|---|---|---|
| `01-preflight-check.sh` | Read-only health check of your instance. Lists OK / WARN / FAIL. Exit code 1 if anything FAILs. | no (some checks see more with sudo) |
| `02-backup.sh` | One dated folder: key + DB dump + volume tar + compose/.env (secrets masked) + workflow/credential JSON + checksums + manifest. Prunes old folders, optional offsite upload, optional monitoring ping. | yes |
| `03-restore.sh` | Restores a folder. `MODE=json` (default, additive), `MODE=volume`, `MODE=database`. | yes |
| `04-restore-drill.sh` | Boots an isolated throwaway n8n, imports your latest backup, walks you through verification, destroys itself. Production untouched. | yes |
| `05-offsite.sh` | `setup` mode = configure rclone + crypt wrapper. Default mode = push backup folders off the server. | setup: yes / sync: no |

## Handy invocations

```bash
# what does the preflight say about my current instance?
bash 01-preflight-check.sh

# back up into a different folder (dry-ish test on a machine with a small disk)
sudo BACKUP_ROOT=/home/me/n8n-backups bash 02-backup.sh

# include a plaintext credential export (encrypted offsite only!)
sudo INCLUDE_DECRYPTED=1 bash 02-backup.sh

# restore a specific night, non-interactive (automation / drill scripting)
sudo FORCE=1 MODE=database bash 03-restore.sh /var/backups/n8n/20260901T031700Z

# drill but keep the stack running so you can poke at it
sudo KEEP=1 bash 04-restore-drill.sh
# ... then clean up manually:
cd ~/n8n-drill && docker compose down -v && cd .. && rm -rf ~/n8n-drill

# only sync today's folder offsite
sudo OFFSITE_REMOTE=n8n-b2: bash 05-offsite.sh sync
```

## Two crontab lines (the standard install)

```cron
17 3 * * * /usr/bin/env bash -c 'cd /opt/n8n/scripts && ./02-backup.sh >> /var/log/n8n-backup.log 2>&1'
43 3 * * * /usr/bin/env bash -c 'cd /opt/n8n/scripts && ./05-offsite.sh >> /var/log/n8n-backup.log 2>&1'
```

## What the scripts touch on your server

- `02` writes: `/var/backups/n8n/<TIMESTAMP>/{backup.tar.gz,SHA256SUMS.txt,SIZE.txt}`, `latest` symlink, `n8n-backup.log`.
- `02` runs inside the n8n container: `printenv`, `cat /home/node/.n8n/config`, `n8n export:*` into `/tmp` inside the container, then removes those temp files.
- `02` reads: `docker exec`, `docker cp`, `docker volume inspect`, `pg_dump` inside the postgres container, your `docker-compose.yml` and `.env` (copies, with secrets masked in the **copy**).
- `03`/`04` additionally: `docker cp` + `n8n import:*` (writes data into the instance you point at), and `04` creates/removes its own containers + volumes named `n8n-drill*`.
- Nothing in this kit edits your real `.env` or compose file. It never needs `rm -rf` on your data folders. Readable, 100% local, no network calls except your chosen storage backend and an optional `hc-ping.com` HTTPS ping.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `container 'n8n' is not running` | Your container has another name. `docker ps` → set `N8N_CONTAINER=` in `/etc/n8n-backup.env`. |
| `could not read an encryption key from anywhere` | Volume isn't persisted, or n8n never wrote a config. Read `02-HOW-SETUP.md` step 2 + the "already live" notes. This is exactly the situation the kit exists for. |
| `pg_dump failed` | Wrong `DB_CONTAINER`/`DB_USER`/`DB_NAME`, or Postgres image uses PGPASSWORD auth. Test manually: `docker exec <db> pg_dump -U n8n -d n8n -Fc -f /tmp/t.dump`. |
| `sqlite3 not available in the image` | Some images lack the binary. Fallback printed by the script: `docker cp n8n:/home/node/.n8n/database.sqlite .` — then put that file into the archive folder manually. |
| workflows/credentials export steps fail | Your n8n version doesn't support `--backup`. Set `EXPORT_SEPARATE=0` to use `--all --output=file.json`. Not fatal: the DB dump remains the authoritative backup. |
| `no volume named ... detected` | Bind mount instead of a named volume. Script auto-falls back to `--volumes-from`. Set `DATA_VOLUME` explicitly if you want the tar to be identical across runs. |
| drill: `drill instance did not become ready` | Port 5678 taken, or no outbound network for the n8n image pull. `DRILL_PORT=5699 sudo -E bash 04-restore-drill.sh`; check `docker compose logs --tail=40 n8n` in `~/n8n-drill`. |
| cron job never runs | cron has a tiny `PATH` and no `docker` in it. That's why the crontab lines above use an absolute `/usr/bin/env bash -c` and full paths. Verify: `sudo crontab -l`, then `grep n8n-backup /var/log/syslog`. |
| offsite upload fails but local backup is fine | Intentional — the script keeps the local copy and marks `STATUS=WARN`. Test the remote alone: `rclone lsd n8n-b2:`. |

## Restoring onto a *different* n8n version

Workflows and credentials restore across versions via JSON in the great majority of cases (node parameter renames are the usual snag — n8n shows a warning and you re-pick the field). A full database dump restore onto a *newer* n8n runs pending migrations automatically on boot; onto an *older* n8n than the one that wrote the dump, don't — restore JSON instead, or match versions. The drill is cheap: run it once after every n8n upgrade.
