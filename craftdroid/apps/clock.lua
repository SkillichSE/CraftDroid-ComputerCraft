local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local function getGameTime()
  local t = os.time()
  local hh = math.floor(t) % 24
  local mm = math.floor((t - math.floor(t)) * 60)
  local ss = math.floor(os.clock() * 20) % 60
  return hh, mm, ss
end

local function getDaypart(hh)
  if hh >= 5 and hh < 12 then return "Morning" end
  if hh >= 12 and hh < 17 then return "Afternoon" end
  if hh >= 17 and hh < 21 then return "Evening" end
  return "Night"
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  local c = state.state.appState
  if not c.clockView then c.clockView = "main" end

  if c.clockView == "main" then
    ui.drawAppBar("Clock", true)
    local hh, mm, ss = getGameTime()

    ui.fill(1, 3, W, 4, ui.T().card)
    ui.ctr(4, string.format("%02d:%02d:%02d", hh, mm, ss), ui.T().accent, ui.T().card)
    local ap = hh >= 12 and "PM" or "AM"
    ui.ctr(5, ap .. "  " .. getDaypart(hh), ui.T().sub, ui.T().card)
    ui.ctr(6, "Day " .. os.day(), ui.T().sub, ui.T().card)

    ui.fill(1, 8, W, 1, ui.T().card)
    ui.ctr(8, "Alarms", ui.T().sub, ui.T().card)
    if #state.appData.alarms == 0 then
      ui.txt(2, 9, "No alarms set", ui.T().sub, ui.T().bg)
    else
      for i, al in ipairs(state.appData.alarms) do
        local ay = 8 + i
        if ay <= H - 2 then
          ui.fill(1, ay, W, 1, ui.T().card)
          local h12 = al.hh % 12
          if h12 == 0 then h12 = 12 end
          local alAP = al.hh >= 12 and "PM" or "AM"
          local label = string.format("%02d:%02d %s  %s", h12, al.mm, alAP, al.enabled and "[ON]" or "[OFF]")
          if al.label and al.label ~= "" then
            label = label .. "  " .. al.label:sub(1, W - #label - 4)
          end
          ui.txt(2, ay, label, al.enabled and ui.T().accent or ui.T().sub, ui.T().card)
          ui.txt(W - 1, ay, "X", ui.T().danger, ui.T().card)
        end
      end
    end
    ui.fill(1, H - 1, W, 1, ui.T().accent)
    ui.ctr(H - 1, "+ Add alarm", colors.black, ui.T().accent)

  elseif c.clockView == "add" then
    ui.drawAppBar("New Alarm", true)
    local ah = c.newHH or 0
    local am = c.newMM or 0
    local h12 = ah % 12
    if h12 == 0 then h12 = 12 end
    local ap = ah >= 12 and "PM" or "AM"

    ui.fill(1, 4, W, 1, ui.T().card)
    ui.ctr(4, "Hour", ui.T().sub, ui.T().card)
    ui.btn(1, 5, math.floor(W / 2), "-", ui.T().text, ui.T().card)
    ui.btn(math.floor(W / 2) + 1, 5, W - math.floor(W / 2), "+", ui.T().accent, ui.T().card)
    ui.fill(1, 6, W, 1, ui.T().bg)
    ui.ctr(6, string.format("%02d (%d %s)", ah, h12, ap), ui.T().accent, ui.T().bg)

    ui.fill(1, 8, W, 1, ui.T().card)
    ui.ctr(8, "Minute", ui.T().sub, ui.T().card)
    ui.btn(1, 9, math.floor(W / 2), "-", ui.T().text, ui.T().card)
    ui.btn(math.floor(W / 2) + 1, 9, W - math.floor(W / 2), "+", ui.T().accent, ui.T().card)
    ui.fill(1, 10, W, 1, ui.T().bg)
    ui.ctr(10, string.format("%02d", am), ui.T().accent, ui.T().bg)

    ui.txt(2, 12, "Label (optional):", ui.T().sub, ui.T().bg)
    ui.fill(1, 13, W, 1, ui.T().card)
    ui.txt(2, 13, (c.newLabel or ""):sub(1, W - 3) .. "_", ui.T().text, ui.T().card)

    ui.fill(1, H - 1, W, 1, colors.green)
    ui.ctr(H - 1, "Set alarm  " .. string.format("%02d:%02d %s", h12, am, ap), colors.white, colors.green)
  end
  ui.drawNavBar()
end

local function checkAlarms()
  local hh, mm = getGameTime()
  for _, al in ipairs(state.appData.alarms) do
    if al.enabled and al.hh == hh and al.mm == mm and not al.fired then
      al.fired = true
      local label = (al.label and al.label ~= "") and (" - " .. al.label) or ""
      ui.showToast("ALARM " .. string.format("%02d:%02d", al.hh, al.mm) .. label)
    end
    if al.fired and not (al.hh == hh and al.mm == mm) then
      al.fired = false
    end
  end
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  local c = state.state.appState
  if not c.clockView then c.clockView = "main" end

  if y == 2 and x <= 3 then
    if c.clockView == "add" then c.clockView = "main" else state.state.screen = "home" end
    return
  end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then
      if c.clockView == "add" then c.clockView = "main" else state.state.screen = "home" end
    end
    return
  end

  if c.clockView == "main" then
    if y == H - 1 then
      c.clockView = "add"
      c.newHH = 0
      c.newMM = 0
      c.newLabel = ""
      return
    end
    for i, al in ipairs(state.appData.alarms) do
      local ay = 8 + i
      if y == ay then
        if x >= W - 1 then
          table.remove(state.appData.alarms, i)
          io.saveTable(const.DATA_DIR .. "alarms.dat", state.appData.alarms)
          ui.showToast("Alarm removed")
        else
          al.enabled = not al.enabled
          io.saveTable(const.DATA_DIR .. "alarms.dat", state.appData.alarms)
          ui.showToast("Alarm " .. (al.enabled and "enabled" or "disabled"))
        end
        return
      end
    end

  elseif c.clockView == "add" then
    if y == 5 then
      if x <= math.floor(W / 2) then
        c.newHH = (c.newHH - 1 + 24) % 24
      else
        c.newHH = (c.newHH + 1) % 24
      end
    elseif y == 9 then
      if x <= math.floor(W / 2) then
        c.newMM = (c.newMM - 1 + 60) % 60
      else
        c.newMM = (c.newMM + 1) % 60
      end
    elseif y == 13 then
      term.setCursorPos(2, 13)
      term.setTextColor(ui.T().text)
      term.setBackgroundColor(ui.T().card)
      local input = read(nil, nil, nil, c.newLabel or "")
      c.newLabel = input or ""
    elseif y == H - 1 then
      table.insert(state.appData.alarms, {
        hh = c.newHH,
        mm = c.newMM,
        label = c.newLabel or "",
        enabled = true,
        fired = false
      })
      io.saveTable(const.DATA_DIR .. "alarms.dat", state.appData.alarms)
      local h12 = c.newHH % 12
      if h12 == 0 then h12 = 12 end
      local ap = c.newHH >= 12 and "PM" or "AM"
      ui.showToast(string.format("Alarm set: %02d:%02d %s", h12, c.newMM, ap))
      c.clockView = "main"
    end
  end
end

function M.register(app)
  app.registerApp("clock", draw, handleTouch)
end

M.checkAlarms = checkAlarms

return M
