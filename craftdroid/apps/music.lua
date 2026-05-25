local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

-- Длительности треков (в игровых секундах, примерно)
local durations = {213, 188, 242, 197, 178, 232, 165, 221, 203, 259, 247}

local function getProgress(m)
  if not m.playing or not m.startTime then return 0 end
  local elapsed = math.floor(os.clock() * 20) - (m.startTime or 0)
  local dur = durations[m.track] or 200
  return math.min(1, elapsed / dur)
end

local function getElapsed(m)
  if not m.startTime then return 0, 0 end
  local elapsed = math.floor(os.clock() * 20) - (m.startTime or 0)
  local dur = durations[m.track] or 200
  elapsed = math.min(elapsed, dur)
  return math.floor(elapsed / 60), elapsed % 60
end

local function getDuration(track)
  local d = durations[track] or 200
  return math.floor(d / 60), d % 60
end

-- Визуализатор эквалайзера (псевдослучайный на основе времени)
local function drawEqualizer(y, W, playing)
  if not playing then
    ui.fill(1, y, W, 1, ui.T().card)
    ui.ctr(y, "_ _ _ _ _ _ _ _", ui.T().sub, ui.T().card)
    return
  end
  local t = math.floor(os.clock() * 10)
  local bars = {}
  for i = 1, 8 do
    local h = ((t * i * 3 + i * 7) % 5) + 1
    local chars = {"|", "I", "l", "!", ":"}
    table.insert(bars, chars[h])
  end
  ui.fill(1, y, W, 1, ui.T().card)
  ui.ctr(y, table.concat(bars, " "), ui.T().accent, ui.T().card)
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Music", true)
  local m = state.appData.music
  if not m.startTime then m.startTime = 0 end
  if not m.shuffle then m.shuffle = false end
  local track = m.tracks[m.track] or "N/A"

  -- Обложка / анимация
  drawEqualizer(3, W, m.playing)

  -- Название трека
  ui.fill(1, 4, W, 2, ui.T().card)
  ui.ctr(4, track:sub(1, W - 2), ui.T().text, ui.T().card)
  local trackInfo = string.format("Track %d / %d", m.track, #m.tracks)
  if m.shuffle then trackInfo = trackInfo .. "  [SHUFFLE]" end
  ui.ctr(5, trackInfo, ui.T().sub, ui.T().card)

  -- Прогресс-бар
  local progress = getProgress(m)
  local barW = W - 2
  local filled = math.floor(progress * barW)
  ui.fill(1, 7, W, 1, ui.T().bg)
  ui.fill(2, 7, barW, 1, ui.T().card)
  if filled > 0 then ui.fill(2, 7, filled, 1, ui.T().accent) end
  -- Время
  local em, es = getElapsed(m)
  local dm, ds = getDuration(m.track)
  ui.txt(1, 7, string.format("%d:%02d", em, es), ui.T().sub, ui.T().bg)
  local durStr = string.format("%d:%02d", dm, ds)
  ui.txt(W - #durStr, 7, durStr, ui.T().sub, ui.T().bg)

  -- Кнопки управления
  local bw = math.floor(W / 4)
  ui.fill(1, 9, W, 1, ui.T().bar)
  ui.btn(1,           9, bw,          "|<<",                    ui.T().text,   ui.T().bar)
  ui.btn(1 + bw,      9, bw,          m.playing and "||" or "|>", ui.T().accent, ui.T().bar)
  ui.btn(1 + bw * 2,  9, bw,          ">>|",                    ui.T().text,   ui.T().bar)
  ui.btn(1 + bw * 3,  9, W - bw * 3, m.shuffle and "RND" or "SEQ", m.shuffle and ui.T().accent or ui.T().sub, ui.T().bar)

  -- Плейлист
  ui.txt(2, 11, "Playlist:", ui.T().sub, ui.T().bg)
  local listStart = 12
  local scroll = m.listScroll or 0
  local visible = H - listStart - 1
  for i = 1 + scroll, math.min(#m.tracks, visible + scroll) do
    local t2 = m.tracks[i]
    local ay = listStart + (i - 1 - scroll)
    local active = i == m.track
    local dm2, ds2 = getDuration(i)
    ui.fill(1, ay, W, 1, active and ui.T().accent or ui.T().card)
    local fg = active and colors.black or ui.T().text
    local bg = active and ui.T().accent or ui.T().card
    local prefix = active and (m.playing and "> " or "| ") or "  "
    ui.txt(2, ay, prefix .. t2:sub(1, W - 10), fg, bg)
    local durLabel = string.format("%d:%02d", dm2, ds2)
    ui.txt(W - #durLabel - 1, ay, durLabel, active and colors.black or ui.T().sub, bg)
  end
  ui.drawNavBar()
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then state.state.screen = "home" return end
  if y == H then
    local bw2 = math.floor(W / 3)
    if x <= bw2 * 2 then state.state.screen = "home" end
    return
  end
  local m = state.appData.music
  if not m.startTime then m.startTime = 0 end
  if not m.shuffle then m.shuffle = false end
  if not m.listScroll then m.listScroll = 0 end

  if y == 9 then
    local bw = math.floor(W / 4)
    if x <= bw then
      -- Предыдущий
      m.track = math.max(1, m.track - 1)
      m.startTime = math.floor(os.clock() * 20)
    elseif x <= bw * 2 then
      -- Play/Pause
      m.playing = not m.playing
      state.state.musicPlaying = m.playing
      if m.playing then
        m.startTime = math.floor(os.clock() * 20)
      end
    elseif x <= bw * 3 then
      -- Следующий
      if m.shuffle then
        local next = math.random(1, #m.tracks)
        m.track = next
      else
        m.track = math.min(#m.tracks, m.track + 1)
      end
      m.startTime = math.floor(os.clock() * 20)
    else
      -- Shuffle
      m.shuffle = not m.shuffle
      ui.showToast(m.shuffle and "Shuffle ON" or "Shuffle OFF")
    end
    return
  end

  -- Тап по плейлисту
  local listStart = 12
  local scroll = m.listScroll or 0
  for i = 1 + scroll, math.min(#m.tracks, (H - listStart - 1) + scroll) do
    local ay = listStart + (i - 1 - scroll)
    if y == ay then
      if m.track == i then
        m.playing = not m.playing
        state.state.musicPlaying = m.playing
        if m.playing then m.startTime = math.floor(os.clock() * 20) end
      else
        m.track = i
        m.playing = true
        state.state.musicPlaying = true
        m.startTime = math.floor(os.clock() * 20)
      end
      return
    end
  end
end

function M.register(app)
  app.registerApp("music", draw, handleTouch)
end

return M
