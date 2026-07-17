--- @since 26.5.6
--- Preview SVG as a rendered image on top with its source code below.
--- The code is drawn manually via ya.preview_widget: yazi only renders a
--- preview lock whose `area` equals the full preview pane (yazi-fm/mgr/preview.rs),
--- so ya.preview_code can't be given a sub-area.

local M = {}

local function no_skip(job)
	return { file = job.file, skip = 0, area = job.area, args = job.args or {} }
end

function M:peek(job)
	local start = os.clock()
	local cache = ya.file_cache(no_skip(job))

	local rendered
	if cache then
		local ok, err = require("svg"):preload(no_skip(job))
		if ok and not err then
			ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
			rendered = ya.image_show(
				cache,
				ui.Rect({
					x = job.area.x,
					y = job.area.y,
					w = job.area.w,
					h = math.max(1, math.floor(job.area.h * 0.6)),
				})
			)
		end
	end

	local image_height = rendered and rendered.h or 0
	local limit = job.area.h - image_height

	local lines, total, eof = {}, 0, true
	local file = io.open(tostring(job.file.url), "r")
	if file then
		for line in file:lines() do
			total = total + 1
			if total > job.skip + limit then
				eof = false
				break
			end
			if total > job.skip then
				local text = line:gsub("\r$", ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
				lines[#lines + 1] = ui.Line(text)
			end
		end
		file:close()
	end

	if eof and #lines == 0 and job.skip > 0 then
		ya.emit("peek", {
			math.max(0, total - limit),
			only_if = job.file.url,
			upper_bound = true,
		})
		return
	end

	ya.preview_widget(job, {
		ui.Text(lines)
			:area(ui.Rect({
				x = job.area.x,
				y = job.area.y + image_height,
				w = job.area.w,
				h = limit,
			}))
			:wrap(ui.Wrap.YES),
	})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step

	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

function M:preload(job)
	return require("svg"):preload(no_skip(job))
end

function M:spot(job)
	require("file"):spot(job)
end

return M
