local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

local function getDate()
  local day = os.day()
  return string.format("Day %d", day)
end

local function submitPin()
  if state.state.lockInput == state.sys.lockCode then
    state.state.screen = "home"
    state.state.lockInput = ""
    state.state.lockError = false
  else
    state.state.lockError = true
    state.state.lockInput = ""
  end
end

local function pressKey(k)
  if state.sys.lockCode == "" then
    state.state.screen = "home"
    return
  end
  if k == "DEL" or k == "<" then
    state.state.lockInput = state.state.lockInput:sub(1, -2)
    state.state.lockError = false
  elseif k == "OK" then
    if #state.state.lockInput > 0 then submitPin() end
  elseif k and k:match("^%d$") then
    if #state.state.lockInput < 4 then
      state.state.lockInput = state.state.lockInput .. k
      state.state.lockError = false
      if #state.state.lockInput == 4 then submitPin() end
    end
  end
end

function M.draw()
  if state.sys.lockCode == "" then
    state.state.screen = "home"
    return
  end
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, colors.black)

  local ts = ui.getTime()
  local timeY = math.floor(H * 0.25)
  ui.fill(1, timeY, W, 1, colors.black)
  ui.ctr(timeY, ts, colors.white, colors.black)

  local dateStr = "Day " .. os.day()
  ui.ctr(timeY + 1, dateStr, colors.lightGray, colors.black)

  local pinY = timeY + 3
  ui.hline(pinY, colors.gray)
  ui.ctr(pinY + 1, "PIN", colors.cyan, colors.black)

  local dots = ""
  for i = 1, 4 do
    dots = dots .. (i <= #state.state.lockInput and "*" or "_") .. " "
  end
  ui.ctr(pinY + 2, dots:sub(1, -2), colors.white, colors.black)

  if state.state.lockError then
    ui.ctr(pinY + 3, "Wrong PIN", colors.red, colors.black)
  end

  local kpad = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"DEL","0","<"}}
  local kw = math.floor(W / 3)
  local kstartY = pinY + 4
  for r, row in ipairs(kpad) do
    for c, k in ipairs(row) do
      local bx = (c - 1) * kw + 1
      local buttonWidth = (c == 3) and (W - bx + 1) or kw
      local by = kstartY + (r - 1)
      local bc = colors.gray
      if k == "DEL" or k == "<" then bc = colors.orange end
      ui.fill(bx, by, buttonWidth, 1, bc)
      ui.ctr(by, k, colors.white, bc, buttonWidth, bx)
    end
  end
end

function M.handleTouch(x, y)
  if state.sys.lockCode == "" then
    state.state.screen = "home"
    return
  end
  local W, H = term.getSize()
  local timeY = math.floor(H * 0.25)
  local pinY = timeY + 3
  local kstartY = pinY + 4

  local kpad = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"DEL","0","<"}}
  local kw = math.floor(W / 3)

  for r, row in ipairs(kpad) do
    if y == kstartY + (r - 1) then
      for c, k in ipairs(row) do
        local bx = (c - 1) * kw + 1
        local buttonWidth = (c == 3) and (W - bx + 1) or kw
        if x >= bx and x < bx + buttonWidth then
          pressKey(k)
        end
      end
    end
  end
end

function M.handleInput(ev)
  if ev[1] == "char" then
    pressKey(ev[2])
  elseif ev[1] == "key" then
    local key = ev[2]
    if key == keys.backspace or key == keys.delete then
      pressKey("DEL")
    elseif key == keys.enter then
      pressKey("OK")
    end
  end
end

return M
