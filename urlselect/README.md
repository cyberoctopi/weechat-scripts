urlselect
=================================================================================

A bar for selecting URLs from current buffer. Requires Weechat 0.4.4 or higher.

![screenshot][]

[screenshot]: http://i.imgur.com/2NirRu2.png

*URL selection bar on top of weechat with the help bar showing list of
available key bindings*


### Usage

Simply run `/urlselect` to activate URL selection bar. You can use
up/down arrow keys to navigate between URLs. Press F1 to see the list of keys
and custom commands (see **Custom Commands** below). It's recommended to bind
`/urlselect` to a key so it can be easily activated. For example, to use
Alt-Enter run the following command in Weechat:

    /key bind meta-ctrl-M /urlselect


### Search

You can enable the search feature by pressing Ctrl-F. Another bar will appear
where you can input a keyword. By default, script will search the first matching
entry from the current position and move backward until the first entry. To
change the search direction simply press up/down arrow key. You can change the
search scope by pressing Tab.


### Custom Commands

You can bind a single key digit (0-9) or lowercase alphabet (a-z) to a custom
Weechat command. When the selection bar is active, you can run these commands
by pressing Alt followed by the key. The syntax to bind a key is:

    /urlselect bind <key> <command>

You can use the following variables inside a command: `${url}`, `${time}`,
`${index}`, `${nick}`, `${message}`, `${buffer_name}`, `${buffer_full_name}`,
`${buffer_short_name}`, and `${buffer_number}`. They will be replaced by their
actual values from the currently selected URL.

For example, to bind Alt-V to view the raw content of a URL inside Weechat you
can use:

    /urlselect bind v /exec -noln -nf url:${url}


To remove a custom command, simply unbind its key:

    /urlselect unbind <key>

Two custom commands are already set by default. `o` for (xdg-)open and `i` for
inserting the URL into input bar. You can unbind these keys or set it into
something else with the above commands.

To see a list of available custom commands, you can press F1 while the URL
selection bar is active.

You can execute custom command without activating selection bar. Just call
`/urlselect run` followed by either a `<key>` character that has been bound
using `/urlselect bind` or a normal WeeChat command. For example:

    /urlselect run o
    /urlselect run /print -core ${nick} wants you to visit ${url}

The URL that will be used when selection bar is not active is the last URL in a
buffer/merged buffers.

### Bar & Bar Items

This script will create 3 bars and 11 bar items. The first bar is called
`urlselect`. This bar is used for displaying the info about currently selected
URL. Its settings are available under `weechat.bar.urlselect.*`. The second bar
is for showing the list of keys and custom commands. It is called
`urlselect_help` and its settings are available under
`weechat.bar.urlselect_help.*`. The last bar is `urlselect_search` and you can
see its settings under `weechat.bar.urlselect_search.*`. All three bars are
hidden by default.

The list of bar items are:

- **urlselect_index**: Index of URL.

- **urlselect_nick**: The nickname who mentioned the URL. If no nickname
  available, this will contain an asterisk.

- **urlselect_time**: The time of message containing the URL.

- **urlselect_url**: The actual URL portion of message.

- **urlselect_message**: Message with its original colors (if there's any)
  stripped and the URL portion highlighted.

- **urlselect_buffer_name**: Name of buffer where the message containing the
  current URL is from. This is probably only useful in merged buffers.

- **urlselect_buffer_number**: Buffer number.

- **urlselect_title**: Bar title. The one that says, `urlselect: <F1> toggle help`.

- **urlselect_help**: Help text for showing keys and list of custom commands.

- **urlselect_status**: Status notification. Visible when certain activity occur.
  For example, running a custom command.

- **urlselect_search**: Search prompt.

- **urlselect_duplicate**: If a URL appear several times, this will contain list
  of duplicate indexes.


### HSignal

This script can send a hsignal `urlselect_current` when you press Ctrl-S. The
hashtable sent with the signal has the following fields: `url`, `index`, `time`,
`message`, `nick`, `buffer_number`, `buffer_name`, `buffer_full_name`,
and `buffer_short_name`.


### Remembered URLs

When you run a custom command on selected URL, it will be added to list of
remembered URLs (similar to visited links in web browser). These remembered
URLs will be marked with different color (underlined magenta) in the selection
bar.

You can exclude remembered URLs so it won't be listed on selection bar by
setting `plugins.var.lua.skip_remember` to `1`.

To see list of all remembered URLs, you can use command `/urlselect remember`
and to clear it you can use `/urlselect forget`.


### Key Bindings

##### Keys on normal mode

Key         | Action
------------|--------------------------------------------------------------------
Ctrl-C      | Close the URL selection bar
Ctrl-F      | Toggle search bar
Up          | Select previous URL
Down        | Select next URL
Home        | Select the first (oldest) URL
End         | Select the last (newest) URL
Ctrl-P      | Select previous URL that contains highlight
Ctrl-N      | Select next URL that contains highlight
Ctrl-S      | Sends HSignal

##### Keys on search mode

Key         | Action
------------|--------------------------------------------------------------------
Up          | Select previous matching entry
Down        | Select next matching entry
Tab         | Switch to next search scope
Shift-Tab   | Switch to previous search scope
Ctrl-N      | Change search scope to nickname only
Ctrl-T      | Change search scope to message/text only
Ctrl-U      | Change search scope to URL only
Ctrl-B      | Change search scope to both nickname and message



### Options

##### plugins.var.lua.urlselect.tags

Comma separated list of tags. If not empty, script will scan URLs only on
messages with any of these tags (default:
`notify_message,notify_private,notify_highlight`).

##### plugins.var.lua.urlselect.scan_merged_buffers

Collect URLs from all buffers that are merged with the current one. Set to `1`
for yes and `0` for no (default: `0`). You can override this setting by calling
`/urlselect activate <mode>`, where `<mode>` is either `current` (scan current
buffer only) or `merged` (scan all buffers merged with the current one).

##### plugins.var.lua.urlselect.status_timeout

Timeout (in milliseconds) for displaying status notification (default: `1300`).

##### plugins.var.lua.urlselect.use_simple_matching

Use simple pattern matching when collecting URLs. Set to `1` to enable it or `0`
to disable it (default: `0`).

##### plugins.var.lua.urlselect.time_format

Format for displaying time (default: `%H:%M:%S`).

##### plugins.var.lua.urlselect.buffer_name

Format of `urlselect_buffer_name` bar item. Valid values are `full`
(eg: *irc.freenode.#weechat*), `normal` (eg: *freenode.#weechat*), and `short`
(eg: *#weechat*). If it's set to other value, it will fallback to the default
one (`normal`).

##### plugins.var.lua.urlselect.search_scope

Default search scope. Valid values are `nick`, `url`, `msg`, and `nick+msg`
(default: `url`).

##### plugins.var.lua.urlselect.max_remember

Maximum number of URLs that can be stored in remember list (default: `100`).

##### plugins.var.lua.urlselect.skip_remember

Do not include remembered URLs on selection bar. Set to `1` to enable it or `0`
to disable it (default: `0`).

##### plugins.var.lua.urlselect.search_prompt_color

Color for search prompt (default: `default`).

##### plugins.var.lua.urlselect.search_scope_color

Color for search scope indicator (default: `green`).

##### plugins.var.lua.urlselect.url_color

Color for URL item (default: `_lightblue`).

##### plugins.var.lua.urlselect.nick_color

Color for nickname item. Leave this empty to use Weechat's nick color (default
is empty).

##### plugins.var.lua.urlselect.highlight_color

Nickname color for URL from message with highlight (default is the value of
`weechat.color.chat_highlight` and `weechat.color.chat_highlight_bg`).

##### plugins.var.lua.urlselect.index_color

Color for URL index (default: `brown`).

##### plugins.var.lua.urlselect.message_color

Color for message containing the URL (default: `default`).

##### plugins.var.lua.urlselect.time_color

Color for time of message (default: `default`).

##### plugins.var.lua.urlselect.title_color

Color for bar title (default: `default`).

##### plugins.var.lua.urlselect.key_color

Color for keys (default: `cyan`).

##### plugins.var.lua.urlselect.help_color

Color for help text (default: `default`)

##### plugins.var.lua.urlselect.status_color

Color for status notification (default: `black,green`)

##### plugins.var.lua.urlselect.buffer_number_color

Color for buffer number (default: `brown`)

##### plugins.var.lua.urlselect.buffer_name_color

Color for buffer name (default: `green`)

##### plugins.var.lua.urlselect.cmd.*

These are for custom commands. Use `/urlselect bind` and `/urlselect unbind` to
modify these options.

##### plugins.var.lua.urlselect.label.*

These settings are for labels of custom commands when displayed in help bar. So
instead of showing `/god -damn long -ass command -with annoying -parameter list`
the text after the keys in help bar will use these custom labels. The
settings have to be set manually. For example, to set custom label for Alt-O you
can use:

    /set plugins.var.lua.urlselect.label.o xdg-open
