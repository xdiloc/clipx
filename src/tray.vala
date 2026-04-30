using Gtk;

/**
 * @brief Управление иконкой трея (Стабильная версия)
 */
public class ClipTray : GLib.Object {
	public signal void tray_clicked();
	public signal void settings_requested();
	public signal void exit_requested();

	private Gtk.StatusIcon status_icon;
	private Gtk.Menu menu;

	public ClipTray() {
		this.status_icon = new Gtk.StatusIcon();
		this.status_icon.set_from_icon_name("edit-copy");
		this.status_icon.set_title("clipx manager");
		this.status_icon.set_tooltip_text("Менеджер буфера обмена clipx");
		this.status_icon.set_visible(true);

		create_menu();

		this.status_icon.activate.connect(() => {
			this.tray_clicked();
		});

		this.status_icon.popup_menu.connect((button, activate_time) => {
			//this.menu.popup(null, null, null, button, activate_time);
			this.menu.popup_at_pointer(null);
		});
	}

	/*
	@brief Создание контекстного меню для правой кнопки мыши
	*/
	private void create_menu() {
		this.menu = new Gtk.Menu();

		var settings_item = new Gtk.MenuItem.with_label("Настройки");
		settings_item.activate.connect(() => {
			this.settings_requested();
		});

		var exit_item = new Gtk.MenuItem.with_label("Выход");
		exit_item.activate.connect(() => {
			this.exit_requested();
		});

		this.menu.append(settings_item);
		this.menu.append(new Gtk.SeparatorMenuItem());
		this.menu.append(exit_item);
		this.menu.show_all();
	}

	public Gtk.StatusIcon get_icon() {
		return this.status_icon;
	}
}
