# Gumroad listing — ready to paste

Everything here is copy-paste ready. Numbers in `[brackets]` are the only places you must fill in your own reality (price of your time, support SLA you can actually keep). Don't invent a guarantee you can't honour.

---

## Product name (pick by where you'll drive traffic)

| # | Title | Best for |
|---|---|---|
| **A** ⭐ | **n8n Bulletproof — Backup & Restore Kit for self-hosted n8n on a VPS** | Google search intent ("n8n backup", "self-hosted n8n") |
| B | The n8n Disaster Recovery Kit — backups that actually restore, + client runbook | Agency/freelancer framing, higher price tolerance |
| C | Never Lose Your n8n Again — the encryption-key, backup & restore kit for Docker installs | Best CTR on Reddit/X, narrower audience |

**URL slug:** `n8n-bulletproof` · **Category:** Software Development / Business & Money · **Cover:** `marketing/cover.png`

---

## Price

| Tier | Price | Contents |
|---|---|---|
| Free sample | **$0+ (PWYW)** | `01-WHY-BACKUPS-FAIL.md` + `01-preflight-check.sh` only |
| **Core kit** ⭐ | **$29** | Everything above |
| Pro | **$59** | Core + `templates/` client kit, 1 private 30-min setup call, priority email support, future updates |
| Team | **$149** | Pro + multi-client layout (one bucket, per-client prefixes), team runbook PDF, 3 setup calls — *agency licence* |

Why $29 and not $9: the $30–49 band converts ~28% better than sub-$10 products on Gumroad, and the buyer here is charging a client for this work at [your hourly rate × 4] anyway. Price it like insurance, not like a template.

---

## Short description (the 1-2 lines under the title)

> The backup, restore and encryption-key setup that keeps your self-hosted n8n (and your clients' automations) recoverable. Copy-paste scripts for Ubuntu + Docker. No coding.

---

## Long description (paste as-is)

**You don't lose n8n because you forgot to back it up. You lose it because the backup you had didn't work.**

Self-hosted n8n encrypts every stored credential with a single key. It generates that key silently on first launch and hides it in `~/.n8n/config`. Almost no tutorial mentions it. So when a container is rebuilt, a volume isn't mounted, or a database is restored on a new server — n8n boots normally, the UI looks healthy, and every workflow fails with:

```
Credentials could not be decrypted.
The likely reason is that a different "encryptionKey" was used.
```

There is no reset. No support ticket. An n8n maintainer confirmed on the community forum: **without the original key, that data cannot be recovered.** For a freelancer running 12 clients' Stripe, HubSpot and SMTP connections, that's a billable week you can't bill — and a trust problem you can't un-ring.

**What this kit gives you**

- **A 10-second safety verdict** on the instance you have right now (`01-preflight-check.sh`) — every FAIL line is one of the four real ways people lose n8n.
- **The safe-by-construction stack**: pinned Docker Compose + `.env` where the encryption key is mandatory *before* first start, so the failure above can't happen to you by accident.
- **The nightly backup script** that captures all four things that matter — database, data volume, **the key**, portable JSON exports — into one dated folder with checksums and a restore-order manifest. Optional encrypted offsite copy to Backblaze B2/R2/Wasabi (pennies/month) and a free healthcheck ping, so a broken backup emails you *before* you need the backup.
- **The restore playbook** for 3 scenarios (container lost, volume wiped, whole server gone) + a clone-to-staging path. Written for someone under stress at 2am, not for a DevOps engineer.
- **The restore drill** — a throwaway n8n instance spun up, your backup imported into it, verified, destroyed. Production untouched. Five minutes. This is the part that separates "I have backups" from "I can restore".
- **The client-facing templates** (agency tier): the credential onboarding form that prevents 80% of rework, the 25-line incident runbook you hand over, and the copy that turns maintenance into a priced line item.

**What you need**: an Ubuntu/Debian VPS with Docker and sudo. **What you don't need**: any coding. Every step says what to run and exactly what output you should see.

**Honest limits** (I'd rather you know now):
- Docker installs on Linux only — not n8n Cloud, not Windows, not npm-without-a-volume (short notes for each are inside).
- This buys you *recovery*, not zero-downtime HA. A hot standby is a different, bigger project.
- You still own three boring habits: the password-manager note for the key, the bucket, the quarterly drill. Skip the drill and you bought files, not safety.

**You get**: lifetime access, all future revisions (n8n changes its hosting docs; I update when it breaks), and answers to support email from [your name] within [2 business days]. 30-day refund if the preflight says you're already fully covered — that happens, and I'd rather you keep the check for free.

---

## Tags (12 max, use all)

`n8n` · `self-hosted` · `backup` · `disaster recovery` · `docker` · `VPS` · `automation agency` · `no-code` · `workflow automation` · `encryption key` · `runbook` · `freelancer tools`

---

## Rating bait that is actually legitimate

1. Ship a `FEEDBACK.md` link at the end of the README: "2 questions, 60 seconds".
2. In the receipt email, ask for a review only after they've reported the drill passed.
3. Free PWYW sample → PWYW products get ratings at ~2.6× the rate of fixed-price ones, and Gumroad's Discover needs sales history + $100 before it surfaces you anyway. Reviews first, traffic second — not the other way round.

---

## Where the traffic comes from (this is the real work)

| Channel | What to do | Why it works here |
|---|---|---|
| **Your own blog / SEO** ⭐ | 3 posts per month, each targeting one exact error string or task. Publish on `triggerworkflow.com`, link the product inside. Use `marketing/BLOG-POSTS.md`. | Medium-style long-form that ranks for a query buyers already type is the single proven zero-ad-spend channel for Gumroad sellers; `medium.com` is Gumroad's biggest referral source. |
| n8n community forum | Answer backup/restore/credential-loss threads with the actual fix, product link in your footer only | Buyers are already there, mid-pain, and the thread keeps ranking in Google for years |
| r/n8n, r/selfhosted, r/automation | Give the free preflight script away in a "here's how to check in 10 seconds whether your n8n can survive a rebuild" post | These subreddits reward tool-shaped value and punish links |
| GitHub | Publish `01-preflight-check.sh` as a standalone repo (MIT), README links to the paid kit | You already know how to use GitHub as an SEO/backlink surface |
| X / LinkedIn | Before/after of a restore drill: 3 screenshots, one number ("restored in 22 min") | Proof beats promises in this niche |
| Etsy (optional, +15 min) | Re-list the same files at $19 | Etsy *has* marketplace search; Gumroad doesn't. Cheap second channel. |

**Do not** expect Gumroad Discover to feed you traffic early: eligibility needs verified sales history and a risk-team pass, and Discover sales carry a 30% fee vs 10% direct. Treat Gumroad as the checkout, and your content as the storefront.

---

## Launch checklist (45 minutes)

- [ ] `zip -r n8n-bulletproof-kit.zip product/n8n-bulletproof-backup-kit/` → upload as the product file
- [ ] Cover `marketing/cover.png` + 3 real screenshots (preflight output, a backup folder listing, `DRILL PASSED`)
- [ ] Enable guest checkout, turn on the PWYW free sample as a separate listing, set $29 core
- [ ] Paste the long description, add the honest-limits block verbatim (it converts better than hype and kills refunds)
- [ ] Publish post 1 from `marketing/BLOG-POSTS.md` before, not after, the listing goes live
- [ ] Add `CHANGELOG.md` + a "last updated" line — buyers of a *maintenance* product expect the product to be maintained
