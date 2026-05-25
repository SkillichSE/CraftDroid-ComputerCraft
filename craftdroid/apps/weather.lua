local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

local function getWeather()
  local day = os.day()
  local t = os.time()
  local hh = math.floor(t) % 24
  local seed = day * 7 + math.floor(day / 3)
  local conditions = {"Clear", "Partly cloudy", "Cloudy", "Overcast", "Rain", "Storm", "Foggy", "Windy"}
  local cols = {colors.yellow, colors.lightBlue, colors.lightGray, colors.gray, colors.blue, colors.purple, colors.gray, colors.cyan}
  local ci = (seed % #conditions) + 1
  local tempBase = 12 + (seed * 3) % 16
  local tempOffset = (hh >= 6 and hh <= 18) and 4 or -3
  return {
    cond = conditions[ci],
    color = cols[ci],
    temp = tempBase + tempOffset,
    humidity = 40 + (seed * 11) % 50,
    wind = 1 + (seed * 5) % 12,
    pressure = 745 + (seed * 7) % 30,
  }
end

local function getForecast()
  local day = os.day()
  local names = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"}
  local conditions = {"Clear", "Cloudy", "Fog", "Rain", "Storm"}
  local result = {}
  for i = 1, 6 do
    local d = day + i
    local seed = d * 7 + math.floor(d / 3)
    local ci = (seed % #conditions) + 1
    local temp = 10 + (seed * 3) % 16
    local label = names[((d - 1) % 7) + 1]
    table.insert(result, {label=label, cond=conditions[ci], temp=temp})
  end
  return result
end

local function drawMetric(y, label, value, fg, bg)
  local W = term.getSize()
  ui.txt(2, y, label, fg, bg)
  ui.txt(math.max(2, W - #value - 1), y, value, fg, bg)
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Weather", true)

  local w = getWeather()
  ui.fill(1, 3, W, 5, w.color)
  ui.ctr(3, w.cond, colors.white, w.color)
  ui.ctr(4, w.temp .. " C", colors.white, w.color)
  drawMetric(5, "Humidity", w.humidity .. "%", colors.white, w.color)
  drawMetric(6, "Wind", w.wind .. " m/s", colors.white, w.color)
  drawMetric(7, "Pressure", w.pressure .. " mmHg", colors.white, w.color)

  ui.fill(1, 9, W, 1, ui.T().card)
  ui.ctr(9, "Forecast", ui.T().sub, ui.T().card)

  local forecast = getForecast()
  local maxRows = math.max(0, H - 11)
  for i = 1, math.min(#forecast, maxRows) do
    local f = forecast[i]
    local ay = 9 + i
    local bg = ui.T().card
    local fg = ui.T().text
    ui.fill(1, ay, W, 1, bg)
    ui.txt(2, ay, f.label:sub(1, 8), fg, bg)
    ui.txt(12, ay, f.cond:sub(1, math.max(1, W - 18)), fg, bg)
    local temp = f.temp .. " C"
    ui.txt(math.max(2, W - #temp - 1), ay, temp, fg, bg)
  end

  local infoY = math.min(H - 1, 11 + math.min(#forecast, maxRows))
  if infoY < H then
    ui.txt(2, infoY, "Day " .. os.day(), ui.T().sub, ui.T().bg)
  end

  ui.drawNavBar()
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then state.state.screen = "home" return end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
  end
end

function M.register(app)
  app.registerApp("weather", draw, handleTouch)
end

return M
