--- @since 26.8.15

local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, f in pairs(tab.selected) do
		paths[#paths + 1] = tostring(f.path)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.path)
	end
	return paths
end)

local function notify(content, level)
	ya.notify({ title = "Win copy", content = content, timeout = 3, level = level or "info" })
end

local function to_windows(paths)
	local args = { "-c", 'for f; do wslpath -w "$f" || exit 1; done', "sh" }
	for _, path in ipairs(paths) do
		args[#args + 1] = path
	end
	local output = Command("sh"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output or not output.status.success then
		return
	end
	local converted = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		converted[#converted + 1] = line
	end
	return converted
end

local M = {}

function M:entry()
	local paths = selected_or_hovered()
	if #paths == 0 then
		return notify("No file to copy", "warn")
	end

	local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	table.insert(paths, 1, config .. "/yazi/plugins/win-copy.yazi/copy.ps1")
	local args = to_windows(paths)
	if not args then
		return notify("wslpath unavailable — WSL only", "error")
	end

	for i, option in ipairs({ "-NoProfile", "-NonInteractive", "-Sta", "-ExecutionPolicy", "Bypass", "-File" }) do
		table.insert(args, i, option)
	end
	local output = Command("powershell.exe"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output or not output.status.success then
		return notify("powershell.exe failed — WSL only", "error")
	end
	ya.emit("escape", { select = true })
	notify(string.format("Copied %d item(s) to the Windows clipboard", #paths - 1))
end

return M
