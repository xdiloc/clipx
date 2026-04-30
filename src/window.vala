using Gtk;
using Gdk;

/*
@brief Окно списка буфера обмена (аналог window.py)
*/
public class ClipWindow : Gtk.Window {
	private ListBox listbox;
	private Box main_box;
	public Box footer_box;
	public Separator footer_sep;

	// Сигналы для связи с главным контроллером
	public signal void app_copy(string text);
	public signal void app_fav(string text);
	public signal void app_settings();
	public signal void app_exit();

	/*
	@brief Управляет видимостью нижней панели управления
	переменная visible - флаг видимости
	*/
	public void set_footer_visible(bool visible) {
		this.footer_box.visible = visible;
		this.footer_sep.visible = visible;
	}

	/*
	@brief Инициализация окна в стиле POPUP
	*/
	public ClipWindow() {
		Object(type: Gtk.WindowType.POPUP);
		this.set_border_width(1);
		this.set_size_request(300, -1);

		main_box = new Box(Orientation.VERTICAL, 0);
		this.add(main_box);

		this.listbox = new ListBox();
		this.listbox.set_selection_mode(SelectionMode.NONE);
		this.listbox.row_activated.connect(on_row_activated);
		main_box.pack_start(this.listbox, true, true, 0);

		add_footer();

		this.focus_out_event.connect((event) => {
			hide_window();
			return true;
		});

		this.button_press_event.connect((event) => {
			Allocation allocation;
			this.get_allocation(out allocation);
			if (!(event.x >= 0 && event.x <= allocation.width && event.y >= 0 && event.y <= allocation.height)) {
				hide_window();
			}
			return false;
		});
	}

	/*
	@brief Обновление контента списка
	favorites/history теперь содержат ClipItem? (boxing для List)
	*/
	public void update_content(List<ClipItem?> favorites, List<ClipItem?> history, string? current_text = null) {
		var children = this.listbox.get_children();
		foreach (var child in children) {
			child.destroy();
		}

		if (favorites.length() == 0 && history.length() == 0) {
			var empty_lbl = new Label("Нет записей");
			empty_lbl.set_halign(Align.CENTER);
			empty_lbl.set_valign(Align.CENTER);
			empty_lbl.margin_top = 10;
			empty_lbl.margin_bottom = 10;
			empty_lbl.set_sensitive(false);
			this.listbox.add(empty_lbl);
		} else {
			// Используем unowned для итерации по упакованным структурам
			foreach (unowned ClipItem? item in favorites) {
				if (item != null) add_list_row(item.text, item.preview, true);
			}

			foreach (unowned ClipItem? item in history) {
				if (item != null) add_list_row(item.text, item.preview, false);
			}
		}

		// Важно: показываем само окно и принудительно обновляем видимость строк списка
		this.show();
		this.listbox.show_all();
	}

	private void add_list_row(string text, string preview, bool is_fav) {
		var row = new ListBoxRow();
		var box = new Box(Orientation.HORIZONTAL, 0);

		var lbl = new Label(preview);
		lbl.set_xalign(0);
		lbl.margin_start = 6;
		lbl.margin_end = 6;
		lbl.margin_top = 2;
		lbl.margin_bottom = 2;

		var star_btn = new Button();
		var star_lbl = new Label(is_fav ? "★" : "☆");
		star_btn.tooltip_text = is_fav ? "Открепить элемент" : "Закрепить элемент";
		star_lbl.set_padding(0, 0);

		star_btn.add(star_lbl);
		star_btn.set_size_request(2, 2);
		star_btn.set_relief(ReliefStyle.NONE);
		star_btn.set_can_focus(false);

		star_btn.clicked.connect(() => {
			this.app_fav(text);
		});

		box.pack_start(lbl, true, true, 0);
		box.pack_end(star_btn, false, false, 5);

		row.add(box);
		row.set_data<string>("clipboard_text", text);
		this.listbox.add(row);
	}

	private void add_footer() {
		this.footer_sep = new Separator(Orientation.HORIZONTAL);
		main_box.pack_start(this.footer_sep, false, false, 0);
		this.footer_box = new Box(Orientation.HORIZONTAL, 0);

		var settings_btn = new Button.from_icon_name("preferences-system", IconSize.BUTTON);
		settings_btn.set_relief(ReliefStyle.NONE);
		settings_btn.tooltip_text = "Настройки приложения";
		settings_btn.clicked.connect(() => { this.app_settings(); });

		var exit_btn = new Button.with_label("Выход");
		exit_btn.set_relief(ReliefStyle.NONE);
		exit_btn.clicked.connect(() => { this.app_exit(); });

		footer_box.pack_start(settings_btn, false, false, 5);
		footer_box.pack_end(exit_btn, false, false, 5);
		main_box.pack_start(footer_box, false, false, 2);

		// По умолчанию кнопки в футере должны быть готовы к показу
		footer_box.show_all();
	}

	private void on_row_activated(ListBoxRow row) {
		string? text = row.get_data<string>("clipboard_text");
		if (text != null) {
			this.app_copy(text);
		}
		hide_window();
	}

	public void hide_window() {
		var display = Display.get_default();
		var seat = display.get_default_seat();
		if (seat != null) seat.ungrab();
		this.hide();
	}

	public void popup(StatusIcon tray_icon) {
		this.show();
		this.main_box.show();
		this.listbox.show_all();
		this.resize(300, 1);

		while (Gtk.events_pending()) {
			Gtk.main_iteration();
		}

		Rectangle area;
		Orientation orientation;
		Gdk.Screen temp_screen;

		bool success = tray_icon.get_geometry(out temp_screen, out area, out orientation);

		int window_width, window_height;
		this.get_size(out window_width, out window_height);
		int offset = 10;

		var display = Display.get_default();
		var monitor = display.get_monitor_at_point(area.x, area.y);
		Rectangle workarea = monitor.get_workarea();

		int x, y;

		if (success) {
			if (orientation == Orientation.VERTICAL) {
				y = area.y + (area.height / 2) - (window_height / 2);
				x = (area.x < workarea.width / 2) ? area.x + area.width + offset : area.x - window_width - offset;
			} else {
				x = area.x + (area.width / 2) - (window_width / 2);
				y = (area.y < workarea.height / 2) ? area.y + area.height + offset : area.y - window_height - offset;
			}
		} else {
			Gdk.Screen p_screen;
#if VALA_0_32
			display.get_default_seat().get_pointer().get_position(out p_screen, out x, out y);
#else
			display.get_device_manager().get_client_pointer().get_position(out p_screen, out x, out y);
#endif
			x -= window_width / 2;
			y += offset;
		}

		x = x.clamp(workarea.x, workarea.x + workarea.width - window_width);
		y = y.clamp(workarea.y, workarea.y + workarea.height - window_height);

		this.move(x, y);

		var seat = display.get_default_seat();
		if (seat != null) {
			seat.grab(this.get_window(), SeatCapabilities.ALL, true, null, null, null);
			this.present();
			this.grab_focus();
		}
	}
}
