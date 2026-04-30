#!/bin/bash

# @brief Архивация исходного кода и сборочных файлов проекта clipx
# BACKUP_DIR - директория для хранения бэкапов
# TIMESTAMP - временная метка для уникальности имени файла
# ARCHIVE_NAME - полный путь к создаваемому zip-архиву

# Переходим в директорию, где лежит сам скрипт
cd "$(dirname "$0")"

BACKUP_DIR="backup"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="${BACKUP_DIR}/clipx_${TIMESTAMP}.zip"

# Создаем папку бэкапа, если её нет
if [ ! -d "$BACKUP_DIR" ]; then
	mkdir -p "$BACKUP_DIR"
fi

# Архивация: вся папка src, Makefile и сам скрипт
# Выводит список файлов по мере добавления
zip -r "$ARCHIVE_NAME" src/ Makefile pack.sh README.md LICENSE release.sh

echo "-------------------------------------------"
echo "Архив создан: $ARCHIVE_NAME"
