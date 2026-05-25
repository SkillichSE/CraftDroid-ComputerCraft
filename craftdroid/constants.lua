local M = {}

M.APPS_DIR = "/craftdroid/apps/"
M.DATA_DIR = "/appdata/"
M.PICTURES_DIR = "/pictures/"
M.CONFIG_FILE = "/craftdroid/system.cfg"

M.THEMES = {
  dark  = {bg=colors.black,  bar=colors.gray,      barTxt=colors.white,  text=colors.white, accent=colors.cyan,    card=colors.gray,    sub=colors.lightGray, sep=colors.lightGray, iconFg=colors.white, danger=colors.red},
  light = {bg=colors.white,  bar=colors.lightGray,  barTxt=colors.black,  text=colors.black, accent=colors.blue,    card=colors.lightGray,sub=colors.gray,    sep=colors.gray,      iconFg=colors.white, danger=colors.red},
  amoled= {bg=colors.black,  bar=colors.black,      barTxt=colors.white,  text=colors.white, accent=colors.lime,    card=colors.black,   sub=colors.gray,      sep=colors.gray,      iconFg=colors.white, danger=colors.red},
}

M.BUILTIN_APPS = {
  {id="calculator", label="Calculator", icon="[+]", iconColor=colors.orange, builtin=true, desc="Math calculator"},
  {id="notepad",    label="Notepad",    icon="[N]", iconColor=colors.yellow, builtin=true, desc="Notes and text"},
  {id="fileman",    label="Files",      icon="[F]", iconColor=colors.blue,   builtin=true, desc="File manager"},
  {id="contacts",   label="Contacts",   icon="[C]", iconColor=colors.green,  builtin=true, desc="Address book"},
  {id="music",      label="Music",      icon="[M]", iconColor=colors.purple, builtin=true, desc="Audio player"},
  {id="browser",    label="Browser",    icon="[@]", iconColor=colors.cyan,   builtin=true, desc="Web browser"},
  {id="weather",    label="Weather",    icon="[W]", iconColor=colors.lightBlue, builtin=true, desc="Weather forecast"},
  {id="clock",      label="Clock",      icon="[T]", iconColor=colors.red,    builtin=true, desc="Time and alarm"},
  {id="paint",      label="Paint",      icon="[P]", iconColor=colors.pink,   builtin=true, desc="Pixel drawing"},
  {id="settings",   label="Settings",   icon="[S]", iconColor=colors.gray,   builtin=true, desc="System"},
}

return M
