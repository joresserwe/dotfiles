local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()
-- plugin.require raises during config eval when a plugin repo fails libgit2's
-- ownership check (e.g. repo cloned by an elevated instance); an unhandled
-- raise aborts the entire config and the GUI exits before any window opens.
local failed_plugins = {}
local function safe_plugin_require(url)
	local ok, plugin = pcall(wezterm.plugin.require, url)
	if ok then
		return plugin
	end
	wezterm.log_error("plugin load failed: " .. url .. ": " .. tostring(plugin))
	table.insert(failed_plugins, url)
	return nil
end
local workspace_switcher = safe_plugin_require("https://github.com/MLFlexer/smart_workspace_switcher.wezterm")
local resurrect = safe_plugin_require("https://github.com/YedPool/resurrect.wezterm")

local plugin_warning_shown = false
wezterm.on("window-config-reloaded", function(window)
	if #failed_plugins > 0 and not plugin_warning_shown then
		plugin_warning_shown = true
		window:toast_notification("wezterm", "Plugin load failed:\n" .. table.concat(failed_plugins, "\n"), nil, 8000)
	end
end)

local is_darwin = wezterm.target_triple:find("darwin") ~= nil

local brew_bin = is_darwin and "/opt/homebrew/bin/" or "/home/linuxbrew/.linuxbrew/bin/"

if workspace_switcher then
	workspace_switcher.zoxide_path = brew_bin .. "zoxide"
end

---------------------------------------------------------------------------
-- AI tools
---------------------------------------------------------------------------
local ai_tools = {
	{ key = "c", label = "Claude Code", cmd = { "claude" } },
	{ key = "r", label = "Claude Code (resume)", cmd = { "claude", "-r" } },
	-- { key = 'x', label = 'Codex',              cmd = { 'codex' } },
	-- { key = 'g', label = 'Gemini CLI',          cmd = { 'gemini' } },
}

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
-- Fallback to the official VS Code codicon font for codepoints beyond the
-- standard Nerd Font codicon range (EA60-EC1E) — e.g. U+EC21 sparkle-filled
-- emitted by Claude Code's TUI. Install codicon.ttf from
-- https://unpkg.com/@vscode/codicons/dist/codicon.ttf
-- Sarasa Mono K (be5invis/Sarasa-Gothic, SIL OFL-1.1) covers Hangul with
-- cells that divide the 0xProto Latin cell at a clean 2:1 ratio, so Korean
-- never drifts out of column alignment. Missing on macOS — font_with_fallback
-- silently skips entries that aren't installed, so the same config works on
-- both platforms (macOS falls through to its built-in CJK system fallback).
config.font = wezterm.font_with_fallback({
	"0xProto Nerd Font",
	"Sarasa Mono K",
	"codicon",
})

-- Silence the missing-glyph log spam. Bash output occasionally renders
-- unassigned codepoints (e.g. U+0378 from mis-decoded bytes) that no font
-- will ever cover. The codicon fallback above still handles sparkle-filled
-- and similar PUA glyphs for display purposes.
config.warn_about_missing_glyphs = false

-- Single static font_size; per-monitor scaling is left to WezTerm's native
-- DPI handling (glyphs rasterize at each monitor's real DPI). Do NOT pin
-- config.dpi or override font_size per monitor: a dpi pin renders text at
-- half size on the 192-DPI monitor, and update-status font_size overrides
-- were tried and removed — every fire on monitor crossing re-triggered
-- window jitter under GlazeWM.
config.font_size = 14.0

config.adjust_window_size_when_changing_font_size = false

config.custom_block_glyphs = true
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }

local window_opacity = 0.85
config.window_background_opacity = window_opacity
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
config.enable_kitty_graphics = true

config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 120
config.animation_fps = 120

local tab_bar_bg
if config.tab_bar_at_bottom then
	tab_bar_bg = "rgba(0, 0, 0, 0)"
else
	local r, g, b = wezterm.color.parse(C.base):srgba_u8()
	tab_bar_bg = string.format("rgba(%d, %d, %d, %s)", r, g, b, window_opacity)
end
config.colors = {
	tab_bar = {
		background = tab_bar_bg,
	},
}

---------------------------------------------------------------------------
-- Leader key
---------------------------------------------------------------------------
config.leader = { key = "phys:a", mods = "CTRL", timeout_milliseconds = 1000 }

---------------------------------------------------------------------------
-- Key bindings
---------------------------------------------------------------------------
config.keys = {
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

	{ key = "phys:t", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "phys:l", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "phys:h", mods = "LEADER", action = act.ActivateTabRelative(-1) },
	-- Hangul IME delivers composed jamo instead of h/l, so bind those too
	{ key = "ㅣ", mods = "LEADER", action = act.ActivateTabRelative(1) },
	{ key = "ㅗ", mods = "LEADER", action = act.ActivateTabRelative(-1) },

	-- Copy mode
	{
		key = "phys:v",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			win:perform_action(act.ActivateCopyMode, pane)
			win:perform_action(act.CopyMode("ClearPattern"), pane)
		end),
	},

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

	{
		key = "/",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
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
						.. '[ -n "$result" ] && printf "%s" "$result" | pbcopy',
				},
			})
		end),
	},

	{ key = "=", mods = "LEADER", action = act.PaneSelect({ mode = "SwapWithActive" }) },

	{ key = ":", mods = "LEADER", action = act.ActivateCommandPalette },

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

	{
		key = "phys:p",
		mods = "LEADER",
		action = workspace_switcher and workspace_switcher.switch_workspace()
			or act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }),
	},
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
						'echo "  C-a ?       this help"',
						'echo "  C-a \\\\       horizontal split"',
						'echo "  C-a -       vertical split"',
						'echo "  C-a ↑↓←→    resize pane"',
						'echo "  C-a m       toggle pane zoom"',
						'echo "  C-a x       close pane"',
						'echo "  C-a t       new tab"',
						'echo "  C-a h/l     previous/next tab"',
						'echo "  C-a ,       rename tab"',
						'echo "  C-a v       copy mode"',
						'echo "  C-a /       search mode"',
						'echo "  C-a q       QuickSelect (URL/path/hash/IP)"',
						'echo "  C-a =       swap panes"',
						'echo "  C-a :       command palette"',
						'echo "  C-a r       reload config"',
						'echo "  C-a p       workspace (zoxide fuzzy)"',
						'echo "  C-a [/]     previous/next workspace"',
						'echo "  C-a n       new workspace"',
						'echo "  C-a \\$       rename session"',
						'echo ""',
						'echo "  Session (after C-a s)"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  s           save session"',
						'echo "  l           restore session (fuzzy)"',
						'echo "  d           delete session"',
						'echo "  C-]         pane move mode (HJKL, 1s)"',
						'echo ""',
						'echo "  AI (after C-a a)"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  a           Claude Code"',
						'echo "  r           Claude Code resume"',
						'echo "  p           pick project → Claude"',
						'echo "  l           AI tool list"',
						'echo ""',
						'echo "  Navigation"',
						'echo "  ─────────────────────────────────"',
						'echo ""',
						'echo "  C-h/j/k/l   move between panes (nvim-aware)"',
						'echo ""',
						'read -n1 -s -p "  Press any key to close..."',
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

	{ key = "phys:s", mods = "LEADER", action = act.ActivateKeyTable({ name = "session", one_shot = true }) },

	{ key = "phys:a", mods = "LEADER", action = act.ActivateKeyTable({ name = "ai", one_shot = true }) },

	{
		key = "]",
		mods = "CTRL",
		action = act.ActivateKeyTable({ name = "move_pane", one_shot = false, timeout_milliseconds = 1000 }),
	},
}

---------------------------------------------------------------------------
-- Pane navigation (nvim-aware)
---------------------------------------------------------------------------
-- user_vars broadcast by nvim over OSC 1337 (see the nvim config's
-- terminal integration):
--   IS_NVIM         : nvim is running in this pane
--   NVIM_AT_<DIR>   : the current nvim window sits at that edge (DIR ∈ LEFT/RIGHT/UP/DOWN)
-- Combined:
--   nvim + non-edge  -> SendKey (nvim-internal window move)
--   nvim + edge      -> ActivatePaneDirection (no CLI call needed)
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
-- Status bar
---------------------------------------------------------------------------
-- gitmux JSON pushed by the shell as a pane user var on every prompt
-- (see __wezterm_git_status_precmd in zsh/.zshrc). Pane-scoped escape
-- sequences cross the SSH boundary, so no subprocess or file access
-- is needed here.
local function get_git_info(pane)
	local ok, vars = pcall(pane.get_user_vars, pane)
	if not ok or not vars then
		return nil
	end
	local raw = vars.git_status
	if not raw or raw == "" then
		return nil
	end
	local function num(key)
		return tonumber(raw:match('"' .. key .. '":%s*(%d+)')) or 0
	end
	local function bool(key)
		return raw:match('"' .. key .. '":%s*true') ~= nil
	end
	local function str(key)
		return raw:match('"' .. key .. '":%s*"([^"]*)"')
	end
	local branch = str("LocalBranch")
	if bool("IsDetached") then
		branch = str("HEAD") or branch
	end
	if not branch or branch == "" then
		return nil
	end
	return {
		branch = branch,
		modified = num("NumModified"),
		staged = num("NumStaged"),
		untracked = num("NumUntracked"),
		ahead = num("AheadCount"),
		behind = num("BehindCount"),
		clean = bool("IsClean"),
		remote = str("RemoteBranch") or "",
	}
end

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

	local workspace = window:active_workspace()
	local leader_active = window:leader_is_active()
	local move_pane_active = window:active_key_table() == "move_pane"
	local session_color = leader_active and C.red or move_pane_active and C.sky or C.green
	window:set_left_status(wezterm.format({
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = session_color } },
		{ Text = "  " .. ROUND_L },
		{ Background = { Color = session_color } },
		{ Foreground = { Color = C.crust } },
		{ Text = utf8.char(0xe795) },
		{ Foreground = { Color = session_color } },
		{ Text = "█" },
		{ Background = { Color = C.surface0 } },
		{ Foreground = { Color = C.text } },
		{ Text = " " .. workspace },
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = C.surface0 } },
		{ Text = ROUND_R .. " " },
	}))

	-- Right: directory | git | datetime
	local dir_name = cwd:match("([^/\\]+)$") or cwd
	local datetime = wezterm.strftime("%y-%m-%d %H:%M")
	local git = get_git_info(pane)

	local right = {}

	-- directory
	append(right, make_module(utf8.char(0xe5ff), dir_name, C.maroon))

	-- git
	if git then
		local git_icon_color = C.green
		append(right, {
			{ Background = { Color = TAB_BG } },
			{ Foreground = { Color = git_icon_color } },
			{ Text = ROUND_L },
			{ Background = { Color = git_icon_color } },
			{ Foreground = { Color = C.crust } },
			{ Text = utf8.char(0xf418) },
			{ Foreground = { Color = git_icon_color } },
			{ Text = "█" },
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
-- Tab title
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
	-- byte-class pattern: the first full UTF-8 character (icon glyph)
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
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = accent } },
		{ Text = ROUND_L },
		{ Background = { Color = accent } },
		{ Foreground = { Color = C.crust } },
		{ Text = title .. zoomed },
		{ Foreground = { Color = accent } },
		{ Text = "█" },
		{ Background = { Color = num_bg } },
		{ Foreground = { Color = num_bg } },
		{ Text = "█" },
		{ Foreground = { Color = num_fg } },
		{ Text = tostring(index) },
		{ Background = { Color = TAB_BG } },
		{ Foreground = { Color = num_bg } },
		{ Text = ROUND_R },
	}
end)

---------------------------------------------------------------------------
-- Key tables
---------------------------------------------------------------------------
config.key_tables = {
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

	resize_pane = {
		{ key = "UpArrow", action = act.AdjustPaneSize({ "Up", 5 }) },
		{ key = "DownArrow", action = act.AdjustPaneSize({ "Down", 5 }) },
		{ key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 5 }) },
		{ key = "RightArrow", action = act.AdjustPaneSize({ "Right", 5 }) },
		{ key = "Escape", action = "PopKeyTable" },
	},

	move_pane = {
		{ key = "phys:h", action = act.ActivatePaneDirection("Left") },
		{ key = "phys:j", action = act.ActivatePaneDirection("Down") },
		{ key = "phys:k", action = act.ActivatePaneDirection("Up") },
		{ key = "phys:l", action = act.ActivatePaneDirection("Right") },
		-- Hangul IME delivers composed jamo instead of h/j/k/l, so bind those too
		{ key = "ㅗ", action = act.ActivatePaneDirection("Left") },
		{ key = "ㅓ", action = act.ActivatePaneDirection("Down") },
		{ key = "ㅏ", action = act.ActivatePaneDirection("Up") },
		{ key = "ㅣ", action = act.ActivatePaneDirection("Right") },
		{ key = "Escape", action = "PopKeyTable" },
	},

	session = {
		{
			key = "s",
			action = wezterm.action_callback(function()
				if not resurrect then
					return
				end
				resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
				wezterm.log_info("Workspace state saved")
			end),
		},
		{
			key = "l",
			action = wezterm.action_callback(function(win, pane) end),
		},
		{ key = "Escape", action = "PopKeyTable" },
	},

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
if resurrect then
	resurrect.state_manager.periodic_save({
		interval_seconds = 900,
		save_workspaces = true,
		save_windows = true,
		save_tabs = true,
	})

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
end

return config
