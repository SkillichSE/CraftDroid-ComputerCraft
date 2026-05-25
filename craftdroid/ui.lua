local state = require("craftdroid.state")
local const = require("craftdroid.constants")

local M = {}

local function T() return state.T() end

local function fill(x, y, w, h, col)
  if w <= 0 or h <= 0 then return end
  paintutils.drawFilledBox(x, y, x + w - 1, y + h - 1, col)
end

local function txt(x, y, s, fg, bg)
  local W, H = term.getSize()
  if y < 1 or y > H or x < 1 then return end
  term.setCursorPos(x, y)
  term.setTextColor(fg or T().text)
  term.setBackgroundColor(bg or T().bg)
  local maxW = W - x + 1
  if maxW <= 0 then return end
  term.write(tostring(s):sub(1, maxW))
end

local function ctr(y, s, fg, bg, w, ox)
  local W = term.getSize()
  ox = ox or 1
  w = w or W
  local ss = tostring(s)
  local x = ox + math.max(0, math.floor((w - #ss) / 2))
  txt(x, y, ss, fg, bg)
end

local function btn(x, y, w, label, fg, bg)
  fill(x, y, w, 1, bg or T().card)
  local lx = x + math.max(0, math.floor((w - #tostring(label)) / 2))
  txt(lx, y, label, fg or T().text, bg or T().card)
end

local function hline(y, col)
  local W = term.getSize()
  fill(1, y, W, 1, col or T().sep)
end

function M.getTime()
  local h = os.time()
  local hh = math.floor(h) % 24
  local mm = math.floor((h - math.floor(h)) * 60)
  if state.sys.clock24 then
    return string.format("%02d:%02d", hh, mm)
  else
    local ap = hh >= 12 and "PM" or "AM"
    local h12 = hh % 12
    if h12 == 0 then h12 = 12 end
    return string.format("%d:%02d %s", h12, mm, ap)
  end
end

function M.drawStatusBar()
  local W, H = term.getSize()
  fill(1, 1, W, 1, T().bar)
  local ts = M.getTime()
  local status = {}
  if state.sys.wifiOn then table.insert(status, "Net") end
  if state.state.musicPlaying then table.insert(status, "Sound") end
  local left = table.concat(status, "  ")
  if left ~= "" then txt(2, 1, left, T().barTxt, T().bar) end
  local right = ts .. " "
  txt(W - #right + 1, 1, right, T().barTxt, T().bar)
end

function M.drawNavBar()
  local W, H = term.getSize()
  fill(1, H, W, 1, T().bar)
  local bw = math.floor(W / 3)
  local bw2 = math.floor(W / 3)
  local bw3 = W - bw - bw2
  ctr(H, "<", T().text, T().bar, bw, 1)
  ctr(H, "o", T().accent, T().bar, bw2, 1 + bw)
  ctr(H, "[]", T().text, T().bar, bw3, 1 + bw + bw2)
end

function M.drawAppBar(title, back)
  local W = term.getSize()
  fill(1, 2, W, 1, T().bar)
  if back then
    txt(2, 2, "<", T().accent, T().bar)
    txt(4, 2, title, T().barTxt, T().bar)
  else
    txt(2, 2, title, T().barTxt, T().bar)
  end
end

function M.showToast(msg, dur)
  local seconds = dur or 2.5
  if dur and dur > 10 then seconds = dur * 0.05 end
  state.state.toast = msg
  state.state.toastTimer = math.max(1, math.floor(seconds / 0.05))
  state.state.toastUntil = os.clock() + seconds
end

function M.showDialog(title, msg, buttons, cb)
  state.state.dialog = {title = title, msg = msg, buttons = buttons, cb = cb}
end

local function dialogLines(msg, width)
  local lines = {}
  local function addWrapped(text)
    text = tostring(text or "")
    if width <= 1 then table.insert(lines, text:sub(1, 1)) return end
    while #text > width do
      local cut = width
      local space = nil
      for i = width, 1, -1 do
        if text:sub(i, i) == " " then space = i break end
      end
      if space and space > 1 then
        cut = space - 1
        table.insert(lines, text:sub(1, cut))
        text = text:sub(space + 1)
      else
        table.insert(lines, text:sub(1, width))
        text = text:sub(width + 1)
      end
    end
    table.insert(lines, text)
  end

  if type(msg) == "table" then
    for _, line in ipairs(msg) do addWrapped(line) end
  else
    local text = tostring(msg or "")
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      addWrapped(line)
    end
  end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

function M.drawToast()
  local W, H = term.getSize()
  if state.state.toast and state.state.toastUntil and os.clock() >= state.state.toastUntil then
    state.state.toast = nil
    state.state.toastTimer = 0
  end
  if state.state.toast and state.state.toastTimer > 0 then
    local msg = state.state.toast
    local tw = math.min(#msg + 4, W - 2)
    local tx = math.floor((W - tw) / 2) + 1
    fill(tx, H - 2, tw, 1, colors.gray)
    txt(tx + 1, H - 2, " " .. msg:sub(1, tw - 4) .. " ", colors.white, colors.gray)
  end
end

function M.drawDialog()
  local W, H = term.getSize()
  if not state.state.dialog then return end
  local d = state.state.dialog
  local dw = math.floor(W * 0.9)
  dw = math.max(12, math.min(W - 2, dw))
  local lines = dialogLines(d.msg, dw - 4)
  local dh = math.min(H - 2, #lines + 5)
  local dx = math.floor((W - dw) / 2) + 1
  local dy = math.floor((H - dh) / 2)
  fill(dx, dy, dw, dh, T().card)
  paintutils.drawBox(dx, dy, dx + dw - 1, dy + dh - 1, T().accent)
  ctr(dy + 1, d.title, T().accent, T().card, dw, dx)
  for i = 1, math.min(#lines, dh - 5) do
    ctr(dy + 1 + i, lines[i], T().text, T().card, dw, dx)
  end
  local nbtn = #d.buttons
  local bw = math.floor(dw / nbtn)
  for i, b in ipairs(d.buttons) do
    local bx = dx + (i - 1) * bw
    local fc = (b == "Uninstall" or b == "Yes") and T().danger or T().accent
    btn(bx, dy + dh - 1, bw, b, fc, T().bar)
  end
end

function M.handleDialogTouch(x, y)
  local W, H = term.getSize()
  if not state.state.dialog then return false end
  local d = state.state.dialog
  local dw = math.floor(W * 0.9)
  dw = math.max(12, math.min(W - 2, dw))
  local lines = dialogLines(d.msg, dw - 4)
  local dh = math.min(H - 2, #lines + 5)
  local dx = math.floor((W - dw) / 2) + 1
  local dy = math.floor((H - dh) / 2)
  if y == dy + dh - 1 then
    local nbtn = #d.buttons
    local bw = math.floor(dw / nbtn)
    for i, b in ipairs(d.buttons) do
      local bx = dx + (i - 1) * bw
      if x >= bx and x < bx + bw then
        state.state.dialog = nil
        if d.cb then d.cb(b) end
        return true
      end
    end
  end
  if x >= dx and x < dx + dw and y >= dy and y < dy + dh then return true end
  return false
end

M.fill = fill
M.txt = txt
M.ctr = ctr
M.btn = btn
M.hline = hline
M.T = T

return M
