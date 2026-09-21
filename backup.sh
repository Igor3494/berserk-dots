#!/usr/bin/env bash
# Резервная копия твоих настроек и списка пакетов в ~/backups.
# Браузеры, пароли, ключи и история не копируются. Обои и видео скопируй вручную.
set -u
OUT="$HOME/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="$OUT/configs-$STAMP.tar.gz"
mkdir -p "$OUT"

ITEMS=(
  .config/hypr .config/noctalia .config/kitty .config/fastfetch .config/cava
  .config/starship.toml .config/kdeglobals .config/dolphinrc
  .zshrc .local/bin
)
EXIST=()
for i in "${ITEMS[@]}"; do [[ -e $HOME/$i ]] && EXIST+=("$i"); done

tar czf "$FILE" -C "$HOME" "${EXIST[@]}"
command -v pacman >/dev/null 2>&1 && pacman -Qqe > "$OUT/packages-$STAMP.txt"

echo "Готово:"
echo "  $FILE"
[[ -f $OUT/packages-$STAMP.txt ]] && echo "  $OUT/packages-$STAMP.txt"
echo
echo "Скопируй папку $OUT на флешку или в облако. Обои и видео (~/Pictures, ~/Videos) копируются отдельно."
echo "Восстановление:  tar xzf $FILE -C ~"
