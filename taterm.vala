// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();
	public static GLib.Regex uri_regex;

	/*
		Credits: http://snipplr.com/view/6889/regular-expressions-for-uri-validationparsing/
	*/
	static const string hex_encode = "%[0-9A-F]{2}";
	static const string common_chars = "\\\\a-z0-9-._~!$&'()*+,;=";
	static const string regex_string =
		"([a-z0-9][a-z0-9+.-]+):" +								// scheme
		"(//)?" +												//it has an authority
		"(([:"+common_chars+"]|"+hex_encode+")*@)?" +			//userinfo
		"(["+common_chars+"]|"+hex_encode+")*" +				//host
		"(:\\d{1,5})?" +										//port
		"(/([:@/"+common_chars+")]|"+hex_encode+")*)?" +		//path

		// v  be flexible with shell escaping here
		"(\\\\?\\?(["+common_chars+":/?@]|"+hex_encode+")*)?" +	//query string
		"(\\\\?\\#(["+common_chars+"+:/?@]|"+hex_encode+")*)?"	//fragment
		;

	public taterm()
	{
		Object(application_id: "de.t-8ch.taterm");

		try {
			var regex_flags = RegexCompileFlags.CASELESS + RegexCompileFlags.OPTIMIZE;
			uri_regex = new GLib.Regex(regex_string, regex_flags);
		} catch {}

		activate.connect(() => {
			var newWin = new Window(pwd);
			add_window(newWin);
			newWin.focus_out_event.connect(() => {
				pwd = newWin.pwd;
				return false;
			});
		});
	}

	public static int main(string[] args)
	{
		Gtk.init(ref args);
		return new taterm().run();
	}

	class Window : Gtk.Window
	{
		Vte.Terminal term;
		GLib.Pid shell;
		public string pwd;
		string[] targs;

		public signal void pwd_changed(string pwd);

		public Window(string pwd)
		{
			this.pwd = pwd;

			term = new Terminal();

			has_resize_grip = false;
			targs = { Vte.get_user_shell() };

			try {
				term.fork_command_full(0, pwd, targs, null, 0, null, out shell);
			} catch (Error err) {
				stderr.printf(err.message);
			}

			term.child_exited.connect ( ()=> {
				destroy();
			});

			term.window_title_changed.connect ( ()=> {
				title = term.window_title;
				var newpwd = Utils.cwd_of_pid(shell);

				if (newpwd != pwd) {
					this.pwd = newpwd;
					pwd_changed(this.pwd);
				}
			});

			add(term);
			show_all();
		}
	}

	class Terminal : Vte.Terminal
	{


		string match_uri = null;

		public Terminal()
		{
			set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
			scrollback_lines = -1; /* infinity */

			button_press_event.connect(check_regex);
			match_add_gregex(uri_regex, 0);
		}

		private bool check_regex(Gdk.EventButton event)
		{
			/* left mousebutton ? */
			if (event.button == 1) {
				var x_pos = event.x / get_char_width();
				var y_pos = event.y / get_char_height();
				/*
				   this tag shouldn't be necessary but if we don't pass it to match_check()
				   the whole thing just segfaults
				*/
				int tag;
				match_uri = match_check((long) x_pos, (long) y_pos, out tag);

				if (match_uri != null) {
					try {
						/* TODO
						 Maybe people don't want to call xdg-open
						*/
						GLib.Process.spawn_command_line_async(@"xdg-open $(match_uri)");
					} catch (Error err) {
						stderr.printf(err.message);
					} finally {
						match_uri = null;
					}
				}
			}
			/* continue calling signalhandlers, why should we stop? */
			return false;
		}
	}

	class Utils
	{
		public static string cwd_of_pid(GLib.Pid pid)
		{
			var cwdlink = @"/proc/$((int)pid)/cwd";
			try {
				return GLib.FileUtils.read_link(cwdlink);
			} catch (Error err) {
				stderr.printf(err.message);
			}
			return GLib.Environment.get_home_dir();
		}
	}
}
