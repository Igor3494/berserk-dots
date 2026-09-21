#!/usr/bin/env bash
# Снимает копию твоих ЖИВЫХ настроек в репозиторий (перед коммитом на GitHub).
# Копируется только список ниже. Пароли, ключи, браузер и прочее личное НЕ трогается.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"

cp_if() {  # cp_if <откуда> <куда в config/>
  local src="$1" dest="$REPO/config/$2"
  if [[ -e $src ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    echo "  ок   $src"
  else
    echo "  нет  $src (пропущено)"
  fi
}

echo "== Копирую настройки =="
cp_if "$CONF/noctalia/config.toml"              noctalia/config.toml
cp_if "$CONF/noctalia/zz-berserk-bar.toml"      noctalia/zz-berserk-bar.toml
cp_if "$CONF/noctalia/zz-berserk-panels.toml"   noctalia/zz-berserk-panels.toml
for p in "$CONF"/noctalia/palettes/*.json; do
  [[ -e $p ]] && cp_if "$p" "noctalia/palettes/$(basename "$p")"
done
cp_if "$CONF/kitty/kitty.conf"       kitty/kitty.conf
cp_if "$CONF/cava/config"            cava/config
cp_if "$CONF/starship.toml"          starship/starship.toml
cp_if "$CONF/fastfetch/config.jsonc" fastfetch/config.jsonc
cp_if "$HOME/.zshrc"                 zsh/zshrc
cp_if "$CONF/kdeglobals"            kde/kdeglobals
cp_if "$CONF/hypr/keybinds.txt"     hypr/keybinds.txt
cp_if "$HOME/.local/bin/keyhints"    bin/keyhints

# личные пути и имена файлов логотипа -> нейтральные
FF="$REPO/config/fastfetch/config.jsonc"
if [[ -f $FF ]]; then
  sed -i "s|$HOME|__HOME__|g" "$FF"
  sed -i -E 's|Pictures/[A-Za-z0-9_.-]+\.png|Pictures/berserk-logo.png|g' "$FF"
fi

# Hyprland: полный конфиг только как справка, свои блоки перенеси в config/hypr/berserk.lua
if [[ -f $CONF/hypr/hyprland.lua ]]; then
  cp -a "$CONF/hypr/hyprland.lua" "$REPO/docs/hyprland.lua.reference"
  sed -i "s|$HOME|__HOME__|g" "$REPO/docs/hyprland.lua.reference"
  echo "  ок   hyprland.lua -> docs/hyprland.lua.reference (справка)"
  echo "       Если менял сочетания клавиш, перенеси их в config/hypr/berserk.lua вручную."
fi

# список установленных пакетов, которые ты поставил сам (для справки)
if command -v pacman >/dev/null 2>&1; then
  pacman -Qqe > "$REPO/docs/explicit-packages.txt"
  echo "  ок   docs/explicit-packages.txt (пакеты, установленные явно)"
fi

# защитный хук git (блокирует коммит личных данных)
if [[ -d $REPO/.git ]]; then
  git -C "$REPO" config core.hooksPath .githooks && echo "  ок   защитный хук включён (.githooks/pre-commit)"
fi

echo
echo "== Проверка: нет ли данных браузера и ключей =="
SENS=$(find "$REPO" -path "$REPO/.git" -prune -o -type f \( -name 'logins.json' -o -name 'key4.db' -o -name 'key3.db' -o -name 'cert9.db' -o -name '*.sqlite' -o -name 'cookies*' -o -name 'Login Data' -o -name 'Web Data' -o -name 'id_rsa' -o -name 'id_ed25519' -o -name '*.pem' -o -name '.env' \) -print)
if [[ -n $SENS ]]; then
  echo "! Найдены файлы, которых в репозитории быть не должно:"; echo "$SENS"; exit 1
fi
echo "ок, профилей браузера и ключей нет."

echo
echo "== Проверка на личное =="
BAD=0
if grep -rInE --exclude-dir=.git --exclude=export.sh \
   '(api[_-]?key|secret|token|passw(or)?d|sk-[A-Za-z0-9_-]{20,}|BEGIN (RSA|OPENSSH|PRIVATE))' "$REPO" ; then
  echo "! Нашёл похожее на секреты (см. выше). Проверь и удали перед публикацией."; BAD=1
fi
if grep -rIn --exclude-dir=.git --exclude=export.sh "$HOME" "$REPO"; then
  echo "! Осталась твоя домашняя папка ($HOME). Замени на __HOME__ или \$HOME."; BAD=1
fi
if find "$REPO" \( -path "$REPO/.git" -o -path "$REPO/docs" \) -prune -o -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.webm' -o -iname '*.jpg' -o -iname '*.png' \) -print | grep -q .; then
  echo "! В репозитории есть картинки или видео. Чужие обои и арты с авторскими правами публиковать нельзя."
  BAD=1
fi
(( BAD )) || echo "Похоже, чисто. Всё равно просмотри:  git status  и  git diff"
