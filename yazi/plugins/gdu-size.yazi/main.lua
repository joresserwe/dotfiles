--- @since 26.5.6
--- @sync entry

local M = {}

local function to_windows(path)
	local drive, rest = path:match("^/mnt/(%a)(.*)$")
	if drive and (rest == "" or rest:sub(1, 1) == "/") then
		return drive:upper() .. ":" .. (rest == "" and "\\" or rest:gsub("/", "\\"))
	end
end

local function from_windows(path)
	local drive, rest = path:match("^(%a):\\(.*)$")
	if not drive then
		return path
	end
	return "/mnt/" .. drive:lower() .. (rest == "" and "" or "/" .. rest:gsub("\\", "/"))
end

local function gdu(cmd, path)
	return Command(cmd)
		:arg({
			"--non-interactive",
			"--no-progress",
			"--no-color",
			"--show-apparent-size",
			"--no-prefix",
			"--depth",
			"2",
			path,
		})
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:output()
end

local function emit_sizes(stdout)
	local groups = {}
	for line in stdout:gmatch("[^\r\n]+") do
		local size, path = line:match("^%s*(%d+) (.+)$")
		path = path and from_windows(path)
		local url = path and path:sub(1, 1) == "/" and Url(path)
		local parent = url and url.parent
		if parent then
			local key = tostring(parent)
			groups[key] = groups[key] or { url = parent, sizes = {} }
			groups[key].sizes[url.urn] = tonumber(size)
		end
	end
	for _, op in pairs(groups) do
		ya.emit("update_files", { op = fs.op("size", op) })
	end
end

function M:scan(done)
	local cwd = cx.active.current.cwd
	local path = tostring(cwd)
	local key = cx.active.id.value .. ":" .. path
	self.scans = self.scans or {}
	if not cwd.is_regular or self.scans[key] then
		return done and done()
	end

	self.scans[key] = "running"
	ya.async(function()
		local windows = to_windows(path)
		local output = windows and gdu("gdu.exe", windows)
		if not (output and output.status.success) then
			output = gdu("gdu-go", path)
		end
		self.scans[key] = output and "done" or nil
		if output then
			emit_sizes(output.stdout)
		end
		if done then
			done()
		end
	end)
end

function M:setup()
	ps.sub("cd", function()
		if cx.active.pref.sort_by == "size" then
			self:scan()
		end
	end)
end

function M:entry(job)
	local reverse = job.args.reverse == true
	ya.emit("linemode", { "size" })
	self:scan(function() ya.emit("sort", { "size", reverse = reverse }) end)
end

return M
