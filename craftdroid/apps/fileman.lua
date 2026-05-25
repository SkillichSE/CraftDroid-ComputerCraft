local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

local editableExt = {
  lua = true,
  txt = true,
  md = true,
  cfg = true,
  json = true,
  dat = true,
  app = true,
}

local imageExt = {
  nfp = true,
  nft = true,
}

local function getExt(name)
  return name:match("%.([^%.]+)$") or ""
end

local function fileIcon(name, isDir)
  if isDir then return "D", colors.yellow end
  local ext = getExt(name):lower()
  if ext == "lua" then return "L", colors.lime end
  if ext == "txt" or ext == "md" then return "T", colors.white end
  if ext == "cfg" or ext == "json" then return "C", colors.cyan end
  if ext == "dat" then return "D", colors.lightGray end
  if ext == "app" then return "A", colors.orange end
  if ext == "nfp" or ext == "nft" then return "P", colors.pink end
  return "F", ui.T().sub
end

local function fmtSize(bytes)
  if bytes >= 1048576 then
    return string.format("%.1fMB", bytes / 1048576)
  elseif bytes >= 1024 then
    return string.format("%.1fKB", bytes / 1024)
  else
    return bytes .. "B"
  end
end

local function normPath(path)
  path = tostring(path or ""):gsub("\\", "/")
  if path == "" then return "/" end
  if path:sub(1, 1) ~= "/" then path = "/" .. path end
  while path:find("//", 1, true) do path = path:gsub("//", "/") end
  if #path > 1 and path:sub(-1) == "/" then path = path:sub(1, -2) end
  return path
end

local function joinPath(dir, name)
  dir = normPath(dir)
  return dir .. (dir == "/" and "" or "/") .. name
end

local function buildCrumbs(path)
  path = normPath(path)
  if path == "/" then return "/" end
  local parts = {}
  for p in path:gmatch("[^/]+") do table.insert(parts, p) end
  if #parts <= 2 then return "/" .. table.concat(parts, "/") end
  return "/.../" .. parts[#parts - 1] .. "/" .. parts[#parts]
end

local function isEditable(path)
  return editableExt[getExt(path):lower()] == true
end

local function isImage(path)
  return imageExt[getExt(path):lower()] == true
end

local function isSystemPath(path)
  path = normPath(path)
  if path == "/startup.lua" or path == "/CraftDroid.lua" then return true end
  if path == "/rom" or path:sub(1, 5) == "/rom/" then return true end
  if path == "/craftdroid" then return true end
  if path == "/craftdroid/system.cfg" then return true end
  if path:match("^/craftdroid/[^/]+%.lua$") then return true end
  return false
end

local function rememberFolder(c)
  c.path = normPath(c.path)
  if c.lastPath ~= c.path then
    c.scroll = 0
    c.lastPath = c.path
  end
end

local function isReadOnlyPath(path)
  if fs.isReadOnly then
    local ok, readOnly = pcall(fs.isReadOnly, path)
    if ok and readOnly then return true end
  end
  return false
end

local function readLines(path)
  local lines = {}
  local h = fs.open(path, "r")
  if h then
    while true do
      local line = h.readLine()
      if line == nil then break end
      table.insert(lines, line)
    end
    h.close()
  end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

local function saveLines(path, lines)
  lines = lines or {""}
  local h = fs.open(path, "w")
  if not h then return false end
  for i, line in ipairs(lines) do
    h.write(line)
    if i < #lines then h.write("\n") end
  end
  h.close()
  return true
end

local function listFiles(path)
  path = normPath(path)
  local flist = {}
  if fs.exists(path) then
    local ok, lst = pcall(fs.list, path)
    if ok then flist = lst end
  end
  table.sort(flist, function(a, b)
    local fpA = joinPath(path, a)
    local fpB = joinPath(path, b)
    local da = fs.isDir(fpA)
    local db = fs.isDir(fpB)
    if da ~= db then return da end
    return a:lower() < b:lower()
  end)
  return flist
end

local function clampCursor(c)
  c.lines = c.lines or {""}
  if #c.lines == 0 then table.insert(c.lines, "") end
  c.cursorLine = math.max(1, math.min(c.cursorLine or 1, #c.lines))
  c.cursorCol = math.max(1, math.min(c.cursorCol or 1, #(c.lines[c.cursorLine] or "") + 1))
end

local function keepCursorVisible(c)
  local W, H = term.getSize()
  local top = 3
  local bottom = H - 2
  local rows = math.max(1, bottom - top + 1)
  c.editScroll = math.max(0, c.editScroll or 0)
  if c.cursorLine <= c.editScroll then c.editScroll = c.cursorLine - 1 end
  if c.cursorLine > c.editScroll + rows then c.editScroll = c.cursorLine - rows end
  local textW = math.max(1, W - 6)
  c.colScroll = math.max(0, c.colScroll or 0)
  if c.cursorCol <= c.colScroll then c.colScroll = c.cursorCol - 1 end
  if c.cursorCol > c.colScroll + textW then c.colScroll = c.cursorCol - textW end
end

local function closeEditor(c)
  c.mode = nil
  c.filePath = nil
  c.lines = nil
  c.cursorLine = nil
  c.cursorCol = nil
  c.editScroll = nil
  c.colScroll = nil
end

local function closeImage(c)
  c.mode = nil
  c.imagePath = nil
  c.imageData = nil
  c.imageError = nil
end

local function openEditor(c, path)
  c.mode = "edit"
  c.filePath = path
  c.lines = readLines(path)
  c.cursorLine = 1
  c.cursorCol = #(c.lines[1] or "") + 1
  c.editScroll = 0
  c.colScroll = 0
end

local function openImage(c, path)
  c.mode = "image"
  c.imagePath = path
  c.imageData = nil
  c.imageError = nil
  local ok, img = pcall(paintutils.loadImage, path)
  if ok and img then
    c.imageData = img
  else
    c.imageError = "Image format not supported"
  end
end

local function saveEditor(c)
  if c.filePath and isReadOnlyPath(c.filePath) then
    ui.showToast("Read-only file")
    return
  end
  if c.filePath and saveLines(c.filePath, c.lines or {""}) then
    ui.showToast("File saved")
  else
    ui.showToast("Save failed")
  end
end

local function drawEditor(c, W, H)
  clampCursor(c)
  keepCursorVisible(c)
  if term.setCursorBlink then term.setCursorBlink(false) end
  ui.drawAppBar(fs.getName(c.filePath or "Edit"), true)
  if isSystemPath(c.filePath or "") then ui.txt(math.max(2, W - 9), 2, "OS", ui.T().accent, ui.T().bar) end
  ui.txt(math.max(2, W - 6), 2, "[Save]", colors.lime, ui.T().bar)

  local top = 3
  local bottom = H - 2
  local rows = math.max(1, bottom - top + 1)
  local scroll = c.editScroll or 0
  ui.fill(1, top, W, rows, ui.T().card)

  for i = 1 + scroll, math.min(#c.lines, scroll + rows) do
    local ay = top + i - 1 - scroll
    local line = c.lines[i] or ""
    local display = line
    ui.txt(2, ay, tostring(i):sub(-3), ui.T().sub, ui.T().card)
    ui.txt(5, ay, ":", ui.T().sub, ui.T().card)
    ui.txt(6, ay, display:sub((c.colScroll or 0) + 1, (c.colScroll or 0) + W - 5), ui.T().text, ui.T().card)

    if i == c.cursorLine and math.floor(os.clock() * 2) % 2 == 0 then
      local col = math.max(1, math.min(c.cursorCol or 1, #line + 1))
      local cx = 6 + col - 1 - (c.colScroll or 0)
      if cx >= 6 and cx <= W then
        local ch = line:sub(col, col)
        if ch == "" then ch = " " end
        ui.txt(cx, ay, ch, colors.black, ui.T().accent)
      end
    end
  end

  ui.fill(1, H - 1, W, 1, ui.T().accent)
  local status = "Ln " .. c.cursorLine .. " Col " .. c.cursorCol
  if c.colScroll and c.colScroll > 0 then status = status .. " >" end
  ui.ctr(H - 1, status, colors.black, ui.T().accent)
  ui.drawNavBar()
end

local function drawImageViewer(c, W, H)
  ui.drawAppBar(fs.getName(c.imagePath or "Image"), true)
  ui.fill(1, 3, W, H - 3, colors.black)

  if c.imageData then
    local imgW = 0
    local imgH = #c.imageData
    for _, row in ipairs(c.imageData) do imgW = math.max(imgW, #row) end
    local x = math.max(1, math.floor((W - imgW) / 2) + 1)
    local y = math.max(3, math.floor(((H - 3) - imgH) / 2) + 3)
    for iy, row in ipairs(c.imageData) do
      local sy = y + iy - 1
      if sy >= 3 and sy <= H - 1 then
        for ix, col in pairs(row) do
          local sx = x + ix - 1
          if sx >= 1 and sx <= W and col and col >= colors.white and col <= colors.black then
            paintutils.drawPixel(sx, sy, col)
          end
        end
      end
    end
  else
    ui.ctr(math.floor(H / 2), c.imageError or "Cannot open image", colors.red, colors.black)
  end

  ui.drawNavBar()
end

local function drawList(c, W, H)
  rememberFolder(c)
  ui.fill(1, 2, W, 1, ui.T().bar)
  if c.path ~= "/" then ui.txt(2, 2, "<", ui.T().accent, ui.T().bar) end
  ui.txt(4, 2, buildCrumbs(c.path):sub(1, W - 4), ui.T().barTxt, ui.T().bar)

  local flist = listFiles(c.path)
  local startY = 3
  local maxShow = H - startY - 1
  c.scroll = math.max(0, math.min(c.scroll or 0, math.max(0, #flist - maxShow)))

  for i = 1 + c.scroll, math.min(#flist, c.scroll + maxShow) do
    local f = flist[i]
    local ay = startY + (i - 1 - c.scroll)
    local fp = joinPath(c.path, f)
    local isDir = fs.isDir(fp)
    local isSystem = isSystemPath(fp)
    ui.fill(1, ay, W, 1, ui.T().card)
    local ic, icCol = fileIcon(f, isDir)
    if isSystem then ic, icCol = "S", ui.T().accent end
    ui.txt(2, ay, ic, icCol, ui.T().card)
    ui.txt(4, ay, f:sub(1, W - 12), ui.T().text, ui.T().card)
    if isSystem and isDir then
      ui.txt(math.max(2, W - 2), ay, "OS>", ui.T().accent, ui.T().card)
    elseif isSystem then
      ui.txt(math.max(2, W - 1), ay, "OS", ui.T().accent, ui.T().card)
    elseif isDir then
      ui.txt(W - 1, ay, ">", ui.T().accent, ui.T().card)
    else
      local sz = fmtSize(fs.getSize(fp))
      ui.txt(math.max(2, W - #sz), ay, sz, ui.T().sub, ui.T().card)
    end
  end

  if #flist == 0 then ui.ctr(math.floor(H / 2), "Empty folder", ui.T().sub, ui.T().bg) end
  ui.drawNavBar()
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  local c = state.state.appState
  if not c.path then c.path = "/" c.scroll = 0 end
  c.path = normPath(c.path)
  if c.mode == "edit" then
    drawEditor(c, W, H)
  elseif c.mode == "image" then
    drawImageViewer(c, W, H)
  else
    drawList(c, W, H)
  end
end

local function handleEditorTouch(c, x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then closeEditor(c) return true end
  if y == 2 and x >= W - 6 then saveEditor(c) return true end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw then closeEditor(c) return true end
    return false
  end
  if y == H - 1 then return true end
  local top = 3
  local bottom = H - 2
  if y >= top and y <= bottom then
    local idx = y - top + 1 + (c.editScroll or 0)
    if idx >= 1 and idx <= #(c.lines or {}) then
      c.cursorLine = idx
      c.cursorCol = math.max(1, math.min((x - 5) + (c.colScroll or 0), #(c.lines[idx] or "") + 1))
      clampCursor(c)
      keepCursorVisible(c)
    end
    return true
  end
  return false
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  local c = state.state.appState
  if not c.path then c.path = "/" c.scroll = 0 end
  c.path = normPath(c.path)
  rememberFolder(c)

  if c.mode == "edit" then
    if handleEditorTouch(c, x, y) then return end
  elseif c.mode == "image" then
    if y == 2 and x <= 3 then closeImage(c) return end
    if y == H then
      local bw = math.floor(W / 3)
      if x <= bw then closeImage(c) return end
    end
    return
  end

  if y == 2 and x <= 3 then
    if c.path ~= "/" then
      c.path = normPath(fs.getDir(c.path))
      if c.path == "" then c.path = "/" end
      c.scroll = 0
    else
      state.state.screen = "home"
    end
    return
  end

  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw then
      c.scroll = math.max(0, (c.scroll or 0) - 3)
    elseif x <= bw * 2 then
      if c.path ~= "/" then
        c.path = normPath(fs.getDir(c.path))
        if c.path == "" then c.path = "/" end
        c.scroll = 0
      else
        state.state.screen = "home"
      end
    else
      c.scroll = (c.scroll or 0) + 3
    end
    return
  end

  local flist = listFiles(c.path)
  local idx = (y - 3) + 1 + (c.scroll or 0)
  if idx >= 1 and idx <= #flist then
    local f = flist[idx]
    local fp = joinPath(c.path, f)
    if fs.isDir(fp) then
      c.path = fp
      c.scroll = 0
    elseif isImage(fp) then
      openImage(c, fp)
    elseif isEditable(fp) then
      if isSystemPath(fp) then
        ui.showDialog("OS file", "This file is used by the system.", {"Edit", "Cancel"}, function(ch)
          if ch == "Edit" then openEditor(c, fp) end
        end)
      else
        openEditor(c, fp)
      end
    else
      ui.showToast(f .. "  " .. fmtSize(fs.getSize(fp)))
    end
  end
end

local function insertText(c, text)
  clampCursor(c)
  local line = c.lines[c.cursorLine] or ""
  local before = line:sub(1, c.cursorCol - 1)
  local after = line:sub(c.cursorCol)
  local parts = {}
  for part in (text .. "\n"):gmatch("([^\n]*)\n") do table.insert(parts, part) end
  if #parts <= 1 then
    c.lines[c.cursorLine] = before .. text .. after
    c.cursorCol = c.cursorCol + #text
  else
    c.lines[c.cursorLine] = before .. parts[1]
    for i = 2, #parts do table.insert(c.lines, c.cursorLine + i - 1, parts[i]) end
    c.cursorLine = c.cursorLine + #parts - 1
    c.cursorCol = #(parts[#parts] or "") + 1
    c.lines[c.cursorLine] = (c.lines[c.cursorLine] or "") .. after
  end
  keepCursorVisible(c)
end

local function backspace(c)
  clampCursor(c)
  if c.cursorCol > 1 then
    local line = c.lines[c.cursorLine]
    c.lines[c.cursorLine] = line:sub(1, c.cursorCol - 2) .. line:sub(c.cursorCol)
    c.cursorCol = c.cursorCol - 1
  elseif c.cursorLine > 1 then
    local prevLen = #c.lines[c.cursorLine - 1]
    c.lines[c.cursorLine - 1] = c.lines[c.cursorLine - 1] .. c.lines[c.cursorLine]
    table.remove(c.lines, c.cursorLine)
    c.cursorLine = c.cursorLine - 1
    c.cursorCol = prevLen + 1
  end
  keepCursorVisible(c)
end

local function deleteChar(c)
  clampCursor(c)
  local line = c.lines[c.cursorLine]
  if c.cursorCol <= #line then
    c.lines[c.cursorLine] = line:sub(1, c.cursorCol - 1) .. line:sub(c.cursorCol + 1)
  elseif c.cursorLine < #c.lines then
    c.lines[c.cursorLine] = line .. c.lines[c.cursorLine + 1]
    table.remove(c.lines, c.cursorLine + 1)
  end
  keepCursorVisible(c)
end

local function newline(c)
  clampCursor(c)
  local line = c.lines[c.cursorLine]
  local after = line:sub(c.cursorCol)
  c.lines[c.cursorLine] = line:sub(1, c.cursorCol - 1)
  table.insert(c.lines, c.cursorLine + 1, after)
  c.cursorLine = c.cursorLine + 1
  c.cursorCol = 1
  keepCursorVisible(c)
end

local function handleInput(ev)
  local c = state.state.appState
  if c.mode ~= "edit" then return end
  if ev[1] == "char" then
    insertText(c, ev[2])
  elseif ev[1] == "paste" then
    insertText(c, ev[2])
  elseif ev[1] == "key" then
    local key = ev[2]
    if key == keys.s and ev[3] then saveEditor(c)
    elseif key == keys.backspace then backspace(c)
    elseif key == keys.delete then deleteChar(c)
    elseif key == keys.enter then newline(c)
    elseif key == keys.left then
      if (c.cursorCol or 1) > 1 then
        c.cursorCol = c.cursorCol - 1
      elseif (c.cursorLine or 1) > 1 then
        c.cursorLine = c.cursorLine - 1
        c.cursorCol = #(c.lines[c.cursorLine] or "") + 1
      end
      clampCursor(c)
      keepCursorVisible(c)
    elseif key == keys.right then
      local line = c.lines[c.cursorLine] or ""
      if (c.cursorCol or 1) <= #line then
        c.cursorCol = c.cursorCol + 1
      elseif (c.cursorLine or 1) < #c.lines then
        c.cursorLine = c.cursorLine + 1
        c.cursorCol = 1
      end
      clampCursor(c)
      keepCursorVisible(c)
    elseif key == keys.up then
      c.cursorLine = (c.cursorLine or 1) - 1
      clampCursor(c)
      keepCursorVisible(c)
    elseif key == keys.down then
      c.cursorLine = (c.cursorLine or 1) + 1
      clampCursor(c)
      keepCursorVisible(c)
    elseif key == keys.home then
      c.cursorCol = 1
      keepCursorVisible(c)
    elseif key == keys["end"] then
      c.cursorCol = #(c.lines[c.cursorLine] or "") + 1
      keepCursorVisible(c)
    end
  end
end

function M.register(app)
  app.registerApp("fileman", draw, handleTouch, handleInput)
end

return M
