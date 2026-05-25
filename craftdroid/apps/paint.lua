local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local palette = {
  colors.black,
  colors.gray,
  colors.white,
  colors.red,
  colors.orange,
  colors.yellow,
  colors.lime,
  colors.lightBlue,
  colors.blue,
  colors.purple,
  colors.pink,
  colors.brown,
}

local function ensurePaint()
  if not state.appData.paint then state.appData.paint = {drawings={}} end
  if state.appData.paint.pixels then
    state.appData.paint.drawings = {
      {name="Untitled", pixels=state.appData.paint.pixels}
    }
    state.appData.paint.pixels = nil
  end
  if not state.appData.paint.drawings then state.appData.paint.drawings = {} end
  return state.appData.paint
end

local exportPaintFiles

local function savePaint()
  local data = ensurePaint()
  io.saveTable(const.DATA_DIR .. "paint.dat", data)
  if exportPaintFiles then exportPaintFiles(data) end
end

local function key(x, y)
  return tostring(x) .. "," .. tostring(y)
end

local function safeFileName(name)
  local s = tostring(name or "Untitled"):gsub("[/\\:*?\"<>|]", "_")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then s = "Untitled" end
  return s
end

local blitChars = {
  [colors.white] = "0", [colors.orange] = "1", [colors.magenta] = "2", [colors.lightBlue] = "3",
  [colors.yellow] = "4", [colors.lime] = "5", [colors.pink] = "6", [colors.gray] = "7",
  [colors.lightGray] = "8", [colors.cyan] = "9", [colors.purple] = "a", [colors.blue] = "b",
  [colors.brown] = "c", [colors.green] = "d", [colors.red] = "e", [colors.black] = "f",
}

local function colorToNfp(col)
  if colors.toBlit then return colors.toBlit(col) end
  return blitChars[col] or "f"
end

local function exportDrawing(drawing)
  if not drawing or not drawing.pixels then return end
  if not fs.exists(const.PICTURES_DIR) then fs.makeDir(const.PICTURES_DIR) end

  local minX, minY, maxX, maxY
  for pos in pairs(drawing.pixels) do
    local px, py = pos:match("^(%-?%d+),(%-?%d+)$")
    px = tonumber(px)
    py = tonumber(py)
    if px and py then
      minX = minX and math.min(minX, px) or px
      minY = minY and math.min(minY, py) or py
      maxX = maxX and math.max(maxX, px) or px
      maxY = maxY and math.max(maxY, py) or py
    end
  end
  if not minX then return end

  local path = const.PICTURES_DIR .. safeFileName(drawing.name) .. ".nfp"
  local h = fs.open(path, "w")
  if not h then return end
  for y = minY, maxY do
    local row = {}
    for x = minX, maxX do
      local col = drawing.pixels[key(x, y)]
      table.insert(row, col and colorToNfp(col) or "0")
    end
    h.write(table.concat(row))
    if y < maxY then h.write("\n") end
  end
  h.close()
end

exportPaintFiles = function(data)
  for _, drawing in ipairs((data and data.drawings) or {}) do exportDrawing(drawing) end
end

local function newDrawingName()
  local data = ensurePaint()
  return "Drawing " .. (#data.drawings + 1)
end

local function openDrawing(c, idx)
  local data = ensurePaint()
  local drawing = data.drawings[idx]
  if not drawing then return end
  c.view = "draw"
  c.drawingIdx = idx
  c.name = drawing.name or newDrawingName()
  c.pixels = {}
  for k, v in pairs(drawing.pixels or {}) do c.pixels[k] = v end
  c.color = c.color or colors.black
end

local function createDrawing(c)
  c.view = "draw"
  c.drawingIdx = nil
  c.name = newDrawingName()
  c.pixels = {}
  c.color = c.color or colors.black
end

local function drawGallery(c, W, H)
  local data = ensurePaint()
  if not c.paintExported then
    exportPaintFiles(data)
    c.paintExported = true
  end
  ui.drawAppBar("Paint", true)
  ui.txt(math.max(2, W - 5), 2, "Draw", ui.T().accent, ui.T().bar)
  if #data.drawings == 0 then
    ui.ctr(math.floor(H / 2), "No drawings", ui.T().sub, ui.T().bg)
  else
    local maxRows = math.max(1, H - 3)
    c.scroll = math.max(0, math.min(c.scroll or 0, math.max(0, #data.drawings - maxRows)))
    for i = 1 + c.scroll, math.min(#data.drawings, c.scroll + maxRows) do
      local ay = 2 + i - c.scroll
      local drawing = data.drawings[i]
      ui.fill(1, ay, W, 1, ui.T().card)
      ui.txt(2, ay, (drawing.name or "Untitled"):sub(1, W - 7), ui.T().text, ui.T().card)
      ui.txt(W - 1, ay, ">", ui.T().accent, ui.T().card)
    end
  end
end

local function drawCanvas(c, W, H)
  local top = 3
  local bottom = H - 2
  ui.drawAppBar(c.name or "Drawing", true)
  ui.txt(math.max(2, W - 12), 2, "Clr", ui.T().danger, ui.T().bar)
  ui.txt(math.max(2, W - 6), 2, "Save", colors.lime, ui.T().bar)

  ui.fill(1, top, W, math.max(1, bottom - top + 1), colors.white)
  for pos, col in pairs(c.pixels or {}) do
    local px, py = pos:match("^(%-?%d+),(%-?%d+)$")
    px = tonumber(px)
    py = tonumber(py)
    if px and py and px >= 1 and px <= W and py >= top and py <= bottom then
      ui.fill(px, py, 1, 1, col)
    end
  end

  local sw = math.max(1, math.floor(W / #palette))
  for i, col in ipairs(palette) do
    local x = 1 + (i - 1) * sw
    local w = i == #palette and W - x + 1 or sw
    ui.fill(x, H - 1, w, 1, col)
    if col == c.color then
      local mark = col == colors.black and colors.white or colors.black
      ui.ctr(H - 1, "*", mark, col, w, x)
    end
  end
end

local function draw()
  local W, H = term.getSize()
  local c = state.state.appState
  if not c.view then c.view = "gallery" c.scroll = 0 end
  if not c.color then c.color = colors.black end

  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  if c.view == "draw" then
    drawCanvas(c, W, H)
  else
    drawGallery(c, W, H)
  end
  ui.drawNavBar()
end

local function saveCurrent(c)
  local data = ensurePaint()
  local W = term.getSize()
  ui.fill(1, 3, W, 1, ui.T().card)
  ui.txt(2, 3, "Name:", ui.T().sub, ui.T().card)
  term.setCursorPos(8, 3)
  term.setTextColor(ui.T().text)
  term.setBackgroundColor(ui.T().card)
  local name = read(nil, nil, nil, c.name or newDrawingName())
  if not name or name == "" then name = c.name or newDrawingName() end
  c.name = name

  local pixels = {}
  for k, v in pairs(c.pixels or {}) do pixels[k] = v end
  if c.drawingIdx and data.drawings[c.drawingIdx] then
    data.drawings[c.drawingIdx] = {name=name, pixels=pixels}
  else
    table.insert(data.drawings, {name=name, pixels=pixels})
    c.drawingIdx = #data.drawings
  end
  savePaint()
  ui.showToast("Painting saved")
end

local function paintAt(c, x, y)
  local W, H = term.getSize()
  local top = 3
  local bottom = H - 2
  if x < 1 or x > W or y < top or y > bottom then return end
  c.pixels = c.pixels or {}
  c.pixels[key(x, y)] = c.color or colors.black
end

local function handleGalleryTouch(c, x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then
    state.state.screen = "home"
    return
  end
  if y == 2 and x >= W - 5 then
    createDrawing(c)
    return
  end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
    return
  end
  local idx = y - 2 + (c.scroll or 0)
  if idx >= 1 and idx <= #ensurePaint().drawings then
    openDrawing(c, idx)
  end
end

local function handleCanvasTouch(c, x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then
    c.view = "gallery"
    c.pixels = nil
    c.drawingIdx = nil
    c.name = nil
    return
  end
  if y == 2 and x >= W - 6 then
    saveCurrent(c)
    return
  end
  if y == 2 and x >= W - 12 then
    c.pixels = {}
    ui.showToast("Canvas cleared")
    return
  end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
    return
  end
  if y == H - 1 then
    local sw = math.max(1, math.floor(W / #palette))
    local idx = math.floor((x - 1) / sw) + 1
    if idx < 1 then idx = 1 end
    if idx > #palette then idx = #palette end
    c.color = palette[idx]
    return
  end
  paintAt(c, x, y)
end

local function handleTouch(x, y)
  local c = state.state.appState
  if not c.view then c.view = "gallery" c.scroll = 0 end
  if not c.color then c.color = colors.black end
  if c.view == "draw" then
    handleCanvasTouch(c, x, y)
  else
    handleGalleryTouch(c, x, y)
  end
end

function M.register(app)
  app.registerApp("paint", draw, handleTouch)
end

return M
