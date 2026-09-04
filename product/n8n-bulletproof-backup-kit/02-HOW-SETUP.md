# 02 · Setup in 25 minutes (no coding)

**Prerequisites:** a Linux VPS (Ubuntu 22.04/24.04 or Debian 12), 1GB+ RAM, root or sudo access, and Docker installed. If Docker isn't there yet:
```bash
curl -fsSL https://get.docker.com | sudo sh
```

> If n8n is **already running** on this server, that's fine — steps 1–4 apply as-is. Skip to the notes at the bottom before you touch anything, and run the preflight first: `bash scripts/01-preflight-check.sh`.

---

## Step 1 — Create the project folder (2 min)

```bash
sudo mkdir -p /opt/n8n
cd /opt/n8n
sudo chown -R "$USER":"$USER" /opt/n8n
```

**Why `/opt`:** it's a stable path that survives you rebuilding containers, and it keeps backups and compose files out of your home directory (where a user deletion would take them with it).

---

## Step 2 — Generate the encryption key, and write `.env` (3 min)

```bash
openssl rand -hex 32      # prints 64 characters - this is your key
```

Open your **password manager** and create a secure note named `n8n encryption key — <your domain>`. Paste it there **now**, before it exists anywhere else. This single habit is what separates a 30-minute restore from a lost instance.

Then:
```bash
cp .env.example .env        # from the kit's scripts/ folder
nano .env
```
Fill in `N8N_ENCRYPTION_KEY`, `DB_PASSWORD` (run the `openssl` line again for that too), and `N8N_HOST` (your real domain). Save with `Ctrl+O`, `Enter`, exit with `Ctrl+X`. Then lock it down:
```bash
chmod 600 .env
```

**What you should see:** `ls -l .env` shows `-rw-------`. If it's readable by "others", any user on that server can read your DB password.

---

## Step 3 — Install the compose file (2 min)

```bash
cp docker-compose.yml /opt/n8n/docker-compose.yml
cd /opt/n8n
docker compose config -q && echo "compose file is valid"
```

If `docker compose config -q` prints nothing (or the echo runs), your variables resolved and the file parses. If it complains about a missing variable, you skipped something in `.env` — the file intentionally refuses to start with `:?set N8N_ENCRYPTION_KEY...`, because starting without a key is exactly how people end up on page 1 of this kit's problem list.

---

## Step 4 — First start (2 min)

```bash
docker compose up -d
docker compose logs --tail=30 n8n
```

**What you should see:** lines ending with `Editor is now accessible via: http://n8n.example.com:5678` and no `ERROR` lines. Open `http://YOUR_SERVER_IP:5678` if you haven't pointed a domain yet (that's fine for setup; see `04` step 5 for TLS before you store real client credentials).

Create the owner account, then **add one credential and click Test**. If that works with the key you just set, you've proved the whole chain: key → credential → readable credential.

---

## Step 5 — Install the scripts (2 min)

```bash
sudo mkdir -p /opt/n8n/scripts
cp scripts/0*.sh scripts/n8n-backup.defaults /opt/n8n/scripts/
cd /opt/n8n/scripts
sudo chmod +x 0*.sh
sudo cp n8n-backup.defaults /etc/n8n-backup.env
sudo nano /etc/n8n-backup.env        # set STACK_DIR=/opt/n8n and the container names
```

Find your real container names (they differ between `docker-compose` and `docker compose`):
```bash
docker ps --format 'table {{.Names}}\t{{.Image}}'
```
Set `N8N_CONTAINER` and `DB_CONTAINER` to those exact values in `/etc/n8n-backup.env`. This is the #1 reason backup scripts fail silently.

---

## Step 6 — Run a manual backup (1 min)

```bash
sudo bash 02-backup.sh
```

**What you should see:**
```
[..] encryption key captured (source: env var)
[..] pg_dump (postgres)
[..] taring data volume: n8n_n8n_data
[..] exporting workflows as JSON
[..] exporting credentials (encrypted at rest)
[..] archive: /var/backups/n8n/20260904T181200Z/backup.tar.gz (4.2M)
[..] DONE. Backup is at ...
[..] Prove it restores:  bash 04-restore-drill.sh
```

Check it:
```bash
ls -lh /var/backups/n8n/latest/
tar tzf /var/backups/n8n/latest/backup.tar.gz | head
```
You want to see `ENCRYPTION_KEY.txt`, `database.dump`, `n8n-data.tar.gz`, `MANIFEST.txt`, and a `workflows/` folder.

---

## Step 7 — Prove the restore works (5 min) ⭐

```bash
sudo bash 04-restore-drill.sh
```

This boots a **separate** throwaway n8n (own containers, own empty database, port 5678 bound to `127.0.0.1`), imports your backup into it, asks you to click through 4 checks in the browser, then deletes everything. Your production instance is never stopped, never touched.

**What you should see:** `DRILL PASSED`. If a check fails, you just saved yourself a real outage — that's the drill succeeding at its job.

> No Docker on the machine right now? Do this instead: read `03-HOW-RESTORE.md` scenario C and simulate it with your JSON exports on any second n8n you can spin up (even a free-tier n8n Cloud trial instance, once, just to learn the flow).

---

## Step 8 — Schedule it (2 min)

```bash
sudo crontab -e
```
Add (press `i`, paste, `Esc`, `:wq`):
```cron
17 3 * * * /usr/bin/env bash -c 'cd /opt/n8n/scripts && ./02-backup.sh >> /var/log/n8n-backup.log 2>&1'
43 3 * * * /usr/bin/env bash -c 'cd /opt/n8n/scripts && OFFSITE_REMOTE=$(grep -m1 ^OFFSITE_REMOTE= /etc/n8n-backup.env | cut -d= -f2) ./05-offsite.sh >> /var/log/n8n-backup.log 2>&1'
```
Odd minute (17) on purpose: avoids the thundering herd of every `0 3 * * *` job on the same host, and it's after most nightly workflow runs finish.

---

## Step 9 — Offsite copy (3 min, do it today)

```bash
sudo bash 05-offsite.sh setup
```
Follow the prompts (Backblaze B2 free tier is the fastest path). Then add to `/etc/n8n-backup.env`:
```
OFFSITE_REMOTE=n8n-b2:
OFFSITE_ENCRYPT_NAME=n8n-crypt:
```
Verify with `rclone ls n8n-crypt: | head`. If you can't read the filenames, that's the **desired** result.

---

## Notes if n8n is already live on this server

1. **Set the key carefully.** If n8n already generated one inside the volume, you must reuse *that* value — do **not** invent a new one. Read it first:
   ```bash
   docker exec n8n cat /home/node/.n8n/config
   ```
   Put that exact value into `.env` as `N8N_ENCRYPTION_KEY`, then `docker compose up -d`. Verify a credential still opens and tests OK. If you set a *different* key here, you create the disaster this kit exists to prevent.
2. **Don't change DB type mid-flight.** SQLite → Postgres is a data migration, not an env var. It's documented in `04-HOW-RUN-FOREVER.md` step 6 (n8n supports `DB_TYPE=postgresdb` with a migration; do it on a copy first, using a drill).
3. **Pin your image tag** before you copy this compose in. If you're running `:latest`, `02` will happily keep backing up whatever version exists, but a surprise auto-upgrade can break nodes. Pin → snapshot the working version → then upgrade deliberately.

---

**Done?** Run the preflight once more — `bash scripts/01-preflight-check.sh` — and you should be at `0 FAIL`. Then read `03-HOW-RESTORE.md` once, calmly, today. Reading a restore procedure while nothing is on fire is the only time it actually sticks.
