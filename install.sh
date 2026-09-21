#!/usr/bin/env bash
# Berserk Dots — установщик с выбором модулей.
# Запуск:  ./install.sh            (интерактивное меню)
#          ./install.sh --dry-run  (только показать, что будет сделано)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

say()  { printf '\033[1;31m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
run()  { if (( DRY )); then echo "   [dry-run] $*"; else "$@"; fi; }

# ---------- проверки ----------
if (( EUID == 0 )) && [[ -z "${BERSERK_TEST:-}" ]]; then
  echo "Не запускай от root. Скрипт сам вызовет sudo, где нужно."; exit 1
fi
if ! (( DRY )) && [[ -z "${BERSERK_TEST:-}" && ! -f /etc/arch-release ]]; then
  echo "Этот установщик рассчитан на Arch Linux."; exit 1
fi

# ---------- модули ----------
MODS=(base gpu desktop terminal apps dolphin theme video asus extras)
DESC=(
  "Базовая система: yay, звук (pipewire), Bluetooth, NetworkManager, шрифты"
  "NVIDIA для гибридных ноутбуков AMD+NVIDIA (драйвер, prime)"
  "Рабочий стол: Hyprland + Noctalia + порталы"
  "Терминал: kitty, zsh с подсказками, starship, fastfetch, cava, btop"
  "Программы: Firefox, Dolphin, Discord, Obsidian, VS Code"
  "Dolphin в теме Берсерка: цвета, иконки, красные папки"
  "Тема Берсерка: палитры, бар, панели, сочетания клавиш"
  "Видеообои: mpvpaper, mpv, ffmpeg, yt-dlp"
  "ASUS ROG: asusctl, supergfxctl (только для ноутбуков ASUS)"
  "Дополнительно: KDE Connect, Thunar, скриншоты (grim, slurp)"
)
SEL=(1 0 1 1 1 1 1 1 0 0)

menu() {
  while true; do
    [[ -t 1 ]] && clear
    echo "Berserk Dots: выбери, что установить"
    echo
    for i in "${!MODS[@]}"; do
      local mark=" "; (( SEL[i] )) && mark="x"
      printf ' %d) [%s] %-9s %s\n' "$((i+1))" "$mark" "${MODS[i]}" "${DESC[i]}"
    done
    echo
    echo " номера через пробел: вкл/выкл   a: всё   n: ничего   Enter: начать   q: выход"
    local ans; read -r -p "> " ans || exit 0
    case "$ans" in
      "") break ;;
      q|Q) exit 0 ;;
      a) for i in "${!SEL[@]}"; do SEL[i]=1; done ;;
      n) for i in "${!SEL[@]}"; do SEL[i]=0; done ;;
      *) for n in $ans; do
           if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#MODS[@]} )); then
             SEL[n-1]=$(( 1 - SEL[n-1] ))
           fi
         done ;;
    esac
  done
}

# ---------- помощники ----------
ensure_yay() {
  command -v yay >/dev/null 2>&1 && return 0
  say "Устанавливаю yay (помощник для AUR)"
  run sudo pacman -S --needed --noconfirm git base-devel
  local tmp; tmp="$(mktemp -d)"
  run git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  if ! (( DRY )); then ( cd "$tmp/yay-bin" && makepkg -si --noconfirm ); fi
}

pkglist() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null; }

install_pkgs() {
  local mod="$1" f
  f="$REPO/packages/$mod.pacman"
  if [[ -f $f ]]; then
    mapfile -t P < <(pkglist "$f")
    (( ${#P[@]} )) && { say "pacman: ${P[*]}"; run sudo pacman -S --needed --noconfirm "${P[@]}"; }
  fi
  f="$REPO/packages/$mod.aur"
  if [[ -f $f ]]; then
    mapfile -t P < <(pkglist "$f")
    if (( ${#P[@]} )); then
      ensure_yay
      say "AUR: ${P[*]}"
      run yay -S --needed --noconfirm "${P[@]}"
    fi
  fi
}

# put <путь в config/> <куда положить>: копирует файл или папку, старое сохраняет в бэкап
put() {
  local src="$REPO/config/$1" dest="$2"
  [[ -e $src ]] || { warn "нет файла $src, пропускаю"; return 0; }
  if [[ -e $dest ]]; then
    local rel="${dest#"$HOME"/}"
    run mkdir -p "$BACKUP/$(dirname "$rel")"
    run cp -a "$dest" "$BACKUP/$rel"
    say "сохранил старую версию: $BACKUP/$rel"
  fi
  run mkdir -p "$(dirname "$dest")"
  if [[ -d $src ]]; then
    run mkdir -p "$dest"
    run cp -a "$src/." "$dest/"
  else
    run cp -a "$src" "$dest"
  fi
}

# ---------- модули ----------
mod_base() {
  install_pkgs base
  run sudo systemctl enable --now NetworkManager bluetooth
  if [[ -f /etc/bluetooth/main.conf ]]; then
    run sudo sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
    run sudo systemctl restart bluetooth
  fi
}

mod_gpu() {
  warn "Модуль для гибридной графики AMD + NVIDIA (драйвер nvidia-open, Turing и новее)."
  local a; read -r -p "Продолжить? [y/N] " a
  [[ ${a:-N} =~ ^[Yy] ]] || { say "gpu пропущен"; return 0; }
  install_pkgs gpu
}

mod_desktop() {
  install_pkgs desktop
  say "Менеджер входа не ставится: войди из консоли командой  Hyprland  или поставь свой (sddm/greetd)."
}

mod_terminal() {
  install_pkgs terminal
  put kitty/kitty.conf   "$CONF/kitty/kitty.conf"
  put cava/config        "$CONF/cava/config"
  put starship/starship.toml "$CONF/starship.toml"
  put fastfetch/config.jsonc "$CONF/fastfetch/config.jsonc"
  put zsh/zshrc          "$HOME/.zshrc"
  if ! (( DRY )) && [[ -f $CONF/fastfetch/config.jsonc ]]; then
    sed -i "s|__HOME__|$HOME|g" "$CONF/fastfetch/config.jsonc"
  fi
  run mkdir -p "$HOME/Pictures"
  say "Свой логотип для терминала положи в ~/Pictures/berserk-logo.png (без него fastfetch покажет текст без картинки)."
}

mod_apps() { install_pkgs apps; }

mod_dolphin() {
  install_pkgs dolphin
  put kde/kdeglobals "$CONF/kdeglobals"
  if command -v papirus-folders >/dev/null 2>&1; then
    run sudo papirus-folders -C carmine --theme Papirus-Dark || run sudo papirus-folders -C red --theme Papirus-Dark
  fi
  if ! (( DRY )); then XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental >/dev/null 2>&1 || true; fi
  # переменные окружения, чтобы Dolphin читал тему KDE
  local f="$CONF/hypr/hyprland.lua"
  if [[ -f $f ]]; then
    run sed -i "/-- BERSERK-DOTS-KDE-BEGIN/,/-- BERSERK-DOTS-KDE-END/d" "$f"
    if ! (( DRY )); then
      { echo "-- BERSERK-DOTS-KDE-BEGIN"; cat "$REPO/config/hypr/kde-env.lua"; echo "-- BERSERK-DOTS-KDE-END"; } >> "$f"
    else
      echo "   [dry-run] добавить переменные KDE в $f"
    fi
    say "Перезайди в сессию, чтобы Dolphin подхватил тему."
  else
    warn "Нет $f. Запусти Hyprland один раз и повтори модуль dolphin."
  fi
}

mod_video() {
  install_pkgs video
  run mkdir -p "$HOME/Videos"
  if pgrep -x noctalia >/dev/null 2>&1; then
    run noctalia msg plugins enable noctalia/mpvpaper
  else
    say "После запуска Noctalia включи плагин:  noctalia msg plugins enable noctalia/mpvpaper"
  fi
  say "Видео положи в ~/Videos и выбери:  noctalia msg panel-toggle noctalia/mpvpaper:picker"
}

mod_asus() {
  install_pkgs asus
  run sudo systemctl enable --now asusd supergfxd
}

mod_extras() { install_pkgs extras; run mkdir -p "$HOME/Pictures/Screenshots"; }

BEGIN_MARK="-- BERSERK-DOTS-BEGIN"
END_MARK="-- BERSERK-DOTS-END"

mod_theme() {
  put noctalia/palettes "$CONF/noctalia/palettes"
  put noctalia/config.toml "$CONF/noctalia/config.toml"
  put noctalia/zz-berserk-bar.toml "$CONF/noctalia/zz-berserk-bar.toml"
  put noctalia/zz-berserk-panels.toml "$CONF/noctalia/zz-berserk-panels.toml"
  put bin/keyhints "$HOME/.local/bin/keyhints"
  run chmod +x "$HOME/.local/bin/keyhints"
  put hypr/keybinds.txt "$CONF/hypr/keybinds.txt"
  command -v noctalia >/dev/null 2>&1 && ! (( DRY )) && noctalia config validate || true

  local f="$CONF/hypr/hyprland.lua"
  if [[ ! -f $f ]]; then
    warn "Нет $f. Запусти Hyprland один раз (он создаст конфиг) и запусти этот модуль (theme) ещё раз."
    return 0
  fi
  run mkdir -p "$BACKUP/.config/hypr"
  run cp -a "$f" "$BACKUP/.config/hypr/hyprland.lua"
  # убрать блок прошлой установки
  run sed -i "/$BEGIN_MARK/,/$END_MARK/d" "$f"
  # стандартные бинды, которые конфликтуют с нашими
  local a; read -r -p "Закомментировать стандартные сочетания, которые конфликтуют с моими (Q, C, D, T, O, X, P, S, Return, скрытый стол magic)? [Y/n] " a
  if [[ ${a:-Y} =~ ^[Yy] ]]; then
    run sed -i -E 's/^([[:space:]]*hl\.bind\(mainMod \.\. " \+ (Q|C|D|T|O|X|P|S|Return)")/-- \1/' "$f"
    run sed -i -E '/toggle_special\("magic"\)|special:magic/ s/^/-- /' "$f"
  fi
  if ! (( DRY )); then
    {
      echo "$BEGIN_MARK"
      grep -q 'exec_cmd("noctalia")' "$f" || cat "$REPO/config/hypr/autostart.lua"
      cat "$REPO/config/hypr/berserk.lua"
      echo "$END_MARK"
    } >> "$f"
  else
    echo "   [dry-run] добавить блок Berserk в $f"
  fi
  say "Готово. Перезайди в сессию (SUPER+M и войди снова). Копия конфига Hyprland: $BACKUP/.config/hypr/"
}

# ---------- профиль (необязательно) ----------
# Пароли и логины скрипт НЕ спрашивает и нигде не хранит.
# Аккаунт создаётся отдельно (setup-account.sh) или при установке Arch (archinstall).
PROFILE_HOST=""; PROFILE_GIT_NAME=""; PROFILE_GIT_EMAIL=""

ask_profile() {
  echo
  say "Твой профиль (необязательно, Enter: пропустить). Ничего из этого не попадает в репозиторий."
  read -r -p "Имя компьютера (hostname), сейчас «$(hostname 2>/dev/null)»: " PROFILE_HOST || true
  read -r -p "Имя для git (твой ник на GitHub): " PROFILE_GIT_NAME || true
  read -r -p "Почта для git: " PROFILE_GIT_EMAIL || true
  if [[ -n $PROFILE_HOST && ! $PROFILE_HOST =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
    warn "Имя компьютера должно состоять из латинских букв, цифр и дефиса. Пропускаю."
    PROFILE_HOST=""
  fi
}

apply_profile() {
  [[ -n $PROFILE_HOST ]] && run sudo hostnamectl set-hostname "$PROFILE_HOST"
  [[ -n $PROFILE_GIT_NAME ]] && run git config --global user.name "$PROFILE_GIT_NAME"
  [[ -n $PROFILE_GIT_EMAIL ]] && run git config --global user.email "$PROFILE_GIT_EMAIL"
  return 0
}

# ---------- запуск ----------
menu
ask_profile
echo
say "Копии заменяемых файлов: $BACKUP"
(( DRY )) && warn "Режим dry-run: ничего не устанавливается"

for i in "${!MODS[@]}"; do
  if (( SEL[i] )); then
    say "=== Модуль: ${MODS[i]} ==="
    "mod_${MODS[i]}"
  fi
done

apply_profile

echo
say "Готово. Если что-то пошло не так, старые файлы лежат в $BACKUP"
