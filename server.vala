// modules: gtk-3.0

using GLib;
using Gtk;
using Vte;

class MyApp
{
	public MyApp()
	{
	}

	public static int main(string[] args)
	{
		var nr = 0;
		Gtk.init(ref args);

		Gtk.Application app = new Gtk.Application("de.t-8ch.test", 0);

		Gtk.Window window = new Gtk.Window();
		var term = new Vte.Terminal();
		window.add(term);

		app.activate.connect(()=> {
			stdout.printf("Server: client no %d\n", ++nr);
			term.feed_child("fooooobar", 10);
		});

		window.show_all();
		Gtk.main();

		return 0;

	}
}
