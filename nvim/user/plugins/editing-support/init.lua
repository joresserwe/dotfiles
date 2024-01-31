local current_path = ... .. "."
return {
  require(current_path .. "autosave"),
  require(current_path .. "inc-rename"),
  require(current_path .. "markdown-preview"),
  require(current_path .. "multicursor"),
}
