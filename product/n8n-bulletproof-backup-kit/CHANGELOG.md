# Changelog — n8n Bulletproof Backup & Restore Kit

## v1.0 — 2026-09-04
**First release.** Targets self-hosted n8n (≥1.x) on Ubuntu/Debian with Docker Compose.

- `scripts/01-preflight-check.sh` — read-only survival check (key, volume mount, DB type, backup freshness, offsite, cron, last drill). Validated with `bash -n` and run on a Docker-less host to confirm graceful FAIL output.
- `scripts/02-backup.sh` — nightly capture: Postgres `pg_dump` (or SQLite consistent `.backup`), data-volume tar, encryption key (env var → volume config fallback), `n8n export:workflow/credentials --backup`, masked `.env` copy, `MANIFEST.txt` with restore order, SHA256, retention pruning, optional rclone offsite + healthchecks.io ping, `STATUS=OK` log line.
- `scripts/03-restore.sh` — three modes: `json` (default, additive, safe on fresh instances), `volume`, `database` (`pg_restore --clean --if-exists`). Interactive `YES` confirmation, `FORCE=1` for automation.
- `scripts/04-restore-drill.sh` — isolated throwaway instance (own compose project, own empty Postgres DB, `127.0.0.1:5678`), imports latest backup, browser verification checklist, self-destructs; writes `~/.n8n-last-drill`.
- `scripts/05-offsite.sh` — rclone setup helper (Backblaze B2 / R2 / Wasabi) + `crypt` wrapper + sync with `rclone check` skip-if-identical.
- `scripts/docker-compose.yml` — pinned image, Postgres 16 + healthcheck, **refuses to start without `N8N_ENCRYPTION_KEY`** (`:?` guard), execution-data pruning, TLS-terminating-proxy-ready, internal + proxy networks.
- `scripts/.env.example`, `scripts/n8n-backup.defaults` (→ `/etc/n8n-backup.env`), `scripts/README.md`.
- Handbook: `01-WHY-BACKUPS-FAIL.md` (4 failure modes), `02-HOW-SETUP.md` (9 steps), `03-HOW-RESTORE.md` (4 scenarios + key-lost decision tree), `04-HOW-RUN-FOREVER.md` (monitoring, drills, disk math, upgrades, SQLite→Postgres, queue-mode key sharing, client handoff, annual review).
- `templates/` — client onboarding form (credentials/ownership/scope), 25-line incident runbook, proposal snippets with 3 maintenance tiers and objection handling.
- `index.html` — printable single-file handbook (browser → Print → Save as PDF).
- `marketing/` — cover art, Gumroad listing copy, 3 SEO posts targeting exact-error queries.

**Verified against:** n8n CLI flags from official docs (`export:workflow|credentials --all --backup --separate --pretty --decrypted --output`, `import:* --input/--separate`, imported workflows arrive deactivated by default), encryption-key behaviour (`~/.n8n/config`, `N8N_ENCRYPTION_KEY`, per-worker key requirement in queue mode), and current backup/restore practice in community and hosting guides.
**Known limits:** not HA/zero-downtime; Windows and n8n Cloud out of scope; `01-preflight-check.sh` uses GNU coreutils (`stat -c`, `find -printf`) so it targets Linux servers, not macOS laptops.

### Planned
- [ ] `rclone` → S3-compatible example for MinIO on a second box (self-hosted offsite)
- [ ] Optional `--dry-run` flag on `02-backup.sh` listing exactly what it will capture
- [ ] Notion/Linear-free `restored successfully ✓` client report template
