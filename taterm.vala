// modules: vte-2.90

using GLib;
using Gtk;
using Vte;

class taterm
{
	public taterm()
	{
	}

	public static int main(string[] args){
		Gtk.init(ref args);

		Gtk.Application app = new Gtk.Application("de.t-8ch.taterm", 0);

		string pwd = "/";
		GLib.Pid lastforkcmd = 0;

		app.activate.connect(() => {
				var window = new Gtk.Window();
				var term = new Vte.Terminal();
				window.maximize();
				string[] targs = { Vte.get_user_shell() };
				try {
					term.fork_command_full(0, pwd, targs, null, 0, null, out lastforkcmd);
				} catch {}
				term.child_exited.connect ( ()=> {
					window.destroy();
				});
				term.window_title_changed.connect ( ()=> {
					pwd = cwd_of_pid(lastforkcmd);
				});
				window.add(term);
				window.show_all();
				Gtk.main();
				});

		var status = app.run();

		return status;

	}

	public static string cwd_of_pid(GLib.Pid pid){
		var cwdlink = "/proc/%d/cwd".printf(pid);
		try {
			return GLib.FileUtils.read_link(cwdlink);
		} catch (Error err) {
			stderr.printf(err.message);
		}
		return "/";
	}


}
