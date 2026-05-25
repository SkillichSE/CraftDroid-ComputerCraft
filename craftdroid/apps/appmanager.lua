local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local function listApps()
  local all = {}
  if fs.exists(const.APPS_DIR) then
    for _, f in ipairs(fs.list(const.APPS_DIR)) do
      if f:match("%.app$") then
        local rec = io.loadTable(const.APPS_DIR .. f)
        if rec then table.insert(all, rec) end
      end
    end
  end
  return all
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Apps", true)
  local c = state.state.appState
  if not c.scroll then c.scroll = 0 end
  local all = listApps()
  local maxShow = H - 4
  for i = 1 + c.scroll, math.min(#all, c.scroll + maxShow) do
    local appInfo = all[i]
    local ay = 3 + (i - 1 - c.scroll)
    ui.fill(1, ay, W, 1, ui.T().card)
    local ic = appInfo.icon or "[?]"
    ui.fill(2, ay, 3, 1, appInfo.iconColor or colors.gray)
    ui.txt(2, ay, ic, ui.T().iconFg, appInfo.iconColor or colors.gray)
    ui.txt(6, ay, (appInfo.label or appInfo.id):sub(1, W - 12), ui.T().text, ui.T().card)
    if appInfo.installed then
      ui.fill(W - 6, ay, 7, 1, ui.T().danger)
      ui.txt(W - 6, ay, "Uninstall", colors.white, ui.T().danger)
    else
      ui.fill(W - 8, ay, 9, 1, colors.green)
      ui.txt(W - 8, ay, "Install", colors.white, colors.green)
    end
  end
  ui.drawNavBar()
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then
    state.state.currentApp = "settings"
    state.state.appState = {}
    return
  end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw then
      state.state.appState.scroll = math.max(0, (state.state.appState.scroll or 0) - 1)
    elseif x <= bw * 2 then
      state.state.currentApp = "settings"
      state.state.appState = {}
    else
      state.state.appState.scroll = (state.state.appState.scroll or 0) + 1
    end
    return
  end
  local c = state.state.appState
  if not c.scroll then c.scroll = 0 end
  local all = listApps()
  local idx = (y - 3) + 1 + c.scroll
  if idx >= 1 and idx <= #all then
    local appInfo = all[idx]
    if appInfo.installed and x >= W - 6 then
      ui.showDialog("Uninstall", "Uninstall " .. appInfo.label .. "?", {"Uninstall", "Cancel"}, function(ch)
        if ch == "Uninstall" then
          appInfo.installed = false
          io.saveTable(const.APPS_DIR .. appInfo.id .. ".app", appInfo)
          ui.showToast(appInfo.label .. " uninstalled")
        end
      end)
    elseif not appInfo.installed and x >= W - 8 then
      appInfo.installed = true
      io.saveTable(const.APPS_DIR .. appInfo.id .. ".app", appInfo)
      ui.showToast(appInfo.label .. " installed")
    end
  end
end

function M.register(app)
  app.registerApp("appmanager", draw, handleTouch)
end

return M
