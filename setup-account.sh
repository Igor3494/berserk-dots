#!/usr/bin/env bash
# Создаёт твоего пользователя на свежей системе Arch (например, после минимальной установки).
# Запускать от root:  sudo ./setup-account.sh
#
# Пароли вводятся ТОЛЬКО в системную команду passwd (ввод скрытый). Скрипт их не видит,
# не записывает и никуда не отправляет. В репозитории нет ничьих имён и паролей.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then echo "Запусти от root:  sudo ./setup-account.sh"; exit 1; fi
if [[ ! -f /etc/arch-release ]]; then echo "Только для Arch Linux."; exit 1; fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Создание пользователя. Ничего не будет отправлено в сеть."
echo

read -r -p "Имя пользователя (латиницей, маленькими буквами): " USERNAME
if [[ ! $USERNAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  echo "Недопустимое имя. Разрешены a-z, 0-9, _ и -, начинать с буквы."; exit 1
fi
if [[ $USERNAME == root ]]; then echo "Нужен обычный пользователь, не root."; exit 1; fi

read -r -p "Имя компьютера (hostname), Enter: не менять: " HOSTNAME_NEW
if [[ -n $HOSTNAME_NEW && ! $HOSTNAME_NEW =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]]; then
  echo "Недопустимое имя компьютера."; exit 1
fi

echo
echo "Ставлю sudo, zsh, git (если их нет)..."
pacman -S --needed --noconfirm sudo zsh git

if id "$USERNAME" >/dev/null 2>&1; then
  echo "Пользователь $USERNAME уже есть, создание пропускаю."
else
  useradd -m -G wheel -s /usr/bin/zsh "$USERNAME"
  echo
  echo "Задай пароль для $USERNAME (ввод скрытый):"
  passwd "$USERNAME"
fi

read -r -p "Сменить пароль root? [y/N] " A
if [[ ${A:-N} =~ ^[Yy] ]]; then
  echo "Новый пароль root (ввод скрытый):"
  passwd root
fi

# sudo для группы wheel (с проверкой синтаксиса)
SUDOERS=/etc/sudoers.d/10-wheel
echo '%wheel ALL=(ALL:ALL) ALL' > "$SUDOERS"
chmod 440 "$SUDOERS"
if ! visudo -cf "$SUDOERS" >/dev/null; then
  rm -f "$SUDOERS"; echo "Ошибка в настройке sudo, файл удалён."; exit 1
fi

if [[ -n $HOSTNAME_NEW ]]; then
  echo "$HOSTNAME_NEW" > /etc/hostname
  echo "Имя компьютера: $HOSTNAME_NEW (применится после перезагрузки)."
fi

# положить репозиторий в домашнюю папку нового пользователя
DEST="/home/$USERNAME/berserk-dots"
if [[ ! -e $DEST ]]; then
  cp -r "$REPO" "$DEST"
  chown -R "$USERNAME:$USERNAME" "$DEST"
fi

cat <<EOF

Готово. Дальше:
  1. Войди под пользователем $USERNAME (например:  su - $USERNAME  или после перезагрузки).
  2. cd ~/berserk-dots && ./install.sh

Установку диска и загрузчика этот скрипт не делает: для этого есть archinstall.
EOF
