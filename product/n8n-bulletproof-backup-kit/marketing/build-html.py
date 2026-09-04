#!/usr/bin/env python3
"""Rebuild index.html from the markdown handbook. Usage:
    /path/to/venv/bin/python marketing/build-html.py
Needs the `markdown` package (pip install markdown in a venv).
"""
import markdown, os, html, datetime, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
docs = [("Read me first","README-KIT.md"),
        ("1 · Why n8n backups fail","01-WHY-BACKUPS-FAIL.md"),
        ("2 · Setup in 25 minutes","02-HOW-SETUP.md"),
        ("3 · Restore playbook","03-HOW-RESTORE.md"),
        ("4 · Running it forever","04-HOW-RUN-FOREVER.md"),
        ("Scripts reference","scripts/README.md")]
if not all(os.path.exists(f) for _,f in docs):
    sys.exit("missing one of the handbook files")
toc = ["## Table of contents",""] + [f"{i+1}. [{t}](#{i})" for i,(t,_) in enumerate(docs)] + [""]
body=[]
for i,(t,f) in enumerate(docs):
    body.append(f'<section id="{i}"><h1 class="doctitle">{html.escape(t)}</h1>')
    body.append(markdown.markdown(open(f,encoding="utf-8").read(),
                extensions=["tables","fenced_code","sane_lists","attr_list"]))
    body.append("</section>")
css = open("marketing/handbook.css").read()
updated = datetime.date.today().isoformat()
page = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>n8n Bulletproof — Backup &amp; Restore Kit</title>
<meta name="description" content="Backup, restore and disaster-recovery kit for self-hosted n8n on a VPS: encryption-key safety, nightly offsite copies, restore drill, client runbook.">
<style>{css}</style></head><body>
<header class="cover"><div class="wrap">
<h1>n8n Bulletproof</h1>
<p class="sub">Backup &amp; Restore Kit for self-hosted n8n — the scripts, the playbook, and the drill that proves a restore works.</p>
<div class="badges"><span>v1.0</span><span>Ubuntu / Debian + Docker</span><span>no coding required</span><span>updated {updated}</span></div>
</div></header>
<div class="wrap">
<div class="toc">{markdown.markdown(chr(10).join(toc))}</div>
{''.join(body)}
<footer>n8n Bulletproof Kit · v1.0 · you own everything in this file — scripts are plain bash, no network calls except your own storage provider.<br>
Support: reply to your Gumroad receipt. Changelog: <code>CHANGELOG.md</code>.</footer>
</div></body></html>"""
open("index.html","w",encoding="utf-8").write(page)
print("wrote index.html", len(page.encode()), "bytes")
