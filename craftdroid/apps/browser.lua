local ui = require("craftdroid.ui")
local state = require("craftdroid.state")

local M = {}

local shortcuts = {
  {label = "MC Wiki",   url = "wiki.mc.net"},
  {label = "CC Forum",  url = "forum.cc.ru"},
  {label = "Lua Docs",  url = "docs.lua.org"},
}

local offlinePages = {
  ["wiki.mc.net"] = {
    title = "Minecraft Wiki",
    lines = {
      "Welcome to the Minecraft Wiki.",
      "",
      "Minecraft is a sandbox video game",
      "developed by Mojang Studios.",
      "",
      "Topics:",
      "  - Blocks & Items",
      "  - Crafting & Recipes",
      "  - Mobs & Entities",
      "  - Biomes & Worlds",
      "  - Redstone & Circuits",
      "",
      "[Offline cached page]",
    }
  },
  ["forum.cc.ru"] = {
    title = "ComputerCraft Forum",
    lines = {
      "ComputerCraft Community Forum",
      "",
      "Latest threads:",
      "  - How to use HTTP API",
      "  - Best Lua libraries 2024",
      "  - Turtle automation tips",
      "  - New peripheral support",
      "",
      "Join the discussion at cc-tweaked.github.io",
      "",
      "[Offline cached page]",
    }
  },
  ["docs.lua.org"] = {
    title = "Lua 5.4 Reference",
    lines = {
      "Lua 5.4 Reference Manual",
      "",
      "Chapters:",
      "  1. Introduction",
      "  2. Basic Concepts",
      "  3. Language",
      "  4. C API",
      "  5. Standard Libraries",
      "",
      "string, table, math, io, os...",
      "",
      "[Offline cached page]",
    }
  },
}

local function tryHttp(url)
  if not http then return nil end
  local fullUrl = url
  if not fullUrl:match("^https?://") then
    fullUrl = "http://" .. url
  end
  local ok, res = pcall(function()
    return http.get(fullUrl, nil, true)
  end)
  if ok and res then
    local body = res.readAll()
    res.close()
    return body
  end
  return nil
end

local function stripHtml(s)
  s = s:gsub("<[^>]+>", "")
  s = s:gsub("&nbsp;", " ")
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&amp;", "&")
  s = s:gsub("&quot;", '"')
  return s
end

local function wrapLines(text, W)
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if #line == 0 then
      table.insert(lines, "")
    else
      while #line > W - 2 do
        table.insert(lines, line:sub(1, W - 2))
        line = line:sub(W - 1)
      end
      if #line > 0 then table.insert(lines, line) end
    end
  end
  return lines
end

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  ui.drawAppBar("Browser", true)

  local c = state.state.appState
  if not c.url then c.url = "" c.pageLines = nil c.pageTitle = "" c.scroll = 0 end

  ui.fill(1, 3, W, 1, ui.T().card)
  ui.txt(2, 3, "@", ui.T().sub, ui.T().card)
  local urlDisp = c.url == "" and "craftdroid://newtab" or c.url
  ui.txt(4, 3, urlDisp:sub(1, W - 7), c.url == "" and ui.T().sub or ui.T().text, ui.T().card)
  ui.fill(W - 2, 3, 3, 1, ui.T().accent)
  ui.ctr(3, "Go", colors.black, ui.T().accent, 3, W - 2)

  local contentY = 4
  local contentH = H - contentY - 2

  if c.url == "" then
    ui.fill(1, contentY, W, contentH, ui.T().card)
    ui.ctr(contentY + 1, "CraftDroid Browser", ui.T().accent, ui.T().card)
    ui.ctr(contentY + 2, "v1.0", ui.T().sub, ui.T().card)
    ui.hline(contentY + 3, ui.T().sep)

    local sbw = math.floor(W / #shortcuts)
    for i, s in ipairs(shortcuts) do
      local bx = (i - 1) * sbw + 1
      local bw = (i == #shortcuts) and (W - bx + 1) or sbw
      ui.fill(bx, contentY + 4, bw, 3, ui.T().bg)
      local ic_col = (i == 1) and colors.green or (i == 2) and colors.orange or colors.blue
      ui.fill(bx + 1, contentY + 4, bw - 2, 1, ic_col)
      ui.ctr(contentY + 4, s.label:sub(1, bw - 2), colors.white, ic_col, bw - 2, bx + 1)
      ui.fill(bx + 1, contentY + 5, bw - 2, 1, ui.T().card)
      ui.ctr(contentY + 5, s.url:sub(1, bw - 2), ui.T().sub, ui.T().card, bw - 2, bx + 1)
    end

    if state.appData.browser.history and #state.appData.browser.history > 0 then
      local hy = contentY + 8
      ui.txt(2, hy, "Recent:", ui.T().sub, ui.T().bg)
      for i, h in ipairs(state.appData.browser.history) do
        if hy + i <= H - 3 then
          ui.fill(1, hy + i, W, 1, ui.T().card)
          ui.txt(3, hy + i, "*", ui.T().sub, ui.T().card)
          ui.txt(5, hy + i, h:sub(1, W - 6), ui.T().text, ui.T().card)
        end
      end
    end

  elseif c.pageLines then
    local lines = c.pageLines
    local scroll = c.scroll or 0
    local maxShow = contentH
    ui.fill(1, contentY, W, contentH, ui.T().card)
    if c.pageTitle and #c.pageTitle > 0 then
      ui.fill(1, contentY, W, 1, ui.T().accent)
      ui.ctr(contentY, c.pageTitle:sub(1, W - 2), colors.black, ui.T().accent)
      contentY = contentY + 1
      maxShow = maxShow - 1
    end
    for i = 1 + scroll, math.min(#lines, scroll + maxShow) do
      local ly = contentY + (i - 1 - scroll)
      local line = lines[i]
      if #line == 0 then
        ui.fill(1, ly, W, 1, ui.T().card)
      else
        ui.fill(1, ly, W, 1, ui.T().card)
        ui.txt(2, ly, line:sub(1, W - 2), ui.T().text, ui.T().card)
      end
    end
    c.maxScroll = math.max(0, #lines - maxShow)
  else
    ui.fill(1, contentY, W, contentH, ui.T().card)
    ui.ctr(contentY + 2, c.loading and "Loading..." or "No content", ui.T().sub, ui.T().card)
    if not c.loading then
      ui.ctr(contentY + 3, "Offline - no HTTP", ui.T().sub, ui.T().card)
    end
  end

  ui.fill(1, H - 1, W, 1, ui.T().bar)
  local bw = math.floor(W / 3)
  ui.btn(1, H - 1, bw, "<", ui.T().text, ui.T().bar)
  ui.btn(1 + bw, H - 1, bw, "R", ui.T().accent, ui.T().bar)
  ui.btn(1 + bw * 2, H - 1, W - bw * 2, ">", ui.T().text, ui.T().bar)
  ui.drawNavBar()
end

local function navigate(c, url)
  c.url = url
  c.scroll = 0
  c.loading = true
  c.pageLines = nil
  c.pageTitle = ""

  local body = tryHttp(url)
  c.loading = false

  if body then
    local plain = stripHtml(body)
    local W = term.getSize()
    c.pageLines = wrapLines(plain, W)
    c.pageTitle = url
  else
    local cached = offlinePages[url]
    if cached then
      c.pageLines = cached.lines
      c.pageTitle = cached.title
    else
      c.pageLines = {
        "Could not load: " .. url,
        "",
        "HTTP unavailable in this environment.",
        "Only pre-cached pages are available.",
        "",
        "Available offline pages:",
      }
      for _, s in ipairs(shortcuts) do
        table.insert(c.pageLines, "  * " .. s.url)
      end
      c.pageTitle = "Offline"
    end
  end

  if state.appData.browser.history then
    for i = #state.appData.browser.history, 1, -1 do
      if state.appData.browser.history[i] == url then
        table.remove(state.appData.browser.history, i)
      end
    end
    table.insert(state.appData.browser.history, 1, url)
    if #state.appData.browser.history > 10 then
      table.remove(state.appData.browser.history)
    end
  end
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  if y == 2 and x <= 3 then state.state.screen = "home" return end
  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then state.state.screen = "home" end
    return
  end

  local c = state.state.appState
  if not c.url then c.url = "" c.pageLines = nil c.scroll = 0 end

  if y == 3 then
    if x >= W - 2 then
      if c.url ~= "" then
        navigate(c, c.url)
      end
    else
      ui.fill(4, 3, W - 6, 1, ui.T().card)
      term.setCursorPos(4, 3)
      term.setTextColor(ui.T().text)
      term.setBackgroundColor(ui.T().card)
      local v = read(nil, nil, nil, c.url)
      if v and #v > 0 then
        navigate(c, v)
      end
    end
    return
  end

  if y == H - 1 then
    local bw = math.floor(W / 3)
    if x <= bw then
      c.url = ""
      c.pageLines = nil
      c.pageTitle = ""
      c.scroll = 0
    elseif x <= bw * 2 then
      if c.url ~= "" then navigate(c, c.url) end
    else
      c.scroll = math.min((c.maxScroll or 0), (c.scroll or 0) + 3)
    end
    return
  end

  local contentY = 4
  if c.url == "" then
    local sbw = math.floor(W / #shortcuts)
    if y == contentY + 4 or y == contentY + 5 then
      for i, s in ipairs(shortcuts) do
        local bx = (i - 1) * sbw + 1
        local bw = (i == #shortcuts) and (W - bx + 1) or sbw
        if x >= bx and x < bx + bw then
          navigate(c, s.url)
          return
        end
      end
    end
    local hy = contentY + 8
    if y > hy and state.appData.browser.history then
      local idx = y - hy
      if idx >= 1 and idx <= #state.appData.browser.history then
        navigate(c, state.appData.browser.history[idx])
      end
    end
  else
    if c.pageLines then
      c.scroll = math.max(0, (c.scroll or 0) - 1)
    end
  end
end

function M.register(app)
  app.registerApp("browser", draw, handleTouch)
end

return M
