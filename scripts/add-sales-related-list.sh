#!/usr/bin/env bash
# Adds the Sales related list to every Account page layout already in the org, then deploys those layouts.
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-dev-edition}"

layouts=$(sf org list metadata --metadata-type Layout --target-org "$TARGET" --json | python3 -c '
import json, sys
payload = json.load(sys.stdin)
if payload.get("status") not in (0, None):
    raise SystemExit(payload.get("message") or payload)
rows = payload.get("result", [])
if isinstance(rows, dict):
    raise SystemExit(rows.get("message") or rows)
for row in rows:
    name = row.get("fullName", "")
    if name.startswith("Account-"):
        print(name)
')

if [ -z "$layouts" ]; then
  echo "No Account page layouts were found." >&2
  exit 1
fi

while IFS= read -r name; do
  sf project retrieve start --metadata "Layout:${name}" --target-org "$TARGET"
done <<< "$layouts"

python3 - <<'PY'
from pathlib import Path

block = """    <relatedLists>
        <fields>NAME</fields>
        <fields>SaleDate__c</fields>
        <fields>Amount__c</fields>
        <relatedList>Sale__c.Account__c</relatedList>
    </relatedLists>
"""
root = Path("force-app/main/default/layouts")
changed = 0
for path in sorted(root.glob("Account-*.layout-meta.xml")):
    text = path.read_text()
    if "<relatedList>Sale__c.Account__c</relatedList>" in text and text.find("<relatedList>Sale__c.Account__c</relatedList>") < text.find("<relatedObjects>"):
        print(f"Already present: {path.name}")
        continue
    text = text.replace(block, "")
    needle = "    <relatedObjects>"
    if needle not in text:
        raise SystemExit(f"No relatedObjects in {path}")
    path.write_text(text.replace(needle, block + needle, 1))
    print(f"Added Sales related list: {path.name}")
    changed += 1
if changed == 0:
    print("No layout changes to deploy.")
PY

sf project deploy start \
  --source-dir force-app/main/default/layouts \
  --target-org "$TARGET"
