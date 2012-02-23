// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();

	public taterm()
	{
		Object(application_id: "de.t-8ch.taterm");

		activate.connect(() => {
			var newWin = new Window(pwd);
			add_window(newWin);
			newWin.pwd_changed.connect((newpwd) => {
				this.pwd = newpwd;
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
		string pwd;
		string[] targs;

		public signal void pwd_changed(string pwd);

		public Window(string pwd)
		{
			this.pwd = pwd;

			term = new Terminal();

			this.has_resize_grip = false;
			targs = { Vte.get_user_shell() };

			try {
				term.fork_command_full(0, pwd, targs, null, 0, null, out shell);
			} catch (Error err) {
				stderr.printf(err.message);
			}

			term.child_exited.connect ( ()=> {
				this.destroy();
			});

			term.window_title_changed.connect ( ()=> {
				this.title = term.window_title;
				var newpwd = Utils.cwd_of_pid(shell);

				if (newpwd != pwd) {
					this.pwd = newpwd;
					pwd_changed(this.pwd);
				}
			});

			this.add(term);
			this.show_all();
		}
	}

	class Terminal : Vte.Terminal
	{

		/*
			TODO
			FIXME
			IMPORTANT

			Move regex stuff away from here!!!
			and fix g_strconcat in C-code
		*/
		/*
			Credits: http://snipplr.com/view/6889/regular-expressions-for-uri-validationparsing/
		*/
		static string hex_encode = "%[0-9A-F]{2}";
		static string common_chars = "a-z0-9-._~!$&'()*+,;=";
		static string regex_string = 	"([a-z0-9+.-]+):" + // scheme
							"//" + //it has an authority
							@"(([:$(common_chars)]|$(hex_encode))*@)?" +	//userinfo
							@"([$(common_chars)]|$(hex_encode))*" +			//host
							"(:\\d{1,5})?" +						//port
							@"(/([:@/$(common_chars)]|$(hex_encode))*)?" +	//path

							//"|" + //it doesn't have an authority:
							//"(/?(?:[a-z0-9-._~!$&'()*+,;=:@]|%[0-9A-F]{2})+(?:[a-z0-9-._~!$&'()*+,;=:@/]|%[0-9A-F]{2})*)?" +	//path

							// v  be flexible with shell escaping here
							@"\\\\?\\?([$(common_chars):/?@]|$(hex_encode))*" +	//query string
							@"(\\\\?\\#([$(common_chars):/?@]|$(hex_encode))*)?"//fragment
						;

		string match_uri = null;
		GLib.Regex uri_regex;

		public Terminal()
		{
			set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
			this.scrollback_lines = -1; /* infinity */

			try {
				/* TODO
				 Do this only one time, it's allways the same
				*/
				uri_regex = new GLib.Regex(regex_string);
			} catch (Error err) {
				stderr.printf(err.message);
			}
			this.button_press_event.connect(check_regex);
			this.match_add_gregex(uri_regex, 0);
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
				match_uri = this.match_check((long) x_pos, (long) y_pos, out tag);

				if (match_uri != null) {
					try {
						/* TODO
						 Maybe people don't want to call xdg-open
						*/
						GLib.Process.spawn_command_line_async(@"xdg-open $match_uri");
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
			var cwdlink = "/proc/%d/cwd".printf(pid);
			try {
				return GLib.FileUtils.read_link(cwdlink);
			} catch (Error err) {
				stderr.printf(err.message);
			}
			return GLib.Environment.get_home_dir();
		}
	}
}
