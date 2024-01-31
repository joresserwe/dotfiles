local current_path = ... .. "."
return {
  require(current_path .. "lualine"),
  require(current_path .. "neo-tree"),
  require(current_path .. "noice"),
  require(current_path .. "notify"),
  require(current_path .. "telescope"),
}
