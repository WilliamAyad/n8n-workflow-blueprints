# Contributing to n8n Workflow Blueprints

Thank you for helping make this resource better for the n8n community.

## What Makes a Good Blueprint

A blueprint that gets merged is **actually useful**:

- **It runs.** Test your workflow with real credentials before submitting. A broken JSON wastes everyone's time.
- **It solves a real problem.** "Hello World" workflows are not blueprints. A workflow that saves an hour per week for a real business is.
- **It is documented.** The README entry must explain what the workflow does, what credentials it needs, and what n8n version it requires.
- **It uses placeholders correctly.** Any value the user must replace (API keys, URLs, IDs) must be clearly marked as `YOUR_VALUE_HERE` in the JSON.

## Folder Structure

```
workflows/
├── ai-automation/      # AI agents, LLM workflows, image generation
├── small-business/     # CRM, invoicing, email, scheduling
├── fixed-errors/       # Companion workflows demonstrating error fixes
└── mcp/                # MCP server and client patterns
```

Place your JSON in the most relevant category. If it fits multiple categories, choose the primary use case.

## JSON File Requirements

1. **Remove real credentials.** Replace all API keys, passwords, and personal IDs with `YOUR_API_KEY_HERE` style placeholders.
2. **Use descriptive node names.** "HTTP Request" is bad. "Fetch Invoice from Stripe" is good.
3. **Set `"active": false`** — imported workflows should never activate automatically.
4. **Include a comment node** (Sticky Note) at the top of the canvas explaining the workflow in 2–3 sentences.
5. **Test your JSON parses.** Run `python3 -c "import json; json.load(open('your-file.json'))"` before submitting.

## README Entry Format

Add your workflow to the correct section in `README.md` using this exact format:

```markdown
### N. Workflow Name

One sentence describing what the workflow does and who it's for.

**What it does:**
- Step 1 → Step 2 → Step 3
- (list the main data flow in 3–5 bullet points)

**Credentials required:** List of services  
**n8n version:** Minimum version tested  

📥 **[Download JSON](workflows/category/filename.json)**  
📖 **[Full Tutorial → link text](https://link-to-documentation)**
```

## Pull Request Process

1. Fork the repository.
2. Create a branch: `git checkout -b add/my-workflow-name`
3. Add your JSON file and update `README.md`.
4. Update `CHANGELOG.md` with a one-line entry under `[Unreleased]`.
5. Open a Pull Request. Title format: `Add: [Workflow Name]`

A maintainer will review within a few days. If changes are requested, please respond within 2 weeks or the PR may be closed.

## Reporting Broken Workflows

If a workflow in this repo stops working (API changes, n8n version changes), open an Issue using the **Bug Report** template. Include:
- Which workflow file
- Your n8n version
- The error message from the execution log
- Any steps you already tried

## Code of Conduct

Be constructive. Feedback on PRs should be specific and actionable, not dismissive. We're all here to make n8n easier for everyone.
