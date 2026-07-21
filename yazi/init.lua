require("full-border"):setup()

require("git"):setup()

local bookmarks = {}

local function dir_exists(path)
	local handle = io.open(path, "r")
	if handle then
		handle:close()
		return true
	end
	return false
end

if ya.target_os() == "linux" and dir_exists("/mnt/c/Windows") then
	-- WSL appendWindowsPath injects /mnt/c/Users/<user>/... entries into PATH
	local win_user = (os.getenv("PATH") or ""):match("/mnt/c/Users/([^/:]+)/")
	if win_user and dir_exists("/mnt/c/Users/" .. win_user) then
		local profile = "/mnt/c/Users/" .. win_user
		table.insert(bookmarks, { tag = "Downloads", path = profile .. "/Downloads/", key = "d" })
		table.insert(bookmarks, { tag = "AppData", path = profile .. "/AppData/", key = "a" })
	end
	for letter in ("cdefghijklmnopqrstuvwxyz"):gmatch("%a") do
		if dir_exists("/mnt/" .. letter) then
			table.insert(bookmarks, { tag = letter:upper() .. ":", path = "/mnt/" .. letter .. "/", key = letter:upper() })
		end
	end
end

require("yamb"):setup({
	bookmarks = bookmarks,
	jump_notify = true,
	cli = "fzf",
})

function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%b %d %H:%M", time)
	else
		time = os.date("%b %d  %Y", time)
	end

	local size = self._file:size()
	return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end
