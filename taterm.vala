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

const string FONT = "17";
const double FONT_SCALE_STEP = 0.1;
const string[] COLORS = {
	"#073642", "#dc322f", "#859900", "#b58900",
	"#268bd2", "#d33682", "#2aa198", "#eee8d5",
	"#002b36", "#cb4b16", "#586e75", "#657b83",
	"#839496", "#6c71c4", "#939191", "#fdf6e3"
};

const string FG_COLOR = "#657b83";
const string BG_COLOR = "#002b36";

static Pango.FontDescription font;
static Gdk.RGBA[] palette;
static Gdk.RGBA fg_color;
static Gdk.RGBA bg_color;

const uint PCRE2_CASELESS = 0x00000008u;
const uint PCRE2_MULTILINE = 0x00000400u;
public static Vte.Regex uri_regex;

// generated with get-uri-regex.c from terminal-regex.h from Gnome Terminal 3.38.1
const string regex_string = """(?<APOS_START>(?<='))?(?(DEFINE)(?<S4>(?x: (?: [0-9] | [1-9][0-9] | 1[0-9]{2} | 2[0-4][0-9] | 25[0-5] ) (?! [0-9] ) )))(?(DEFINE)(?<IPV4>(?x: (?: (?&S4) \. ){3} (?&S4) )))(?(DEFINE)(?<S6>[[:xdigit:]]{1,4})(?<CS6>:(?&S6))(?<S6C>(?&S6):))(?(DEFINE)(?<IPV6>(?x: (?: (?x: :: ) | (?x: : (?&CS6){1,7} ) | (?x: (?! (?: [[:xdigit:]]*: ){8} ) (?&S6C){1,6} (?&CS6){1,6} ) | (?x: (?&S6C){1,7} : ) | (?x: (?&S6C){7} (?&S6) ) | (?: (?x: (?&S6C){6} ) | (?x: :: (?&S6C){0,5} ) | (?x: (?! (?: [[:xdigit:]]*: ){7} ) (?&S6C){1,4} (?&CS6){1,4} ) : | (?x: (?&S6C){1,5} : ) ) (?&IPV4) ) (?! [.:[:xdigit:]] ) )))(?(DEFINE)(?<PATH_INNER>(?x: (?: [-[:alnum:]\Q_$.+!*,:;@&=?/~#|%'\E]* (?: \( (?&PATH_INNER) \) | \[ (?&PATH_INNER) \] ) )* [-[:alnum:]\Q_$.+!*,:;@&=?/~#|%'\E]* )))(?(DEFINE)(?<PATH>(?x: (?: [-[:alnum:]\Q_$.+!*,:;@&=?/~#|%'\E]* (?: \( (?&PATH_INNER) \) | \[ (?&PATH_INNER) \] ) )* (?: [-[:alnum:]\Q_$.+!*,:;@&=?/~#|%'\E]* (?(<APOS_START>)[-[:alnum:]\Q_$+*:@&=/~#|%\E]|[-[:alnum:]\Q_$+*:@&=/~#|%'\E]) )? )))(?ix: news | telnet | nntp | https? | ftps? | sftp | webcal )://(?:[-+.[:alnum:]]+(?x: :[-[:alnum:]\Q,?;.:/!%$^*&~"#'\E]* )?@)?(?x: (?x: (?: (?x: [-[:alnum:]] | (?! [[:ascii:]] ) [[:graph:]] )+ \. )* (?x: [-[:alnum:]] | (?! [[:ascii:]] ) [[:graph:]] )* (?! [0-9] ) (?x: [-[:alnum:]] | (?! [[:ascii:]] ) [[:graph:]] )+ ) | (?&IPV4) | \[ (?&IPV6) \] )(?x: \:(?x: (?: [1-9][0-9]{0,3} | [1-5][0-9]{4} | 6[0-4][0-9]{3} | 65[0-4][0-9]{2} | 655[0-2][0-9] | 6553[0-5] ) (?! [0-9] ) ) )?(?x: /(?&PATH) )?""";

public static int main(string[] args)
{
	try {
		uri_regex = new Vte.Regex.for_match(regex_string, regex_string.length, PCRE2_CASELESS | PCRE2_MULTILINE);
		uri_regex.jit(0);
	} catch (GLib.Error e) {
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
		Object(application_id: "de.t-8ch.taterm");

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
			decorated = false;
			this.pwd = pwd;

			term = new Terminal(this);

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
		Gtk.Window window;

		public Terminal(Gtk.Window window)
		{
			this.window = window;
			cursor_blink_mode = Vte.CursorBlinkMode.OFF;
			scrollback_lines = -1; /* infinity */
			pointer_autohide = true;
			set_font(font);
			set_colors(fg_color, bg_color, palette);

			key_press_event.connect(handle_key);
			button_press_event.connect(handle_button);
			match_add_regex(uri_regex, 0);
		}

		private bool handle_key(Gdk.EventKey event)
		{
			bool handled = false;

			if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
				switch (event.keyval) {
					case Gdk.Key.minus:
						font_scale /= 1 + FONT_SCALE_STEP;
						handled = true;
						break;
					case Gdk.Key.plus:
						font_scale *= 1 + FONT_SCALE_STEP;
						handled = true;
						break;
					case Gdk.Key.@0:
						font_scale = 1;
						handled = true;
						break;
				}
			}

			return handled ? Gdk.EVENT_STOP : Gdk.EVENT_PROPAGATE;
		}

		private bool handle_button(Gdk.EventButton event)
		{
			switch (event.button) {
				case Gdk.BUTTON_PRIMARY:
					check_regex(event);
					return Gdk.EVENT_PROPAGATE;
				case Gdk.BUTTON_MIDDLE:
					
					return Gdk.EVENT_PROPAGATE;
			}
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
					Gtk.show_uri_on_window(window, match_uri, event.time);
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
