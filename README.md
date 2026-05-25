# CraftDroid OS

CraftDroid is a compact phone-style operating system for ComputerCraft. It has a lock screen, app launcher, file manager, notes, paint, contacts, settings and a few small utility apps.

The goal is simple: make a ComputerCraft computer feel like a tiny handheld OS.

## Highlights

- Home screen with app tiles
- PIN lock screen with touch and keyboard input
- File manager with text editing and image preview
- Notepad, Contacts, Paint, Music, Clock, Weather and Browser apps
- Theme, PIN and app management settings
- Factory reset for returning to a clean state

## Folder Map

```text
/
|-- startup.lua          Boot entry point
|-- CraftDroid.lua       Main OS loop
|-- craftdroid/          OS core files
|   |-- apps/            Built-in apps and app manifests
|   |-- constants.lua    System constants and app registry
|   |-- state.lua        Runtime state and saved data loading
|   |-- ui.lua           Shared UI drawing helpers
|   `-- system.cfg       Saved system settings
|-- appdata/             App databases
|   |-- notes.dat        Notepad notes
|   `-- paint.dat        Paint's internal drawing list
`-- pictures/            Exported Paint images
    `-- *.nfp            Viewable picture files
```

## Using The OS

### Home

Tap or click an app tile to open it. The home screen keeps apps in a centered grid.

### Navigation Bar

| Button | Action |
| --- | --- |
| `<` | Back, or scroll up in some screens |
| `o` | Home |
| `[]` | Running apps |

### Lock Screen

Enter the PIN using the on-screen keypad or a keyboard.

- Digits `0-9` enter the PIN
- `Backspace` or `Delete` removes a digit
- `Enter` checks the PIN

### Files

The Files app can open common text files in the editor. It also opens `.nfp` and `.nft` files as images.

Files marked `OS` are part of the system. They can still be opened, but CraftDroid warns before editing them.

### Paint

Paint keeps its working data in `appdata/paint.dat`, and exports normal viewable images into `pictures/`.

Open files from `pictures/` when you want to view Paint drawings in the Files app.

### Settings

Settings can change theme, WiFi state, time format, PIN, app management and sound state.

Factory reset clears user data, restores default settings and reinstalls built-in app manifests.

## Developer Notes

App code lives in `craftdroid/apps/`. Each built-in app usually has:

- a `.lua` module containing the app logic
- a `.app` manifest containing label, icon and install state

The main loop in `CraftDroid.lua` routes events to the current screen or app. Shared UI helpers live in `craftdroid/ui.lua`.

## Safe Editing

Good places to edit:

- `craftdroid/apps/*.lua`
- `craftdroid/apps/*.app`
- `README.md`

Be more careful with:

- `CraftDroid.lua`
- `startup.lua`
- `craftdroid/ui.lua`
- `craftdroid/state.lua`
- `craftdroid/constants.lua`

Those files control boot, app routing, rendering and saved state.
