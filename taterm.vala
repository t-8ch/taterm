// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm : Gtk.Application
{
	public taterm()
	{
		this.application_id = "de.t-8ch.taterm";

		activate.connect(() => {
				add_window(new tatermWindow());
		});
	}


	public static int main(string[] args){

		Gtk.init(ref args);

		return new taterm().run();

	}

}

class tatermWindow : Gtk.Window
{

	Vte.Terminal term;

	string pwd = GLib.Environment.get_variable("HOME");
	GLib.Pid shell;

	public tatermWindow() {
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
		/* TODO
		   we should save the PID of the last active shell
		   and then get the CWD of this on
		*/
		term.window_title_changed.connect ( ()=> {
			this.title = term.window_title;
			pwd = tatermUtils.cwd_of_pid(shell);
		});
		this.add(term);
		this.show_all();
		Gtk.main();
	}
}

class tatermUtils
{
	public static string cwd_of_pid(GLib.Pid pid){
		var cwdlink = "/proc/%d/cwd".printf(pid);
		try {
			return GLib.FileUtils.read_link(cwdlink);
		} catch (Error err) {
			stderr.printf(err.message);
		}
		return GLib.Environment.get_variable("HOME");
	}
}
