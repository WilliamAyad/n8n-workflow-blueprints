# Paste-ready copy: sell reliability as a line item

Three blocks. Copy them into your proposal / quote / SOW. They turn "backups" from an invisible chore into a priced, defensible deliverable — which is how you stop competing on price alone.

---

## 1. In-scope paragraph (build phase)

> **Operational baseline included.** The automation platform will be deployed in a recoverable configuration: a persistent data volume, an explicitly managed encryption key held in *your* password manager, nightly backups of workflows, credentials and instance configuration, and a copy of every backup stored off the server with an independent failure mode (separate storage provider, encrypted at rest). This is standard infrastructure hygiene, not an optional extra; it is the difference between a 30-minute restore and rebuilding 40 service connections by hand.

## 2. Maintenance tier (recurring — pick one and quote it)

| Tier | What it covers | Typical price |
|---|---|---|
| **Essential** | Nightly automated backups + offsite copy. Monthly restore drill report (one page: date, duration, verified working). n8n security/minor version updates. Response within 2 business days. | **$120–250/mo** |
| **Priority** | Everything above + uptime & backup monitoring, 4-hour response during business hours, quarterly recovery *rehearsal* with your team in the call, credential-expiry checks (Google OAuth refresh, app-review scopes). | **$400–800/mo** |
| **Recovery retainer (standalone)** | For clients who already run their own instance: we hold the runbook, run the drills, and restore on request. Not "monitoring", explicitly: 2 drills + reports per quarter + up to 2 restore events. | **$79–150/mo** |

> **Not included / billed separately:** re-authorisation after credential or password changes made on your side without notice (15 min at my hourly rate); rebuilding workflows deleted inside the n8n UI; third-party API or subscription lapses (the storage provider's failed card is the #1 cause of missing backups).

## 3. The one paragraph that closes (put it near the price)

> **What we're really quoting.** Your workflows are the asset; the platform is interchangeable. If the current host dies on a Sunday, the question isn't "can we restore?" but "who has the key, which bucket, and has anyone tested the restore this quarter?" Our answer to all three is documented, dated and rehearsed — and you own the copies.

---

## Objection handling

**"Isn't hosting included in that?"** — Hosting is a machine. This covers the *recoverability* of your business logic on it. If we didn't add it, the risk doesn't disappear, it just moves onto me in a way I can't price properly. Here's the tier — most clients pick Essential.

**"We use n8n Cloud, so we're fine."** — Cloud removes server risk, not process risk: who owns the export, who can read the last workflow version, what happens when the seat payment fails. Same 20-line runbook, same monthly export into your own repo — included, no extra tier.

**"Do we need offsite if you back up locally?"** — A backup on the same disk fails with the disk. Provider account closures, expired cards and dead volumes take both together. Offsite is 40 cents a month and it's the reason we can restore from scratch on a brand-new server in 30 minutes.

---

## If you sell the kit itself (digital product, not a service)

Suggested one-liners for the listing, in your own voice:

- "For people who run client automations and can't tell a client 'we lost it.'"
- "Includes the exact form I send clients before I build anything, the 25-line incident runbook, and the paragraph that makes maintenance a paid line item."
- "No coding: every file is copy-paste, and every step says what you should see."
