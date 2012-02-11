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

		app.activate.connect(() => {
				var window = new Gtk.Window();
				var term = new Vte.Terminal();
				string[] targs = { Vte.get_user_shell() };
				try {
					term.fork_command_full(0, null, targs, null, 0, null, null);
				} catch {}
				term.child_exited.connect ( ()=> {
					window.destroy();
				});
				window.add(term);
				window.show_all();
				Gtk.main();
				});

		var status = app.run();

		return status;

	}
}