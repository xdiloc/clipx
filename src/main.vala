using Gtk;
using Gdk;

/*
@brief Главный контроллер приложения с защитой от двойного запуска
*/
public class ClipTrayApp : Gtk.Application {
	private ClipTray tray;
	private ClipWindow window;
	private Gtk.Clipboard clipboard;
	private ClipDatabase db;
	private ClipData data;

	public ClipTrayApp() {
		Object(
			application_id: "com.xdiloc.clipx",
			flags: ApplicationFlags.FLAGS_NONE
		);
	}

	protected override bool local_command_line(ref unowned string[] args, out int exit_status) {
		try {
			if (!this.register(null)) {
				exit_status = 0;
				return true;
			}
		} catch (Error e) {
			exit_status = 1;
			return true;
		}
		return base.local_command_line(ref args, out exit_status);
	}

	private string _get_preview(string text) {
		string display_text = text.replace("\n", " ").strip();
		if (display_text.char_count() > 40) {
			return display_text.substring(0, display_text.index_of_nth_char(40)) + "...";
		}
		return display_text;
	}

	/*
	@brief Вспомогательный метод для обновления интерфейса
	*/
	private void refresh_ui() {
		if (window.get_visible()) {
			string? current_text = clipboard.wait_for_text();
			if (current_text == null) current_text = "";

			List<ClipItem?> fav_ui;
			List<ClipItem?> hist_ui;

			data.get_ui_lists(this._get_preview, out fav_ui, out hist_ui);
			window.update_content(fav_ui, hist_ui, current_text);
		}
	}

	/*
	@brief Обработчик изменения лимита
	*/
	private void _limit_callback(int new_limit) {
		if (data.update_limit(new_limit)) {
			refresh_ui();
		}
	}

	/*
	@brief Обработчик очистки данных
	*/
	private void _clear_callback(bool all_data) {
		data.clear(all_data);
		refresh_ui();
	}

	protected override void activate() {
		if (tray != null) return;

		db = new ClipDatabase();
		data = new ClipData(db);

		clipboard = Gtk.Clipboard.get(Gdk.Atom.intern_static_string("CLIPBOARD"));
		tray = new ClipTray();
		window = new ClipWindow();

		window.set_footer_visible(data.show_footer);

		unowned ClipTrayApp self = this;

		clipboard.owner_change.connect((clipboard, event) => {
			if (clipboard.wait_is_text_available()) {
				string text = clipboard.wait_for_text();
				if (text != null && text.strip() != "") {
					self.data.add_to_history(text);
					Idle.add(() => {
						self.refresh_ui();
						return false;
					});
				}
			}
		});

		tray.tray_clicked.connect(() => {
			string? current_text = self.clipboard.wait_for_text();
			if (current_text == null) current_text = ""; // Защита от null

			List<ClipItem?> fav_ui;
			List<ClipItem?> hist_ui;

			self.data.get_ui_lists(self._get_preview, out fav_ui, out hist_ui);
			self.window.update_content(fav_ui, hist_ui, current_text);
			self.window.popup(self.tray.get_icon());
		});

		tray.settings_requested.connect(() => {
			self.window.app_settings();
		});

		tray.exit_requested.connect(() => {
			self.window.app_exit();
		});

		window.app_copy.connect((text) => {
			self.clipboard.set_text(text, -1);
		});

		window.app_fav.connect((text) => {
			self.data.toggle_favorite(text);
			self.refresh_ui();
		});

		window.app_settings.connect(() => {
			self.window.hide_window();
			var settings_dialog = new SettingsWindow(self.data.max_items, self.data.show_footer);

			settings_dialog.footer_toggled.connect((visible) => {
				self.data.update_footer_setting(visible); // Сохраняем
				self.window.set_footer_visible(visible);  // Обновляем UI «на лету»
			});

			// Используем unowned ссылку для разрыва цикла в сигналах окна настроек
			settings_dialog.limit_changed.connect((new_limit) => {
				self._limit_callback(new_limit);
			});

			settings_dialog.clear_history.connect(() => {
				self._clear_callback(false);
			});

			settings_dialog.clear_all.connect(() => {
				self._clear_callback(true);
			});

			settings_dialog.show_all();
		});

		window.app_exit.connect(() => {
			self.db.close();
			GLib.Process.exit(0);
		});

		this.hold();
	}

	public static int main(string[] args) {
		var app = new ClipTrayApp();
		return app.run(args);
	}
}
