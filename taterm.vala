/*    Copyright (c) 2012 Thomas Weißschuh
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

static const string FONT = "11";
static const string[] COLORS = {
	"#000000", "#c00000", "#00c000", "#c0c000",
	"#0000c0", "#c000c0", "#00c0c0", "#c0c0c0",
	"#3f3f3f", "#ff3f3f", "#3fff3f", "#ffff3f",
	"#3f3fff", "#ff3fff", "#3fffff", "#ffffff"
};

static const string FG_COLOR = "#c0c0c0";
static const string BG_COLOR = "#000000";

static const string WORD_CHARS = "-A-Za-z0-9_$.+!*(),;:@&=?/~#%";

static Pango.FontDescription font;
static Gdk.Color[] palette;
static Gdk.Color fg_color;
static Gdk.Color bg_color;

public static GLib.Regex uri_regex;

/*
	Credits: http://snipplr.com/view/6889/regular-expressions-for-uri-validationparsing/
*/
static const string hex_encode = "%[0-9A-F]{2}";
static const string common_chars = "\\\\a-z0-9-._~!$&'()*+,;=";
static const string regex_string =
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
		uri_regex = new GLib.Regex(regex_string, regex_flags);
	} catch (RegexError err) {
		GLib.assert_not_reached();
	}

	font = Pango.FontDescription.from_string(FONT);

	for (int i = 0; i < 16; i++) {
		Gdk.Color color = Gdk.Color();
		Gdk.Color.parse(COLORS[i], out color);
		palette += color;
	}
	Gdk.Color.parse(FG_COLOR, out fg_color);
	Gdk.Color.parse(BG_COLOR, out bg_color);

	return new Taterm().run();
}

class Taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();

	public Taterm()
	{
		Object(application_id: "de.t-8ch.taterm");

		activate.connect(() => {
			var new_win = new Window(pwd);
			add_window(new_win);
			new_win.focus_out_event.connect(() => {
				pwd = new_win.pwd;
				/* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
				return false;
			});
		}); // activate.connect()
	} // Taterm()

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

			focus_in_event.connect(() => {
				urgency_hint = false;
				/* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
				return false;
			});

			term.child_exited.connect(() => {
				destroy();
			});

			term.beep.connect(() => {
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
		} // Window()
	} // class Window

	class Terminal : Vte.Terminal
	{


		string match_uri = null;

		public Terminal()
		{
			set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
			scrollback_lines = -1; /* infinity */
			pointer_autohide = true;
			set_font(font);
			set_colors(fg_color, bg_color, palette);
			set_word_chars(WORD_CHARS);


			button_press_event.connect(handle_button);
			match_add_gregex(uri_regex, 0);
		}

		private bool handle_button(Gdk.EventButton event)
		{
			if (event.button == Gdk.BUTTON_PRIMARY) {
				check_regex(
						(long) event.x/get_char_width(),
						(long) event.y/get_char_height()
				);
			}
			/* continue calling signalhandlers, why should we stop? */
			/* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
			return false;
		}

		private void check_regex(long x_pos, long y_pos)
		{
			/*
			   this tag shouldn't be necessary but if we don't pass it to match_check()
			   the whole thing just segfaults
			*/
			int tag;
			match_uri = match_check(x_pos, y_pos, out tag);

			if (match_uri != null) {
				try {
					Gtk.show_uri(null, match_uri, Gdk.CURRENT_TIME);
				} catch (Error err) {
					stderr.printf(err.message);
				} finally {
					match_uri = null;
				}
			} // if
		} // check_regex
	} // class Terminal

	class Utils
	{
		public static string cwd_of_pid(GLib.Pid pid)
		{
			var cwdlink = @"/proc/$((int)pid)/cwd";
			try {
				return GLib.FileUtils.read_link(cwdlink);
			} catch (FileError err) {
				stderr.printf(err.message);
			}
			return GLib.Environment.get_home_dir();
		}
	} // class Utils
}
