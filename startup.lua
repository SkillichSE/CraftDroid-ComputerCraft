local ok, err = pcall(function()
  if not fs.exists("CraftDroid.lua") then
    error("CraftDroid.lua not found. Place it in the root directory.")
  end
  shell.run("CraftDroid.lua")
end)
if not ok then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.red)
  term.clear()
  term.setCursorPos(1,1)
  print("CraftDroid boot error:")
  term.setTextColor(colors.white)
  print(tostring(err))
  print("")
  term.setTextColor(colors.gray)
  print("Press any key to open shell...")
  os.pullEvent("key")
end
