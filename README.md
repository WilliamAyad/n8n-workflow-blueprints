# 🔌 n8n Workflow Blueprints

> **Production-ready n8n workflow templates you can import and run today.**
> Each blueprint includes a full JSON file, setup instructions, required credentials, and a link to the complete tutorial.

[![Workflows](https://img.shields.io/badge/Workflows-12-C9920A?style=flat-square)](https://github.com/triggerworkflow/n8n-workflow-blueprints)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![n8n Version](https://img.shields.io/badge/n8n-%3E%3D1.88.0-blue?style=flat-square)](https://n8n.io)
[![Last Updated](https://img.shields.io/badge/Updated-June%202026-purple?style=flat-square)](CHANGELOG.md)

---

## Why This Repo Exists

Most n8n resources give you a screenshot. This repo gives you the **actual JSON** you can import in 30 seconds.

Every workflow here is:
- ✅ Tested on n8n v1.88.0+
- ✅ Documented with node-by-node explanations
- ✅ Includes credentials setup guide
- ✅ Includes common error fixes
- ✅ Links to a full tutorial for each blueprint

**Maintained by [TriggerWorkflow.com](https://www.triggerworkflow.com)** — practical n8n automation tutorials for developers and small business owners.

---

## 📁 Workflow Categories

| Category | Workflows | Description |
|----------|-----------|-------------|
| [🤖 AI Automation](#-ai-automation) | 4 | AI agents, content generation, MCP servers |
| [🏢 Small Business](#-small-business) | 4 | Invoice processing, lead routing, email automation |
| [🐛 Error Fixes](#-error-fixes) | 2 | Common n8n errors with working fix workflows |
| [🔌 MCP](#-mcp-model-context-protocol) | 2 | MCP server and client patterns |

---

## 🤖 AI Automation

### 1. AI Content Factory (DeepSeek + Gemini Imagen + Blogger)

Generates, illustrates, and publishes blog posts automatically. Includes OAuth token auto-refresh, human review gateway via email, and in-article image injection.

**What it does:**
- Schedule Trigger → DeepSeek topic generation (JSON-parsed, BOM-safe)
- Per-topic article writing with `<!--IMG:description-->` placeholders
- Gemini Imagen 3 image generation + imgbb upload (base64 prefix stripped)
- Email-based human review gate (approve/reject links via n8n Wait node)
- Blogger API publish with fresh OAuth token from sub-workflow

**Credentials required:** DeepSeek API, Google Gemini API, imgbb API, Blogger OAuth 2.0, Gmail  
**n8n version:** 1.88.0+  
**Estimated cost:** ~$0.031/100 articles (DeepSeek tokens only)

📥 **[Download JSON](workflows/ai-automation/ai-content-factory.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-build-an-ai-content-factory-with-n8n-deepSeek-and-gemini.html)**

---

### 2. n8n AI Agent (LangChain + Tool Nodes)

A production-ready AI agent with memory, tool access, and structured output. Connects to external APIs as tools and maintains conversation context.

**What it does:**
- Chat Trigger → LangChain Agent node
- Tool nodes: HTTP Request (any API), Code node, Google Sheets read/write
- Window Buffer Memory for conversation context
- Structured JSON output with error handling

**Credentials required:** OpenAI API key (or any compatible LLM endpoint)  
**n8n version:** 1.70.0+

📥 **[Download JSON](workflows/ai-automation/ai-agent-with-tools.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-build-ai-agent-with-n8n-step-by-step-guide.html)**

---

### 3. Invoice Data Extractor (AI + Google Sheets)

Extracts structured data from invoice PDFs using an LLM, validates the output, and writes to a Google Sheet — with a fallback row for extraction failures.

**What it does:**
- Email trigger (Gmail) → PDF attachment extraction
- LLM prompt with JSON schema enforcement
- Output validation (required fields check)
- Google Sheets append (success) or error log sheet (failure)

**Credentials required:** Gmail, OpenAI or DeepSeek API, Google Sheets  
**n8n version:** 1.80.0+

📥 **[Download JSON](workflows/ai-automation/invoice-extractor-ai.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-automate-invoice-processing-unpaid-reminders-using-n8n.html)**

---

### 4. RSS → AI Rewrite → Auto Publish

Monitors RSS feeds, rewrites articles using DeepSeek, and publishes to Blogger. Includes duplicate detection via Google Sheets and configurable publishing schedule.

**What it does:**
- Schedule Trigger → RSS Read → Google Sheets duplicate check
- DeepSeek rewrite with tone prompt
- Blogger API publish (with OAuth refresh sub-workflow)
- Google Sheets log (URL + timestamp)

**Credentials required:** DeepSeek API, Blogger OAuth 2.0, Google Sheets  
**n8n version:** 1.88.0+

📥 **[Download JSON](workflows/ai-automation/rss-ai-rewrite-publish.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com)**

---

## 🏢 Small Business

### 5. Invoice Processing + Unpaid Payment Reminders

Full invoice lifecycle: extract → store → track payment → send reminders at Day 7, Day 14, Day 30.

**What it does:**
- Gmail trigger → invoice data extraction
- Google Sheets storage with status column (`PENDING`, `PAID`, `OVERDUE`)
- Daily scheduler checks overdue invoices
- Gmail reminder with escalating tone per reminder stage

**Credentials required:** Gmail, Google Sheets  
**n8n version:** 1.60.0+

📥 **[Download JSON](workflows/small-business/invoice-reminders.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-automate-invoice-processing-unpaid-reminders-using-n8n.html)**

---

### 6. Lead Capture → CRM + Slack Notification

Webhook receives a new lead (from any form), enriches it, stores in Google Sheets as CRM, and sends a formatted Slack notification.

**What it does:**
- Webhook trigger → field validation (required: name, email)
- IP geolocation enrichment (ipapi.co, free tier)
- Google Sheets append
- Slack message with lead card (name, company, source, location)

**Credentials required:** Slack Bot Token, Google Sheets  
**n8n version:** 1.50.0+

📥 **[Download JSON](workflows/small-business/lead-capture-crm-slack.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com)**

---

### 7. Google Sheets → Email Report (Daily/Weekly)

Reads a Google Sheet, computes a summary (total, average, top item), and sends a formatted HTML report to one or multiple recipients.

**What it does:**
- Schedule Trigger → Google Sheets read
- Code node: compute totals, averages, top performers
- Gmail send with HTML email template (inline CSS)
- Optional: CC logic based on threshold values

**Credentials required:** Gmail, Google Sheets  
**n8n version:** 1.50.0+

📥 **[Download JSON](workflows/small-business/sheets-email-report.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com)**

---

### 8. Social Media Post Scheduler

Reads scheduled posts from a Google Sheet and publishes to multiple platforms at the right time.

**What it does:**
- Schedule Trigger (every 15 min) → Google Sheets read
- Filter: rows where `publish_at <= now` and `status = PENDING`
- Branch by platform (Twitter/X, LinkedIn, Facebook)
- Update sheet row status to `PUBLISHED` after success

**Credentials required:** Google Sheets, Twitter API v2 (or LinkedIn, Meta API)  
**n8n version:** 1.60.0+

📥 **[Download JSON](workflows/small-business/social-scheduler.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com)**

---

## 🐛 Error Fixes

These are companion workflows that demonstrate the fix for common n8n errors — importable and runnable so you can see the solution working before applying it.

### 9. Fix: "Workflow Execution Failed" — Debug Template

A diagnostic workflow that reproduces the most common execution failure patterns and shows the correct fix for each: timeout, JSON parse error, credential mismatch, and webhook loop.

📥 **[Download JSON](workflows/fixed-errors/execution-failed-debug.json)**  
📖 **[Full Error Guide → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-fix-workflow-execution-failed-error-in-n8n.html)**

---

### 10. Fix: OAuth Token Expiry — Auto Refresh Sub-Workflow

A standalone sub-workflow that refreshes a Google OAuth 2.0 access token every 50 minutes and stores it for use by other workflows. Prevents 401 errors on Blogger, Google Sheets, and Gmail integrations.

📥 **[Download JSON](workflows/fixed-errors/oauth-token-refresher.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/how-to-build-an-ai-content-factory-with-n8n-deepSeek-and-gemini.html)**

---

## 🔌 MCP (Model Context Protocol)

### 11. MCP Server — Expose Your n8n Workflows as AI Tools

The per-workflow MCP Server pattern: MCP Server Trigger with three tool nodes (search workflows, add to available pool via Redis, execute workflow). Correctly wired with `ai_tool` connections.

**What it does:**
- MCP Server Trigger → Search Workflows tool (n8n node, tagged "mcp")
- Add to Available tool (Redis SET with session key)
- Execute Workflow tool (Custom n8n Workflow Tool)
- Any MCP client (Claude Desktop, Cursor, ChatGPT) can discover and run your workflows

**Credentials required:** n8n API key, Redis  
**n8n version:** 1.88.0+

📥 **[Download JSON](workflows/mcp/mcp-server-workflow.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/n8n-mcp-server-connect-your-ai-agent-to-any-tool.html)**

---

### 12. MCP Client — n8n as an AI Agent Consuming External MCP Tools

An AI Agent workflow that connects to an external MCP server (any SSE/HTTP endpoint) and uses its tools as part of an n8n automation.

**What it does:**
- Chat Trigger → AI Agent node
- MCP Client Tool node (SSE connection to external MCP server)
- Agent decides which MCP tool to call and when
- Response formatted and returned to chat

**Credentials required:** OpenAI API (or compatible LLM), MCP server URL + Bearer token  
**n8n version:** 1.88.0+

📥 **[Download JSON](workflows/mcp/mcp-client-agent.json)**  
📖 **[Full Tutorial → TriggerWorkflow.com](https://www.triggerworkflow.com/2026/06/n8n-mcp-server-connect-your-ai-agent-to-any-tool.html)**

---

## 🚀 How to Import a Workflow

1. Open your n8n instance
2. Go to **Workflows** → top-right menu → **Import from File**
3. Select the `.json` file from this repo
4. Replace placeholder credentials (marked as `YOUR_*_HERE`)
5. Activate and test

> **Tip:** Always use the **Test Execution** button before activating a workflow. Check the execution log for any credential errors.

---

## ⚠️ Important Notes

- **Credential IDs** in JSON files are placeholders — you must reconnect credentials after import.
- **Node type strings** (e.g. `n8n-nodes-base.httpRequest`) can shift between n8n versions. If a node fails to import, build it manually from the UI and re-export.
- **Pricing APIs** (DeepSeek, Gemini) may change their endpoint URLs or model names. Always verify in the provider's current documentation.
- These workflows are tested on n8n **v1.88.0 – v2.18.x**. Earlier versions may lack certain node types.

---

## 🤝 Contributing

Found a bug? Have a workflow to share? Contributions are welcome.

1. Fork this repo
2. Add your workflow JSON to the appropriate category folder
3. Update `README.md` with the workflow description and setup notes
4. Open a Pull Request with a clear title: `Add: [workflow name]`

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

---

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and new additions.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

You are free to use, modify, and distribute these workflows in personal and commercial projects. Attribution appreciated but not required.

---

## 🔗 More Resources

- 📚 **Full tutorials:** [TriggerWorkflow.com](https://www.triggerworkflow.com) — in-depth n8n guides for every workflow in this repo
- 🐛 **Error fixes:** [n8n Error Troubleshooting Guides](https://www.triggerworkflow.com/2026/06/how-to-fix-workflow-execution-failed-error-in-n8n.html)
- 🤖 **AI Automation:** [Build an AI Content Factory](https://www.triggerworkflow.com/2026/06/how-to-build-an-ai-content-factory-with-n8n-deepSeek-and-gemini.html)
- 🔌 **MCP Server:** [Connect Your AI Agent to n8n](https://www.triggerworkflow.com/2026/06/n8n-mcp-server-connect-your-ai-agent-to-any-tool.html)
- 💬 **n8n Community:** [community.n8n.io](https://community.n8n.io)

---

*Maintained with ❤️ by [William Ayadi](https://www.triggerworkflow.com) — if this repo saved you time, a ⭐ helps others find it.*
