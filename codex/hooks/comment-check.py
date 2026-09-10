#!/usr/bin/env python3
import json
import os
import re
import sys

COMMENT_LEADERS = {
    '.yaml': ('#',), '.yml': ('#',), '.sh': ('#',), '.zsh': ('#',),
    '.bash': ('#',), '.ps1': ('#',), '.psm1': ('#',), '.psd1': ('#',),
    '.toml': ('#',), '.py': ('#',), '.txt': ('#',), '.conf': ('#',),
    '.tf': ('#',), '.rb': ('#',), '.pl': ('#',), '.lua': ('--',),
    '.sql': ('--',), '.ahk': (';',), '.ini': (';',), '.js': ('//',),
    '.ts': ('//',), '.jsx': ('//',), '.tsx': ('//',), '.mjs': ('//',),
    '.c': ('//',), '.h': ('//',), '.cpp': ('//',), '.hpp': ('//',),
    '.cs': ('//',), '.go': ('//',), '.rs': ('//',), '.java': ('//',),
    '.kt': ('//',), '.swift': ('//',), '.vbs': ("'",),
    '.html': ('//', '<!--'), '.htm': ('//', '<!--'), '.xml': ('<!--',),
    '.vue': ('//', '<!--'), '.svelte': ('//', '<!--'),
    '.css': ('/*',), '.scss': ('//', '/*'), '.md': ('<!--',),
}

EXTENSIONLESS = {
    '.zshenv': ('#',), '.zshrc': ('#',), '.zprofile': ('#',),
    '.bashrc': ('#',), '.bash_profile': ('#',), 'Brewfile': ('#',),
    'Makefile': ('#',), 'Dockerfile': ('#',), 'Containerfile': ('#',),
    'Gemfile': ('#',), 'Rakefile': ('#',), 'Justfile': ('#',),
    '.aliases': ('#',), '.gitignore': ('#',), '.gitmodules': ('#',),
    'conf': ('#',), 'config': ('#',),
}

DIRECTIVE = re.compile(
    r'^\s*(?:#!|#\s*(?:shellcheck|noqa|pyright|pylint|mypy|yamllint|markdownlint)\b|'
    r'#\s*(?:type:|fmt:|pragma:)\s*|'
    r'//\s*(?:go:|nolint\b|clang-format|eslint|prettier)|<!--\s*eslint\b)'
)


def leaders_for(path):
    name = os.path.basename(path)
    if name in EXTENSIONLESS:
        return EXTENSIONLESS[name]
    return COMMENT_LEADERS.get(os.path.splitext(name)[1].lower(), ())


def added_comments(command):
    path = ''
    found = []
    for line in command.splitlines():
        match = re.match(r'^\*\*\* (?:Add|Update|Delete) File: (.+)$', line)
        if match:
            path = match.group(1).strip()
            continue
        if not path or not line.startswith('+') or line.startswith('+++'):
            continue
        content = line[1:]
        leaders = leaders_for(path)
        if not leaders or DIRECTIVE.match(content):
            continue
        if any(re.match(r'^\s*' + re.escape(leader), content) for leader in leaders):
            found.append((path, content.strip()))
    return found


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    if not isinstance(payload, dict):
        return
    if payload.get('tool_name') != 'apply_patch':
        return
    tool_input = payload.get('tool_input') or {}
    if not isinstance(tool_input, dict):
        return
    command = tool_input.get('command')
    if not isinstance(command, str):
        return
    comments = added_comments(command)
    if not comments:
        return
    counts = {}
    for path, _ in comments:
        counts[path] = counts.get(path, 0) + 1
    details = ', '.join(f'{path} ({count})' for path, count in list(counts.items())[:5])
    if len(counts) > 5:
        details += f', +{len(counts) - 5} files'
    context = f'Advisory: review {len(comments)} added comment line(s) against global AGENTS.md; {details}.'
    if len(context) > 480:
        context = context[:477] + '...'
    print(json.dumps({
        'hookSpecificOutput': {
            'hookEventName': 'PostToolUse',
            'additionalContext': context,
        }
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
