#!/usr/bin/env bash
# Установка одной командой: скачивает репозиторий и запускает установщик.
# Пример (адрес подставь свой):
#   bash <(curl -fsSL https://raw.githubusercontent.com/igor3494/berserk-dots/main/bootstrap.sh)
# Не запускай чужие скрипты вслепую: сначала можно открыть файл по ссылке и прочитать.
set -euo pipefail

REPO_URL="https://github.com/igor3494/berserk-dots.git"
DIR="${BERSERK_DIR:-$HOME/berserk-dots}"

if [[ $REPO_URL == *igor3494* ]]; then
  echo "В bootstrap.sh не указан адрес репозитория (REPO_URL)."; exit 1
fi

command -v git >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm git

if [[ -d $DIR/.git ]]; then
  git -C "$DIR" pull --ff-only
else
  git clone --depth=1 "$REPO_URL" "$DIR"
fi

cd "$DIR"
# вопросы меню читаются с клавиатуры, даже если скрипт запущен через конвейер
exec ./install.sh "$@" < /dev/tty
