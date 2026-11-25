#!/usr/bin/env bash
exec python3 -c '
import json
import os
import sys
import time
import unicodedata
from datetime import datetime

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

ROSEWATER = (245, 224, 220)
FLAMINGO = (242, 205, 205)
PINK = (245, 194, 231)
MAUVE = (203, 166, 247)
RED = (243, 139, 168)
MAROON = (235, 160, 172)
PEACH = (250, 179, 135)
YELLOW = (249, 226, 175)
GREEN = (166, 227, 161)
TEAL = (148, 226, 213)
SKY = (137, 220, 235)
SAPPHIRE = (116, 199, 236)
BLUE = (137, 180, 250)
LAVENDER = (180, 190, 254)

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
        f"{ac_bg}{CRUST_FG}{icon} "
        f"{SURF0_BG}{TEXT_FG} {body_ansi} "
        f"{RST}{SURF0_FG}{ROUND_R}{RST}"
    )
    width = 1 + cell_width(icon) + 1 + 1 + cell_width(body_plain) + 1 + 1
    return rendered, width


def fmt_tokens(n):
    if not n or n <= 0:
        return "0"
    if n % 1_048_576 == 0:
        return f"{n // 1_048_576 * 1000}k"
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
    m_accent, m_icon = PINK, "\U000f0ae2"
elif state in ("tool_use", "reviewing"):
    m_accent, m_icon = PEACH, "\U000f0ae2"
else:
    m_accent, m_icon = MAUVE, "\U000f0ae2"

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

suffix = f" ({effort})"
if effort and m_name.lower().endswith(suffix.lower()):
    m_name = m_name[: -len(suffix)]

m_parts = [(f"{BOLD}{fg(*m_accent)}", m_name)]
if effort:
    ef_map = {
        "low": (SUB0_FG, "low"),
        "medium": (fg(*SKY), "med"),
        "high": (fg(*YELLOW), "high"),
        "xhigh": (fg(*PEACH), "xhigh"),
        "max": (fg(*RED), "max"),
    }
    ef_col, ef_lbl = ef_map.get(effort, (fg(*YELLOW), effort))
    m_parts.append((f"{NOBOLD}{ef_col}", f" \uf0e7 {ef_lbl}"))
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
    pill_dir = make_pill("\uf07b", BLUE, [(fg(*SKY), dir_label)])

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
bar_parts.append((f"{BOLD}{fg(*c_accent)}", f" {pct}%"))
bar_parts.append((NOBOLD, ""))

cur_u = cw.get("current_usage") if isinstance(cw.get("current_usage"), dict) else {}
cur_total = (
    int(cur_u.get("input_tokens") or 0)
    + int(cur_u.get("cache_read_input_tokens") or 0)
    + int(cur_u.get("cache_creation_input_tokens") or 0)
)
used_tok = cur_total or int(cw.get("total_input_tokens") or 0)
size_tok = cw.get("context_window_size") or 0
pill_ctx_compact = make_pill("\U000f035b", c_accent, list(bar_parts))
if size_tok > 0:
    bar_parts_full = list(bar_parts) + [(fg(*LAVENDER), f" {fmt_tokens(used_tok)}/{fmt_tokens(size_tok)}")]
    pill_ctx = make_pill("\U000f035b", c_accent, bar_parts_full)
else:
    pill_ctx = pill_ctx_compact


def resolve_transcript(payload):
    tp = payload.get("transcript_path") or ""
    if tp and os.path.isfile(tp):
        return tp
    # agy emits ~/.gemini/antigravity/brain/... even when data lives under antigravity-cli
    conv_id = payload.get("conversation_id") or payload.get("session_id") or ""
    if conv_id:
        alt = os.path.expanduser(
            f"~/.gemini/antigravity-cli/brain/{conv_id}/.system_generated/logs/transcript.jsonl"
        )
        if os.path.isfile(alt):
            return alt
    return ""


def model_rates(model_key, prompt_tokens):
    k = (model_key or "").lower()
    high_ctx = prompt_tokens > 200_000
    if "opus" in k:
        if "opus-4-0" in k or "opus-4-1" in k or "opus-4.0" in k or "opus-4.1" in k:
            return (15.0, 1.5, 75.0)
        return (5.0, 0.5, 25.0)
    if "sonnet" in k:
        return (6.0, 0.6, 22.5) if high_ctx else (3.0, 0.3, 15.0)
    if "haiku" in k:
        return (1.0, 0.1, 5.0)
    if "flash" in k or "hydrogen" in k or "argon" in k:
        return (0.75, 0.075, 3.75)
    return (4.0, 0.4, 18.0) if high_ctx else (2.0, 0.2, 12.0)


def parse_transcript(path, need_cost, fallback_model):
    start_ts = None
    est_usd = 0.0
    saw_tokens = False
    if not path:
        return start_ts, None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for idx, line in enumerate(f):
                if idx == 0:
                    try:
                        first = json.loads(line)
                        ca = first.get("created_at")
                        if ca:
                            start_ts = datetime.fromisoformat(ca.replace("Z", "+00:00")).timestamp()
                    except Exception:
                        pass
                    if not need_cost:
                        break
                if not need_cost:
                    break
                if "\"input_tokens\"" not in line and "\"output_tokens\"" not in line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                inp = int(obj.get("input_tokens") or 0)
                cr = int(obj.get("cache_read_tokens") or 0)
                out = int(obj.get("output_tokens") or 0)
                if not (inp or cr or out):
                    continue
                saw_tokens = True
                r_in, r_cr, r_out = model_rates(obj.get("model") or fallback_model, inp + cr)
                est_usd += (inp * r_in + cr * r_cr + out * r_out) / 1_000_000.0
    except Exception:
        return start_ts, None
    return start_ts, (est_usd if saw_tokens else None)


def fmt_duration(sec):
    total_min = int(max(0, sec) // 60)
    if total_min >= 1440:
        days, rem = divmod(total_min, 1440)
        hours = rem // 60
        return f"{days}d {hours}h" if hours else f"{days}d"
    hours, mins = divmod(total_min, 60)
    return f"{hours}h {mins}m" if hours else f"{mins}m"


cost_obj = d.get("cost") if isinstance(d.get("cost"), dict) else {}
reported_usd = cost_obj.get("total_usd")
if reported_usd is None:
    reported_usd = cost_obj.get("total_cost_usd")
has_reported_cost = reported_usd is not None and float(reported_usd) >= 0

t_path = resolve_transcript(d)
start_ts, est_usd = parse_transcript(t_path, need_cost=not has_reported_cost, fallback_model=m_name)

pill_cost = None
if has_reported_cost:
    prefix = "~" if cost_obj.get("estimated") else ""
    pill_cost = make_pill("\U000f01c1", YELLOW, [(f"{BOLD}{fg(*YELLOW)}", f"{prefix}${float(reported_usd):.2f}"), (NOBOLD, "")])
elif est_usd is not None:
    pill_cost = make_pill("\U000f01c1", YELLOW, [(f"{BOLD}{fg(*YELLOW)}", f"~${est_usd:.2f}"), (NOBOLD, "")])
else:
    tot_in = int(cw.get("total_input_tokens") or 0)
    tot_out = int(cw.get("total_output_tokens") or 0)
    if tot_in or tot_out:
        r_in, _, r_out = model_rates(m_name, tot_in)
        fallback_usd = (tot_in * r_in + tot_out * r_out) / 1_000_000.0
        pill_cost = make_pill("\U000f01c1", YELLOW, [(f"{BOLD}{fg(*YELLOW)}", f"~${fallback_usd:.2f}"), (NOBOLD, "")])

pill_time = None
dur_ms = cost_obj.get("total_duration_ms")
if dur_ms is not None:
    pill_time = make_pill("\U000f051b", FLAMINGO, [(fg(*ROSEWATER), fmt_duration(float(dur_ms) / 1000.0))])
elif start_ts is not None:
    pill_time = make_pill("\U000f051b", FLAMINGO, [(fg(*ROSEWATER), fmt_duration(time.time() - start_ts))])

pill_ops = None
subs = d.get("subagents") if isinstance(d.get("subagents"), list) else []
running_subs = sum(1 for s in subs if isinstance(s, dict) and s.get("status") == "running")
tasks = int(d.get("task_count") or 0)
queued = int(d.get("pending_input_count") or 0)
ops_tokens = []
if running_subs:
    ops_tokens.append((fg(*PINK), f"{running_subs} sub"))
if tasks:
    if ops_tokens:
        ops_tokens.append((OVL0_FG, " · "))
    ops_tokens.append((fg(*SKY), f"{tasks} task"))
if queued:
    if ops_tokens:
        ops_tokens.append((OVL0_FG, " · "))
    ops_tokens.append((fg(*PEACH), f"{queued} queued"))
if ops_tokens:
    ops_icon = "\U000f1296" if (queued and not running_subs and not tasks) else "\U000f0328"
    pill_ops = make_pill(ops_icon, LAVENDER, ops_tokens)

pill_quota = None
q_parts = []
q_worst_rem = 100
quota = d.get("quota") if isinstance(d.get("quota"), dict) else {}
active_model_slug = (m_name.lower().replace(" ", "-") + (f"-{effort.lower()}" if effort else "")).strip("-")
for key, val in quota.items():
    if not isinstance(val, dict) or val.get("disabled"):
        continue
    rem_f = val.get("remaining_fraction")
    rem_amt = val.get("remaining_amount")
    reset_s = int(val.get("reset_in_seconds") or 0)
    reset_t = str(val.get("reset_time") or "")
    # Enterprise GCP returns 30+ static per-model entries with fraction=1 and epoch-0 reset_time
    if rem_amt is None and rem_f is not None and float(rem_f) >= 1.0 and reset_s <= 0 and (not reset_t or reset_t.startswith("1970-")):
        continue
    k_low = key.lower()
    if "month" in k_low or "30d" in k_low or "1m" in k_low:
        lbl = "1M"
    elif "week" in k_low or "7d" in k_low:
        lbl = "7d"
    elif "five" in k_low or "5h" in k_low:
        lbl = "5h"
    elif "day" in k_low or "daily" in k_low or "24h" in k_low:
        lbl = "1d"
    elif active_model_slug and k_low == active_model_slug:
        lbl = "cur"
    elif rem_amt is not None:
        lbl = key[:6]
    else:
        continue
    if rem_f is not None:
        rem = round(float(rem_f) * 100)
        q_worst_rem = min(q_worst_rem, rem)
        q_col = fg(*RED) if rem <= 15 else (fg(*YELLOW) if rem <= 40 else fg(*GREEN))
        val_txt = f"{rem}%"
    elif rem_amt is not None:
        q_col = fg(*GREEN)
        val_txt = fmt_tokens(int(rem_amt))
    else:
        continue
    if q_parts:
        q_parts.append((OVL0_FG, " · "))
    q_parts.append((SUB0_FG, f"{lbl} "))
    q_parts.append((q_col, val_txt))

rl = d.get("rate_limits") if isinstance(d.get("rate_limits"), dict) else {}
if not q_parts and rl:
    for lbl, rkey in (("5h", "five_hour"), ("7d", "seven_day"), ("1M", "monthly")):
        obj = rl.get(rkey)
        if isinstance(obj, dict) and obj.get("used_percentage") is not None:
            rem = max(0, 100 - round(float(obj["used_percentage"])))
            q_worst_rem = min(q_worst_rem, rem)
            q_col = fg(*RED) if rem <= 15 else (fg(*YELLOW) if rem <= 40 else fg(*GREEN))
            if q_parts:
                q_parts.append((OVL0_FG, " · "))
            q_parts.append((SUB0_FG, f"{lbl} "))
            q_parts.append((q_col, f"{rem}%"))

if q_parts:
    q_acc = RED if q_worst_rem <= 15 else (YELLOW if q_worst_rem <= 40 else MAROON)
    pill_quota = make_pill("\U000f029a", q_acc, q_parts)

term_w = int(d.get("terminal_width") or 0)
candidates = [
    ("model", pill_model, True),
    ("dir", pill_dir, False),
    ("ctx", pill_ctx, True),
    ("cost", pill_cost, False),
    ("time", pill_time, False),
    ("ops", pill_ops, False),
    ("quota", pill_quota, False),
]
active = [(k, p[0], p[1], req) for k, p, req in candidates if p is not None]


def total_width(items):
    return sum(w for _, _, w, _ in items) + max(0, len(items) - 1)


def wrap_rows(items, max_w):
    rows = []
    cur = []
    cur_w = 0
    for it in items:
        w = it[2]
        need = w if not cur else cur_w + 1 + w
        if cur and need > max_w:
            rows.append(cur)
            cur = [it]
            cur_w = w
        else:
            cur.append(it)
            cur_w = need
    if cur:
        rows.append(cur)
    return rows


if term_w > 0:
    limit = max(20, term_w - 2)
    if total_width(active) <= limit:
        rows = [active]
    else:
        rows = wrap_rows(active, limit)
        if len(rows) > 2:
            for drop_key in ("ops", "dir"):
                if len(rows) <= 2:
                    break
                active = [it for it in active if it[0] != drop_key]
                rows = wrap_rows(active, limit)
        if len(rows) > 2:
            active = [
                (k, pill_ctx_compact[0], pill_ctx_compact[1], req) if k == "ctx" else (k, s, w, req)
                for k, s, w, req in active
            ]
            rows = wrap_rows(active, limit)
    sys.stdout.write("\n".join(" ".join(s for _, s, _, _ in r) for r in rows[:2]) + "\n")
else:
    sys.stdout.write(" ".join(s for _, s, _, _ in active) + "\n")
'
