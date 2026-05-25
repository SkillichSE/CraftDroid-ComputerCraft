local const = require("craftdroid.constants")
local io = require("craftdroid.io")

local M = {}

M.sys = {
  theme    = "dark",
  lockCode = "",
  clock24  = true,
  wifiOn   = true,
  osName   = "CraftDroid",
}

M.state = {
  screen      = "boot",
  lockInput   = "",
  lockError   = false,
  currentApp  = nil,
  appState    = {},
  appStates   = {},
  runningApps = {},
  longpress   = nil,
  contextApp  = nil,
  toast       = nil,
  toastTimer  = 0,
  toastUntil  = 0,
  appList     = {},
  scrollY     = 0,
  tasksScroll = 0,
  musicPlaying= false,
  musicTrack  = 1,
  dialog      = nil,
}

M.appData = {
  notes    = {},
  contacts = {},
  music    = {track=1, playing=false, tracks={"Sweden","Wet Hands","Mice on Venus","Minecraft","Clark","Subwoofer Lullaby","Living Mice","Haggstrom","Oxygene","Dreiton","Taswell"}},
  calc     = {input="", result="", history={}},
  browser  = {url="", history={}},
  alarms   = {},
  paint    = {drawings={}},
}

function M.T()
  return require("craftdroid.constants").THEMES[M.sys.theme]
end

function M.loadSavedData()
  local cfg = io.loadTable(const.CONFIG_FILE)
  if cfg then
    for k, v in pairs(cfg) do
      M.sys[k] = v
    end
  end

  local savedNotes = io.loadTable(const.DATA_DIR .. "notes.dat")
  if savedNotes then M.appData.notes = savedNotes end

  local savedAlarms = io.loadTable(const.DATA_DIR .. "alarms.dat")
  if savedAlarms then M.appData.alarms = savedAlarms end

  local savedContacts = io.loadTable(const.DATA_DIR .. "contacts.dat")
  if savedContacts then M.appData.contacts = savedContacts end

  local savedPaint = io.loadTable(const.DATA_DIR .. "paint.dat")
  if savedPaint then M.appData.paint = savedPaint end
end

return M
