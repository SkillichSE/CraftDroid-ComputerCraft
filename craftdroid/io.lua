local const = require("craftdroid.constants")
local M = {}

function M.ensureDirs()
  for _, d in ipairs({"/craftdroid", const.APPS_DIR, const.DATA_DIR, const.PICTURES_DIR}) do
    if not fs.exists(d) then fs.makeDir(d) end
  end

  for _, oldData in ipairs({"/craftdroid/data/", "/data/"}) do
    if oldData ~= const.DATA_DIR and fs.exists(oldData) then
      for _, name in ipairs(fs.list(oldData)) do
        local from = oldData .. name
        local to = const.DATA_DIR .. name
        if not fs.exists(to) then fs.move(from, to) end
      end
    end
  end
end

function M.saveFile(path, content)
  local f = fs.open(path, "w")
  if f then f.write(content) f.close() end
end

function M.loadFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local c = f.readAll()
  f.close()
  return c
end

function M.saveTable(path, t)
  M.saveFile(path, textutils.serialize(t))
end

function M.loadTable(path)
  local c = M.loadFile(path)
  if not c then return nil end
  return textutils.unserialize(c)
end

return M
