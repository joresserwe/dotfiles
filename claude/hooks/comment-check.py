#!/usr/bin/env python3
"""PostToolUse hook (Edit|Write): whenever Claude adds comment lines, feed the
comment checklist from claude/CLAUDE.md back to it as tool feedback. Exit 2 so
stderr reaches Claude; the edit itself is not blocked."""
import json
import os
import re
import sys

COMMENT_LEADERS = {
    '.yaml': '#', '.yml': '#', '.sh': '#', '.zsh': '#', '.bash': '#',
    '.ps1': '#', '.psm1': '#', '.psd1': '#', '.toml': '#', '.py': '#',
    '.txt': '#', '.conf': '#', '.tf': '#', '.rb': '#', '.pl': '#',
    '.lua': '--', '.sql': '--',
    '.ahk': ';', '.ini': ';',
    '.js': '//', '.ts': '//', '.jsx': '//', '.tsx': '//', '.mjs': '//',
    '.c': '//', '.h': '//', '.cpp': '//', '.hpp': '//', '.cs': '//',
    '.go': '//', '.rs': '//', '.java': '//', '.kt': '//', '.swift': '//',
    '.vbs': "'",
}

CHECKLIST = """\
You added comment line(s):
{lines}
Run the comment checklist from CLAUDE.md on each one — first match decides:
1. Change-story wording (added/removed/now/no longer/instead of/safe because,
   or any why-this-edit content) -> DELETE, put it in the commit message.
2. Explains why the edit was made or why it is correct -> DELETE, commit message.
3. Echo — content recoverable from the code it sits on -> DELETE.
   (Sibling comments/file density never justify keeping it.)
4. Observed failure, upstream bug/issue ref, required ordering, or non-obvious
   unit/format -> keep. On lines you MINT unasked, nothing else qualifies:
   identifier mappings ("X is the ... client"), why-this-key-over-that, tool
   background -> DELETE, commit message.
5. Nothing matched -> DELETE. Default is delete.
These are lines YOU wrote, not existing ones you kept: if you are weighing
whether one earns its place, it doesn't. Remove every non-rule-4 line now."""


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    tool = data.get('tool_name', '')
    ti = data.get('tool_input') or {}
    path = ti.get('file_path') or ''
    leader = COMMENT_LEADERS.get(os.path.splitext(path)[1].lower())
    if not leader:
        return
    if tool == 'Edit':
        new_text = ti.get('new_string') or ''
        old_lines = set((ti.get('old_string') or '').splitlines())
    elif tool == 'Write':
        new_text = ti.get('content') or ''
        old_lines = set()
    else:
        return
    pat = re.compile(r'^\s*' + re.escape(leader) + r'(?!!)')
    added = [ln.strip() for ln in new_text.splitlines()
             if ln not in old_lines and pat.match(ln)]
    if not added:
        return
    shown = '\n'.join('  ' + ln for ln in added[:15])
    if len(added) > 15:
        shown += f'\n  ... and {len(added) - 15} more'
    sys.stderr.write(CHECKLIST.format(lines=shown))
    sys.exit(2)


main()
