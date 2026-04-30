#!/bin/bash

NAME="clipx_linux_amd64"

# Упаковываем файлы в архив. -j убирает пути, чтобы файлы лежали в корне zip.
zip -j out/$NAME.zip out/clipx README.md LICENSE

echo "Готово: out/$NAME.zip"
