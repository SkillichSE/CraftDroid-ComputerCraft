local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

local layout = {
  {"AC", "%", "<", "/"},
  {"7",  "8", "9", "*"},
  {"4",  "5", "6", "-"},
  {"1",  "2", "3", "+"},
  {"0",  ".", "=", "="},
}

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Calculator", true)

  local c = state.state.appState
  if not c.input then c.input = "" c.result = "" c.history = {} c.hasResult = false end

  local numRows = #layout
  local dispH = 3
  local navH = 1
  local btnAreaH = H - 2 - dispH - navH
  local btnH = math.max(1, math.floor(btnAreaH / numRows))
  local dispY = H - navH - numRows * btnH - dispH

  ui.fill(1, dispY, W, dispH, ui.T().card)

  local disp = c.input == "" and (c.result ~= "" and c.result or "0") or c.input
  local dispStr = tostring(disp):sub(-(W - 3))
  ui.fill(1, dispY + dispH - 2, W, 1, ui.T().card)
  local dx = W - #dispStr - 1
  if dx < 2 then dx = 2 end
  ui.txt(dx, dispY + dispH - 2, dispStr, ui.T().text, ui.T().card)

  if c.result ~= "" and c.input ~= "" then
    local rstr = ("= " .. tostring(c.result)):sub(1, W - 2)
    ui.txt(W - #rstr - 1, dispY + dispH - 1, rstr, ui.T().accent, ui.T().card)
  end

  local bw = math.floor(W / 4)
  local sy = H - navH - numRows * btnH

  for r, row in ipairs(layout) do
    local by = sy + (r - 1) * btnH
    local usedCols = {}
    local ci = 1
    local col = 1
    while col <= #row do
      local k = row[col]
      local nextK = row[col + 1]
      local span = 1
      if k == "=" and nextK == "=" then span = 2 end
      local bx = (ci - 1) * bw + 1
      local buttonWidth = bw * span
      if ci + span - 1 == 4 then buttonWidth = W - bx + 1 end

      local bc
      if k == "=" then bc = ui.T().accent
      elseif k == "AC" or k == "C" then bc = ui.T().danger
      elseif k == "/" or k == "*" or k == "-" or k == "+" or k == "%" or k == "<" then bc = colors.orange
      else bc = ui.T().card end

      local fc = colors.white
      if bc == ui.T().card then fc = ui.T().text end

      ui.fill(bx, by, buttonWidth, btnH, bc)
      local labelY = by + math.floor(btnH / 2)
      ui.ctr(labelY, k == "AC" and (c.input ~= "" and "C" or "AC") or k, fc, bc, buttonWidth, bx)

      ci = ci + span
      col = col + span
    end
  end

  ui.drawNavBar()
end

local function handleTouch(x, y)
  if y == 2 and x <= 3 then state.state.screen = "home" return end
  local W, H = term.getSize()
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
    return
  end
  local c = state.state.appState
  if not c.input then c.input = "" c.result = "" c.history = {} c.hasResult = false end

  local numRows = #layout
  local dispH = 3
  local navH = 1
  local btnAreaH = H - 2 - dispH - navH
  local btnH = math.max(1, math.floor(btnAreaH / numRows))
  local sy = H - navH - numRows * btnH
  local bw = math.floor(W / 4)

  for r, row in ipairs(layout) do
    local by = sy + (r - 1) * btnH
    if y >= by and y < by + btnH then
      local ci = 1
      local col = 1
      while col <= #row do
        local k = row[col]
        local nextK = row[col + 1]
        local span = 1
        if k == "=" and nextK == "=" then span = 2 end
        local bx = (ci - 1) * bw + 1
        local buttonWidth = bw * span
        if ci + span - 1 == 4 then buttonWidth = W - bx + 1 end

        if x >= bx and x < bx + buttonWidth then
          local label = k
          if k == "AC" then label = (c.input ~= "" and "C" or "AC") end

          if label == "AC" then
            c.input = "" c.result = "" c.hasResult = false
          elseif label == "C" then
            c.input = "" c.hasResult = false
          elseif k == "<" then
            c.input = c.input:sub(1, -2)
            c.hasResult = false
          elseif k == "=" then
            if c.input ~= "" then
              local expr = c.input:gsub("%%", "/100")
              local fn = load("return " .. expr, "=calc", "t")
              if fn then
                local ok, res = pcall(fn)
                if ok and res ~= nil then
                  local resStr = tostring(res)
                  if resStr:find("%.") then
                    resStr = string.format("%.10g", res)
                  end
                  c.result = resStr
                  table.insert(c.history, c.input .. " = " .. c.result)
                  if #c.history > 10 then table.remove(c.history, 1) end
                  c.hasResult = true
                else
                  c.result = "Error"
                end
              else
                c.result = "Error"
              end
            end
          else
            if c.hasResult and k:match("^%d$") then
              c.input = k
              c.result = ""
              c.hasResult = false
            elseif c.hasResult and (k == "+" or k == "-" or k == "*" or k == "/" or k == "%") then
              c.input = c.result .. k
              c.result = ""
              c.hasResult = false
            else
              c.input = c.input .. k
              c.hasResult = false
            end
          end
          return
        end
        ci = ci + span
        col = col + span
      end
    end
  end
end

function M.register(app)
  app.registerApp("calculator", draw, handleTouch)
end

return M
