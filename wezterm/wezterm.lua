local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()
local workspace_switcher = wezterm.plugin.require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_darwin = wezterm.target_triple:find("darwin") ~= nil

-- Homebrew prefix differs per OS. On Windows (WSL stub case) WezTerm runs
-- natively on Windows and cannot exec WSL-side binaries directly, so leave
-- brew_bin empty and skip brew-path-dependent features below.
local brew_bin = is_darwin and "/opt/homebrew/bin/" or (not is_windows and "/home/linuxbrew/.linuxbrew/bin/" or "")
-- Homebrew path for commands running inside WSL panes (pane:split args)
local wsl_brew_bin = is_windows and "/home/linuxbrew/.linuxbrew/bin/" or brew_bin
local clip_cmd = is_windows and "win32yank.exe -i --crlf" or "pbcopy"

-- On Windows, the entry config (%USERPROFILE%\.wezterm.lua) is a stub that
-- dofile()s this file over the \\wsl.localhost UNC path. The 9P protocol
-- powering \\wsl.localhost does not propagate inotify events, so edits to
-- this file never trigger WezTerm's auto-reload on Windows. The workaround
-- lives in wezterm/wezterm-watch.sh, which runs inside WSL and touches the
-- Windows-side stub whenever this file changes.
if brew_bin ~= "" then
	workspace_switcher.zoxide_path = brew_bin .. "zoxide"
end

---------------------------------------------------------------------------
-- AI Tools (여기에 추가하면 C-a+A 메뉴에 자동 반영)
---------------------------------------------------------------------------
local ai_tools = {
	{ key = "c", label = "Claude Code", cmd = { "claude" } },
	{ key = "r", label = "Claude Code (resume)", cmd = { "claude", "-r" } },
	-- { key = 'x', label = 'Codex',              cmd = { 'codex' } },
	-- { key = 'g', label = 'Gemini CLI',          cmd = { 'gemini' } },
}

-- 자주 쓰는 프로젝트 경로 (C-a+A 메뉴에서 프로젝트 선택 후 AI 도구 실행)
local projects = {
	-- { label = 'my-project', path = '/Users/cyan/dev/my-project' },
}

local function spawn_ai_tool(args)
	return wezterm.action_callback(function(win, pane)
		local cwd = pane:get_current_working_dir()
		pane:split({
			direction = "Right",
			size = 0.5,
			args = args,
			cwd = cwd and cwd.file_path or nil,
		})
	end)
end

---------------------------------------------------------------------------
-- Appearance
---------------------------------------------------------------------------
-- config.color_scheme = 'Catppuccin Mocha'

-- 현재 테마에서 색상 자동 추출
local scheme = config.color_scheme and wezterm.color.get_builtin_schemes()[config.color_scheme]
	or wezterm.color.get_default_colors()
local ansi = scheme.ansi or {}
local brights = scheme.brights or {}

local bg = scheme.background or "#000000"
local bg_color = wezterm.color.parse(bg)

local C = {
	red = brights[2] or ansi[2] or "#cc6666",
	green = brights[3] or ansi[3] or "#b5bd68",
	yellow = brights[4] or ansi[4] or "#f0c674",
	blue = brights[5] or ansi[5] or "#81a2be",
	mauve = brights[6] or ansi[6] or "#b294bb",
	sky = brights[7] or ansi[7] or "#8abeb7",
	maroon = ansi[2] or "#cc6666",
	lavender = brights[5] or "#81a2be",
	text = scheme.foreground or "#c5c8c6",
	overlay1 = ansi[8] or "#707880",
	surface1 = bg_color:lighten(0.15),
	surface0 = bg_color:lighten(0.10),
	base = bg,
	mantle = bg_color:darken(0.03),
	crust = bg_color:darken(0.06),
}
-- Use the non-Mono Nerd Font variant: the 'Mono' variant squeezes icon
-- glyphs into a single cell, which on Windows DPI renders them tiny.
-- Non-Mono lets icons occupy 2 cells and show at a normal size, while
-- regular text glyphs stay single-width as usual.
config.font = wezterm.font("0xProto Nerd Font")

-- OS + DPI based font size (single source of truth).
-- Low-DPI (≤96) usually means an external non-Retina monitor → bump up by 2.
local function desired_font_size(dpi)
	local base = is_windows and 11.0 or 14.0
	return dpi <= 96 and (base + 2.0) or base
end

config.font_size = desired_font_size(96) -- initial value; replaced by handler below once a window exists

wezterm.on("update-status", function(window)
	local overrides = window:get_config_overrides() or {}
	local want = desired_font_size(window:get_dimensions().dpi)
	if overrides.font_size ~= want then
		overrides.font_size = want
		window:set_config_overrides(overrides)
	end
end)

config.custom_block_glyphs = true
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
config.window_background_opacity = 0.85
config.macos_window_background_blur = 10

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.show_new_tab_button_in_tab_bar = false

-- Active pane highlighting
config.inactive_pane_hsb = {
	saturation = 0.5,
	brightness = 0.42,
}

config.scrollback_lines = 200000
config.automatically_reload_config = true
config.status_update_interval = 200

local tab_bar_bg
if config.tab_bar_at_bottom then
	tab_bar_bg = "rgba(0, 0, 0, 0)"
else
	-- NOTE: must match the *final* window_background_opacity for the current OS.
	-- The Windows override (0.7) is applied later in the file (in the OS-specific
	-- block), so reading config.window_background_opacity here would still see the
	-- mac default (0.85) and the tab bar would render darker than the terminal pane.
	local effective_opacity = is_windows and 0.7 or 0.85
	local r, g, b = wezterm.color.parse(C.base):srgba_u8()
	tab_bar_bg = string.format("rgba(%d, %d, %d, %s)", r, g, b, effective_opacity)
end
config.colors = {
	tab_bar = {
		background = tab_bar_bg,
	},
}

---------------------------------------------------------------------------
-- Leader key (C-a, tmux 호환)
---------------------------------------------------------------------------
config.leader = { key = "phys:a", mods = "CTRL", timeout_milliseconds = 1000 }

---------------------------------------------------------------------------
-- Key bindings
---------------------------------------------------------------------------
config.keys = {
	-- C-a 두번 입력 시 화면 전체 선택 (Copy Mode → 스크롤백 맨 위 → 맨 아래까지 선택)
	{
		key = "phys:a",
		mods = "LEADER|CTRL",
		action = act.Multiple({
			act.ActivateCopyMode,
			act.CopyMode("MoveToScrollbackTop"),
			act.CopyMode({ SetSelectionMode = "Line" }),
			act.CopyMode("MoveToScrollbackBottom"),
		}),
	},

	-- Disable default C-S-Arrow (pane activate)
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "UpArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "DownArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "LeftArrow", mods = "CTRL|SHIFT|ALT", action = act.DisableDefaultAssignment },
	{ key = "RightArrow", mods = "CTRL|SHIFT|ALT", action = act.DisableDefaultAssignment },
	{ key = "UpArrow", mods = "CTRL|SHIFT|ALT", action = act.DisableDefaultAssignment },
	{ key = "DownArrow", mods = "CTRL|SHIFT|ALT", action = act.DisableDefaultAssignment },
	{ key = "L", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },

	-- Debug overlay
	{ key = "phys:d", mods = "LEADER", action = act.ShowDebugOverlay },

	-- Split panes
	{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Pane resize (C-a+Arrow → resize 모드 진입, 1초 무입력 시 자동 종료)
	{
		key = "UpArrow",
		mods = "LEADER",
		action = act.Multiple({
			act.AdjustPaneSize({ "Up", 5 }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 1000 }),
		}),
	},
	{
		key = "DownArrow",
		mods = "LEADER",
		action = act.Multiple({
			act.AdjustPaneSize({ "Down", 5 }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 1000 }),
		}),
	},
	{
		key = "LeftArrow",
		mods = "LEADER",
		action = act.Multiple({
			act.AdjustPaneSize({ "Left", 5 }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 1000 }),
		}),
	},
	{
		key = "RightArrow",
		mods = "LEADER",
		action = act.Multiple({
			act.AdjustPaneSize({ "Right", 5 }),
			act.ActivateKeyTable({ name = "resize_pane", one_shot = false, timeout_milliseconds = 1000 }),
		}),
	},

	-- Maximize pane (zoom)
	{ key = "phys:m", mods = "LEADER", action = act.TogglePaneZoomState },

	-- Tab
	{ key = "phys:t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "phys:l", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "phys:h", mods = "LEADER", action = act.ActivateTabRelative(-1) },

	-- Copy mode
	{
		key = "phys:v",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			win:perform_action(act.ActivateCopyMode, pane)
			win:perform_action(act.CopyMode("ClearPattern"), pane)
		end),
	},

	-- QuickSelect: URL → 브라우저, 그 외 → 클립보드 복사
	{
		key = "phys:q",
		mods = "LEADER",
		action = act.QuickSelectArgs({
			label = "quick select",
			patterns = {
				"https?://\\S+", -- URL
				"[\\w.-]+/[\\w.-]+(?:#\\d+)?", -- owner/repo or owner/repo#123
				"/[\\w.-/]+\\.\\w+", -- file path
				"[0-9a-f]{7,40}", -- git hash
				"\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}(?::\\d+)?", -- IP(:port)
			},
			action = wezterm.action_callback(function(window, pane)
				local text = window:get_selection_text_for_pane(pane)
				if text:match("^https?://") then
					wezterm.open_with(text)
				else
					window:copy_to_clipboard(text)
				end
			end),
		}),
	},

	-- 검색 모드 (fzf로 스크롤백 검색, 한글 지원)
	{
		key = "/",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			local pane_id = pane:pane_id()
			if is_windows then
				-- On Windows, Lua io runs on the Windows filesystem and mangles encoding.
				-- Instead, the new pane fetches scrollback directly via wezterm.exe cli.
				pane:split({
					direction = "Bottom",
					size = 0.4,
					args = {
						"/bin/zsh",
						"-c",
						"result=$(wezterm.exe cli get-text --pane-id "
							.. tostring(pane_id)
							.. " | "
							.. wsl_brew_bin
							.. 'fzf -m --tac --no-sort --exact --height=100% --layout=default --prompt="Search> "'
							.. '); [ -n "$result" ] && printf "%s" "$result" | '
							.. clip_cmd,
					},
				})
			else
				local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
				local tmp = "/tmp/wezterm_search_" .. tostring(os.time())
				local f = io.open(tmp, "w")
				if not f then return end
				f:write(text)
				f:close()
				pane:split({
					direction = "Bottom",
					size = 0.4,
					args = {
						"/bin/zsh",
						"-c",
						"result=$("
							.. brew_bin
							.. 'fzf -m --tac --no-sort --exact --layout=default --prompt="Search> " < "'
							.. tmp
							.. '"); rm -f "'
							.. tmp
							.. '"; '
							.. '[ -n "$result" ] && printf "%s" "$result" | '
							.. clip_cmd,
					},
				})
			end
		end),
	},

	-- 패인 위치 스왑
	{ key = "=", mods = "LEADER", action = act.PaneSelect({ mode = "SwapWithActive" }) },

	-- 커맨드 팔레트
	{ key = ":", mods = "LEADER", action = act.ActivateCommandPalette },

	-- Close pane/tab (선택 후 즉시 종료, 추가 확인창 없음)
	{
		key = "phys:x",
		mods = "LEADER",
		action = act.InputSelector({
			title = "Close",
			choices = {
				{ label = "Current pane", id = "pane" },
				{ label = "Current tab (all panes)", id = "tab" },
			},
			action = wezterm.action_callback(function(win, pane, id, label)
				if id == "pane" then
					win:perform_action(act.CloseCurrentPane({ confirm = false }), pane)
				elseif id == "tab" then
					win:perform_action(act.CloseCurrentTab({ confirm = false }), pane)
				end
			end),
		}),
	},

	-- Reload config
	{ key = "phys:r", mods = "LEADER", action = act.ReloadConfiguration },

	-- Workspace (zoxide 연동 fuzzy 검색)
	{ key = "phys:p", mods = "LEADER", action = workspace_switcher.switch_workspace() },
	{ key = "]", mods = "LEADER", action = act.SwitchWorkspaceRelative(1) },
	{ key = "[", mods = "LEADER", action = act.SwitchWorkspaceRelative(-1) },

	-- New workspace
	{
		key = "phys:n",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "New workspace name:",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
				end
			end),
		}),
	},

	-- Keybinding cheat sheet (C-a+?)
	{
		key = "?",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			pane:split({
				direction = "Bottom",
				size = 0.95,
				args = {
					"bash",
					"-c",
					table.concat({
						"clear",
						'echo ""',
						'echo "  Keybindings"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  C-a ?       이 도움말"',
						'echo "  C-a \\\\       수평 분할"',
						'echo "  C-a -       수직 분할"',
						'echo "  C-a ↑↓←→    패인 크기 조절"',
						'echo "  C-a m       패인 줌 토글"',
						'echo "  C-a x       패인 닫기"',
						'echo "  C-a t       새 탭"',
						'echo "  C-a h/l     이전/다음 탭"',
						'echo "  C-a ,       탭 이름 변경"',
						'echo "  C-a v       복사 모드"',
						'echo "  C-a /       검색 모드"',
						'echo "  C-a q       QuickSelect (URL/경로/hash/IP)"',
						'echo "  C-a =       패인 위치 스왑"',
						'echo "  C-a :       커맨드 팔레트"',
						'echo "  C-a r       설정 리로드"',
						'echo "  C-a p       워크스페이스 (zoxide fuzzy)"',
						'echo "  C-a [/]     이전/다음 워크스페이스"',
						'echo "  C-a n       새 워크스페이스"',
						'echo "  C-a \\$       세션명 변경"',
						'echo ""',
						'echo "  Session (C-a s 후)"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  s           세션 저장"',
						'echo "  l           세션 복원 (fuzzy)"',
						'echo "  d           세션 삭제"',
						'echo "  C-]         패인 이동 모드 (HJKL, 1초)"',
						'echo ""',
						'echo "  AI (C-a a 후)"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  a           Claude Code"',
						'echo "  r           Claude Code resume"',
						'echo "  p           프로젝트 선택 → Claude"',
						'echo "  l           AI 도구 목록"',
						'echo ""',
						'echo "  Navigation"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  C-h/j/k/l   패인 이동 (nvim 연동)"',
						'echo ""',
						'read -n1 -s -p "  아무 키나 누르면 닫힙니다..."',
					}, "; "),
				},
			})
		end),
	},

	-- Rename session (C-a+$)
	{
		key = "$",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Session name:",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					wezterm.mux.rename_workspace(window:active_workspace(), line)
				end
			end),
		}),
	},

	-- Rename tab (C-a+,)
	{
		key = ",",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Tab name:",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},

	-- Session management (C-a+s → session 모드)
	{ key = "phys:s", mods = "LEADER", action = act.ActivateKeyTable({ name = "session", one_shot = true }) },

	-- AI tools (C-a+a → AI 모드)
	{ key = "phys:a", mods = "LEADER", action = act.ActivateKeyTable({ name = "ai", one_shot = true }) },

	-- Pane 이동 모드 (C-] → 1초간 HJKL로 pane 전환)
	{
		key = "]",
		mods = "CTRL",
		action = act.ActivateKeyTable({ name = "move_pane", one_shot = false, timeout_milliseconds = 1000 }),
	},
}

---------------------------------------------------------------------------
-- Pane navigation (nvim-aware, vim-tmux-navigator 대체)
---------------------------------------------------------------------------
-- nvim 측(polish.lua) 이 OSC 1337 로 broadcast 하는 user_var:
--   IS_NVIM         : 이 pane 에 nvim 떠있음
--   NVIM_AT_<DIR>   : 현재 nvim 창이 해당 방향 edge 에 위치 (DIR ∈ LEFT/RIGHT/UP/DOWN)
-- 두 플래그 조합으로:
--   nvim + non-edge  -> SendKey (nvim 내부 창 이동)
--   nvim + edge      -> ActivatePaneDirection (wezterm 직접 전환, CLI 호출 없음)
--   non-nvim         -> ActivatePaneDirection
local edge_flag = { h = "NVIM_AT_LEFT", j = "NVIM_AT_DOWN", k = "NVIM_AT_UP", l = "NVIM_AT_RIGHT" }
local function should_send_to_nvim(pane, nav_key)
	local vars = pane:get_user_vars() or {}
	if vars.IS_NVIM ~= "1" then
		return false
	end
	return vars[edge_flag[nav_key]] ~= "1"
end

local nav_keys = {
	{ key = "h", dir = "Left" },
	{ key = "j", dir = "Down" },
	{ key = "k", dir = "Up" },
	{ key = "l", dir = "Right" },
}
for _, nav in ipairs(nav_keys) do
	table.insert(config.keys, {
		key = "phys:" .. nav.key,
		mods = "CTRL",
		action = wezterm.action_callback(function(win, pane)
			local tab = pane:tab()
			if should_send_to_nvim(pane, nav.key) or (tab and #tab:panes() == 1) then
				win:perform_action(act.SendKey({ key = nav.key, mods = "CTRL" }), pane)
			else
				win:perform_action(act.ActivatePaneDirection(nav.dir), pane)
			end
		end),
	})
end

---------------------------------------------------------------------------
-- Status bar (catppuccin 스타일)
---------------------------------------------------------------------------
local git_cache = {} -- { [cwd] = { info = ..., time = ... } }

-- .git 디렉토리 찾기 (cwd에서 위로 탐색)
local function find_git_dir(cwd)
	local dir = cwd
	while dir and dir ~= "" and dir ~= "/" do
		local f = io.open(dir .. "/.git/HEAD", "r")
		if f then
			f:close()
			return dir .. "/.git"
		end
		dir = dir:match("(.+)/[^/]*$")
	end
	return nil
end

-- .git/HEAD에서 브랜치명 직접 읽기 (서브프로세스 없음, 즉시 반환)
local function read_branch(git_dir)
	if not git_dir then
		return nil
	end
	local f = io.open(git_dir .. "/HEAD", "r")
	if not f then
		return nil
	end
	local head = f:read("*l")
	f:close()
	if not head then
		return nil
	end
	return head:match("ref: refs/heads/(.+)") or head:sub(1, 7)
end

local function get_git_info(cwd)
	if not cwd or cwd == "" then
		return nil
	end

	-- 브랜치는 항상 파일에서 즉시 읽기
	local git_dir = find_git_dir(cwd)
	local branch = read_branch(git_dir)
	if not branch then
		return nil
	end

	-- 상세 정보(modified/staged 등)는 gitmux + per-cwd 10초 캐시
	local now = os.time()
	local entry = git_cache[cwd]
	local cached = entry and entry.info
	if not cached or (now - (entry and entry.time or 0)) >= 10 then
		local ok, handle =
			pcall(io.popen, brew_bin .. "gitmux -dbg -timeout 500ms '" .. cwd:gsub("'", "'\\''") .. "' 2>/dev/null")
		if ok and handle then
			local raw = handle:read("*a")
			handle:close()
			local function num(key)
				return tonumber(raw:match('"' .. key .. '":%s*(%d+)')) or 0
			end
			local function bool(key)
				return raw:match('"' .. key .. '":%s*true') ~= nil
			end
			local function str(key)
				return raw:match('"' .. key .. '":%s*"([^"]*)"')
			end
			cached = {
				modified = num("NumModified"),
				staged = num("NumStaged"),
				untracked = num("NumUntracked"),
				ahead = num("AheadCount"),
				behind = num("BehindCount"),
				clean = bool("IsClean"),
				remote = str("RemoteBranch"),
			}
			git_cache[cwd] = { info = cached, time = now }
		end
	end

	return {
		branch = branch,
		modified = cached and cached.modified or 0,
		staged = cached and cached.staged or 0,
		untracked = cached and cached.untracked or 0,
		ahead = cached and cached.ahead or 0,
		behind = cached and cached.behind or 0,
		clean = cached and cached.clean or true,
		remote = cached and cached.remote or "",
	}
end

-- tmux catppuccin 스타일 (build_status_module: fill=icon, connect=no)
-- ROUND_L fg=color bg=default, icon fg=thm_gray bg=color, text fg=thm_fg bg=thm_gray, ROUND_R fg=thm_gray bg=default
local ROUND_L = utf8.char(0xe0b6)
local ROUND_R = utf8.char(0xe0b4)
local TAB_BG = tab_bar_bg

local function append(tbl, items)
	for _, v in ipairs(items) do
		table.insert(tbl, v)
	end
end

local function make_module(icon, text, icon_color)
	icon_color = icon_color or C.surface0
	return {
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = icon_color } },
		{ Text = ROUND_L },
		{ Background = { Color = icon_color } },
		{ Foreground = { Color = C.crust } },
		{ Text = icon },
		{ Foreground = { Color = icon_color } },
		{ Text = "█" },
		{ Background = { Color = C.surface0 } },
		{ Foreground = { Color = C.text } },
		{ Text = " " .. text },
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = C.surface0 } },
		{ Text = ROUND_R .. " " },
	}
end

wezterm.on("update-status", function(window, pane)
	local ok, cwd_uri = pcall(pane.get_current_working_dir, pane)
	if not ok then
		return
	end
	local cwd = cwd_uri and cwd_uri.file_path or ""

	-- Left: session (터미널 아이콘은 초록/빨강 배경, 세션명은 기존 스타일)
	local workspace = window:active_workspace()
	local leader_active = window:leader_is_active()
	local move_pane_active = window:active_key_table() == "move_pane"
	local session_color = leader_active and C.red or move_pane_active and C.sky or C.green
	window:set_left_status(wezterm.format({
		-- 반원
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = session_color } },
		{ Text = "  " .. ROUND_L },
		-- 터미널 아이콘
		{ Background = { Color = session_color } },
		{ Foreground = { Color = C.crust } },
		{ Text = utf8.char(0xe795) },
		{ Foreground = { Color = session_color } },
		{ Text = "█" },
		-- 세션명 (기존 surface0 배경)
		{ Background = { Color = C.surface0 } },
		{ Foreground = { Color = C.text } },
		{ Text = " " .. workspace },
		-- 오른쪽 반원
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = C.surface0 } },
		{ Text = ROUND_R .. " " },
	}))

	-- Right: directory | git | datetime
	local dir_name = cwd:match("([^/\\]+)$") or cwd
	local datetime = wezterm.strftime("%y-%m-%d %H:%M")
	-- Windows: wezterm runs natively and cannot exec WSL-side gitmux, and
	-- io.open on WSL paths from the Windows side is unreliable. Skip entirely.
	local git = not is_windows and get_git_info(cwd) or nil

	local right = {}

	-- directory
	append(right, make_module(utf8.char(0xe5ff), dir_name, C.maroon))

	-- git
	if git then
		local git_icon_color = C.green
		-- 반원 + 아이콘
		append(right, {
			{ Background = { Color = TAB_BG } },
			{ Foreground = { Color = git_icon_color } },
			{ Text = ROUND_L },
			{ Background = { Color = git_icon_color } },
			{ Foreground = { Color = C.crust } },
			{ Text = utf8.char(0xf418) },
			{ Foreground = { Color = git_icon_color } },
			{ Text = "█" },
			-- 텍스트 영역
			{ Background = { Color = C.surface0 } },
			{ Foreground = { Color = C.text } },
			{ Text = " " .. git.branch },
		})
		if git.remote ~= "" then
			append(right, {
				{ Foreground = { Color = C.sky } },
				{ Text = " " .. git.remote },
			})
		end
		if git.ahead > 0 then
			append(right, {
				{ Foreground = { Color = C.yellow } },
				{ Text = " ↑·" .. git.ahead },
			})
		end
		if git.behind > 0 then
			append(right, {
				{ Foreground = { Color = C.yellow } },
				{ Text = " ↓·" .. git.behind },
			})
		end
		if git.staged > 0 then
			append(right, {
				{ Foreground = { Color = C.green } },
				{ Text = " ● " .. git.staged },
			})
		end
		if git.modified > 0 then
			append(right, {
				{ Foreground = { Color = C.red } },
				{ Text = " ✚ " .. git.modified },
			})
		end
		if git.untracked > 0 then
			append(right, {
				{ Foreground = { Color = C.yellow } },
				{ Text = " … " .. git.untracked },
			})
		end
		if git.clean then
			append(right, {
				{ Foreground = { Color = C.green } },
				{ Text = " ✔" },
			})
		end
		-- 닫기
		append(right, {
			{ Background = { Color = TAB_BG } },
			{ Foreground = { Color = C.surface0 } },
			{ Text = ROUND_R .. " " },
		})
	end

	-- datetime
	append(right, make_module("󰃰", datetime, C.lavender))
	table.insert(right, { Background = { Color = TAB_BG } })
	table.insert(right, { Text = " " })

	window:set_right_status(wezterm.format(right))
end)

---------------------------------------------------------------------------
-- Tab title (catppuccin pill 스타일, zoom 표시)
---------------------------------------------------------------------------
wezterm.on("format-tab-title", function(tab)
	local raw_title = tab.active_pane.title or ""
	local tab_title = tab.tab_title
	local proc = tab.active_pane.foreground_process_name or ""
	local pname
	if tab_title and #tab_title > 0 then
		pname = tab_title
	else
		pname = proc:match("([^/\\]+)$") or raw_title
	end
	-- raw_title의 첫 문자(아이콘)를 추출
	local icon = raw_title:match("^([%z\1-\127\194-\244][\128-\191]*)") or ""
	local title = icon ~= "" and (icon .. " " .. pname) or pname
	if #title > 24 then
		title = title:sub(1, 22) .. ".."
	end
	local index = tab.tab_index + 1
	local zoomed = tab.active_pane.is_zoomed and (" " .. utf8.char(0xeb81)) or ""

	local tab_bg, tab_fg
	if tab.is_active then
		tab_bg, tab_fg = C.surface1, C.text
	else
		tab_bg, tab_fg = C.surface0, C.overlay1
	end

	local accent = tab.is_active and C.mauve or C.surface1
	local num_bg = tab.is_active and C.surface0 or C.surface0
	local num_fg = tab.is_active and C.text or C.overlay1

	return {
		-- 왼쪽 반원 + 프로세스명 (같은 색)
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = accent } },
		{ Text = ROUND_L },
		{ Background = { Color = accent } },
		{ Foreground = { Color = C.crust } },
		{ Text = title .. zoomed },
		{ Foreground = { Color = accent } },
		{ Text = "█" },
		-- 인덱스
		{ Background = { Color = num_bg } },
		{ Foreground = { Color = num_bg } },
		{ Text = "█" },
		{ Foreground = { Color = num_fg } },
		{ Text = tostring(index) },
		-- 오른쪽 반원
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = num_bg } },
		{ Text = ROUND_R },
	}
end)

---------------------------------------------------------------------------
-- Key tables
---------------------------------------------------------------------------
config.key_tables = {
	-- Copy mode: 기본 + vi 스타일 검색(/, ?, n, N)
	copy_mode = (function()
		local t = wezterm.gui.default_key_tables().copy_mode
		local extra = {
			{ key = "/", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") },
			{ key = "?", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") },
			{ key = "n", mods = "NONE", action = act.CopyMode("NextMatch") },
			{ key = "phys:n", mods = "SHIFT", action = act.CopyMode("PriorMatch") },
			{
				key = "q",
				mods = "NONE",
				action = act.Multiple({
					act.CopyMode("ClearPattern"),
					act.CopyMode("Close"),
				}),
			},
			{
				key = "Escape",
				mods = "NONE",
				action = act.Multiple({
					act.CopyMode("ClearPattern"),
					act.CopyMode("Close"),
				}),
			},
		}
		for _, k in ipairs(extra) do
			table.insert(t, k)
		end
		return t
	end)(),

	-- Search mode: Enter로 검색 확정 후 copy mode 복귀, Escape로 취소
	search_mode = (function()
		local t = wezterm.gui.default_key_tables().search_mode
		local extra = {
			{ key = "Enter", mods = "NONE", action = act.CopyMode("AcceptPattern") },
			{
				key = "Escape",
				mods = "NONE",
				action = act.Multiple({
					act.CopyMode("ClearPattern"),
					act.CopyMode("Close"),
				}),
			},
		}
		for _, k in ipairs(extra) do
			table.insert(t, k)
		end
		return t
	end)(),

	-- Pane resize 모드 (C-a+Arrow로 진입, 방향키 반복, Escape로 종료)
	resize_pane = {
		{ key = "UpArrow", action = act.AdjustPaneSize({ "Up", 5 }) },
		{ key = "DownArrow", action = act.AdjustPaneSize({ "Down", 5 }) },
		{ key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 5 }) },
		{ key = "RightArrow", action = act.AdjustPaneSize({ "Right", 5 }) },
		{ key = "Escape", action = "PopKeyTable" },
	},

	-- Pane 이동 모드 (C-] 로 진입, HJKL로 pane 전환, 1초 무입력 시 자동 종료)
	move_pane = {
		{ key = "phys:h", action = act.ActivatePaneDirection("Left") },
		{ key = "phys:j", action = act.ActivatePaneDirection("Down") },
		{ key = "phys:k", action = act.ActivatePaneDirection("Up") },
		{ key = "phys:l", action = act.ActivatePaneDirection("Right") },
		{ key = "Escape", action = "PopKeyTable" },
	},

	-- config.key_tables 안에 추가
	session = {
		{
			key = "s",
			action = wezterm.action_callback(function()
				resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
				wezterm.log_info("Workspace state saved")
			end),
		},
		{
			key = "l",
			action = wezterm.action_callback(function(win, pane)
				-- 여기에 resurrect load 관련 로직 (이전 코드에 있던 내용) 추가
			end),
		},
		{ key = "Escape", action = "PopKeyTable" },
	},

	-- C-a, a → AI 모드
	--   a: Claude Code (현재 cwd)
	--   r: Claude Code resume
	--   p: 프로젝트 선택 → Claude Code
	--   l: AI 도구 선택
	ai = {
		{ key = "phys:a", action = spawn_ai_tool(ai_tools[1].cmd) },
		{ key = "phys:r", action = spawn_ai_tool(ai_tools[2].cmd) },
		{
			key = "phys:p",
			action = wezterm.action_callback(function(win, pane)
				if #projects == 0 then
					win:perform_action(
						act.PromptInputLine({
							description = "Project path:",
							action = wezterm.action_callback(function(_, inner_pane, line)
								if line and line ~= "" then
									inner_pane:split({
										direction = "Right",
										size = 0.5,
										args = ai_tools[1].cmd,
										cwd = line,
									})
								end
							end),
						}),
						pane
					)
					return
				end
				local choices = {}
				for _, proj in ipairs(projects) do
					table.insert(choices, { label = proj.label, id = proj.path })
				end
				win:perform_action(
					act.InputSelector({
						title = "Select Project",
						choices = choices,
						action = wezterm.action_callback(function(_, inner_pane, id)
							if id then
								inner_pane:split({
									direction = "Right",
									size = 0.5,
									args = ai_tools[1].cmd,
									cwd = id,
								})
							end
						end),
					}),
					pane
				)
			end),
		},
		{
			key = "phys:l",
			action = wezterm.action_callback(function(win, pane)
				local choices = {}
				for _, tool in ipairs(ai_tools) do
					table.insert(choices, { label = tool.label, id = tool.label })
				end
				win:perform_action(
					act.InputSelector({
						title = "AI Tools",
						choices = choices,
						action = wezterm.action_callback(function(_, inner_pane, id)
							if id then
								for _, tool in ipairs(ai_tools) do
									if tool.label == id then
										local cwd = inner_pane:get_current_working_dir()
										inner_pane:split({
											direction = "Right",
											size = 0.5,
											args = tool.cmd,
											cwd = cwd and cwd.file_path or nil,
										})
										break
									end
								end
							end
						end),
					}),
					pane
				)
			end),
		},
		{ key = "Escape", action = "PopKeyTable" },
	},
}

---------------------------------------------------------------------------
-- Session persistence (resurrect.wezterm)
---------------------------------------------------------------------------
-- 15분마다 워크스페이스 자동 저장
resurrect.state_manager.periodic_save({
	interval_seconds = 900,
	save_workspaces = true,
	save_windows = true,
	save_tabs = true,
})

-- 워크스페이스 전환 시 자동 저장/복원 (smart_workspace_switcher 연동)
wezterm.on("smart_workspace_switcher.workspace_switcher.selected", function()
	resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
end)

wezterm.on("smart_workspace_switcher.workspace_switcher.created", function(window, path, label)
	local state = resurrect.state_manager.load_state(label, "workspace")
	resurrect.workspace_state.restore_workspace(state, {
		window = window,
		relative = true,
		restore_text = true,
		on_pane_restore = resurrect.tab_state.default_on_pane_restore,
	})
end)

---------------------------------------------------------------------------
-- OS-specific
---------------------------------------------------------------------------
if is_windows then
	-- Launch WSL (Ubuntu) + zsh as a login shell by default
	config.default_domain = "WSL:Ubuntu"

	config.window_background_opacity = 0.7
	config.win32_system_backdrop = "Acrylic"
	config.macos_window_background_blur = nil
end

return config
