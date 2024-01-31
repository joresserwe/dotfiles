return function(maps)
  local utils = require "astronvim.utils"
  local is_available = utils.is_available

  -- LSP Code Action
  if maps.n["<leader>la"] then
    maps.n[";a"] = maps.n["<leader>la"]
    maps.v[";a"] = maps.v["<leader>la"]
    maps.n["<leader>la"] = false
    maps.v["<leader>la"] = false
  end

  -- Format buffer
  if maps.n["<leader>lf"] then
    maps.n[";f"] = maps.n["<leader>lf"]
    maps.v[";f"] = maps.v["<leader>lf"]
    maps.n["<leader>lf"] = false
    maps.v["<leader>lf"] = false
  end

  -- telescope diagonostic
  if maps.n["<leader>lD"] then
    maps.n["fd"] = maps.n["<leader>lD"]
    maps.n["<leader>lD"] = false
  end

  -- LSP Default rename symbol 비활성화
  if is_available "inc-rename.nvim" then maps.n["<leader>lr"] = false end
  return maps
end
