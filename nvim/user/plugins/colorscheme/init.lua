local current_path = ... .. "."
return {
  require(current_path .. "catppuccin"),
  require(current_path .. "solarized_osaka"),
  require(current_path .. "tokyo-night"),
  require(current_path .. "midnights"),
}
