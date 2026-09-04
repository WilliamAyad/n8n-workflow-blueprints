# n8n incident runbook — the 25-line page you'll actually read at 2am

**Instance:** `n8n.____________.com` · **Stack dir:** `/opt/n8n` · **Container:** `n8n` · **Backups:** `/var/backups/n8n` · **Offsite:** `n8n-b2:` (crypt: `n8n-crypt:`) · **Key note:** password manager → "n8n encryption key"
**Last successful restore drill:** ____________ (date)

---

## Step 0 — Stop, classify, then act (2 min)

| What do you see? | Section |
|---|---|
| n8n won't open at all | A |
| n8n opens, workflows listed, but they error on auth | B |
| n8n opens, workflows are **missing** | C |
| Only one workflow/integration is broken | D |
| Server unreachable (SSH fails too) | E |

**Do not** re-create credentials, re-run failed executions in bulk, or edit the compose file before you've read B. Half of "lost credential" stories are a self-inflicted second mistake.

---

## A — Instance down

```bash
cd /opt/n8n && docker compose ps && docker compose logs --tail=50 n8n
```
- `standard_init_linux_...` / image pull error → `docker compose pull && docker compose up -d`
- Postgres not healthy → `docker compose logs --tail=30 postgres` (disk full is the usual culprit: `df -h`)
- Disk full → `docker system prune -f` and delete old backup folders you don't need, then `docker compose up -d`

## B — "Credentials could not be decrypted"

1. **Do not re-enter anything yet.**
2. `docker exec n8n printenv N8N_ENCRYPTION_KEY` → empty, or different from your password-manager note?
3. Fix `.env` to the note's value → `docker compose up -d` → test one credential. Most cases end here.
4. No key in `.env` but an old volume exists: `docker run --rm -v <old_n8n_data>:/data alpine cat /data/config`
5. Only if the key is truly gone: re-authorise, then set an explicit key immediately so this is the last time.

## C — Workflows missing

```bash
sudo bash /opt/n8n/scripts/03-restore.sh /var/backups/n8n/<latest>     # JSON path, additive
```
Then open the two most business-critical workflows, test, activate. Nothing was deleted by a JSON restore — if you see duplicates, that's expected; delete the empty shells after verifying.

## D — One integration broken

Webhook 404 → is the workflow **active**? Did `WEBHOOK_URL` change with a domain/protocol edit?
Rate limit / 401 → credential expired on *their* side, or quota. Check the provider's status page before touching n8n.
Works manually, fails on schedule → timezone: `docker exec n8n printenv GENERIC_TIMEZONE`.

## E — Whole server gone

`03-HOW-RESTORE.md` → **Scenario C**, top to bottom. Target: 30 minutes. Tell affected clients **once**, with a number: "back by 04:15, no data loss after 03:17."

---

## While you fix

- [ ] Snapshot the VPS **before** any destructive step (provider panel, 1 minute, saves you from your own mistake)
- [ ] Screenshot the exact error text before changing anything
- [ ] Note the time you started (you'll need "restored in 22 min" later — in the report, in the invoice, in the renewal conversation)

## After it's fixed (10 minutes, do it — this is what stops repeat incidents)

```
Date/time · Duration · Cause (real, not proximate) · What failed to protect us · What changed
```
Then: run `bash /opt/n8n/scripts/01-preflight-check.sh` → must be `0 FAIL`. Add a monitoring alert for the exact failure mode you just hit. If a client was affected, send three lines: what happened, what you changed, what you'd recommend next. That email is the reason retainers get renewed.
