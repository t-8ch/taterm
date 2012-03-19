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

public static int main(string[] args)
{
	Gtk.init(ref args);
	return new taterm().run();
}

class taterm : Gtk.Application
{
	string pwd = GLib.Environment.get_home_dir();
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

	public taterm()
	{
		Object(application_id: "de.t-8ch.taterm");

		try {
			var regex_flags = RegexCompileFlags.CASELESS + RegexCompileFlags.OPTIMIZE;
			uri_regex = new GLib.Regex(regex_string, regex_flags);
		} catch (RegexError err) {
			GLib.assert_not_reached ();
		}

		activate.connect(() => {
			var newWin = new Window(pwd);
			add_window(newWin);
			newWin.focus_out_event.connect(() => {
				pwd = newWin.pwd;
				/* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
				return false;
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

			has_resize_grip = false;
			targs = { Vte.get_user_shell() };

			try {
				term.fork_command_full(0, pwd, targs, null, 0, null, out shell);
			} catch (Error err) {
				stderr.printf(err.message);
			}

			this.focus_in_event.connect( () => {
				this.urgency_hint = false;
				/* TODO change to GDK_EVENT_PROPAGATE, when .vapi provides it */
				return false;
			});

			term.child_exited.connect ( ()=> {
				destroy();
			});

			term.beep.connect( () => {
				this.urgency_hint = true;
			});

			term.window_title_changed.connect ( ()=> {
				title = term.window_title;
				var newpwd = Utils.cwd_of_pid(shell);

				if (newpwd != pwd) {
					this.pwd = newpwd;
					pwd_changed(this.pwd);
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
			set_cursor_blink_mode(Vte.TerminalCursorBlinkMode.OFF);
			scrollback_lines = -1; /* infinity */
			/* TODO use property when available */
			set_mouse_autohide(true);
			/* TODO remove when it gets detected again (VTE 0.32.0) */
			emulation = "xterm";

			button_press_event.connect(handle_button);
			match_add_gregex(uri_regex, 0);
		}

		private bool handle_button(Gdk.EventButton event){
			/* left mousebutton ? */
			/* TODO use Gdk.BUTTON_PRIMARY when available */
			if (event.button == 1) {
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
			match_uri = match_check( x_pos, y_pos, out tag);

			if (match_uri != null) {
				try {
					/* TODO
					 Maybe people don't want to call xdg-open
					*/
					GLib.Process.spawn_command_line_async(@"xdg-open $(match_uri)");
				} catch (SpawnError err) {
					stderr.printf(err.message);
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
				stderr.printf(err.message);
			}
			return GLib.Environment.get_home_dir();
		}
	}
}
