local M = {}

M.tableToString = function(tbl, indent)
  indent = indent or 0
  local str = ""

  for k, v in pairs(tbl) do
    str = str .. string.rep("  ", indent) .. tostring(k) .. ": "
    if type(v) == "table" then
      str = str .. "\n" .. M.tableToString(v, indent + 1)
    else
      str = str .. tostring(v) .. "\n"
    end
  end

  return str
end

M.includes = function(tbl, element)
  for _, value in pairs(tbl) do
    if value == element then return true end
  end
  return false
end

return M
