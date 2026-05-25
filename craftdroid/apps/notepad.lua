local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local function saveNotes()
  io.saveTable(const.DATA_DIR .. "notes.dat", state.appData.notes)
end

local function getTimestamp()
  local h = os.time()
  local hh = math.floor(h) % 24
  local mm = math.floor((h - math.floor(h)) * 60)
  return string.format("Day %d  %02d:%02d", os.day(), hh, mm)
end

local function splitLines(text)
  local lines = {}
  text = text or ""
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

local function joinLines(lines)
  return table.concat(lines or {""}, "\n")
end

local function countWords(text)
  local count = 0
  for _ in (text or ""):gmatch("%S+") do count = count + 1 end
  return count
end

local function wrapText(text, width)
  local lines = {}
  width = math.max(1, width)
  for paragraph in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do
    if #paragraph == 0 then
      table.insert(lines, "")
    else
      local pos = 1
      while pos <= #paragraph do
        table.insert(lines, paragraph:sub(pos, pos + width - 1))
        pos = pos + width
      end
    end
  end
  return lines
end

local function visibleNotes(c)
  local notes = {}
  local q = c.searchQ
  if q then q = q:lower() end
  for i, n in ipairs(state.appData.notes) do
    if not q or q == ""
      or (n.title or ""):lower():find(q, 1, true)
      or (n.body or ""):lower():find(q, 1, true) then
      table.insert(notes, {idx = i, note = n})
    end
  end
  return notes
end

local function startEdit(c, idx, focus)
  local n = state.appData.notes[idx]
  if not n then return end
  c.view = "edit"
  c.editIdx = idx
  c.editTitle = n.title or ""
  c.editLines = splitLines(n.body or "")
  c.editField = focus or "body"
  c.cursorLine = 1
  c.cursorCol = #(c.editLines[1] or "") + 1
  c.titleCol = #c.editTitle + 1
  c.editScroll = 0
end

local function leaveEdit(c)
  c.editTitle = nil
  c.editLines = nil
  c.editField = nil
  c.cursorLine = nil
  c.cursorCol = nil
  c.titleCol = nil
  c.editScroll = nil
end

local function saveEdit(c)
  local n = state.appData.notes[c.editIdx]
  if not n then return end
  local title = c.editTitle or n.title or ""
  if title == "" then title = "Untitled" end
  n.title = title
  n.body = joinLines(c.editLines)
  n.modified = getTimestamp()
  saveNotes()
  leaveEdit(c)
  c.view = "detail"
  ui.showToast("Saved")
end

local function drawList(c, W, H)
  ui.drawAppBar("Notepad", true)
  ui.txt(W - 4, 2, "[+]", ui.T().accent, ui.T().bar)
  local startY = 3
  if c.searchQ and c.searchQ ~= "" then
    ui.fill(1, 3, W, 1, ui.T().card)
    ui.txt(2, 3, "/ " .. c.searchQ, ui.T().text, ui.T().card)
    startY = 4
  end
  local notes = visibleNotes(c)
  if #notes == 0 then
    ui.ctr(math.floor(H / 2), c.searchQ and "No results" or "No notes", ui.T().sub, ui.T().bg)
  else
    for vi, v in ipairs(notes) do
      local ay = startY + (vi - 1) * 2 - (c.scroll or 0)
      if ay >= startY and ay + 1 <= H - 1 then
        local n = v.note
        ui.fill(1, ay, W, 2, ui.T().card)
        ui.txt(2, ay, (n.title or "Untitled"):sub(1, W - 8), ui.T().text, ui.T().card)
        if n.modified then ui.txt(math.max(2, W - #n.modified), ay, n.modified, ui.T().sub, ui.T().card) end
        ui.txt(2, ay + 1, (n.body or ""):gsub("\n", " "):sub(1, W - 4), ui.T().sub, ui.T().card)
        ui.txt(W - 1, ay, ">", ui.T().accent, ui.T().card)
      end
    end
  end
  ui.txt(2, H - 1, #state.appData.notes .. " notes", ui.T().sub, ui.T().bg)
  ui.txt(W - 5, H - 1, "[/]", ui.T().sub, ui.T().bg)
end

local function drawDetail(c, W, H)
  local n = state.appData.notes[c.editIdx]
  if not n then c.view = "list" return end
  ui.drawAppBar(n.title or "Untitled", true)
  ui.txt(W - 5, 2, "[Edit]", ui.T().accent, ui.T().bar)
  ui.fill(1, 3, W, 1, ui.T().bar)
  local body = n.body or ""
  ui.txt(2, 3, countWords(body) .. "w  " .. #body .. "c  " .. (n.modified or ""), ui.T().sub, ui.T().bar)
  local lines = wrapText(body, W - 3)
  local scroll = c.detailScroll or 0
  ui.fill(1, 4, W, H - 5, ui.T().card)
  for i = 1 + scroll, math.min(#lines, H - 6 + scroll) do
    ui.txt(2, 3 + (i - scroll), lines[i]:sub(1, W - 2), ui.T().text, ui.T().card)
  end
  ui.fill(1, H - 1, W, 1, ui.T().danger)
  ui.ctr(H - 1, "Delete note", colors.white, ui.T().danger)
end

local function drawEdit(c, W, H)
  local n = state.appData.notes[c.editIdx]
  if not n then c.view = "list" return end
  ui.drawAppBar("Edit note", true)
  ui.txt(W - 5, 2, "[Save]", colors.lime, ui.T().bar)
  ui.txt(2, 3, "Title", ui.T().sub, ui.T().bg)
  ui.fill(1, 4, W, 1, ui.T().card)
  local title = c.editTitle or ""
  if c.editField == "title" then
    local col = math.max(1, math.min((c.titleCol or #title + 1), #title + 1))
    title = title:sub(1, col - 1) .. "|" .. title:sub(col)
  end
  ui.txt(2, 4, title:sub(1, W - 2), ui.T().text, ui.T().card)
  ui.txt(2, 6, "Body", ui.T().sub, ui.T().bg)
  local lines = c.editLines or {""}
  local top = 7
  local bottom = H - 2
  local maxRows = math.max(1, bottom - top + 1)
  c.editScroll = math.max(0, math.min(c.editScroll or 0, math.max(0, #lines - maxRows)))
  ui.fill(1, top, W, maxRows, ui.T().card)
  for i = 1 + c.editScroll, math.min(#lines, c.editScroll + maxRows) do
    local ay = top + i - 1 - c.editScroll
    local line = lines[i] or ""
    if c.editField == "body" and i == c.cursorLine then
      local col = math.max(1, math.min(c.cursorCol or 1, #line + 1))
      line = line:sub(1, col - 1) .. "|" .. line:sub(col)
    end
    ui.txt(2, ay, line:sub(1, W - 2), ui.T().text, ui.T().card)
  end
  local text = joinLines(lines)
  ui.fill(1, H - 1, W, 1, ui.T().accent)
  ui.ctr(H - 1, c.editField == "title" and "Title" or (countWords(text) .. "w  " .. #text .. "c"), colors.black, ui.T().accent)
end

local function drawSearch(c, W, H)
  ui.drawAppBar("Search", true)
  ui.fill(1, 4, W, 1, ui.T().card)
  ui.txt(2, 4, "/" .. (c.searchDraft or "") .. "|", ui.T().text, ui.T().card)
  ui.ctr(H - 1, "Enter to apply", ui.T().sub, ui.T().bg)
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  local c = state.state.appState
  if not c.view then c.view = "list" c.scroll = 0 end
  if c.view == "list" then drawList(c, W, H)
  elseif c.view == "detail" then drawDetail(c, W, H)
  elseif c.view == "edit" then drawEdit(c, W, H)
  elseif c.view == "search" then drawSearch(c, W, H) end
  ui.drawNavBar()
end

local function handleBack(c)
  if c.view == "edit" then
    leaveEdit(c)
    c.view = "detail"
  elseif c.view == "detail" then
    c.detailScroll = 0
    c.view = "list"
  elseif c.view == "search" then
    c.searchDraft = nil
    c.view = "list"
  else
    state.state.screen = "home"
  end
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  local c = state.state.appState
  if not c.view then c.view = "list" c.scroll = 0 end

  if (y == 2 and x <= 3) or (y == H and x <= math.floor(W / 3) * 2) then
    handleBack(c)
    return
  end

  if c.view == "list" then
    if y == 2 and x >= W - 5 then
      local ts = getTimestamp()
      table.insert(state.appData.notes, {title = "Note #" .. (#state.appData.notes + 1), body = "", created = ts, modified = ts})
      saveNotes()
      startEdit(c, #state.appData.notes, "body")
      return
    end
    if y == H - 1 and x >= W - 6 then
      c.searchDraft = c.searchQ or ""
      c.view = "search"
      return
    end
    local startY = (c.searchQ and c.searchQ ~= "") and 4 or 3
    local idx = math.floor((y - startY) / 2) + 1 + math.floor((c.scroll or 0) / 2)
    local notes = visibleNotes(c)
    if idx >= 1 and idx <= #notes then
      c.view = "detail"
      c.editIdx = notes[idx].idx
      c.detailScroll = 0
    end
  elseif c.view == "detail" then
    local n = state.appData.notes[c.editIdx]
    if not n then c.view = "list" return end
    if y == 2 and x >= W - 6 then
      startEdit(c, c.editIdx, "body")
    elseif y == H - 1 then
      ui.showDialog("Delete", "Delete \"" .. (n.title or "Untitled"):sub(1, 15) .. "\"?", {"Yes", "Cancel"}, function(ch)
        if ch == "Yes" then
          table.remove(state.appData.notes, c.editIdx)
          saveNotes()
          c.editIdx = nil
          c.detailScroll = 0
          c.view = "list"
          ui.showToast("Note deleted")
        end
      end)
    elseif y >= 4 and y <= H - 2 then
      local mid = math.floor((H - 4) / 2) + 4
      if y > mid then c.detailScroll = (c.detailScroll or 0) + 3 else c.detailScroll = math.max(0, (c.detailScroll or 0) - 3) end
    end
  elseif c.view == "edit" then
    if y == 2 and x >= W - 6 then
      saveEdit(c)
    elseif y == 4 then
      c.editField = "title"
      c.titleCol = math.max(1, math.min(x - 1, #(c.editTitle or "") + 1))
    elseif y >= 7 and y <= H - 2 then
      local line = y - 7 + 1 + (c.editScroll or 0)
      if line >= 1 and line <= #(c.editLines or {}) then
        c.editField = "body"
        c.cursorLine = line
        c.cursorCol = math.max(1, math.min(x - 1, #(c.editLines[line] or "") + 1))
      end
    end
  end
end

local function clampCursor(c)
  if c.editField == "title" then
    c.titleCol = math.max(1, math.min(c.titleCol or 1, #(c.editTitle or "") + 1))
    return
  end
  local lines = c.editLines or {""}
  c.cursorLine = math.max(1, math.min(c.cursorLine or 1, #lines))
  c.cursorCol = math.max(1, math.min(c.cursorCol or 1, #(lines[c.cursorLine] or "") + 1))
end

local function insertBody(c, text)
  local lines = c.editLines or {""}
  local line = lines[c.cursorLine] or ""
  local before = line:sub(1, c.cursorCol - 1)
  local after = line:sub(c.cursorCol)
  local parts = splitLines(text)
  if #parts == 1 then
    lines[c.cursorLine] = before .. parts[1] .. after
    c.cursorCol = c.cursorCol + #parts[1]
  else
    lines[c.cursorLine] = before .. parts[1]
    for i = 2, #parts do
      table.insert(lines, c.cursorLine + i - 1, parts[i])
    end
    c.cursorLine = c.cursorLine + #parts - 1
    c.cursorCol = #(parts[#parts] or "") + 1
    lines[c.cursorLine] = lines[c.cursorLine] .. after
  end
end

local function handleChar(c, text)
  if c.view == "search" then
    c.searchDraft = (c.searchDraft or "") .. text
  elseif c.view == "edit" then
    clampCursor(c)
    if c.editField == "title" then
      text = text:gsub("[\r\n]", " ")
      local title = c.editTitle or ""
      c.editTitle = title:sub(1, c.titleCol - 1) .. text .. title:sub(c.titleCol)
      c.titleCol = c.titleCol + #text
    else
      insertBody(c, text)
    end
  end
end

local function handleBackspace(c)
  if c.view == "search" then
    c.searchDraft = (c.searchDraft or ""):sub(1, -2)
  elseif c.view == "edit" then
    clampCursor(c)
    if c.editField == "title" then
      local title = c.editTitle or ""
      if c.titleCol > 1 then
        c.editTitle = title:sub(1, c.titleCol - 2) .. title:sub(c.titleCol)
        c.titleCol = c.titleCol - 1
      end
    else
      local lines = c.editLines
      if c.cursorCol > 1 then
        local line = lines[c.cursorLine]
        lines[c.cursorLine] = line:sub(1, c.cursorCol - 2) .. line:sub(c.cursorCol)
        c.cursorCol = c.cursorCol - 1
      elseif c.cursorLine > 1 then
        local prevLen = #lines[c.cursorLine - 1]
        lines[c.cursorLine - 1] = lines[c.cursorLine - 1] .. lines[c.cursorLine]
        table.remove(lines, c.cursorLine)
        c.cursorLine = c.cursorLine - 1
        c.cursorCol = prevLen + 1
      end
    end
  end
end

local function handleKey(ev)
  local c = state.state.appState
  local key = ev[2]
  if key == keys.backspace then handleBackspace(c)
  elseif key == keys.enter then
    if c.view == "search" then
      c.searchQ = c.searchDraft ~= "" and c.searchDraft or nil
      c.searchDraft = nil
      c.scroll = 0
      c.view = "list"
    elseif c.view == "edit" and c.editField == "body" then
      clampCursor(c)
      local lines = c.editLines
      local line = lines[c.cursorLine]
      local after = line:sub(c.cursorCol)
      lines[c.cursorLine] = line:sub(1, c.cursorCol - 1)
      table.insert(lines, c.cursorLine + 1, after)
      c.cursorLine = c.cursorLine + 1
      c.cursorCol = 1
    end
  elseif key == keys.left then
    if c.view == "edit" then
      clampCursor(c)
      if c.editField == "title" then c.titleCol = math.max(1, c.titleCol - 1)
      elseif c.cursorCol > 1 then c.cursorCol = c.cursorCol - 1 end
    end
  elseif key == keys.right then
    if c.view == "edit" then
      clampCursor(c)
      if c.editField == "title" then c.titleCol = math.min(#(c.editTitle or "") + 1, c.titleCol + 1)
      else c.cursorCol = math.min(#(c.editLines[c.cursorLine] or "") + 1, c.cursorCol + 1) end
    end
  elseif key == keys.up then
    if c.view == "edit" and c.editField == "body" then
      c.cursorLine = math.max(1, (c.cursorLine or 1) - 1)
      clampCursor(c)
    elseif c.view == "list" then
      c.scroll = math.max(0, (c.scroll or 0) - 2)
    end
  elseif key == keys.down then
    if c.view == "edit" and c.editField == "body" then
      c.cursorLine = math.min(#(c.editLines or {""}), (c.cursorLine or 1) + 1)
      clampCursor(c)
    elseif c.view == "list" then
      c.scroll = (c.scroll or 0) + 2
    end
  elseif key == keys.tab and c.view == "edit" then
    c.editField = c.editField == "title" and "body" or "title"
  end
  if c.view == "edit" and c.editField == "body" then
    local H = ({term.getSize()})[2]
    local maxRows = math.max(1, H - 8)
    if c.cursorLine <= (c.editScroll or 0) then c.editScroll = c.cursorLine - 1 end
    if c.cursorLine > (c.editScroll or 0) + maxRows then c.editScroll = c.cursorLine - maxRows end
  end
end

local function handleInput(ev)
  if ev[1] == "char" then
    handleChar(state.state.appState, ev[2])
  elseif ev[1] == "paste" then
    handleChar(state.state.appState, ev[2])
  elseif ev[1] == "key" then
    handleKey(ev)
  end
end

function M.register(app)
  app.registerApp("notepad", draw, handleTouch, handleInput)
end

return M
