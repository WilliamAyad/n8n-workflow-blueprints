# 01 · Why n8n backups fail

Most people don't lose their n8n instance because they forgot to back it up. They lose it because they had a backup that looked fine and didn't work when it mattered. There are four failure modes, and between them they account for nearly every horror story in the n8n community forum.

---

## Failure mode 1 — The key that was never captured *(the brutal one)*

**Mechanism.** n8n doesn't store your API keys and OAuth tokens as plain text. Before anything touches the database, it is encrypted with one key:

- If you set `N8N_ENCRYPTION_KEY`, n8n uses yours.
- If you didn't, n8n generates a random one on first launch and writes it to `~/.n8n/config` (inside the container: `/home/node/.n8n/config`).

**The trap.** That config file lives *next to* the data. Rebuild the container without a persistent volume, restore a database dump onto a fresh instance, or reinstall n8n on a new server, and you get a **new** key. Now the old credentials in the database are mathematically unreachable.

> An n8n maintainer on the community forum, when asked for a recovery path: there is no way of getting the data back without the original key. Encryption that could be undone without the key wouldn't be encryption.

**Symptom.** `Credentials could not be decrypted. The likely reason is that a different "encryptionKey" was used to encrypt the data.` Everything else — the UI, the workflow list, the execution history — looks perfectly normal, which is what makes it so disorienting.

**What changes the outcome.** Set the key explicitly **before you create your first credential**, and store it somewhere that outlives the server (password manager, not just `.env` on the box). If the server dies and the key was only on the server, they die together.

**Cost of being caught by this.** Re-entering every credential. For a personal setup, an afternoon. For an agency with 12 clients' Stripe, HubSpot, Google Workspace and SMTP credentials, it's a billable week you can't bill — and a trust problem.

---

## Failure mode 2 — The volume that was never mounted

**Mechanism.** `docker run` without `-v n8n_data:/home/node/.n8n` writes everything into the container's writable layer. Containers are disposable. Delete the container, upgrade the image, or restart after a compose edit, and the data is gone.

**Symptom.** "n8n reset itself", empty workflow list, or the key problem above with an extra step: nothing to recover.

**Detection (2 seconds):**
```bash
docker inspect -f '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{println}}{{end}}' n8n
```
If there is no line ending in `-> /home/node/.n8n`, you are running on borrowed time. `scripts/01-preflight-check.sh` checks this for you.

**Fix.** Named volume or bind mount, plus `restart: unless-stopped`. See `02-HOW-SETUP.md`.

---

## Failure mode 3 — The backup on the same disk

**Mechanism.** `~/n8n-backups/` on the VPS. Great — until the incident that destroys the instance also destroys the backups: a dead disk, a provider account closed for a billing dispute, a ransomware pass, a `rm -rf` in the wrong terminal, an expired card leading to a server deletion you learn about a week later.

**Rule.** A backup needs an **independent failure mode**. Different machine, different provider, different account. Offsite isn't a "nice to have" for n8n, because the most likely cause of loss is the whole server.

**Also true:** offsite copies of *encrypted credential dumps* are only as safe as the storage. Encrypt before you upload (`scripts/05-offsite.sh` wraps the bucket in rclone `crypt`, so the provider stores opaque blobs).

---

## Failure mode 4 — The backup nobody ever restored

The most common one, and the least talked about. Someone runs `pg_dump` nightly for two years, then needs it once — and finds:

- the dump was 0 bytes because the container name had changed after an upgrade;
- `pg_restore` fails because the role/database names differ on the new box;
- workflows restore fine, but every node's credential is a red "missing" badge;
- the n8n version is newer than the schema in the dump and the import half-applies;
- or the cron job silently never ran because `docker` wasn't in root's `PATH`.

**A backup you have never restored is a hypothesis.** That's why this kit ships `04-restore-drill.sh` as a first-class file rather than a paragraph of advice, and why `01-preflight-check.sh` fails the check if your last drill is more than 90 days old.

**The standard to aim for:** quarterly drill, ~30 minutes, on a throwaway instance. Measured recovery target for a solo/small setup: **RTO ≈ 30 minutes** (time to be back up), **RPO ≈ 24 hours** (data you can lose) — tightened to RPO ≈ 1 hour only if your automations create records outside n8n that you'd have to hand-repair.

---

## What a correct backup set actually contains

| Component | Where it lives | Without it, you lose… |
|---|---|---|
| **Database** | `postgres_data` volume (or `database.sqlite`) | everything: workflows, credentials (encrypted), users, history |
| **Encryption key** | `N8N_ENCRYPTION_KEY` env var, or `~/.n8n/config` | the ability to *read* any credential |
| **n8n data volume** | `n8n_data` volume | custom nodes, binary data, instance settings |
| **Stack files** | `/opt/n8n/docker-compose.yml`, `.env`, proxy config | hours of reconstructing config; webhooks that point at the wrong host |
| **JSON exports** | `n8n export:workflow` / `n8n export:credentials` | nothing — but they're your escape hatch when the DB restore is the thing that broke |

Five lines. `scripts/02-backup.sh` captures all five into one dated folder per night, with a checksum and a `MANIFEST.txt` that states the restore order.

---

## One thing to internalise before you set anything up

> **The order of a restore matters more than the backup itself.**
> Key first (before the instance ever starts), then database, then volume, then verify one credential with `Test`, then run one workflow.
> Do it out of order and you can corrupt a recoverable situation into an unrecoverable one — e.g. starting n8n with a fresh auto-generated key on a machine that's about to hold your restored credentials.

Keep that as a printed page next to the server rack in your head. `templates/incident-runbook.md` is exactly that page, in 25 lines, so you never have to recall it under pressure.
