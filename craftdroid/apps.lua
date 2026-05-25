local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")
local ui = require("craftdroid.ui")

local M = {}

local appDrawers = {}
local appHandlers = {}
local appKeyHandlers = {}

local function getAppById(id)
  for _, a in ipairs(state.state.appList) do
    if a.id == id then return a end
  end
  return nil
end

local function getVisibleApps()
  local list = {}
  for _, a in ipairs(state.state.appList) do
    if a.installed then table.insert(list, a) end
  end
  return list
end

local function getRunningAppIndex(id)
  for i, appId in ipairs(state.state.runningApps) do
    if appId == id then return i end
  end
  return nil
end

local function rememberCurrentApp()
  if state.state.currentApp then
    state.state.appStates[state.state.currentApp] = state.state.appState
  end
end

local COLS = 3
local CELL_W = 7
local CELL_H = 4
local function getGridParams()
  local W, _ = term.getSize()
  local cols = math.min(COLS, math.floor((W + 1) / (CELL_W + 1)))
  cols = math.max(1, cols)
  local gap = math.max(1, math.floor((W - cols * CELL_W) / (cols + 1)))
  local gridW = cols * CELL_W + (cols - 1) * gap
  local startX = math.max(1, math.floor((W - gridW) / 2) + 1)
  return cols, CELL_W, startX, gap
end

function M.loadApps()
  local apps = {}
  for _, ba in ipairs(const.BUILTIN_APPS) do
    local rec = io.loadTable(const.APPS_DIR .. ba.id .. ".app")
    if rec == nil or rec.installed then
      table.insert(apps, {
        id = ba.id,
        label = ba.label,
        icon = ba.icon,
        iconColor = ba.iconColor,
        builtin = true,
        installed = true,
        desc = ba.desc,
      })
    end
  end
  if fs.exists(const.APPS_DIR) then
    for _, f in ipairs(fs.list(const.APPS_DIR)) do
      if f:match("%.app$") then
        local rec = io.loadTable(const.APPS_DIR .. f)
        if rec and not rec.builtin and rec.installed then
          table.insert(apps, rec)
        end
      end
    end
  end
  state.state.appList = apps
end

function M.saveAppRec(app)
  io.saveTable(const.APPS_DIR .. app.id .. ".app", app)
end

function M.installBuiltins()
  for _, ba in ipairs(const.BUILTIN_APPS) do
    local path = const.APPS_DIR .. ba.id .. ".app"
    if not fs.exists(path) then
      io.saveTable(path, {id=ba.id, label=ba.label, icon=ba.icon, iconColor=ba.iconColor, builtin=true, installed=true, desc=ba.desc})
    end
  end
end

function M.uninstallApp(id)
  local path = const.APPS_DIR .. id .. ".app"
  if fs.exists(path) then
    local rec = io.loadTable(path)
    if rec then
      rec.installed = false
      io.saveTable(path, rec)
    end
  end
  M.loadApps()
end

function M.openApp(id)
  rememberCurrentApp()
  local idx = getRunningAppIndex(id)
  if idx then table.remove(state.state.runningApps, idx) end
  table.insert(state.state.runningApps, 1, id)
  state.state.currentApp = id
  state.state.appState = state.state.appStates[id] or {}
  state.state.appStates[id] = state.state.appState
  state.state.screen = "app"
end

function M.closeApp(id)
  local idx = getRunningAppIndex(id)
  if idx then table.remove(state.state.runningApps, idx) end
  state.state.appStates[id] = nil
  if state.state.currentApp == id then
    state.state.currentApp = nil
    state.state.appState = {}
    state.state.screen = "home"
  end
end

function M.drawHome()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  local apps = getVisibleApps()
  local cols, cellWidth, startX, gap = getGridParams()
  local cellH = CELL_H
  local startY = 3
  local contentH = H - startY - 1
  local maxRows = math.floor(contentH / cellH)
  local totalRows = math.ceil(#apps / cols)
  local maxScroll = math.max(0, (totalRows - maxRows) * cellH)
  state.state.scrollY = math.max(0, math.min(state.state.scrollY, maxScroll))

  for i, appInfo in ipairs(apps) do
    local row = math.floor((i - 1) / cols)
    local col = (i - 1) % cols
    local ax = startX + col * (cellWidth + gap)
    local ay = startY + row * cellH - state.state.scrollY
    if ay + cellH - 1 >= startY and ay <= H - 1 then
      local ic_bg = appInfo.iconColor or colors.gray
      local selected = state.state.contextApp == appInfo.id
      ui.fill(ax, ay, cellWidth, 1, ic_bg)
      local ic = appInfo.icon or "[ ]"
      ui.ctr(ay, ic, ui.T().iconFg, ic_bg, cellWidth, ax)
      ui.fill(ax, ay + 1, cellWidth, 1, selected and ui.T().accent or ui.T().card)
      local lbl = (appInfo.label or appInfo.id):sub(1, cellWidth)
      ui.ctr(ay + 1, lbl, selected and colors.black or ui.T().text, selected and ui.T().accent or ui.T().card, cellWidth, ax)
      ui.fill(ax, ay + 2, cellWidth, cellH - 2, ui.T().bg)
    end
  end

  ui.drawNavBar()
  ui.drawToast()
  if state.state.dialog then ui.drawDialog() end
end

function M.handleHomeTouch(x, y)
  if ui.handleDialogTouch(x, y) then return end
  local W, H = term.getSize()
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw then
      state.state.contextApp = nil
      state.state.scrollY = math.max(0, state.state.scrollY - 3)
    end
    return
  end

  if state.state.contextApp then
    local appInfo = getAppById(state.state.contextApp)
    state.state.contextApp = nil
    if appInfo then
      ui.showDialog(appInfo.label, "Uninstall app?", {"Uninstall", "Cancel"}, function(choice)
        if choice == "Uninstall" then
          M.uninstallApp(appInfo.id)
          ui.showToast(appInfo.label .. " uninstalled")
        end
      end)
    end
    return
  end

  local apps = getVisibleApps()
  local cols, cellWidth, startX, gap = getGridParams()
  local cellH = CELL_H
  local startY = 3

  for i, appInfo in ipairs(apps) do
    local row = math.floor((i - 1) / cols)
    local col = (i - 1) % cols
    local ax = startX + col * (cellWidth + gap)
    local ay = startY + row * cellH - state.state.scrollY
    if x >= ax and x < ax + cellWidth and y >= ay and y < ay + cellH - 1 then
      M.openApp(appInfo.id)
      return
    end
  end
end

function M.drawTasks()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Running", true)
  local list = state.state.runningApps
  local maxRows = math.max(1, H - 3)
  local scroll = math.max(0, math.min(state.state.tasksScroll or 0, math.max(0, #list - maxRows)))
  state.state.tasksScroll = scroll
  if #list == 0 then
    ui.ctr(math.floor(H / 2), "No running apps", ui.T().sub, ui.T().bg)
  else
    for i = 1 + scroll, math.min(#list, scroll + maxRows) do
      local id = list[i]
      local ay = 2 + i - scroll
      if ay <= H - 1 then
        local info = getAppById(id)
        local label = info and info.label or id
        local icon = info and info.icon or "[ ]"
        local col = info and info.iconColor or colors.gray
        ui.fill(1, ay, W, 1, ui.T().card)
        ui.fill(2, ay, 3, 1, col)
        ui.ctr(ay, icon:sub(1, 3), ui.T().iconFg, col, 3, 2)
        ui.txt(6, ay, label:sub(1, W - 11), ui.T().text, ui.T().card)
        ui.txt(W - 1, ay, "X", ui.T().danger, ui.T().card)
      end
    end
  end
  ui.drawNavBar()
  ui.drawToast()
  if state.state.dialog then ui.drawDialog() end
end

function M.handleTasksTouch(x, y)
  if ui.handleDialogTouch(x, y) then return end
  local W, H = term.getSize()
  if y == 2 and x <= 3 then
    state.state.screen = "home"
    return
  end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then
      rememberCurrentApp()
      state.state.screen = "home"
    end
    return
  end
  local idx = y - 2 + (state.state.tasksScroll or 0)
  local id = state.state.runningApps[idx]
  if id then
    if x >= W - 1 then
      M.closeApp(id)
      if state.state.screen ~= "home" then state.state.screen = "tasks" end
    else
      M.openApp(id)
    end
  end
end

function M.handleNavTouch(x, y)
  local W, H = term.getSize()
  if y ~= H then return false end
  local bw = math.floor(W / 3)
  if x > bw and x <= bw * 2 then
    rememberCurrentApp()
    state.state.contextApp = nil
    state.state.dialog = nil
    state.state.screen = "home"
    state.state.scrollY = 0
    return true
  elseif x > bw * 2 then
    rememberCurrentApp()
    state.state.contextApp = nil
    state.state.dialog = nil
    state.state.screen = "tasks"
    return true
  end
  return false
end

function M.handleHomeScroll(dir)
  state.state.scrollY = math.max(0, state.state.scrollY + dir * 3)
end

function M.registerApp(id, drawer, handler, keyHandler)
  appDrawers[id] = drawer
  appHandlers[id] = handler
  appKeyHandlers[id] = keyHandler
end

function M.drawApp()
  local id = state.state.currentApp
  if id and appDrawers[id] then
    appDrawers[id]()
    if state.state.dialog then ui.drawDialog() end
    ui.drawToast()
  else
    local W, H = term.getSize()
    ui.fill(1, 1, W, H, ui.T().bg)
    ui.drawStatusBar()
    ui.drawAppBar("Error", true)
    ui.ctr(H / 2, "App not found", ui.T().danger, ui.T().bg)
    ui.drawNavBar()
  end
end

function M.handleAppTouch(x, y)
  if ui.handleDialogTouch(x, y) then return end
  local id = state.state.currentApp
  if id and appHandlers[id] then
    appHandlers[id](x, y)
  end
end

function M.handleAppInput(ev)
  local id = state.state.currentApp
  if id and appKeyHandlers[id] then
    appKeyHandlers[id](ev)
  end
end

return M
