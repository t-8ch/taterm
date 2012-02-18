// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();

	public taterm()
	{
		Object(application_id: "de.t-8ch.taterm5");
		hold();

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

		/* TODO: split regex string */
					/*    scheme             user      host  port     path  query   part*/
		static string regex_string = "[a-z][a-z+.-]+:[//]?.+(:?.*@)?.*(:\\d{1-5})?(/.*)*(\\?.*)?(#\\w*)?";
		/* TODO                    don't match '/' here   ^   */
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
				match_uri = this.match_check((long) x_pos, (long) y_pos, null);

				if (match_uri != null) {
					try {
						/* TODO
						 Maybe people don't want to call xdg-open
						*/
						GLib.Process.spawn_command_line_async(@"zenity --info --text=$match_uri");
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
