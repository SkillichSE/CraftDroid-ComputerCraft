local ui = require("craftdroid.ui")
local state = require("craftdroid.state")
local io = require("craftdroid.io")
local const = require("craftdroid.constants")

local M = {}

local function saveContacts()
  io.saveTable(const.DATA_DIR .. "contacts.dat", state.appData.contacts)
end

local function sortContacts()
  table.sort(state.appData.contacts, function(a, b)
    local na = (a.name or ""):lower()
    local nb = (b.name or ""):lower()
    if na == "" then return false end
    if nb == "" then return true end
    return na < nb
  end)
end

local function filterContacts(query)
  if not query or query == "" then return state.appData.contacts end
  local q = query:lower()
  local result = {}
  for _, c in ipairs(state.appData.contacts) do
    local n = (c.name or ""):lower()
    local p = (c.phone or ""):lower()
    if n:find(q, 1, true) or p:find(q, 1, true) then
      table.insert(result, c)
    end
  end
  return result
end

local palColors = {colors.red, colors.blue, colors.green, colors.orange, colors.purple, colors.cyan}

local function draw()
  local W, H = term.getSize()
  ui.fill(1, 1, W, H, ui.T().bg)
  ui.drawStatusBar()
  local c = state.state.appState
  if not c.view then c.view = "list" c.search = "" c.searchActive = false end

  if c.view == "list" then
    ui.drawAppBar("Contacts", true)

    ui.fill(1, 3, W, 1, ui.T().card)
    ui.txt(2, 3, ">", ui.T().sub, ui.T().card)
    local searchDisp = c.searchActive and (c.search .. "_") or (c.search == "" and "Search..." or c.search)
    local sfg = (c.search == "" and not c.searchActive) and ui.T().sub or ui.T().text
    ui.txt(4, 3, searchDisp:sub(1, W - 8), sfg, ui.T().card)
    ui.fill(W - 3, 2, 4, 1, ui.T().bar)
    ui.txt(W - 2, 2, "+", ui.T().accent, ui.T().bar)

    sortContacts()
    local filtered = filterContacts(c.search)

    if #filtered == 0 then
      local msg = #state.appData.contacts == 0 and "No contacts" or "No results"
      ui.ctr(math.floor(H / 2), msg, ui.T().sub, ui.T().bg)
    else
      local startY = 4
      local maxShow = H - startY - 1
      local scroll = c.scroll or 0
      local lastLetter = ""
      local displayList = {}
      for _, con in ipairs(filtered) do
        local letter = (#con.name > 0) and con.name:sub(1,1):upper() or "#"
        if letter ~= lastLetter then
          table.insert(displayList, {type="header", letter=letter})
          lastLetter = letter
        end
        table.insert(displayList, {type="contact", con=con})
      end

      for i = 1 + scroll, math.min(#displayList, scroll + maxShow) do
        local item = displayList[i]
        local ay = startY + (i - 1 - scroll)
        if item.type == "header" then
          ui.fill(1, ay, W, 1, ui.T().bg)
          ui.txt(2, ay, item.letter, ui.T().accent, ui.T().bg)
        else
          local con = item.con
          local ci = 0
          for j, fc in ipairs(state.appData.contacts) do
            if fc == con then ci = j break end
          end
          local cc = palColors[((ci - 1) % #palColors) + 1]
          ui.fill(1, ay, W, 1, ui.T().card)
          ui.fill(2, ay, 2, 1, cc)
          local initial = (#con.name > 0) and con.name:sub(1,1):upper() or "?"
          ui.txt(2, ay, initial, colors.white, cc)
          ui.txt(5, ay, (con.name ~= "" and con.name or "(no name)"):sub(1, W - 8), ui.T().text, ui.T().card)
          if con.phone and #con.phone > 0 then
            local ph = con.phone:sub(1, 8)
            ui.txt(W - #ph - 1, ay, ph, ui.T().sub, ui.T().card)
          end
        end
      end
      c.displayList = displayList
    end

  elseif c.view == "detail" then
    local con = state.appData.contacts[c.idx]
    if not con then c.view = "list" return end
    ui.drawAppBar(con.name ~= "" and con.name or "(no name)", true)
    local ci = c.idx
    local cc = palColors[((ci - 1) % #palColors) + 1]
    ui.fill(1, 3, W, 3, cc)
    local initial = (#con.name > 0) and con.name:sub(1,1):upper() or "?"
    ui.ctr(3, initial, colors.white, cc)
    ui.ctr(4, #con.name > 0 and con.name or "(no name)", colors.white, cc)
    ui.ctr(5, #(con.phone or "") > 0 and con.phone or "No number", colors.white, cc)
    ui.fill(1, 6, W, 1, ui.T().card)
    ui.txt(2, 6, "Name:  " .. (#con.name > 0 and con.name or "-"), ui.T().text, ui.T().card)
    ui.fill(1, 7, W, 1, ui.T().card)
    ui.txt(2, 7, "Phone: " .. (#(con.phone or "") > 0 and con.phone or "-"), ui.T().text, ui.T().card)
    ui.fill(1, 8, W, 1, ui.T().card)
    ui.txt(2, 8, "Email: " .. (#(con.email or "") > 0 and con.email or "-"), ui.T().text, ui.T().card)
    ui.fill(W - 6, 2, 7, 1, ui.T().bar)
    ui.txt(W - 5, 2, "[Edit]", ui.T().accent, ui.T().bar)
    ui.fill(1, 10, W, 1, ui.T().danger)
    ui.ctr(10, "Delete contact", colors.white, ui.T().danger)

  elseif c.view == "edit" then
    local isNew = (c.isNew == true)
    ui.drawAppBar(isNew and "New contact" or "Edit contact", true)
    ui.fill(W - 6, 2, 7, 1, ui.T().bar)
    ui.txt(W - 5, 2, "[Save]", colors.lime, ui.T().bar)
    ui.txt(2, 4, "Name:", ui.T().sub, ui.T().bg)
    ui.fill(1, 5, W, 1, ui.T().card)
    ui.txt(2, 5, (c.editName or ""):sub(1, W - 2), ui.T().text, ui.T().card)
    ui.txt(2, 7, "Phone:", ui.T().sub, ui.T().bg)
    ui.fill(1, 8, W, 1, ui.T().card)
    ui.txt(2, 8, (c.editPhone or ""):sub(1, W - 2), ui.T().text, ui.T().card)
    ui.txt(2, 10, "Email:", ui.T().sub, ui.T().bg)
    ui.fill(1, 11, W, 1, ui.T().card)
    ui.txt(2, 11, (c.editEmail or ""):sub(1, W - 2), ui.T().text, ui.T().card)
    if c.editField == "name" then ui.txt(W, 5, "<", ui.T().accent, ui.T().card) end
    if c.editField == "phone" then ui.txt(W, 8, "<", ui.T().accent, ui.T().card) end
    if c.editField == "email" then ui.txt(W, 11, "<", ui.T().accent, ui.T().card) end
    ui.fill(1, H - 1, W, 1, ui.T().accent)
    ui.ctr(H - 1, "Tap field to edit", colors.black, ui.T().accent)
  end

  ui.drawNavBar()
end

local function handleTouch(x, y)
  local W, H = term.getSize()
  local c = state.state.appState

  if y == 2 and x <= 3 then
    if c.view == "edit" then
      if c.isNew then
        table.remove(state.appData.contacts, c.idx)
      end
      c.editName = nil c.editPhone = nil c.editEmail = nil c.editField = nil c.isNew = nil
      c.view = "list"
    elseif c.view == "detail" then
      c.view = "list"
    else
      state.state.screen = "home"
    end
    return
  end

  if y == H then
    local bw = math.floor(W / 3)
    if x <= bw * 2 then
      if c.view == "edit" then
        if c.isNew then table.remove(state.appData.contacts, c.idx) end
        c.editName = nil c.editPhone = nil c.editEmail = nil c.editField = nil c.isNew = nil
        c.view = "list"
      elseif c.view == "detail" then
        c.view = "list"
      else
        state.state.screen = "home"
      end
    end
    return
  end

  if c.view == "list" then
    if y == 2 and x >= W - 3 then
      sortContacts()
      table.insert(state.appData.contacts, {name = "", phone = "", email = ""})
      c.view = "edit"
      c.idx = #state.appData.contacts
      c.editName = "" c.editPhone = "" c.editEmail = "" c.editField = "name"
      c.isNew = true
      return
    end

    if y == 3 then
      c.searchActive = true
      ui.fill(1, 3, W, 1, ui.T().card)
      ui.txt(2, 3, ">", ui.T().sub, ui.T().card)
      term.setCursorPos(4, 3)
      term.setTextColor(ui.T().text)
      term.setBackgroundColor(ui.T().card)
      local v = read(nil, nil, nil, c.search or "")
      c.search = v or ""
      c.searchActive = false
      c.scroll = 0
      return
    end

    local startY = 4
    local displayList = c.displayList or {}
    local scroll = c.scroll or 0
    local lineIdx = (y - startY) + 1 + scroll
    if lineIdx >= 1 and lineIdx <= #displayList then
      local item = displayList[lineIdx]
      if item and item.type == "contact" then
        local con = item.con
        for i, fc in ipairs(state.appData.contacts) do
          if fc == con then
            c.view = "detail"
            c.idx = i
            break
          end
        end
      end
    end

  elseif c.view == "detail" then
    local con = state.appData.contacts[c.idx]
    if not con then c.view = "list" return end
    if y == 2 and x >= W - 6 then
      c.editName = con.name or ""
      c.editPhone = con.phone or ""
      c.editEmail = con.email or ""
      c.editField = "name"
      c.isNew = false
      c.view = "edit"
    elseif y == 10 then
      local idx = c.idx
      table.remove(state.appData.contacts, idx)
      saveContacts()
      c.view = "list"
      ui.showToast("Contact removed")
    else
      c.view = "list"
    end

  elseif c.view == "edit" then
    local con = state.appData.contacts[c.idx]
    if not con then c.view = "list" return end
    if y == 2 and x >= W - 6 then
      con.name = c.editName or ""
      con.phone = c.editPhone or ""
      con.email = c.editEmail or ""
      sortContacts()
      saveContacts()
      c.editName = nil c.editPhone = nil c.editEmail = nil c.editField = nil c.isNew = nil
      c.view = "list"
      c.search = ""
      ui.showToast("Saved")
    elseif y == 5 then
      c.editField = "name"
      ui.fill(1, 5, W, 1, ui.T().card)
      term.setCursorPos(2, 5) term.setTextColor(ui.T().text) term.setBackgroundColor(ui.T().card)
      local v = read(nil, nil, nil, c.editName or "")
      if v ~= nil then c.editName = v end
    elseif y == 8 then
      c.editField = "phone"
      ui.fill(1, 8, W, 1, ui.T().card)
      term.setCursorPos(2, 8) term.setTextColor(ui.T().text) term.setBackgroundColor(ui.T().card)
      local v = read(nil, nil, nil, c.editPhone or "")
      if v ~= nil then c.editPhone = v end
    elseif y == 11 then
      c.editField = "email"
      ui.fill(1, 11, W, 1, ui.T().card)
      term.setCursorPos(2, 11) term.setTextColor(ui.T().text) term.setBackgroundColor(ui.T().card)
      local v = read(nil, nil, nil, c.editEmail or "")
      if v ~= nil then c.editEmail = v end
    end
  end
end

function M.register(app)
  app.registerApp("contacts", draw, handleTouch)
end

return M
