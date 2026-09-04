# 03 · Restore playbook — 3 scenarios + 1 migration

Print this. Keep it in your password manager's secure notes, not only on the server you're recovering.

**Rule that never changes:** on the target machine, the key goes into `.env` **before** n8n starts there. Once a fresh instance writes its own auto-generated key and you've created credentials with it, mixing restored credentials into that instance gets confusing.

**Quick selector**

| What happened | Go to |
|---|---|
| Container gone / bad update / compose file broken — server itself is fine | Scenario **A** |
| Data volume wiped or corrupted, server fine | Scenario **B** |
| Whole VPS dead / account closed / migrating to a new provider | Scenario **C** |
| Copying a stack into staging, or cloning for a second client | Scenario **D** |

---

## Scenario A — Container rebuilt (4 minutes)

```bash
cd /opt/n8n
grep N8N_ENCRYPTION_KEY .env                  # confirm the key line exists
docker compose up -d
docker compose logs --tail=20 n8n
```
Nothing else needed — the volume still holds your data. If n8n came back but credentials now fail to decrypt, the `.env` key and the volume's key disagree; read the value in the volume (`docker run --rm -v n8n_n8n_data:/data alpine cat /data/config`) and make them match.

---

## Scenario B — Data volume lost (12 minutes)

```bash
cd /opt/n8n/scripts
sudo MODE=volume bash 03-restore.sh /var/backups/n8n/<TIMESTAMP>
```
The script stops n8n, empties the volume, unpacks `n8n-data.tar.gz`, restarts. It asks you to type `YES` first. If the volume name isn't detected, set it: `sudo DATA_VOLUME=n8n_n8n_data MODE=volume bash 03-restore.sh`.

---

## Scenario C — Whole server gone (this is the one)

**You need three things:** the offsite folder, the encryption key (password manager), and the compose file (also in the offsite folder).

### 1. New box (5 min)
Buy the smallest Ubuntu 24.04 VPS your provider offers (€5–8/mo is plenty). Then:
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo mkdir -p /opt/n8n && cd /opt/n8n
```

### 2. Pull the backup down (2 min)
```bash
rclone copy n8n-crypt:/n8n/20260904T181200Z /opt/n8n/restore/ --progress
```
No rclone yet? `aws s3 sync` / provider dashboard download / `scp` from the old box if it still lives.

### 3. Restore the key and stack FIRST (2 min)
```bash
cd /opt/n8n
tar xzf restore/backup.tar.gz -C restore/
cp restore/docker-compose.yml . 2>/dev/null || cp /opt/n8n/scripts/docker-compose.yml .
printf 'N8N_ENCRYPTION_KEY=%s\n' "$(cat restore/ENCRYPTION_KEY.txt)" >> .env
nano .env                # re-add DB_PASSWORD + N8N_HOST (they were masked on purpose)
chmod 600 .env
```
> The backup deliberately **masks** `.env` secrets. So the DB password is the one thing you must remember or reset: create a fresh `DB_PASSWORD` on the new box — it doesn't need to match the old server, since you're restoring the *data*, not the credentials of Postgres itself.

### 4. Bring up the stack (3 min)
```bash
docker compose up -d
docker compose logs --tail=30 n8n       # wait for the "Editor is now accessible" line
```

### 5. Restore the data (2 min)
```bash
cd /opt/n8n/scripts
sudo MODE=database bash 03-restore.sh /opt/n8n/restore
```
It asks for `YES`, stops n8n, `pg_restore --clean --if-exists`, restarts.

### 6. If `pg_restore` fights you: use the JSON path instead
This is why the kit exports JSON every night. On a **fresh empty** instance:
```bash
sudo bash 03-restore.sh /opt/n8n/restore          # MODE=json is the default
```
Then re-create the owner account if asked, and re-check credentials.

### 7. Point DNS at the new IP (10–30 min to propagate)
```bash
dig +short n8n.yourdomain.com
```
Then, once the site loads: **every active workflow that talks to webhooks needs its URL re-checked** (`WEBHOOK_URL`/`N8N_HOST` in compose). If you use Zapier/Stripe/Make calling your webhooks, they'll follow DNS automatically; anything with the IP hard-coded needs an edit.

### 8. Verify (5 min)
Credentials → open → **Test**. Then run one workflow end to end. Then a second one that writes data. Only now tell the client / resume business.

---

## Scenario D — Clone a stack to staging, or duplicate for another client

Same as C, but **skip the `--clean`**: the JSON path only. Two things to watch:

1. **IDs overwrite.** n8n exports include workflow/credential IDs; importing into an instance that already has those IDs replaces them. For a clean clone, import into an empty instance (the drill does exactly this — see `scripts/README.md`).
2. **Shared credentials = shared blast radius.** Cloning a client's stack for a second client is where people accidentally leak one client's API key into another's workflow. After cloning: delete all credentials in the copy, then re-add per-client ones, and run the credential test node in every workflow.

---

## When the DB is fine but credentials are broken

`Credentials could not be decrypted` after a restore means key mismatch. Three options, in order of preference:

1. **Find the old key.** Old `.env` files, a shell history (`grep N8N_ENCRYPTION_KEY ~/.bash_history`), a previous server snapshot, or the old volume if it still exists:
   ```bash
   docker run --rm -v old_n8n_data:/data alpine cat /data/config
   ```
   Set it, restart, done — everything comes back in about two minutes.
2. **You have a decrypted export** (`INCLUDE_DECRYPTED=1` backups): `docker exec n8n n8n import:credentials --input=/tmp/creds.json` on the *new* instance — imports re-encrypt with the current key. Then **shred that file**.
3. **Neither:** re-enter credentials. Annoying, not catastrophic, because your *workflows* are intact. Do it in dependency order (SMTP, Google, Stripe, CRM), test each, and re-run the affected workflows one at a time.

---

## Post-restore hygiene

```bash
find /opt/n8n -maxdepth 1 -name '*.json' -newer /opt/n8n/.env   # stray decrypted dumps?
sudo shred -u /opt/n8n/RESTORE-ENCRYPTION_KEY.txt                # after the key is in your password manager
sudo bash /opt/n8n/scripts/01-preflight-check.sh                 # should be 0 FAIL again
```
Record the incident: date, cause, time-to-recover, what you'd change. That paragraph becomes the maintenance-report line item that justifies your retainer (`templates/proposal-snippet.md`).
