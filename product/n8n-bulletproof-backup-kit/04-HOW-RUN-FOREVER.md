# 04 · Running it forever (and getting paid for it)

Setup done once; the boring parts keep you safe. Seven things, ~30 minutes of work total.

---

## 1. Monitoring: a backup that fails silently is worse than none

Free, 3 minutes: create a check at [healthchecks.io](https://healthchecks.io), copy its UUID, and set it in `/etc/n8n-backup.env`:
```
HEALTHCHECK_UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```
`02-backup.sh` pings it on success. If a nightly run dies, you get an email in under 26 hours. This is how you learn about a broken backup *before* you need the backup.

No-account alternative: the log line the script appends.
```bash
tail -5 /var/backups/n8n/n8n-backup.log
grep -c 'STATUS=OK' /var/backups/n8n/n8n-backup.log   # count of good nights
```

---

## 2. Quarterly drill (the one habit that keeps the others honest)

```bash
sudo bash /opt/n8n/scripts/04-restore-drill.sh
```
Put it in your calendar for the first Saturday of January / April / July / October, at 10:00, 30 minutes. It writes `~/.n8n-last-drill`, and `01-preflight-check.sh` will start nagging (loudly, in red) after 90 days.

If you sell automation as a service, run it while a client is on a call. Nothing sells "this person is serious" like restoring a live instance on demand.

---

## 3. Log rotation (so the log doesn't eat your disk)

```bash
printf '/var/log/n8n-backup.log {\n  monthly\n  rotate 6\n  compress\n  missingok\n  notifempty\n}\n' | sudo tee /etc/logrotate.d/n8n-backup
```

---

## 4. Disk math: how big will this get?

A typical solo instance: 2–40 MB per nightly backup (execution history dominates). 14 days retained locally ≈ 0.5 GB; offsite ≈ a few cents per month on Backblaze B2.

If your `backup.tar.gz` is bigger than ~500 MB, your execution history is the reason. Reduce retention inside n8n rather than dropping backups:
```
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168        # hours (7 days)
EXECUTIONS_DATA_PRUNE_MAX_COUNT=50000
```
Also worth knowing: `docker system prune -f` on a host that's been upgraded a few times can free more GB than your entire backup folder weighs.

---

## 5. Version pinning + upgrade routine

Never run `:latest` in a client-facing stack. Pin (`image: docker.n8n.io/n8nio/n8n:1.88.0`), and upgrade like this:

```bash
cd /opt/n8n
sudo bash scripts/02-backup.sh            # explicit safety copy before the change
nano docker-compose.yml                    # bump the tag
docker compose pull && docker compose up -d
docker exec n8n n8n --version
```
Then: open the 3 workflows that matter most and run each once. If anything's off, roll back by editing the tag and re-running `up -d` — your data volume and database are untouched. **Take a snapshot at your VPS provider before a major-version jump** (1.88 → 2.x style changes); it costs pennies for an hour and it's the second-best backup you have.

---

## 6. SQLite → PostgreSQL, when you outgrow the default file DB

Signs it's time: many concurrent workflows, execution DB locking errors, >1 GB `database.sqlite`, or you're adding workers. Do it on a copy, using the drill infrastructure:

1. `sudo bash scripts/02-backup.sh` (obviously).
2. Spin up the kit's compose **with Postgres** on a staging port, empty DB.
3. Use the JSON path to populate it: `sudo bash 03-restore.sh` (workflows + credentials). Users/settings don't come across this way — you'll recreate the owner account, which on a 1-user instance is 90 seconds.
4. Run both stacks side by side for a day if you can afford it.
5. Flip DNS/webhooks, keep the SQLite volume mounted as an escape hatch for a week.

n8n's own `export:workflow` / `import:workflow` CLI is the supported path; there is no in-place "switch the DB type and go" button.

---

## 7. Queue mode / multiple workers: the key must be identical everywhere

If you scale to workers (`EXECUTIONS_MODE=queue`), **every worker container needs the same `N8N_ENCRYPTION_KEY`** as the main instance. A worker without it generates its own and cannot decrypt credentials — which shows up as baffling per-node auth failures on some executions only. Same variable, same value, all services in the compose file.

---

## Handing this to a client (the part people forget)

The kit's real value in an agency context: *the client gets an owned, documented, recoverable system, and you get a maintenance line item.*

Minimum handoff package per client:

1. Copy of `templates/client-onboarding-form.md` — filled in **before** you build. It collects exactly what you need (credential owners, redirect URLs, what breaks when they change a password) and quietly tells the client you're organised.
2. Their own password-manager entry holding `N8N_ENCRYPTION_KEY`, their bucket name, and their healthcheck URL. **Give it to them, keep a copy** — an instance whose key only you hold becomes a hostage situation on the day you two fall out. That's bad for them and legally bad for you.
3. Their `/etc/n8n-backup.env` with `BACKUP_ROOT=/var/backups/n8n-<client>` and their own offsite prefix (`OFFSITE_REMOTE=n8n-b2:` + folder). One bucket, one prefix per client. If a client's credentials ever mix into another's backup folder, that's a contract problem, not a bug.
4. The `01-preflight-check.sh` output, saved as a PDF, in the handoff doc.
5. `templates/incident-runbook.md`, filled with their hostname and bucket so a non-technical person could follow it.

**Support boundary, stated in writing** (paste into the proposal — see `templates/proposal-snippet.md`):
- Included: restore within 30 min of being notified; monthly drill; config changes for upgrades.
- Not included: rebuilding workflows they deleted inside the UI; re-authorising credentials whose passwords *they* changed and never told you about (that's a 15-minute billable task, not a warranty claim).

---

## A yearly 20-minute review

Once a year, before renewing servers:

- [ ] Password manager note exists, is findable, and the key inside actually matches (`docker exec n8n printenv N8N_ENCRYPTION_KEY`).
- [ ] Offsite bucket credentials are still valid and the payment card behind it isn't expiring — more instances die from a dead card at the storage provider than from hackers.
- [ ] A drill passed in the last 90 days.
- [ ] Retention policy matches what clients expect (14 days ≠ "you can restore last March").
- [ ] Domain + DNS for `N8N_HOST`/`WEBHOOK_URL` are on an account that won't lapse silently.
- [ ] Restore time measured in minutes and written down in the runbook. Numbers in a runbook are worth money in a negotiation.
