#!/usr/bin/env python3
import json
import os
import re
import sys
import tempfile

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


def unwrap_str(val):
    if not isinstance(val, str):
        return ''
    if len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        try:
            parsed = json.loads(val)
            if isinstance(parsed, str):
                return parsed
        except Exception:
            pass
    return val


def state_file_for(conv_id):
    safe = re.sub(r'[^A-Za-z0-9_-]', '', conv_id or '')
    if not safe:
        return None
    base = os.path.join(tempfile.gettempdir(), f'agy-comment-check-{os.getuid()}')
    os.makedirs(base, mode=0o700, exist_ok=True)
    return os.path.join(base, f'{safe}.json')


def record_comments(state_path, path, count):
    counts = {}
    if os.path.exists(state_path):
        try:
            with open(state_path, 'r', encoding='utf-8') as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    counts = loaded
        except Exception:
            counts = {}
    counts[path] = int(counts.get(path, 0)) + count
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(state_path), text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            json.dump(counts, f, ensure_ascii=False)
        os.replace(tmp, state_path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def handle_post_tool_use(payload, state_path):
    tool_call = payload.get('toolCall') or {}
    if not isinstance(tool_call, dict):
        return
    tool = tool_call.get('name') or ''
    args = tool_call.get('args') or {}
    if not isinstance(args, dict):
        return
    path = unwrap_str(args.get('Path') or args.get('path'))
    leaders = leaders_for(path)
    if not leaders:
        return
    if tool == 'edit_file':
        new_text = unwrap_str(args.get('Replacement') or args.get('replacement'))
        old_lines = set(unwrap_str(args.get('Target') or args.get('target')).splitlines())
    elif tool == 'write_file':
        new_text = unwrap_str(args.get('Content') or args.get('content'))
        old_lines = set()
    else:
        return
    count = 0
    for line in new_text.splitlines():
        if line in old_lines or DIRECTIVE.match(line):
            continue
        if any(re.match(r'^\s*' + re.escape(leader), line) for leader in leaders):
            count += 1
    if count and state_path:
        record_comments(state_path, path, count)


def handle_post_invocation(state_path):
    if not state_path or not os.path.exists(state_path):
        print('{}')
        return
    try:
        with open(state_path, 'r', encoding='utf-8') as f:
            counts = json.load(f)
    except Exception:
        counts = {}
    try:
        os.unlink(state_path)
    except OSError:
        pass
    if not isinstance(counts, dict) or not counts:
        print('{}')
        return
    total = sum(int(v) for v in counts.values())
    items = list(counts.items())
    details = ', '.join(f'{p} ({c})' for p, c in items[:5])
    if len(items) > 5:
        details += f', +{len(items) - 5} files'
    context = f'Advisory: review {total} added comment line(s) against global AGENTS.md; {details}.'
    if len(context) > 480:
        context = context[:477] + '...'
    print(json.dumps({
        'injectSteps': [
            {
                'systemMessage': {
                    'systemMessage': context,
                }
            }
        ]
    }, ensure_ascii=False))


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        print('{}')
        return
    if not isinstance(payload, dict):
        print('{}')
        return
    state_path = state_file_for(payload.get('conversationId'))
    event = payload.get('hookEventName') or ('PostToolUse' if 'toolCall' in payload else '')
    if event == 'PostToolUse':
        handle_post_tool_use(payload, state_path)
        print('{}')
    elif event == 'PostInvocation':
        handle_post_invocation(state_path)
    else:
        print('{}')


if __name__ == '__main__':
    main()
