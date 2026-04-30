# Параметры компилятора
VALAC = valac
CC = gcc
PKGS = --pkg gtk+-3.0 --pkg sqlite3 --pkg posix
SRC_DIR = src
OUT_DIR = out
OBJ_DIR = obj

# Находим все .vala файлы в папке src
SOURCES = $(wildcard $(SRC_DIR)/*.vala)
# Формируем пути для объектных файлов (внутри obj/src)
OBJECTS = $(patsubst $(SRC_DIR)/%.vala, $(OBJ_DIR)/$(SRC_DIR)/%.o, $(SOURCES))
OUT = $(OUT_DIR)/clipx

# Флаги для GCC
CFLAGS = $(shell pkg-config --cflags gtk+-3.0 sqlite3) -O2 -fno-ident
LIBS = $(shell pkg-config --libs gtk+-3.0 sqlite3)
LDFLAGS = -s

# Цель по умолчанию
all: prepare $(OUT)
	@echo "Сборка завершена: $(OUT)"

# Линковка финального бинарника
$(OUT): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS) $(LIBS) $(LDFLAGS)

# Компиляция: Vala генерирует .c файлы, GCC превращает их в .o
$(OBJ_DIR)/$(SRC_DIR)/%.o: $(SRC_DIR)/%.vala
	$(VALAC) $(PKGS) -C $(SOURCES) --directory=$(OBJ_DIR)
	$(CC) $(CFLAGS) -c $(OBJ_DIR)/$(SRC_DIR)/$*.c -o $@ -w

# Создание только необходимых для сборки папок
prepare:
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(OBJ_DIR)/$(SRC_DIR)

# Безопасная точечная очистка
clean:
	@if [ -f $(OUT) ]; then rm -f $(OUT); echo "Удален бинарник: $(OUT)"; fi
	@if [ -d "$(OBJ_DIR)/$(SRC_DIR)" ]; then \
		find $(OBJ_DIR)/$(SRC_DIR) -type f \( -name "*.o" -o -name "*.c" \) -delete; \
		echo "Очищены временные файлы сборки (.o, .c) в $(OBJ_DIR)/$(SRC_DIR)"; \
	fi

.PHONY: all prepare clean
