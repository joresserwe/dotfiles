-- full-border: 전체 테두리로 깔끔한 UI
require("full-border"):setup()

-- git: 파일 목록에 git 상태 표시
require("git"):setup()

-- 커스텀 linemode: 파일 크기 + 수정 시간 동시 표시
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
