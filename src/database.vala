using Sqlite;
using Posix;

/**
 * @brief Класс для работы с БД SQLite
 */
public class ClipDatabase : Object {
	private Database db;
	private string db_path;

	/**
	 * @brief Инициализация подключения и создание таблиц
	 */
	public ClipDatabase() {
		string config_dir = Path.build_filename(Environment.get_home_dir(), ".config", "clipx");
		this.db_path = Path.build_filename(config_dir, "database.db");

		// Исправлено: Создаем директорию, если её нет (как в Python)
		if (!FileUtils.test(config_dir, FileTest.EXISTS | FileTest.IS_DIR)) {
			DirUtils.create_with_parents(config_dir, 0700);
		}

		int rc = Database.open(this.db_path, out this.db);
		if (rc != Sqlite.OK) {
			GLib.stderr.printf("Ошибка открытия БД: %s\n", this.db.errmsg());
			return;
		}

		Posix.chmod(this.db_path, 0600);

		this.create_tables();
		this.integrity_check();
	}

	/*
	@brief Быстрая системная проверка наличия файла и восстановление
	*/
	private void _check_db() {
		Posix.Stat st;
		// Posix.stat — самый быстрый системный способ проверить файл (быстрее FileUtils.test)
		if (Posix.stat(this.db_path, out st) != 0) {
			// Если мы здесь, значит файл исчез (stat вернул ошибку)
			this.db = null; // Принудительно закрываем старый дескриптор
			Database.open(this.db_path, out this.db);
			Posix.chmod(this.db_path, 0600);
			this.create_tables();
		}
	}

	private void create_tables() {
		string query = """
			CREATE TABLE IF NOT EXISTS history (content TEXT UNIQUE);
			CREATE TABLE IF NOT EXISTS favorites (content TEXT UNIQUE);
			CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT);
		""";
		this.db.exec(query);
	}

	private void integrity_check() {
		this._check_db();
		this.db.exec("PRAGMA integrity_check;");
		this.db.exec("DELETE FROM history WHERE TRIM(content) = '';");
		this.db.exec("DELETE FROM favorites WHERE TRIM(content) = '';");
		// Добавлен VACUUM для соответствия Python-версии при очистке
		this.db.exec("VACUUM;");
	}

	/*
	@brief Загрузка данных и настроек из базы данных
	favorites - список избранного
	history - список истории
	max_items - лимит записей
	show_footer - флаг видимости панели
	*/
	public void load_data(out GLib.List<string> favorites, out GLib.List<string> history, out int max_items, out bool show_footer) {
		this._check_db();
		favorites = new GLib.List<string>();
		history = new GLib.List<string>();
		max_items = 10;
		show_footer = true;

		Statement stmt;

		// Загрузка отображения панели
		if (this.db.prepare_v2("SELECT value FROM settings WHERE key = 'show_footer'", -1, out stmt) == Sqlite.OK) {
			if (stmt.step() == Sqlite.ROW) {
				// Исправлено: сравнение с "true", так как bool.to_string() сохраняет текст
				show_footer = stmt.column_text(0) == "true";
			}
		}

		// Загрузка избранного
		if (this.db.prepare_v2("SELECT content FROM favorites ORDER BY rowid ASC", -1, out stmt) == Sqlite.OK) {
			while (stmt.step() == Sqlite.ROW) {
				favorites.append(stmt.column_text(0));
			}
		}

		// Загрузка истории
		if (this.db.prepare_v2("SELECT content FROM history ORDER BY rowid DESC", -1, out stmt) == Sqlite.OK) {
			while (stmt.step() == Sqlite.ROW) {
				history.append(stmt.column_text(0));
			}
		}

		// Загрузка лимита
		if (this.db.prepare_v2("SELECT value FROM settings WHERE key = 'max_items'", -1, out stmt) == Sqlite.OK) {
			if (stmt.step() == Sqlite.ROW) {
				max_items = int.parse(stmt.column_text(0));
			}
		}
	}

	public void save_history_item(string text) {
		this._check_db();
		Statement stmt;
		if (this.db.prepare_v2("INSERT OR REPLACE INTO history (content) VALUES (?)", -1, out stmt) == Sqlite.OK) {
			stmt.bind_text(1, text);
			stmt.step();
		}
	}

	public void move_to_favorites(string text) {
		this._check_db();
		Statement stmt_del, stmt_ins;
		this.db.exec("BEGIN TRANSACTION;");

		if (this.db.prepare_v2("DELETE FROM history WHERE content = ?", -1, out stmt_del) == Sqlite.OK) {
			stmt_del.bind_text(1, text);
			stmt_del.step();
		}
		if (this.db.prepare_v2("INSERT OR REPLACE INTO favorites (content) VALUES (?)", -1, out stmt_ins) == Sqlite.OK) {
			stmt_ins.bind_text(1, text);
			stmt_ins.step();
		}

		this.db.exec("COMMIT;");
	}

	public void move_from_favorites(string text) {
		this._check_db();
		Statement stmt_del, stmt_ins;
		this.db.exec("BEGIN TRANSACTION;");

		if (this.db.prepare_v2("DELETE FROM favorites WHERE content = ?", -1, out stmt_del) == Sqlite.OK) {
			stmt_del.bind_text(1, text);
			stmt_del.step();
		}
		if (this.db.prepare_v2("INSERT OR REPLACE INTO history (content) VALUES (?)", -1, out stmt_ins) == Sqlite.OK) {
			stmt_ins.bind_text(1, text);
			stmt_ins.step();
		}

		this.db.exec("COMMIT;");
	}

	public void delete_items(string table, GLib.List<string> items) {
		if (items == null || items.length() == 0) return;
		this._check_db();

		Statement stmt;
		// Оптимизация: компилируем один раз, выполняем много (аналог executemany)
		string query = "DELETE FROM %s WHERE content = ?".printf(table);
		if (this.db.prepare_v2(query, -1, out stmt) == Sqlite.OK) {
			this.db.exec("BEGIN TRANSACTION;");
			foreach (unowned string text in items) {
				stmt.bind_text(1, text);
				stmt.step();
				stmt.reset(); // Сброс для повторного использования
			}
			this.db.exec("COMMIT;");
		}
	}

	public void clear_tables(bool clear_favorites = false) {
		this._check_db();
		this.db.exec("BEGIN TRANSACTION;");
		this.db.exec("DELETE FROM history;");
		if (clear_favorites) {
			this.db.exec("DELETE FROM favorites;");
		}
		this.db.exec("COMMIT;");
	}

	public void update_setting(string key, string value) {
		this._check_db();
		Statement stmt;
		if (this.db.prepare_v2("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", -1, out stmt) == Sqlite.OK) {
			stmt.bind_text(1, key);
			stmt.bind_text(2, value);
			stmt.step();
		}
	}

	public void close() {
		// В Vala присваивание null объекту Database автоматически закрывает его через деструктор vapi
		this.db = null;
	}
}
