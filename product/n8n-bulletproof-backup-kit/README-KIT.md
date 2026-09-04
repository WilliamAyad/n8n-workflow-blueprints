# n8n Bulletproof Backup & Restore Kit

**Turn a self-hosted n8n instance into something you can actually rebuild after it breaks — in under 30 minutes, with a dated proof that it works.**

You don't need to know how to code. Every file here is copy-paste. Each step says what it does and what it should print.

---

## Who this is for

| You are… | Why this kit pays for itself |
|---|---|
| **Freelancer / agency running automations for clients** | If a client's API keys and workflows vanish, you are rebuilding 40 credentials at 2am for free — or explaining to a client why their Stripe webhook is dead. This kit is the difference between a 30-minute restore and a lost client. |
| **Solo builder self-hosting n8n on a VPS ($5–12/mo)** | The VPS bill is the cheap part. One unmounted volume, one "temporary" server migration, one lost `~/.n8n/config` and the encryption key, and every stored credential is **permanently unreadable** — not "annoying", *permanently*. |
| **Someone who almost paid for n8n Cloud because self-hosting felt scary** | 11 hours of setup pain and $5,000/yr of hidden maintenance time is what happens when nobody hands you a production-grade file set. You are getting that file set. |

---

## The problem in one paragraph

n8n encrypts every stored credential with a single key. It generates that key automatically on first launch and tucks it in `~/.n8n/config`. Almost every tutorial — including the good ones — never mentions it. So when someone restores a database onto a new server with a *different* key, n8n boots perfectly, the UI looks fine, and then **every workflow fails with `Credentials could not be decrypted`**. There is no reset. There is no support ticket. An n8n maintainer confirmed on the community forum: without the original key, that data cannot be recovered.

This kit makes sure that sentence never applies to you.

---

## What's in the box

```
README-KIT.md                  ← you are here
01-WHY-BACKUPS-FAIL.md         ← the 4 failure modes (read this once, 10 min)
02-HOW-SETUP.md                ← install in 25 minutes, step by step
03-HOW-RESTORE.md              ← the 3 recovery scenarios + migration
04-HOW-RUN-FOREVER.md          ← cron, monitoring, client handoff, upsell
index.html                     ← printable handbook version (print to PDF from your browser)

scripts/
  01-preflight-check.sh        ← 10-second safety verdict on your current instance
  02-backup.sh                 ← the nightly backup (DB + volume + key + JSON)
  03-restore.sh                ← 3 restore modes (json / volume / database)
  04-restore-drill.sh          ← proves restore works on a throwaway instance
  05-offsite.sh                ← offsite copies (Backblaze B2 / R2 / Wasabi)
  docker-compose.yml           ← the safe-by-construction stack
  .env.example                 ← every variable explained
  n8n-backup.defaults          ← config for the scripts (no script editing)
  README.md                    ← commands, options, troubleshooting

templates/
  client-onboarding-form.md    ← the credentials + scope form that prevents rework
  incident-runbook.md          ← one-page "it broke at 2am" procedure
  proposal-snippet.md          ← paste into a quote: maintenance & backups, priced

CHANGELOG.md                   ← what's in each version (a maintenance product should be maintained)
FEEDBACK.md                    ← 2 questions, 60 seconds
```

**Prefer paper?** Open `index.html` in any browser → `Ctrl/Cmd+P` → Save as PDF. It's the whole handbook in one printable file, with page breaks in the right places.

---

## Fastest possible path (25 minutes)

1. **Get the verdict on what you have now**
   ```bash
   bash scripts/01-preflight-check.sh
   ```
   Every `FAIL` line is a real way people lose n8n. Don't skip ahead.

2. **Install** — follow `02-HOW-SETUP.md`. It's 9 numbered steps: key, compose file, backup script, permissions, first manual backup.

3. **Prove it** — this is the part that makes the kit worth buying:
   ```bash
   sudo bash scripts/04-restore-drill.sh
   ```
   Five minutes, zero risk to production (it uses its own containers, own database, port 5678). You finish with `DRILL PASSED` on screen and a dated file in `~/.n8n-last-drill`.

4. **Automate** — `04-HOW-RUN-FOREVER.md` step 1 gives you the two crontab lines and a free healthcheck ping, so a broken backup emails *you* instead of surprising you mid-outage.

---

## What "safe" looks like, concretely

After setup, you can survive:

- **Container deleted / image updated badly** → `MODE=volume` restore, ~4 minutes.
- **Server terminated by the provider, disk dead, account closed** → new $6 VPS, restore from offsite, **under 30 minutes**, credentials intact because you stored the key.
- **You want to duplicate a client's stack to a staging instance** → the JSON path in `03-restore.sh` does it additively.
- **A client asks "do you back this up?" during a sales call** → you send the date of your last successful restore drill. That sentence alone justifies the price of this kit many times over.

## Honest limits — read this before you buy

- It targets **Docker-based self-hosted n8n on Linux** (Ubuntu/Debian). n8n Cloud, Windows, and npm-without-a-volume installs are out of scope (there's a short note in `04` for each).
- It is **not** high-availability. It gives you *recovery*, not zero-downtime failover. Queue-mode / worker setups get an extra section, but a hot standby is a different problem.
- **You still own the boring 20%**: creating the password-manager note for the key, adding the bucket, running the drill each quarter. If you skip the drill, you bought a file set, not safety.
- n8n's own encryption design is theirs, not a flaw I can script around: **no key = no credentials**, period. Everything here exists to make sure you never lose the key.

---

**Support & updates:** reply to your Gumroad receipt and I'll answer within 2 business days. Version history in `CHANGELOG.md`.
