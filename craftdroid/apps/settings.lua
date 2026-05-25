local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local function defaultSys()
  return {
    theme    = "dark",
    lockCode = "",
    clock24  = true,
    wifiOn   = true,
    osName   = "CraftDroid",
  }
end

local function defaultAppData()
  return {
    notes    = {},
    contacts = {},
    music    = {track=1, playing=false, tracks={"Sweden","Wet Hands","Mice on Venus","Minecraft","Clark","Subwoofer Lullaby","Living Mice","Haggstrom","Oxygene","Dreiton","Taswell"}},
    calc     = {input="", result="", history={}},
    browser  = {url="", history={}},
    alarms   = {},
    paint    = {drawings={}},
  }
end

local function clearDir(path)
  if fs.exists(path) then fs.delete(path) end
  fs.makeDir(path)
end

local function factoryReset()
  if fs.exists(const.CONFIG_FILE) then fs.delete(const.CONFIG_FILE) end
  clearDir(const.DATA_DIR)
  clearDir(const.PICTURES_DIR)
  if fs.exists(const.APPS_DIR) then
    for _, name in ipairs(fs.list(const.APPS_DIR)) do
      if name:match("%.app$") then fs.delete(const.APPS_DIR .. name) end
    end
  end

  for k in pairs(state.sys) do state.sys[k] = nil end
  for k, v in pairs(defaultSys()) do state.sys[k] = v end

  for k in pairs(state.appData) do state.appData[k] = nil end
  for k, v in pairs(defaultAppData()) do state.appData[k] = v end

  state.state.lockInput = ""
  state.state.lockError = false
  state.state.contextApp = nil
  state.state.appStates = {}
  state.state.runningApps = {}
  state.state.currentApp = nil
  state.state.appState = {}
  state.state.scrollY = 0
  state.state.tasksScroll = 0
  state.state.musicPlaying = false
  state.state.musicTrack = 1
  state.state.screen = "home"

  require("craftdroid.apps").installBuiltins()
  require("craftdroid.apps").loadApps()
  io.saveTable(const.CONFIG_FILE, state.sys)
  ui.showToast("Factory reset done")
end

local items = {
  {label = "Theme",       val = function() return state.sys.theme end,              id = "theme",  icon = "Th", iconCol = colors.purple},
  {label = "WiFi",        val = function() return state.sys.wifiOn and "On" or "Off" end, id = "wifi", icon = "Wi", iconCol = colors.blue},
  {label = "Time format", val = function() return state.sys.clock24 and "24h" or "12h" end, id = "clock", icon = "Tm", iconCol = colors.cyan},
  {label = "Change PIN",  val = function() return state.sys.lockCode == "" and "Off" or "On" end, id = "pin",    icon = "Pi", iconCol = colors.orange},
  {label = "Manage apps", val = function() return "" end,                           id = "apps",   icon = "Ap", iconCol = colors.green},
  {label = "Display",     val = function() return "" end,                           id = "display",icon = "Ds", iconCol = colors.yellow},
  {label = "Sound",       val = function() return state.state.musicPlaying and "On" or "Off" end, id = "sound", icon = "So", iconCol = colors.red},
  {label = "Factory reset",val = function() return "" end,                           id = "reset",  icon = "Rs", iconCol = colors.red},
  {label = "About",       val = function() return "" end,                           id = "about",  icon = "?", iconCol = colors.lightGray},
}

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Settings", true)

  for i, item in ipairs(items) do
    local ay = 2 + i
    if ay <= H - 1 then
      ui.fill(1, ay, W, 1, ui.T().card)
      ui.fill(2, ay, 2, 1, item.iconCol)
      ui.txt(2, ay, item.icon, colors.white, item.iconCol)
      ui.txt(5, ay, item.label, ui.T().text, ui.T().card)
      local val = item.val()
      if val ~= "" then
        local vx = W - #val - 2
        ui.txt(vx, ay, val, ui.T().accent, ui.T().card)
      end
      ui.txt(W, ay, ">", ui.T().sub, ui.T().card)
    end
  end

  ui.drawNavBar()
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then state.state.screen = "home" return end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
    return
  end
  local idx = y - 2
  if idx >= 1 and idx <= #items then
    local id = items[idx].id
    if id == "wifi" then
      state.sys.wifiOn = not state.sys.wifiOn
      io.saveTable(const.CONFIG_FILE, state.sys)
      ui.showToast("WiFi " .. (state.sys.wifiOn and "on" or "off"))
    elseif id == "clock" then
      state.sys.clock24 = not state.sys.clock24
      io.saveTable(const.CONFIG_FILE, state.sys)
      ui.showToast("Format " .. (state.sys.clock24 and "24h" or "12h"))
    elseif id == "theme" then
      local list = {"dark", "light", "amoled"}
      local cur = 1
      for i, t in ipairs(list) do if t == state.sys.theme then cur = i end end
      state.sys.theme = list[cur % #list + 1]
      ui.showToast("Theme: " .. state.sys.theme)
      io.saveTable(const.CONFIG_FILE, state.sys)
    elseif id == "about" then
      ui.showDialog("About", {"CraftDroid OS v2.0", "ComputerCraft 1.21"}, {"OK"}, function() end)
    elseif id == "apps" then
      require("craftdroid.apps").openApp("appmanager")
    elseif id == "display" then
      ui.showDialog("Display", "Brightness auto", {"OK"}, function() end)
    elseif id == "sound" then
      state.state.musicPlaying = not state.state.musicPlaying
      ui.showToast("Sound " .. (state.state.musicPlaying and "on" or "off"))
    elseif id == "reset" then
      ui.showDialog("Factory reset", {"Clear settings, notes,", "contacts and pictures?"}, {"Reset", "Cancel"}, function(ch)
        if ch == "Reset" then factoryReset() end
      end)
    elseif id == "pin" then
      if state.sys.lockCode ~= "" then
        ui.fill(1, H - 2, W, 1, ui.T().card)
        ui.txt(2, H - 2, "Current PIN:", ui.T().sub, ui.T().card)
        term.setCursorPos(14, H - 2)
        term.setTextColor(ui.T().text)
        term.setBackgroundColor(ui.T().card)
        local cur = read("*")
        if cur ~= state.sys.lockCode then
          ui.showToast("Wrong PIN")
          return
        end
      end
      ui.fill(1, H - 2, W, 1, ui.T().card)
      ui.txt(2, H - 2, "New PIN empty=off:", ui.T().sub, ui.T().card)
      term.setCursorPos(20, H - 2)
      term.setTextColor(ui.T().text)
      term.setBackgroundColor(ui.T().card)
      local p1 = read("*") or ""
      ui.fill(1, H - 2, W, 1, ui.T().card)
      ui.txt(2, H - 2, "Repeat PIN:", ui.T().sub, ui.T().card)
      term.setCursorPos(13, H - 2)
      local p2 = read("*") or ""
      if p1 == p2 and (p1 == "" or (p1:match("^%d+$") and #p1 >= 4)) then
        state.sys.lockCode = p1
        io.saveTable(const.CONFIG_FILE, state.sys)
        ui.showToast(p1 == "" and "PIN disabled" or "PIN changed")
      else
        ui.showToast("PIN mismatch")
      end
    end
  end
end

function M.register(app)
  app.registerApp("settings", draw, handleTouch)
end

return M
