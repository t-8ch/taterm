/*    Copyright (c) 2012, 2013, 2014 Thomas Weißschuh
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// modules: vte-2.90

using GLib;
using Gtk;
using Vte;
using Pango;

const string FONT = "11";
const string[] COLORS = {
	"#000000", "#c00000", "#00c000", "#c0c000",
	"#0000c0", "#c000c0", "#00c0c0", "#c0c0c0",
	"#3f3f3f", "#ff3f3f", "#3fff3f", "#ffff3f",
	"#3f3fff", "#ff3fff", "#3fffff", "#ffffff"
};

const string FG_COLOR = "#c0c0c0";
const string BG_COLOR = "#000000";

static Pango.FontDescription font;
static Gdk.RGBA[] palette;
static Gdk.RGBA fg_color;
static Gdk.RGBA bg_color;

public static Vte.Regex uri_regex;

/*
	Credits: http://snipplr.com/view/6889/regular-expressions-for-uri-validationparsing/
*/
const string hex_encode = "%[0-9A-F]{2}";
const string common_chars = "\\\\a-z0-9-._~!$&'()*+,;=";
const string regex_string =
	"([a-z0-9][a-z0-9+.-]+):"                               + // scheme
	"(//)?"                                                 + // it has an authority
	"(([:"+common_chars+"]|"+hex_encode+")*@)?"             + // userinfo
	"(["+common_chars+"]|"+hex_encode+"){3,}"               + // host
	"(:\\d{1,5})?"                                          + // port
	"(/([:@/"+common_chars+")]|"+hex_encode+")*)?"          + // path
	// v  be flexible with shell escaping here
	"(\\\\?\\?(["+common_chars+":/?@]|"+hex_encode+")*)?"   + // query string
	"(\\\\?\\#(["+common_chars+"+:/?@]|"+hex_encode+")*)?"  + // fragment
	"(?=[\\s)}>\"\',;])"                                      // look ahead
	;

public static int main(string[] args)
{
	try {
		var regex_flags = RegexCompileFlags.CASELESS | RegexCompileFlags.OPTIMIZE;
		uri_regex = new Vte.Regex.for_match(regex_string, regex_string.length, regex_flags);
	} catch (GLib.Error err) {
		GLib.assert_not_reached();
	}

	font = Pango.FontDescription.from_string(FONT);

	for (int i = 0; i < COLORS.length; i++) {
		Gdk.RGBA color = Gdk.RGBA();
		color.parse(COLORS[i]);
		palette += color;
	}
	fg_color.parse(FG_COLOR);
	bg_color.parse(BG_COLOR);

	return new Taterm().run();
}

class Taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();

	public Taterm()
	{
		Object(application_id: "de.t-8ch.tatermxxx");

		activate.connect(() => {
			var new_win = new Window(pwd);
			add_window(new_win);
			new_win.focus_out_event.connect(() => {
				pwd = new_win.pwd;
				return Gdk.EVENT_PROPAGATE;
			});
		});
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

			targs = { Vte.get_user_shell() };

			try {
				term.spawn_sync(Vte.PtyFlags.DEFAULT, pwd, targs, null, 0, null, out shell);
			} catch (Error err) {
				stderr.printf("%s\n", err.message);
			}

			focus_in_event.connect(() => {
				urgency_hint = false;
				return Gdk.EVENT_PROPAGATE;
			});

			term.child_exited.connect(() => {
				destroy();
			});

			term.bell.connect(() => {
				urgency_hint = true;
			});

			term.window_title_changed.connect(() => {
				title = term.window_title;
				var newpwd = Utils.cwd_of_pid(shell);

				if (newpwd != this.pwd) {
					this.pwd = newpwd;
					pwd_changed(newpwd);
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
			cursor_blink_mode = Vte.CursorBlinkMode.OFF;
			scrollback_lines = -1; /* infinity */
			pointer_autohide = true;
			set_font(font);
			set_colors(fg_color, bg_color, palette);

			button_press_event.connect(handle_button);
			match_add_regex(uri_regex, 0);
		}

		private bool handle_button(Gdk.EventButton event)
		{
			if (event.button == Gdk.BUTTON_PRIMARY) {
				check_regex(event);
			}
			/* continue calling signalhandlers, why should we stop? */
			return Gdk.EVENT_PROPAGATE;
		}

		private void check_regex(Gdk.EventButton event)
		{
			/*
			   this tag shouldn't be necessary but if we don't pass it to match_check()
			   the whole thing just segfaults
			*/
			int tag;
			match_uri = match_check_event(event, out tag);

			if (match_uri != null) {
				try {
					Gtk.show_uri_on_window(null, match_uri, Gdk.CURRENT_TIME);
				} catch (Error err) {
					stderr.printf("%s\n", err.message);
				} finally {
					match_uri = null;
				}
			}
		}
	}

	class Utils
	{
		public static string cwd_of_pid(GLib.Pid pid)
		{
			var cwdlink = @"/proc/$((int)pid)/cwd";
			try {
				return GLib.FileUtils.read_link(cwdlink);
			} catch (FileError err) {
				stderr.printf("%s\n", err.message);
			}
			return GLib.Environment.get_home_dir();
		}
	}
}
