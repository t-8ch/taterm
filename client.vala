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
		Gtk.init(ref args);

		Gtk.Application app = new Gtk.Application("de.t-8ch.test", 0);

		var status = app.run();

		return status;

	}
}
