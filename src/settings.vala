using Gtk;
using Gdk;

/*
@brief Независимое окно настроек приложения
*/
public class SettingsWindow : Gtk.Window {
	public signal void limit_changed(int new_limit);
	public signal void footer_toggled(bool visible);
	public signal void clear_history();
	public signal void clear_all();

	private Switch auto_sw;
	private Switch menu_sw;
	private Switch footer_sw;

	/*
	@brief Конструктор окна настроек
	переменная current_limit - текущее ограничение истории
	*/
	public SettingsWindow(int current_limit, bool footer_visible) {
		Object(title: "Настройки");

		this.set_default_size(250, -1);
		this.set_position(WindowPosition.CENTER);
		this.set_border_width(10);

		unowned SettingsWindow self = this;
		var vbox = new Box(Orientation.VERTICAL, 10);
		this.add(vbox);

		var notebook = new Notebook();
		vbox.pack_start(notebook, true, true, 0);

		notebook.append_page(create_main_tab(), new Label("Основное"));
		notebook.append_page(create_view_tab(footer_visible), new Label("Вид"));
		notebook.append_page(create_history_tab(current_limit), new Label("История"));
		notebook.append_page(create_about_tab(), new Label("О программе"));

		var close_btn = new Button.with_label("Закрыть");
		close_btn.halign = Align.END;
		close_btn.clicked.connect(() => {
			self.destroy(); // Здесь unowned self безопасен
		});

		vbox.pack_end(close_btn, false, false, 0);
		this.show_all();
	}

	/*
	@brief Определяет путь к исполняемому файлу текущего процесса
	@return строка с полным путем к бинарнику
	*/
	private string _get_bin_path() {
		try {
			return FileUtils.read_link("/proc/self/exe");
		} catch (Error e) {
			return "";
		}
	}

	/*
	@brief Генерирует содержимое desktop-файла
	переменная exec_path - путь к бинарнику для ключа Exec
	@return строка с содержимым файла
	*/
	private string _get_desktop_content(string exec_path) {
		return "[Desktop Entry]\n" +
		"Type=Application\n" +
		"Name=clipx\n" +
		"Comment=Менеджер буфера обмена clipx\n" +
		"Exec=" + exec_path + "\n" +
		"Icon=edit-copy\n" +
		"Terminal=false\n" +
		"Categories=Utility;\n";
	}

	/*
	@brief Проверяет существование desktop-файла и корректность пути Exec
	переменная path - путь к проверяемому файлу
	@return true если файл существует и путь совпадает с текущим бинарником
	*/
	private bool _check_desktop_integrity(string path) {
		if (!FileUtils.test(path, FileTest.EXISTS)) return false;
		try {
			string content;
			FileUtils.get_contents(path, out content);
			string current_bin = _get_bin_path();
			if (current_bin != "" && content.contains("Exec=" + current_bin)) {
				return true;
			}
			// Если путь не совпадает (портативный запуск из другого места), обновляем файл
			if (current_bin != "") {
				FileUtils.set_contents(path, _get_desktop_content(current_bin));
				return true;
			}
		} catch (Error e) {}
		return false;
	}

	/*
	@brief Универсальный метод управления desktop-файлом (автозагрузка или меню)
	переменная dir - целевая директория
	переменная active - создавать или удалять файл
	*/
	private void _update_desktop_file(string dir, bool active) {
		string bin = _get_bin_path();
		if (bin == "") return;
		string file = Path.build_filename(dir, "clipx.desktop");

		if (active) {
			try {
				if (!FileUtils.test(dir, FileTest.EXISTS)) {
					DirUtils.create_with_parents(dir, 0755);
				}
				FileUtils.set_contents(file, _get_desktop_content(bin));
				Posix.chmod(file, 0755);
			} catch (Error e) {
				stderr.printf("Ошибка управления файлом %s: %s\n", file, e.message);
			}
		} else {
			if (FileUtils.test(file, FileTest.EXISTS)) {
				FileUtils.remove(file);
			}
		}
	}

	private Widget create_main_tab() {
		var grid = new Grid();
		grid.border_width = 15;
		grid.row_spacing = 10;
		grid.column_spacing = 20;

		string autostart_dir = Path.build_filename(Environment.get_user_config_dir(), "autostart");
		string apps_dir = Path.build_filename(Environment.get_user_data_dir(), "applications");

		var auto_label = new Label("Запускать при старте системы");
		auto_label.halign = Align.START;
		auto_label.hexpand = true;

		this.auto_sw = new Switch();
		this.auto_sw.halign = Align.END;
		this.auto_sw.active = _check_desktop_integrity(Path.build_filename(autostart_dir, "clipx.desktop"));
		this.auto_sw.notify["active"].connect(() => {
			_update_desktop_file(autostart_dir, this.auto_sw.active);
		});

		grid.attach(auto_label, 0, 0, 1, 1);
		grid.attach(this.auto_sw, 1, 0, 1, 1);

		var menu_label = new Label("Показывать в меню приложений");
		menu_label.halign = Align.START;
		menu_label.hexpand = true;

		this.menu_sw = new Switch();
		this.menu_sw.halign = Align.END;
		this.menu_sw.active = _check_desktop_integrity(Path.build_filename(apps_dir, "clipx.desktop"));
		this.menu_sw.notify["active"].connect(() => {
			_update_desktop_file(apps_dir, this.menu_sw.active);
		});

		grid.attach(menu_label, 0, 1, 1, 1);
		grid.attach(this.menu_sw, 1, 1, 1, 1);

		return grid;
	}

	/*
	@brief Создает вкладку внешнего вида
	переменная footer_visible - состояние переключателя
	*/
	private Widget create_view_tab(bool footer_visible) {
		var grid = new Grid();
		grid.border_width = 15;
		grid.row_spacing = 10;
		grid.column_spacing = 20;

		var menu_lbl = new Label("Показывать панель управления");
		menu_lbl.halign = Align.START;
		menu_lbl.hexpand = true;

		this.footer_sw = new Switch();
		this.footer_sw.halign = Align.END;
		this.footer_sw.active = footer_visible;

		this.footer_sw.notify["active"].connect(() => {
			this.footer_toggled(this.footer_sw.active);
		});

		grid.attach(menu_lbl, 0, 0, 1, 1);
		grid.attach(this.footer_sw, 1, 0, 1, 1);

		return grid;
	}

	private Widget create_history_tab(int current_limit) {
		var tab = new Box(Orientation.VERTICAL, 10);
		tab.border_width = 10;
		unowned SettingsWindow self = this;

		var limit_box = new Box(Orientation.HORIZONTAL, 10);
		limit_box.pack_start(new Label("Лимит элементов:"), false, false, 0);

		var adj = new Adjustment(current_limit, 1, 100, 1, 1, 0);
		var spin = new SpinButton(adj, 1.0, 0);

		spin.value_changed.connect(() => {
			self.limit_changed((int)spin.get_value());
		});

		limit_box.pack_start(spin, false, false, 0);
		tab.add(limit_box);

		var clear_history_btn = new Button.with_label("Очистить историю");
		clear_history_btn.halign = Align.START;
		clear_history_btn.clicked.connect(() => {
			self.clear_history();
		});
		tab.add(clear_history_btn);

		var clear_all_btn = new Button.with_label("Очистить все");
		clear_all_btn.halign = Align.START;
		clear_all_btn.clicked.connect(() => {
			self.confirm_action("Вы уверены, что хотите удалить всё, включая избранное?");
		});
		tab.add(clear_all_btn);

		return tab;
	}

	/*
	@brief Создает вкладку с информацией о программе
	@return виджет вкладки
	*/
	private Widget create_about_tab() {
		var tab = new Box(Orientation.VERTICAL, 10);
		tab.border_width = 15;
		tab.valign = Align.CENTER;

		var label = new Label("Разработчик: xdiloc");
		label.halign = Align.CENTER;

		var version_label = new Label("Версия: 1.0");
		version_label.halign = Align.CENTER;

		var link = new Label("<a href=\"https://github.com/xdiloc/clipx\">https://github.com/xdiloc/clipx</a>");
		link.set_use_markup(true);
		link.halign = Align.CENTER;

		tab.pack_start(label, false, false, 0);
		tab.pack_start(version_label, false, false, 0);
		tab.pack_start(link, false, false, 0);

		return tab;
	}

	/*
	@brief Создает диалог подтверждения действия
	переменная message - текст сообщения
	*/
	private void confirm_action(string message) {
		unowned SettingsWindow self = this;

		var dialog = new MessageDialog(this, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.YES_NO, "%s", message);
		dialog.title = "Подтверждение";

		dialog.response.connect((id) => {
			if (id == ResponseType.YES) {
				self.clear_all();
			}
			dialog.destroy();
		});

		dialog.show_all();
	}
}
