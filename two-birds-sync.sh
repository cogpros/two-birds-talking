#!/usr/bin/env bash
# two-birds-sync.sh -- Sync debrief markdown files into the HTML viewer
# Replaces data between EMBEDDED_DATA markers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

export TBT_DEBRIEFS_DIR="${DEBRIEFS_DIR:-./debriefs}"
export TBT_VIEWER_FILE="${VIEWER_FILE:-./viewer.html}"

if [[ ! -f "$TBT_VIEWER_FILE" ]]; then
  echo "Viewer not found at $TBT_VIEWER_FILE" >&2
  exit 1
fi

python3 << 'PYEOF'
import json, os, glob

debriefs_dir = os.path.expanduser(os.environ["TBT_DEBRIEFS_DIR"])
html_file = os.path.expanduser(os.environ["TBT_VIEWER_FILE"])

entries = []
for f in sorted(glob.glob(os.path.join(debriefs_dir, "*.md"))):
    date = os.path.basename(f).replace(".md", "")
    with open(f) as fh:
        content = fh.read().strip()
    entries.append({"date": date, "content": content})

data_str = json.dumps(entries, ensure_ascii=False)

with open(html_file, "r") as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    if "// EMBEDDED_DATA_START" in line:
        out.append(line)
        out.append(f"let DEBRIEFS = {data_str};\n")
        skip = True
        continue
    if "// EMBEDDED_DATA_END" in line:
        out.append(line)
        skip = False
        continue
    if not skip:
        out.append(line)

with open(html_file, "w") as f:
    f.writelines(out)

print(f"Synced {len(entries)} debriefs to {html_file}")
PYEOF
