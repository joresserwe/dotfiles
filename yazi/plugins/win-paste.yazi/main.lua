--- @since 26.5.6
--- WSLg's clipboard bridge carries only text/images, not Explorer's CF_HDROP
--- file list, hence reading the copied paths via powershell.exe interop.

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local function notify(content, level)
	ya.notify({ title = "Win paste", content = content, timeout = 3, level = level or "info" })
end

local function to_wsl(path)
	local converted = Command("wslpath"):arg({ "-u", path }):stdout(Command.PIPED):output()
	if converted and converted.status.success then
		return (converted.stdout:gsub("%s+$", ""))
	end
end

local M = {}

function M:entry()
	local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
	local script = Command("wslpath")
		:arg({ "-w", config .. "/yazi/plugins/win-paste.yazi/paste.ps1" })
		:stdout(Command.PIPED)
		:output()
	if not script or not script.status.success then
		return notify("wslpath unavailable — WSL only", "error")
	end

	notify("Reading Windows clipboard…")
	local output = Command("powershell.exe")
		:arg({
			"-NoProfile",
			"-NonInteractive",
			"-Sta",
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			(script.stdout:gsub("%s+$", "")),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	if not output or not output.status.success then
		return notify("powershell.exe unavailable — WSL only", "error")
	end

	local temp_dir
	local sources = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local virt = line:match("^VIRT\t(.+)")
		if virt then
			temp_dir = to_wsl(virt)
		else
			local src = to_wsl(line)
			if src then
				sources[#sources + 1] = src
			end
		end
	end
	if #sources == 0 then
		return notify("No files in the Windows clipboard", "warn")
	end

	local args = { "-a", "-n", "--" }
	for _, src in ipairs(sources) do
		args[#args + 1] = src
	end
	args[#args + 1] = get_cwd()

	local copied = Command("cp"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if temp_dir then
		Command("rm"):arg({ "-rf", "--", temp_dir }):status()
	end
	if copied and copied.status.success then
		notify(string.format("Pasted %d item(s)", #sources))
	else
		notify("cp failed", "error")
	end
end

return M
