// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_variable("HOME");

	public taterm()
	{
		Object(application_id: "de.t-8ch.taterm6");
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

		public signal void pwd_changed(string pwd);

		public Window(string pwd)
		{
			term = new Vte.Terminal();
			term.set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
			term.scrollback_lines = -1; /* infinity */
			this.maximize();
			string[] targs = { Vte.get_user_shell() };

			try {
				term.fork_command_full(0, pwd, targs, null, 0, null, out shell);
			} catch {}

			term.child_exited.connect ( ()=> {
				this.destroy();
			});

			term.window_title_changed.connect ( ()=> {
				this.title = term.window_title;
				var newpwd = Utils.cwd_of_pid(shell);

				if (newpwd != pwd) {
					pwd = newpwd;
					pwd_changed(pwd);
				}
			});

			this.add(term);
			this.show_all();
			// Gtk.main();
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
			return GLib.Environment.get_variable("HOME");
		}
	}
}
