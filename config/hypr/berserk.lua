local mainMod = "SUPER"
local ipc = "noctalia msg "
local function try(f) pcall(f) end
local function exec(keys, cmd) try(function() hl.bind(keys, hl.dsp.exec_cmd(cmd)) end) end

-- раскладка RU/EN, переключение Alt+Shift
try(function()
  hl.config({ input = { kb_layout = "us,ru", kb_options = "grp:alt_shift_toggle" } })
end)

-- внешний вид
try(function()
  hl.config({
    general = { gaps_in = 5, gaps_out = 10 },
    decoration = {
      rounding = 10,
      rounding_power = 2,
      shadow = { enabled = true, range = 4, render_power = 3, color = 0xee1a1a1a },
      blur = { enabled = true, size = 3, passes = 2, vibrancy = 0.1696 },
    },
  })
end)

-- анимации
try(function()
  hl.curve("bs", { type = "bezier", points = { {0.2, 0.9}, {0.1, 1.0} } })
  hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "bs", style = "popin 85%" })
  hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "bs", style = "slidevert" })
  hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "bs" })
end)

-- Noctalia: окно настроек и размытие панелей
try(function()
  hl.window_rule({ match = { class = "dev.noctalia.Noctalia" }, float = true, size = { 1080, 920 } })
end)
try(function()
  hl.layer_rule({
    name = "noctalia",
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
    no_anim = true, ignore_alpha = 0.5, blur = true, blur_popups = true,
  })
end)

-- программы
exec(mainMod .. " + Return", "kitty")
exec(mainMod .. " + Q", "firefox")
exec(mainMod .. " + T", "dolphin")
exec(mainMod .. " + D", "discord")
exec(mainMod .. " + C", "code")
exec(mainMod .. " + O", "obsidian")

-- окна
try(function() hl.bind(mainMod .. " + X", hl.dsp.window.close()) end)
try(function() hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen()) end)
try(function() hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" })) end)

-- Noctalia
exec(mainMod .. " + Space", ipc .. "panel-toggle launcher")
exec(mainMod .. " + S", ipc .. "panel-toggle control-center")
exec(mainMod .. " + comma", ipc .. "settings-toggle")
exec("ALT + Tab", ipc .. "window-switcher")
exec(mainMod .. " + W", ipc .. "panel-toggle wallpaper")
exec(mainMod .. " + ALT + V", ipc .. "panel-toggle clipboard")
exec(mainMod .. " + SHIFT + N", ipc .. "panel-toggle control-center notifications")
exec("CTRL + ALT + P", ipc .. "panel-toggle session")
exec("CTRL + ALT + L", ipc .. "session lock")

-- скриншоты (нужны grim, slurp, wl-clipboard из модуля extras)
exec(mainMod .. " + P", 'grim -g "$(slurp)" - | wl-copy')
exec(mainMod .. " + SHIFT + P", 'grim $HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png')
exec(mainMod .. " + ALT + P", 'grim -g "$(slurp)" $HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png')

-- подсказки по сочетаниям клавиш (SUPER + H)
try(function()
  hl.window_rule({ match = { class = "keyhints" }, float = true, size = { 900, 720 } })
end)
exec(mainMod .. " + H", "kitty --class keyhints --title Сочетания $HOME/.local/bin/keyhints")
