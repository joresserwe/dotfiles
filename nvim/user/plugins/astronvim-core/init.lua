local current_path = ... .. "."
return {
  require(current_path .. "core"),
  require(current_path .. "community"),
}
