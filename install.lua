-- CraftDroid Beta 1.0 Installer
--   wget https://raw.githubusercontent.com/SkillichSE/CraftDroid-ComputerCraft/main/install.lua install.lua
--   install.lua

local BASE = "https://raw.githubusercontent.com/SkillichSE/CraftDroid-ComputerCraft/main/"

local FILES = {
    "startup.lua",
    "CraftDroid.lua",
    "craftdroid/constants.lua",
    "craftdroid/state.lua",
    "craftdroid/ui.lua",
    "craftdroid/io.lua",
    "craftdroid/lock.lua",
    "craftdroid/apps.lua",
    "craftdroid/system.cfg",
    "craftdroid/apps/appmanager.lua",
    "craftdroid/apps/browser.lua",
    "craftdroid/apps/browser.app",
    "craftdroid/apps/calculator.lua",
    "craftdroid/apps/calculator.app",
    "craftdroid/apps/clock.lua",
    "craftdroid/apps/clock.app",
    "craftdroid/apps/contacts.lua",
    "craftdroid/apps/contacts.app",
    "craftdroid/apps/fileman.lua",
    "craftdroid/apps/fileman.app",
    "craftdroid/apps/music.lua",
    "craftdroid/apps/music.app",
    "craftdroid/apps/notepad.lua",
    "craftdroid/apps/notepad.app",
    "craftdroid/apps/paint.lua",
    "craftdroid/apps/paint.app",
    "craftdroid/apps/settings.lua",
    "craftdroid/apps/settings.app",
    "craftdroid/apps/terminal.lua",
    "craftdroid/apps/terminal.app",
    "craftdroid/apps/terminalapp.lua",
    "craftdroid/apps/weather.lua",
    "craftdroid/apps/weather.app",
}

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.yellow)
print("================================")
print("   CraftDroid Beta 1.0")
print("   Installer")
print("================================")
term.setTextColor(colors.white)
print("")

if not http then
    term.setTextColor(colors.red)
    print("HTTP API отключен!")
    print("Включи http в настройках сервера.")
    return
end

local DIRS = {
    "craftdroid",
    "craftdroid/apps",
    "craftdroid/data",
    "appdata",
    "pictures",
}
for _, dir in ipairs(DIRS) do
    if not fs.exists(dir) then fs.makeDir(dir) end
end

local ok_count = 0
local fail_count = 0
local failed = {}

for i, path in ipairs(FILES) do
    term.setTextColor(colors.lightGray)
    term.write("[" .. i .. "/" .. #FILES .. "] " .. path .. " ... ")

    local res, err = http.get(BASE .. path)
    if res then
        local content = res.readAll()
        res.close()
        local f = fs.open(path, "w")
        f.write(content)
        f.close()
        term.setTextColor(colors.green)
        print("OK")
        ok_count = ok_count + 1
    else
        term.setTextColor(colors.red)
        print("FAIL")
        fail_count = fail_count + 1
        table.insert(failed, path)
    end
end

print("")
if fail_count == 0 then
    term.setTextColor(colors.green)
    print("Установка завершена! " .. ok_count .. " файлов.")
    term.setTextColor(colors.white)
    print("")
    term.setTextColor(colors.yellow)
    write("Перезагрузить сейчас? [y/n]: ")
    local ans = read()
    if ans == "y" or ans == "Y" then os.reboot() end
else
    term.setTextColor(colors.orange)
    print("Установлено: " .. ok_count .. "  Ошибок: " .. fail_count)
    print("")
    term.setTextColor(colors.red)
    print("Не удалось скачать:")
    for _, p in ipairs(failed) do print("  - " .. p) end
    term.setTextColor(colors.white)
    print("")
    print("Проверь подключение к интернету.")
end
