#!/usr/bin/env bash
exec python3 -c '
import json
import os
import subprocess
import sys
import unicodedata

raw = sys.stdin.read()
if not raw.strip():
    raise SystemExit(0)
try:
    d = json.loads(raw)
except Exception:
    raise SystemExit(0)
if not isinstance(d, dict):
    raise SystemExit(0)

E = "\033"
RST = f"{E}[0m"
BOLD = f"{E}[1m"
NOBOLD = f"{E}[22m"


def fg(r, g, b):
    return f"{E}[38;2;{r};{g};{b}m"


def bg(r, g, b):
    return f"{E}[48;2;{r};{g};{b}m"


CRUST_FG = fg(17, 17, 27)
SURF0_BG = bg(49, 50, 68)
SURF0_FG = fg(49, 50, 68)
SURF2_FG = fg(88, 91, 112)
OVL0_FG = fg(108, 112, 134)
OVL1_FG = fg(127, 132, 156)
SUB0_FG = fg(166, 173, 200)
TEXT_FG = fg(205, 214, 244)

MAUVE = (203, 166, 247)
LAVENDER = (180, 190, 254)
BLUE = (137, 180, 250)
SAPPHIRE = (116, 199, 236)
SKY = (137, 220, 235)
TEAL = (148, 226, 213)
GREEN = (166, 227, 161)
YELLOW = (249, 226, 175)
PEACH = (250, 179, 135)
RED = (243, 139, 168)

ROUND_L = "\ue0b6"
ROUND_R = "\ue0b4"


def cell_width(text):
    w = 0
    for ch in text:
        cp = ord(ch)
        if 0xE000 <= cp <= 0xF8FF or cp >= 0xF0000:
            w += 2
        elif unicodedata.east_asian_width(ch) in ("W", "F"):
            w += 2
        else:
            w += 1
    return w


def make_pill(icon, accent, parts):
    ac_fg = fg(*accent)
    ac_bg = bg(*accent)
    body_ansi = "".join(f"{color}{txt}" for color, txt in parts)
    body_plain = "".join(txt for _, txt in parts)
    rendered = (
        f"{ac_fg}{ROUND_L}"
        f"{ac_bg}{CRUST_FG}{icon}"
        f"{SURF0_BG}{ac_fg}█"
        f"{SURF0_BG}{TEXT_FG} {body_ansi} "
        f"{RST}{SURF0_FG}{ROUND_R}{RST}"
    )
    width = 1 + cell_width(icon) + 1 + 1 + cell_width(body_plain) + 1 + 1
    return rendered, width


def fmt_tokens(n):
    if not n or n <= 0:
        return "0"
    if n >= 950_000:
        m = n / 1_048_576 if abs(n - round(n / 1_048_576) * 1_048_576) < 65_536 else n / 1_000_000
        return f"{m:.0f}M" if abs(m - round(m)) < 0.08 else f"{m:.1f}M"
    if n >= 1_000:
        return f"{round(n / 1_000)}k"
    return str(int(n))


state = d.get("agent_state") or "idle"
confirm = bool(d.get("tool_confirmation_pending"))
if confirm:
    m_accent, m_icon = RED, "\uf071"
elif state == "error":
    m_accent, m_icon = RED, "\uf071"
elif state in ("working", "initializing", "authenticating"):
    m_accent, m_icon = SAPPHIRE, "\U000f06a9"
elif state in ("tool_use", "reviewing"):
    m_accent, m_icon = PEACH, "\U000f06a9"
else:
    m_accent, m_icon = MAUVE, "\U000f06a9"

m_obj = d.get("model")
if isinstance(m_obj, dict):
    m_name = m_obj.get("display_name") or m_obj.get("id") or "agy"
    effort = m_obj.get("effort") or ""
elif isinstance(m_obj, str) and m_obj:
    m_name, effort = m_obj, ""
else:
    m_name, effort = "agy", ""
if not effort and isinstance(d.get("effort"), dict):
    effort = d["effort"].get("level") or ""

m_parts = [(f"{BOLD}{TEXT_FG}", m_name)]
if effort:
    ef_map = {
        "low": (OVL1_FG, "low"),
        "medium": (fg(*SKY), "med"),
        "high": (fg(*PEACH), "high"),
        "xhigh": (fg(*MAUVE), "xhigh"),
        "max": (fg(*RED), "max"),
    }
    ef_col, ef_lbl = ef_map.get(effort, (fg(*YELLOW), effort))
    m_parts.append((f"{NOBOLD}{ef_col}", f" \uf0e7{ef_lbl}"))
else:
    m_parts.append((NOBOLD, ""))

cycle = d.get("cycle_mode") or ""
if cycle:
    cy_map = {
        "auto": (fg(*GREEN), "auto"),
        "accept-edits": (fg(*YELLOW), "edits"),
        "plan": (fg(*LAVENDER), "plan"),
    }
    cy_col, cy_lbl = cy_map.get(cycle, (SUB0_FG, cycle))
    m_parts.append((OVL0_FG, " · "))
    m_parts.append((cy_col, cy_lbl))

vim_mode = (d.get("vim") or {}).get("mode") if isinstance(d.get("vim"), dict) else ""
if vim_mode:
    vm = {"NORMAL": (fg(*BLUE), "N"), "INSERT": (fg(*GREEN), "I")}.get(vim_mode, (fg(*MAUVE), "V"))
    m_parts.append((vm[0], f" [{vm[1]}]"))

if confirm:
    m_parts.append((f"{BOLD}{fg(*RED)}", " !ask"))
    m_parts.append((NOBOLD, ""))

pill_model = make_pill(m_icon, m_accent, m_parts)

ws = d.get("workspace") if isinstance(d.get("workspace"), dict) else {}
cwd = ws.get("current_dir") or d.get("cwd") or ""
proj = ws.get("project_dir") or ""
pill_dir = None
if cwd:
    c_norm = cwd.rstrip("/") or "/"
    p_norm = proj.rstrip("/") if proj else ""
    if p_norm and c_norm.startswith(p_norm + "/"):
        rel = c_norm[len(p_norm) + 1 :]
        p_base = os.path.basename(p_norm)
        parts_rel = rel.split("/")
        dir_label = f"{p_base}/{parts_rel[-1]}" if len(parts_rel) == 1 else f"{p_base}/…/{parts_rel[-1]}"
    else:
        dir_label = os.path.basename(c_norm) or "/"
    pill_dir = make_pill("\uf07b", BLUE, [(TEXT_FG, dir_label)])

pill_git = None
if cwd and os.path.isdir(cwd):
    try:
        proc = subprocess.run(
            ["git", "-C", cwd, "status", "--porcelain=v2", "--branch"],
            capture_output=True,
            text=True,
            timeout=0.4,
        )
        if proc.returncode == 0:
            branch = ""
            ahead = behind = staged = modified = untracked = conflicts = 0
            for ln in proc.stdout.splitlines():
                if ln.startswith("# branch.head "):
                    branch = ln[14:].strip()
                elif ln.startswith("# branch.ab "):
                    for tok in ln[12:].split():
                        if tok.startswith("+"):
                            ahead = int(tok[1:] or 0)
                        elif tok.startswith("-"):
                            behind = int(tok[1:] or 0)
                elif ln.startswith("? "):
                    untracked += 1
                elif ln.startswith("u "):
                    conflicts += 1
                elif ln.startswith(("1 ", "2 ")):
                    xy = ln.split(" ", 2)[1]
                    if len(xy) >= 2:
                        if xy[0] != ".":
                            staged += 1
                        if xy[1] != ".":
                            modified += 1
            if branch and branch != "(detached)":
                b_disp = branch if len(branch) <= 22 else branch[:21] + "…"
            elif branch == "(detached)":
                b_disp = "detached"
            else:
                b_disp = ""
            if b_disp:
                dirty = staged + modified + untracked + conflicts
                g_accent = RED if conflicts else (YELLOW if dirty else GREEN)
                g_parts = [(TEXT_FG, b_disp)]
                if ahead:
                    g_parts.append((fg(*SKY), f" ↑{ahead}"))
                if behind:
                    g_parts.append((fg(*SKY), f" ↓{behind}"))
                if conflicts:
                    g_parts.append((fg(*RED), f" !{conflicts}"))
                if staged:
                    g_parts.append((fg(*GREEN), f" ●{staged}"))
                if modified:
                    g_parts.append((fg(*PEACH), f" ✚{modified}"))
                if untracked:
                    g_parts.append((OVL1_FG, f" ?{untracked}"))
                if not dirty and not ahead and not behind:
                    g_parts.append((fg(*GREEN), " ✔"))
                pill_git = make_pill("\uf1d3", g_accent, g_parts)
    except Exception:
        pass

cw = d.get("context_window") if isinstance(d.get("context_window"), dict) else {}
pct = int(cw.get("used_percentage") or 0)
if pct >= 80:
    c_accent = RED
elif pct >= 55:
    c_accent = YELLOW
else:
    c_accent = TEAL

bar_w = 8
filled = min(max(round(pct * bar_w / 100), 1 if pct > 0 else 0), bar_w)
bar_parts = []
if filled:
    bar_parts.append((fg(*c_accent), "━" * filled))
if filled < bar_w:
    bar_parts.append((SURF2_FG, "─" * (bar_w - filled)))
bar_parts.append((f"{BOLD}{TEXT_FG}", f" {pct}%"))
bar_parts.append((NOBOLD, ""))

cur_u = cw.get("current_usage") if isinstance(cw.get("current_usage"), dict) else {}
used_tok = cur_u.get("input_tokens") or cw.get("total_input_tokens") or 0
size_tok = cw.get("context_window_size") or 0
pill_ctx_compact = make_pill("\U000f035b", c_accent, list(bar_parts))
if size_tok > 0:
    bar_parts_full = list(bar_parts) + [(SUB0_FG, f" {fmt_tokens(used_tok)}/{fmt_tokens(size_tok)}")]
    pill_ctx = make_pill("\U000f035b", c_accent, bar_parts_full)
else:
    pill_ctx = pill_ctx_compact

pill_ops = None
subs = d.get("subagents") if isinstance(d.get("subagents"), list) else []
running_subs = sum(1 for s in subs if isinstance(s, dict) and s.get("status") == "running")
tasks = int(d.get("task_count") or 0)
queued = int(d.get("pending_input_count") or 0)
ops_tokens = []
if running_subs:
    ops_tokens.append((fg(*SAPPHIRE), f"{running_subs} sub"))
if tasks:
    if ops_tokens:
        ops_tokens.append((OVL0_FG, " · "))
    ops_tokens.append((fg(*SKY), f"{tasks} task"))
if queued:
    if ops_tokens:
        ops_tokens.append((OVL0_FG, " · "))
    ops_tokens.append((fg(*YELLOW), f"+{queued} q"))
if ops_tokens:
    pill_ops = make_pill("\U000f0626", SAPPHIRE, ops_tokens)

pill_quota = None
q_parts = []
q_worst_rem = 100
quota = d.get("quota") if isinstance(d.get("quota"), dict) else {}
for key, val in quota.items():
    if not isinstance(val, dict) or val.get("disabled"):
        continue
    rem_f = val.get("remaining_fraction")
    if rem_f is None:
        continue
    rem = round(float(rem_f) * 100)
    q_worst_rem = min(q_worst_rem, rem)
    k_low = key.lower()
    if "week" in k_low or "7d" in k_low:
        lbl = "7d"
    elif "five" in k_low or "5h" in k_low:
        lbl = "5h"
    elif "day" in k_low or "daily" in k_low:
        lbl = "1d"
    else:
        lbl = key.replace("gemini-", "")[:6]
    q_col = fg(*RED) if rem <= 15 else (fg(*YELLOW) if rem <= 40 else fg(*GREEN))
    if q_parts:
        q_parts.append((OVL0_FG, " · "))
    q_parts.append((SUB0_FG, f"{lbl} "))
    q_parts.append((q_col, f"{rem}%"))

rl = d.get("rate_limits") if isinstance(d.get("rate_limits"), dict) else {}
if not q_parts and rl:
    for lbl, rkey in (("5h", "five_hour"), ("7d", "seven_day")):
        obj = rl.get(rkey)
        if isinstance(obj, dict) and obj.get("used_percentage") is not None:
            rem = max(0, 100 - round(float(obj["used_percentage"])))
            q_worst_rem = min(q_worst_rem, rem)
            q_col = fg(*RED) if rem <= 15 else (fg(*YELLOW) if rem <= 40 else fg(*GREEN))
            if q_parts:
                q_parts.append((OVL0_FG, " · "))
            q_parts.append((SUB0_FG, f"{lbl} "))
            q_parts.append((q_col, f"{rem}%"))

cost_obj = d.get("cost") if isinstance(d.get("cost"), dict) else {}
usd = cost_obj.get("total_usd")
if usd is None:
    usd = cost_obj.get("total_cost_usd")
if usd is not None and float(usd) > 0:
    if q_parts:
        q_parts.append((OVL0_FG, " · "))
    q_parts.append((fg(*YELLOW), f"${float(usd):.2f}"))

if q_parts:
    q_acc = RED if q_worst_rem <= 15 else (YELLOW if q_worst_rem <= 40 else LAVENDER)
    pill_quota = make_pill("\U000f029a", q_acc, q_parts)

term_w = int(d.get("terminal_width") or 0)
candidates = [
    ("model", pill_model, True),
    ("dir", pill_dir, False),
    ("git", pill_git, False),
    ("ctx", pill_ctx, True),
    ("ops", pill_ops, False),
    ("quota", pill_quota, False),
]
active = [(k, p[0], p[1], req) for k, p, req in candidates if p is not None]


def total_width(items):
    return sum(w for _, _, w, _ in items) + max(0, len(items) - 1)


if term_w > 0 and total_width(active) > term_w - 2:
    for drop_key in ("quota", "ops", "dir", "git"):
        if total_width(active) <= term_w - 2:
            break
        active = [it for it in active if it[0] != drop_key]
    if total_width(active) > term_w - 2:
        active = [
            (k, pill_ctx_compact[0], pill_ctx_compact[1], req) if k == "ctx" else (k, s, w, req)
            for k, s, w, req in active
        ]

sys.stdout.write(" ".join(s for _, s, _, _ in active) + "\n")
'
