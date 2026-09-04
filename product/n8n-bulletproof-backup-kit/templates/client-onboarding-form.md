# Client automation onboarding — credentials & scope form

*Fill this **before** you build. Half of all rework in automation projects is a missing redirect URL, an approval that arrived four days late, or a "who owns this account?" argument discovered at handoff. Sending this form as page one of your proposal also quietly tells the client you run a serious process — which is why clients stay on retainers.*

---

## 1. Business context (3 lines each)

| Question | Answer |
|---|---|
| What should this automation replace, today? (be specific: "Maria copies leads from email into the CRM, 40 min/day") | |
| What does "working" look like in 30 days? (number, not feeling: "every form lead in HubSpot within 2 min, tagged") | |
| What happens if it stops for a day? (this sets the maintenance tier you charge) | |
| Who is the daily user / who sees errors? | |

## 2. Accounts & ownership — the part that bites later

| Service | Account owner (client / agency) | Login email | 2FA method | Can we create a **dedicated** API user / app? | Renewal date of that subscription |
|---|---|---|---|---|---|
| e.g. Google Workspace | Client | ops@client.com | Authenticator app | Yes — we need OAuth app with our redirect URI | |
| | | | | | |
| | | | | | |

**Ask for a dedicated integration user, not the founder's personal account.** Founder-owned Gmail + founder leaves company = your whole stack dies, and you're rebuilding under a legal argument.

## 3. Technical items you must collect up front

- [ ] Domain/subdomain for n8n (and who controls DNS): `n8n.____.com`
- [ ] VPS: provider, size, monthly cost, **whose account pays for it**
- [ ] Which services call **into** n8n (webhooks) — they need our URL, so we must fix the domain before build
- [ ] Any service that needs an allowlisted IP (banking APIs, ERP, some CRMs)
- [ ] OAuth apps that need a review/approval cycle (Slack, Google restricted scopes, HubSpot private app): **start today, budget days not hours**
- [ ] Data volume estimate (leads/day, orders/day, email size) → decides Postgres vs SQLite and execution-data retention
- [ ] Where the source of truth lives (CRM? Sheets? DB?) → decides who wins on conflict
- [ ] Anything with **PII / card data**: what must never be persisted in execution data (`EXECUTIONS_DATA_PRUNE` + field-level exclusion in high-risk nodes)

## 4. Failure & recovery expectations (this is the section that justifies your fee)

| Item | Value |
|---|---|
| Recovery Point Objective (how much data the automation can lose) | 24 h default · tighter = more cost |
| Recovery Time Objective (how long until it runs again) | 30 min |
| Who gets alerted when it breaks | |
| Response window (business hours / 24×7) | |
| Where the n8n **encryption key** is stored | client's password manager, copy held by agency |
| Backup location + retention | offsite bucket, 14 days daily |
| Restore drill date + who runs it | quarterly, agency, report emailed to client |
| If the client changes a password/API key without telling us | re-authorisation = 15 min billable |

## 5. Handoff & access

- [ ] Client gets: instance URL, own owner account (not shared), the runbook, the key note
- [ ] Agency gets: admin account (documented as such in writing) + deploy access to the repo holding the workflows JSON
- [ ] Workflows exported as JSON into a repo the **client owns** — even a private GitHub they create — so the relationship, not the vendor, is the source of truth
- [ ] 30-day support window defined, then retainer

## 6. Sign-off

By signing, the client confirms: they own the third-party accounts, they authorise automation touching them, and they accept that **credential re-entry is their responsibility after they change passwords**.

`Name / role / date: ______________________`
