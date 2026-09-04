# 3 ready-to-publish posts (traffic, not promotion)

Each targets a query a person types **while they're in pain** — highest-intent traffic that exists. Publish on your own site (canonical), then re-post on Medium with a canonical link back. Every post ends with one product line; no more. Replace `<link>` and `yourdomain`.

---

## POST 1 · "Credentials could not be decrypted" in n8n: the real fix (and the 5-minute check that prevents it forever)

**Title (60 chars):** n8n "Credentials could not be decrypted" — fix + prevention
**Slug:** `/n8n-credentials-could-not-be-decrypted-fix`
**Meta description:** This error means your n8n encryption key changed. Here's how to find the old key, restore access to every credential, and make sure it never happens again.

### The error, in one sentence

n8n encrypts every stored credential with a single key; the message means the key now loaded isn't the key that encrypted that data.

### Why it happens (the 4 causes, ranked by how often I see them)

1. **The data volume isn't persistent.** No `-v n8n_data:/home/node/.n8n` in the compose file. The key lived in the container's writable layer; the container was recreated, so n8n generated a fresh one. Most common by far.
2. **Restoring a database onto a new server** with the key left behind. Workflows return, credentials don't.
3. **A `.env` edit.** Someone added/changed `N8N_ENCRYPTION_KEY` while debugging something else.
4. **Queue mode with workers.** One worker doesn't share the same key. Symptoms are intermittent and confusing — some executions auth fine, others don't.

### Step 1 — stop, and check before you type anything

```bash
docker exec n8n printenv N8N_ENCRYPTION_KEY
docker exec n8n cat /home/node/.n8n/config
grep -n ENCRYPTION /opt/n8n/.env
```

Three outcomes: the key is in the env var, in the config file, or nowhere. **Do not** re-create credentials yet — re-entering them is the last resort, not the first, and each new credential you create makes the old set harder to reason about.

### Step 2 — recover the original key

```bash
# is there an old volume hanging around?
docker volume ls | grep n8n
docker run --rm -v <OLD_VOLUME>:/data alpine cat /data/config

# or an old .env from before the migration
grep -R "N8N_ENCRYPTION_KEY" /opt /root /home 2>/dev/null

# or shell history, if you ever set it by hand
grep ENCRYPTION ~/.bash_history
```

Put the found value in `.env` as `N8N_ENCRYPTION_KEY=…`, then `docker compose up -d`. Everything comes back in about two minutes. This is the whole fix in the majority of cases.

### Step 3 — if the key is genuinely gone

There is no recovery path: no reset, no vendor unlock (an n8n maintainer has said exactly this on the community forum — encryption that could be undone without the key wouldn't be encryption). So:

1. **Set a permanent key first** — before you re-enter anything, so this is the last time.
2. Delete the broken credentials in **Credentials**, recreate them, and test each one.
3. Open affected workflows, confirm the credential selector points at the new ones, run one test execution, then re-activate.
4. Also check your **backup**: a database dump without its matching key restores workflows but not credentials. That's how most people discover the whole problem — during a real recovery.

### Step 4 — never again (3 lines of config + 1 habit)

```yaml
services:
  n8n:
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}   # set BEFORE first launch,
    volumes:                                        # i.e. before any credential exists
      - n8n_data:/home/node/.n8n
```
Plus the habit that actually saves you: the key goes in your **password manager**, not only on the server. If the server dies and the key was only on the server, they die together.

### Get a 10-second verdict instead of reading this at 2am

I ship a read-only `01-preflight-check.sh` (volume mounted? key in env? backup fresh? last restore drill ≤90 days?) inside **[n8n Bulletproof](<link>)** — a copy-paste kit for self-hosted n8n: hardened compose, nightly backups of DB + volume + key + JSON, offsite encrypted copies, restore playbook, and a drill that proves a restore works without touching production. The checklist page is in the free sample.

---

## POST 2 · How to back up self-hosted n8n (4 things, not 1)

**Title:** How to back up self-hosted n8n: database, volume, key, JSON
**Slug:** `/backup-self-hosted-n8n-docker`
**Meta:** A `pg_dump` isn't enough. Here's what a complete n8n backup contains, a script that captures all of it, and the drill that proves it restores.

### The mistake: one dump, four components

| Component | Location | Without it, you lose |
|---|---|---|
| Database | `postgres_data` volume / `database.sqlite` | workflows, credentials (encrypted), users, history |
| **Encryption key** | `N8N_ENCRYPTION_KEY` or `~/.n8n/config` | the ability to *read* any credential |
| Data volume | `n8n_data` volume | custom nodes, binary data, instance settings |
| Stack files | `docker-compose.yml`, `.env`, proxy config | an hour of reconstructing, webhooks on the wrong host |

**Restore order matters more than the backup:** key → database → volume → verify one credential → run one workflow. Out of order turns recoverable into unrecoverable.

### The command set (manual, for understanding)

```bash
# database
docker exec n8n-postgres-1 pg_dump -U n8n -d n8n -Fc -f /tmp/n8n.dump
docker cp n8n-postgres-1:/tmp/n8n.dump ./backup/
# key + settings
docker exec n8n printenv N8N_ENCRYPTION_KEY > ./backup/ENCRYPTION_KEY.txt
docker run --rm -v n8n_n8n_data:/data:ro -v $(pwd)/backup:/bk alpine tar czf /bk/n8n-data.tar.gz -C /data .
# portable copies (your escape hatch when a dump won't restore)
docker exec n8n n8n export:workflow   --backup --output=/tmp/wf
docker exec n8n n8n export:credentials --backup --output=/tmp/cred
```

### The part everyone skips: a restore drill

Run a copy of your instance from the backup on the same box (own containers, empty database, `127.0.0.1:5678`), import, verify, delete. Five minutes, zero production risk, and it's the only evidence that your backup is real. `untested backups are not backups` is a cliché precisely because it keeps being true.

Add an offsite copy with an independent failure mode — a different provider, encrypted at rest (rclone `crypt`) — because the likeliest cause of n8n loss is "the whole server", which takes local backups with it. Then ping a free healthcheck URL from the backup script so a silent failure tells you within a day.

**Want the whole thing pre-written?** [n8n Bulletproof](<link>) ships these exact scripts (idempotent, config in `/etc/n8n-backup.env`, no editing of scripts), the compose file that refuses to start without a key, the restore drill, a 25-line incident runbook and the client onboarding form. $29, Docker on Linux, no coding.

---

## POST 3 · Moving n8n to a new VPS without losing your credentials

**Title:** Migrate n8n to a new VPS without losing credentials
**Slug:** `/migrate-n8n-new-vps-without-losing-credentials`
**Meta:** Two ways to move a self-hosted n8n instance — full DB restore, or JSON export/import. Which to pick, the exact commands, and the trap that locks you out.

**The trap:** a fresh instance generates its own key on first boot. If you import credentials *after* that, you get a mess; if you restore the DB without the original key, credentials are unreadable. **Order: key into `.env` on the target → start n8n once → stop → data in → start.**

**Method A (exact copy)** — same n8n version, both DB + volume. Highest fidelity (users, execution history, tags). `pg_dump`/`pg_restore --clean --if-exists`, or copy the SQLite file. Don't restore a newer-version dump onto an older install.

**Method B (recommended for most)** — JSON path:
```bash
docker exec n8n n8n export:workflow    --all --output=/tmp/wf.json
docker exec n8n n8n export:credentials --all --decrypted --output=/tmp/cred.json
scp ... target:/tmp/
docker exec n8n n8n import:credentials --input=/tmp/cred.json
docker exec n8n n8n import:workflow    --input=/tmp/wf.json
```
`--decrypted` exists precisely for cross-instance migration with different keys, so the target re-encrypts on import. Treat that file as radioactive: transfer over SSH, `shred -u` on both machines right after, and never let it into a git repo or a shared drive. Import overwrites same-ID objects, and imported workflows arrive **deactivated** — good: activate deliberately, one at a time, after a test run.

**After the move:** fix `N8N_HOST`/`WEBHOOK_URL` to the new domain, `dig +short` to confirm DNS, test every inbound webhook (the ones where *other* services call you — Stripe, Typeform, Google), then check credential tests in each workflow that touches money or email.

Full checklist + the rollback plan in [n8n Bulletproof](<link>).

---

## Publishing rules (so this compounds instead of rotting)

1. **One post per exact problem phrase.** Title/H1 must contain it. `n8n credentials could not be decrypted` beats `n8n troubleshooting tips`.
2. Publish on your site first, canonical tag, then Medium with canonical → Medium is Gumroad's biggest external referral source for a reason.
3. Include a **real terminal screenshot** per post. In this niche, proof of a working command outsells adjectives.
4. Answer one forum thread per post you publish, using the post's Step-by-step, with the link only in your footer profile. Zero promotion in-thread = zero moderator problems and long-lived Google visibility.
5. Refresh the "last updated" line every time n8n changes anything relevant — this category punishes stale posts hard.
