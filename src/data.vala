using GLib;

/*
@brief Структура для передачи данных в интерфейс
*/
public struct ClipItem {
	public string text;
	public string preview;
}

/*
@brief Модуль управления данными буфера обмена
*/
public class ClipData {
	private ClipDatabase db;
	public List<string> favorites;
	public List<string> history;
	private GenericSet<string> favorites_set;
	private GenericSet<string> history_set;
	public int max_items { get; private set; }
	public bool show_footer { get; private set; }

	/*
	@brief Обновляет состояние видимости футера в памяти и БД
	переменная visible - новое состояние
	*/
	public void update_footer_setting(bool visible) {
		this.show_footer = visible;
		db.update_setting("show_footer", visible.to_string());
	}

	public ClipData(ClipDatabase database) {
		this.db = database;

		List<string> favs_list;
		List<string> hist_list;
		int limit;
		bool footer_vis;

		this.db.load_data(out favs_list, out hist_list, out limit, out footer_vis);

		this.favorites = (owned) favs_list;
		this.history = (owned) hist_list;
		this.max_items = limit;
		this.show_footer = footer_vis;

		this.favorites_set = new GenericSet<string>(str_hash, str_equal);
		foreach (unowned string s in favorites) {
			favorites_set.add(s);
		}

		this.history_set = new GenericSet<string>(str_hash, str_equal);
		foreach (unowned string s in history) {
			history_set.add(s);
		}
	}

	private List<string> enforce_limit() {
		var removed_items = new List<string>();
		while (history.length() > (uint)max_items) {
			unowned string item = history.last().data;
			history_set.remove(item);
			removed_items.append(item);
			history.delete_link(history.last());
		}
		return removed_items;
	}

	public string? add_to_history(string text) {
		if (favorites_set.contains(text)) {
			return null;
		}

		if (history_set.contains(text)) {
			// Удаление старой копии по значению
			unowned List<string> node = history.find_custom(text, (CompareFunc)strcmp);
			if (node != null) {
				history.remove_link(node);
			}
		} else {
			history_set.add(text);
		}

		history.insert(text, 0);

		List<string> removed_list = enforce_limit();

		db.save_history_item(text);

		if (removed_list.length() > 0) {
			db.delete_items("history", removed_list);
			return removed_list.nth_data(0);
		}

		return null;
	}

	public void toggle_favorite(string text) {
		if (favorites_set.contains(text)) {
			// Избранное -> История
			unowned List<string> node = favorites.find_custom(text, (CompareFunc)strcmp);
			if (node != null) {
				favorites.remove_link(node);
			}
			favorites_set.remove(text);

			history.insert(text, 0);
			history_set.add(text);

			db.move_from_favorites(text);

			List<string> removed = enforce_limit();
			if (removed.length() > 0) {
				db.delete_items("history", removed);
			}
		} else {
			// История -> Избранное
			if (history_set.contains(text)) {
				unowned List<string> node = history.find_custom(text, (CompareFunc)strcmp);
				if (node != null) {
					history.remove_link(node);
				}
				history_set.remove(text);
			}

			favorites.append(text);
			favorites_set.add(text);
			db.move_to_favorites(text);
		}
	}

	public bool update_limit(int new_limit) {
		this.max_items = new_limit;
		db.update_setting("max_items", new_limit.to_string());

		List<string> removed = enforce_limit();
		if (removed.length() > 0) {
			db.delete_items("history", removed);
			return true;
		}
		return false;
	}

	public void clear(bool all_data = false) {
		history = new List<string>();
		history_set = new GenericSet<string>(str_hash, str_equal);

		if (all_data) {
			favorites = new List<string>();
			favorites_set = new GenericSet<string>(str_hash, str_equal);
		}

		db.clear_tables(all_data);
	}

	public delegate string PreviewFunc(string text);

	public void get_ui_lists(PreviewFunc preview_func, out List<ClipItem?> fav_previews, out List<ClipItem?> hist_previews) {
		fav_previews = new List<ClipItem?>();
		hist_previews = new List<ClipItem?>();

		foreach (unowned string t in favorites) {
			fav_previews.append({t, preview_func(t)});
		}
		foreach (unowned string t in history) {
			hist_previews.append({t, preview_func(t)});
		}
	}
}
