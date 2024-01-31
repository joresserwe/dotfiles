local current_path = ... .. "."
return {
  require(current_path .. "cmp"),
  require(current_path .. "mason"),
  require(current_path .. "null-ls"),
  require(current_path .. "treesitter"),
  require(current_path .. "language/json"),
  require(current_path .. "language/prettier"),
  require(current_path .. "language/lua"),
  require(current_path .. "language/typescript"),
}
