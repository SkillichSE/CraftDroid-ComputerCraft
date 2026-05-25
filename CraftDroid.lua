local const = require("craftdroid.constants")
local io = require("craftdroid.io")
local state = require("craftdroid.state")
local ui = require("craftdroid.ui")
local app = require("craftdroid.apps")
local lock = require("craftdroid.lock")

local modules = {
  require("craftdroid.apps.calculator"),
  require("craftdroid.apps.notepad"),
  require("craftdroid.apps.fileman"),
  require("craftdroid.apps.contacts"),
  require("craftdroid.apps.music"),
  require("craftdroid.apps.browser"),
  require("craftdroid.apps.weather"),
  require("craftdroid.apps.clock"),
  require("craftdroid.apps.paint"),
  require("craftdroid.apps.settings"),
  require("craftdroid.apps.appmanager"),
}

for _, mod in ipairs(modules) do
  if mod.register then mod.register(app) end
end

io.ensureDirs()
app.installBuiltins()
state.loadSavedData()
app.loadApps()

term.clear()
term.setCursorPos(1,1)
state.state.screen = "boot"

local bootTimer = os.startTimer(2)
local tickTimer = os.startTimer(0.05)

local function drawScreen()
  local W, H = term.getSize()
  term.clear()
  if state.state.screen == "boot" then
    ui.fill(1, 1, W, H, colors.black)
    ui.ctr(math.floor(H / 2) - 1, "CraftDroid", colors.cyan, colors.black)
    ui.ctr(math.floor(H / 2), "OS v2.0", colors.gray, colors.black)
    local bar = math.min(W - 4, math.floor((os.clock() % 2) * ((W - 4) / 2) * 2))
    ui.fill(3, math.floor(H / 2) + 2, W - 4, 1, colors.gray)
    if bar > 0 then ui.fill(3, math.floor(H / 2) + 2, bar, 1, colors.cyan) end
  elseif state.state.screen == "lock" then
    lock.draw()
  elseif state.state.screen == "home" then
    app.drawHome()
  elseif state.state.screen == "tasks" then
    app.drawTasks()
  elseif state.state.screen == "app" then
    app.drawApp()
  end
end

drawScreen()

while true do

  local ev = {os.pullEvent()}
  if ev[1] == "timer" then
    if ev[2] == bootTimer and state.state.screen == "boot" then
      state.state.screen = (state.sys.lockCode == "" and "home" or "lock")
    end
    if ev[2] == tickTimer then
      if state.state.toast and state.state.toastUntil and os.clock() >= state.state.toastUntil then
        state.state.toast = nil
        state.state.toastTimer = 0
      elseif state.state.toastTimer > 0 then
        state.state.toastTimer = state.state.toastTimer - 1
        if state.state.toastTimer == 0 then state.state.toast = nil end
      end
      for _, mod in ipairs(modules) do
        if mod.checkAlarms then mod.checkAlarms() end
      end
      tickTimer = os.startTimer(0.05)
    end
  elseif ev[1] == "mouse_click" or ev[1] == "mouse_drag" or ev[1] == "monitor_touch" then
    local x = ev[3] or ev[4]
    local y = ev[4] or ev[5]
    if x and y then
      if state.state.screen == "lock" then
        lock.handleTouch(x, y)
      elseif state.state.screen == "tasks" then
        if not app.handleNavTouch(x, y) then app.handleTasksTouch(x, y) end
      elseif state.state.screen == "home" then
        if not app.handleNavTouch(x, y) then app.handleHomeTouch(x, y) end
      elseif state.state.screen == "app" then
        if not app.handleNavTouch(x, y) then app.handleAppTouch(x, y) end
      end
    end
  elseif ev[1] == "touch" then
    if ev[2] and ev[3] then
      if state.state.screen == "lock" then
        lock.handleTouch(ev[2], ev[3])
      elseif state.state.screen == "tasks" then
        if not app.handleNavTouch(ev[2], ev[3]) then app.handleTasksTouch(ev[2], ev[3]) end
      elseif state.state.screen == "home" then
        if not app.handleNavTouch(ev[2], ev[3]) then app.handleHomeTouch(ev[2], ev[3]) end
      elseif state.state.screen == "app" then
        if not app.handleNavTouch(ev[2], ev[3]) then app.handleAppTouch(ev[2], ev[3]) end
      end
    end
  elseif ev[1] == "mouse_scroll" then
    if state.state.screen == "tasks" then
      state.state.tasksScroll = math.max(0, (state.state.tasksScroll or 0) + ev[2])
    elseif state.state.screen == "home" then
      app.handleHomeScroll(ev[2])
    elseif state.state.screen == "app" then
      if state.state.currentApp == "fileman" or state.state.currentApp == "appmanager" then
        if state.state.currentApp == "fileman" and state.state.appState.mode == "edit" then
          state.state.appState.editScroll = math.max(0, (state.state.appState.editScroll or 0) + ev[2])
        else
          state.state.appState.scroll = math.max(0, (state.state.appState.scroll or 0) + ev[2])
        end
      elseif state.state.currentApp == "notepad" then
        if state.state.appState.view == "edit" then
          state.state.appState.editScroll = math.max(0, (state.state.appState.editScroll or 0) + ev[2])
        elseif state.state.appState.view == "detail" then
          state.state.appState.detailScroll = math.max(0, (state.state.appState.detailScroll or 0) + ev[2])
        else
          state.state.appState.scroll = math.max(0, (state.state.appState.scroll or 0) + ev[2])
        end
      elseif state.state.currentApp == "paint" then
        if state.state.appState.view ~= "draw" then
          state.state.appState.scroll = math.max(0, (state.state.appState.scroll or 0) + ev[2])
        end
      end
    end
  elseif ev[1] == "key" then
    if state.state.screen == "lock" then
      lock.handleInput(ev)
    elseif state.state.screen == "app" and not state.state.dialog then
      app.handleAppInput(ev)
    end
    if ev[2] == keys.q and ev[3] then
      io.saveTable(const.CONFIG_FILE, state.sys)
      term.clear()
      term.setCursorPos(1,1)
      print("CraftDroid stopped.")
      break
    end
  elseif ev[1] == "char" or ev[1] == "paste" then
    if state.state.screen == "lock" then
      lock.handleInput(ev)
    elseif state.state.screen == "app" and not state.state.dialog then
      app.handleAppInput(ev)
    end
  end
  drawScreen()
end
