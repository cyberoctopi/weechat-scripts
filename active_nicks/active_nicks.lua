w, script_name = weechat, "active_nicks"

g = {
   config = {},
   defaults = {
      delay = {
         type = "integer",
         min = 1,
         max = 10080,
         value = "5", -- default value will be replaced by irc.look.smart_filter_delay
         description = "Delay before hiding nick again (in minutes, values: 1..10080)"
      },
      ignore_filtered = {
         type = "boolean",
         value = "on",
         description = "Ignore filtered line."
      },
      conditions = {
         type = "string",
         value = "${buffer.nicklist}",
         description = [[Only watch buffers that matched these conditions.
         See /help eval for syntax. Example: ${buffer.nicklist_nicks_count} > 20]]
      },
      tags = {
         type = "string",
         value = "nick_*+log1",
         description = [[Only count activity from messages with these tags.
         See https://weechat.org/doc/api#_hook_print for syntax of tags]]
      },
      groups = {
         type = "string",
         value = "*",
         description = [[Comma separated list of nick groups that will be
         modified by this script. Wildcard "*" is allowed, a name beginning with
         "!" is excluded]]
      }
   },
   hooks = {},
   buffers = {}
}

function string:match_list(pattern, is_group)
   if is_group then
      local pos = self:find("|", 1, true)
      self = pos and self:sub(pos + 1) or self
      if not self or self == "" then
         return false
      end
   end
   local result = false
   for mask in pattern:gmatch("([^,]+)") do
      local negate = false
      if mask:sub(1, 1) == "!" then
         negate, mask = true, mask:sub(2)
      end
      local match = w.string_match(self, mask, 0) == 1
      if match then
         if negate then
            result = false
            break
         end
         result = true
      end
   end
   return result
end

function main()
   local reg_ok = w.register(
      script_name,
      "singalaut <https://github.com/tomoe-mami>",
      "0.1",
      "WTFPL",
      "Show only active users in nicklist",
      "unload_cb", "")

   if reg_ok then
      local wee_ver = tonumber(w.info_get("version_number", "") or 0)
      if wee_ver < 0x01000000 then
         w.print("", w.prefix("error")..script_name..": Your WeeChat is outdated!")
         w.command("", "/wait 1ms /lua unload "..script_name)
         return
      end

      init_config()
      hide_all_nicks(true)

      w.hook_config("plugins.var.lua."..script_name..".*", "config_cb", "")
      w.hook_signal("buffer_closed", "buffer_closed_cb", "")
      w.hook_hsignal("nicklist_nick_added", "nick_added_cb", "")
      w.hook_hsignal("nicklist_nick_removing", "nick_removing_cb", "")
      w.hook_modifier("irc_in2_353", "names_received_cb", "")
      w.hook_signal("*,irc_in_366", "names_end_cb", "")
      w.hook_modifier("irc_in2_nick", "nick_changes_cb", "")
      w.hook_signal("*,irc_out_part", "part_channel_cb", "")
      w.hook_signal("*,irc_out_quit", "quit_server_cb", "")
      hook_print()
      hook_timer()

      w.hook_command(script_name, "Control "..script_name, "toggle",
         "toggle: Toggle current buffer", "toggle", "command_cb", "")
   end
end

function iter_buffers()
   local h_buffer = w.hdata_get("buffer")
   local buffer = w.hdata_get_list(h_buffer, "gui_buffers")
   return function ()
      if buffer and buffer ~= "" then
         local ptr_buffer = buffer
         buffer = w.hdata_pointer(h_buffer, ptr_buffer, "next_buffer")
         return ptr_buffer, h_buffer
      end
   end
end

function iter_nicklist(buffer)
   local h_buffer = w.hdata_get("buffer")
   local h_nick, h_group = w.hdata_get("nick"), w.hdata_get("nick_group")
   local root = w.hdata_pointer(h_buffer, buffer, "nicklist_root")
   local current_item, h_current = w.hdata_pointer(h_group, root, "children"), h_group
   local next_item, h_next = ""

   local get_parent_next_sibling = function (ptr, is_nick)
      while ptr ~= "" and ptr ~= root do
         if is_nick then
            ptr = w.hdata_pointer(h_nick, ptr, "group")
            is_nick = false
         else
            ptr = w.hdata_pointer(h_group, ptr, "parent")
         end
         local next_group = w.hdata_pointer(h_group, ptr, "next_group")
         if next_group ~= "" then
            ptr = next_group
            break
         end
      end
      return ptr
   end

   return function ()
      if current_item ~= "" and current_item ~= root then
         local ret_item, h_ret = current_item, h_current
         if h_current == h_group then
            next_item = w.hdata_pointer(h_group, current_item, "children")
            if next_item ~= "" then
               h_next = h_group
            else
               next_item = w.hdata_pointer(h_group, current_item, "nicks")
               if next_item ~= "" then
                  h_next = h_nick
               else
                  next_item = w.hdata_pointer(h_group, current_item, "next_group")
                  h_next = h_group
                  if next_item == "" then
                     next_item = get_parent_next_sibling(current_item)
                  end
               end
            end
         elseif h_current == h_nick then
            next_item = w.hdata_pointer(h_nick, current_item, "next_nick")
            if next_item == "" then
               next_item = get_parent_next_sibling(current_item, true)
               h_next = h_group
            end
         end
         current_item, h_current = next_item, h_next
         return ret_item, h_ret, (h_ret == h_group)
      end
   end
end

function get_valid_option_value(value, default)
   if default.callback and type(default.callback) == "function" then
      return default.callback(value)
   else
      if default.type == "integer" then
         value = math.floor(tonumber(value) or 0)
         if default.min and value < default.min then
            value = default.min
         end
         if default.max and value > default.max then
            value = default.max
         end
      elseif default.type == "boolean" then
         value = w.config_string_to_boolean(value) == 1
      elseif default.type == "string" and default.choices and not default.choices[value] then
         value = default.value
      end
      return value
   end
end

function init_config()
   local conf = {}
   g.defaults.delay.value = w.config_integer(w.config_get("irc.look.smart_filter_delay"))
   for name, info in pairs(g.defaults) do
      local value
      if w.config_is_set_plugin(name) == 0 then
         value = info.value
         w.config_set_plugin(name, value)
         w.config_set_desc_plugin(name, (info.description:gsub("%s+", " ")))
      else
         value = w.config_get_plugin(name)
      end
      conf[name] = get_valid_option_value(value, info)
   end
   g.config = conf
end

function config_cb(_, opt_name, opt_value)
   local prefix = "plugins.var.lua."..script_name.."."
   local name = opt_name:sub(#prefix + 1)
   if name and g.defaults[name] then
      local orig_value = g.config[name]
      g.config[name] = get_valid_option_value(opt_value, g.defaults[name])
      if name == "delay" then
         hook_timer()
      elseif name == "tags" then
         hook_print()
      elseif name == "conditions" then
         recheck_buffer_conditions()
      elseif name == "groups" then
         recheck_groups(orig_value, g.config[name])
      end
   end
   return w.WEECHAT_RC_OK
end

function check_buffer_conditions(buffer)
   if g.config.conditions ~= "" then
      local result = w.string_eval_expression(
         g.config.conditions,
         { buffer = buffer },
         {},
         { type = "condition" })
      return result == "1"
   end
   return true
end

function recheck_buffer_conditions()
   for buf_ptr in iter_buffers() do
      local v
      if not check_buffer_conditions(buf_ptr) then
         v = true
         if g.buffers[buf_ptr] then
            g.buffers[buf_ptr] = nil
         end
      elseif not g.buffers[buf_ptr] then
         v = false
      end
      if v ~= nil then
         set_all_nicks_visibility(buf_ptr, v, true)
      end
   end
end

function recheck_groups(old_mask, new_mask)
   if old_mask == new_mask then
      return
   end
   for buf_ptr, buf in pairs(g.buffers) do
      local current_group = ""
      for ptr, hdata, is_group in iter_nicklist(buf_ptr) do
         if is_group then
            current_group = w.hdata_string(hdata, ptr, "name")
         else
            local old_match = current_group:match_list(old_mask, true)
            local new_match = current_group:match_list(new_mask, true)
            if not old_match and new_match then
               w.nicklist_nick_set(buf_ptr, ptr, "visible", "0")
            elseif old_match and not new_match then
               local nick_name = w.hdata_string(hdata, ptr, "name")
               buf.nicklist[nick_name] = nil
               w.nicklist_nick_set(buf_ptr, ptr, "visible", "1")
            end
         end
      end
   end
end

function add_buffer(buf_ptr)
   if not g.buffers[buf_ptr] then
      g.buffers[buf_ptr] = { nicklist = {} }
   end
   return g.buffers[buf_ptr]
end

function nick_group_match(buffer, nick_ptr, group_ptr)
   if not group_ptr or group_ptr == "" then
      group_ptr = w.nicklist_nick_get_pointer(buffer, nick_ptr, "group")
      if not group_ptr or group_ptr == "" then
         return false
      end
   end
   local group_name = w.nicklist_group_get_string(buffer, group_ptr, "name")
   if not group_name or group_name == "" then
      return false
   end
   return group_name:match_list(g.config.groups, true)
end

function set_all_nicks_visibility(buf_ptr, flag, is_init)
   flag = flag and "1" or "0"
   local mask = g.config.groups
   local current_group = ""
   for ptr, hdata, is_group in iter_nicklist(buf_ptr) do
      if is_group then
         current_group = w.hdata_string(hdata, ptr, "name")
      else
         if current_group:match_list(mask, true) then
            w.nicklist_nick_set(buf_ptr, ptr, "visible", flag)
         elseif is_init then
            w.nicklist_nick_set(buf_ptr, ptr, "visible", "1")
         end
      end
   end
end

function hide_all_nicks(flag)
   for buf_ptr in iter_buffers() do
      local total_nicks = w.buffer_get_integer(buf_ptr, "nicklist_nicks_count")
      if total_nicks > 0 and check_buffer_conditions(buf_ptr) then
         if flag then
            add_buffer(buf_ptr)
         end
         set_all_nicks_visibility(buf_ptr, not flag, true)
      end
   end
end

function show_nick(buffer, nick_name, timestamp)
   local buf = add_buffer(buffer)
   if not buf.hold then
      local ptr = w.nicklist_search_nick(buffer, "", nick_name)
      if ptr ~= "" then
         if not buf.nicklist[nick_name] then
            w.hook_hsignal_send(script_name.."_status",
                                { buffer = buffer, nick = nick_name, status = 1})
         end
         buf.nicklist[nick_name] = timestamp
         if w.nicklist_nick_get_integer(buffer, ptr, "visible") == 0 and
            nick_group_match(buffer, ptr) then
            w.nicklist_nick_set(buffer, ptr, "visible", "1")
         end
      end
   end
end

function print_cb(_, buffer, time, tags, displayed)
   if g.config.ignore_filtered and displayed == 0 then
      return w.WEECHAT_RC_OK
   end
   local nick = string.match(","..tags..",", ",nick_([^,]-),")
   if nick == "" then
      return w.WEECHAT_RC_OK
   end
   if check_buffer_conditions(buffer) then
      show_nick(buffer, nick, tonumber(time))
   end
   return w.WEECHAT_RC_OK
end

function nick_added_cb(_, _, param)
   if check_buffer_conditions(param.buffer) then
      local buf = add_buffer(param.buffer)
      if not buf.hold and nick_group_match(param.buffer, param.nick, param.parent_group) then
         local nick_name = w.nicklist_nick_get_string(param.buffer, param.nick, "name")
         if not buf.nicklist[nick_name] then
            w.nicklist_nick_set(param.buffer, param.nick, "visible", "0")
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function nick_removing_cb(_, _, param)
   if g.buffers[param.buffer] and not g.buffers[param.buffer].hold then
      -- weechat doesn't decrease nicklist_visible_count when an invisible nick
      -- is removed. so we have to make sure it's visible first
      w.nicklist_nick_set(param.buffer, param.nick, "visible", "1")
   end
   return w.WEECHAT_RC_OK
end

function buffer_closed_cb(_, _, buffer)
   g.buffers[buffer] = nil
   return w.WEECHAT_RC_OK
end

function names_received_cb(_, _, server, msg)
   local info = w.info_get_hashtable("irc_message_parse", { message = msg })
   if info and type(info) == "table" and info.text then
      local channel = info.text:match("^%S+ (%S+)")
      if channel then
         local buf_ptr = w.info_get("irc_buffer", server..","..channel)
         if check_buffer_conditions(buf_ptr) then
            local buf = add_buffer(buf_ptr)
            if not buf.hold then
               buf.hold = true
               set_all_nicks_visibility(buf_ptr, true, true)
            end
         end
      end
   end
   return msg
end

function names_end_cb(_, signal, msg)
   local server = signal:match("^([^,]+)")
   if server then
      local info = w.info_get_hashtable("irc_message_parse", { message = msg })
      if info and type(info) == "table" and info.channel then
         local buf_ptr = w.info_get("irc_buffer", server..","..info.channel)
         if not g.buffers[buf_ptr] then
            return w.WEECHAT_RC_OK
         end
         local buf = g.buffers[buf_ptr]
         local mask = g.config.groups
         local current_group = ""
         for ptr, hdata, is_group in iter_nicklist(buf_ptr) do
            if is_group then
               current_group = w.hdata_string(hdata, ptr, "name")
            else
               local nick_name = w.hdata_string(hdata, ptr, "name")
               if not buf.nicklist[nick_name] and current_group:match_list(mask, true) then
                  w.nicklist_nick_set(buf_ptr, ptr, "visible", "0")
               end
            end
         end
         buf.hold = nil
      end
   end
   return w.WEECHAT_RC_OK
end

function nick_changes_cb(_, _, server, msg)
   local info = w.info_get_hashtable("irc_message_parse", { message = msg })
   if info and type(info) == "table" and info.nick and info.arguments then
      info.arguments = info.arguments:gsub("^:", "")
      for buf_ptr, buf in pairs(g.buffers) do
         local buf_server = w.buffer_get_string(buf_ptr, "localvar_server")
         if buf_server == server and buf.nicklist[info.nick] then
            buf.nicklist[info.arguments] = buf.nicklist[info.nick]
         end
      end
   end
   return msg
end

function part_channel_cb(_, signal, msg)
   local server = signal:match("^([^,]+)")
   if server then
      local info = w.info_get_hashtable("irc_message_parse", { message = msg })
      if info and type(info) == "table" and info.channel then
         for chan in info.channel:gmatch("([^,]+)") do
            local buf_ptr = w.info_get("irc_buffer", server..","..chan)
            g.buffers[buf_ptr] = nil
            set_all_nicks_visibility(buf_ptr, true)
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function quit_server_cb(_, signal, msg)
   local server_name = signal:match("^([^,]+)")
   if server_name then
      local h_server = w.hdata_get("server")
      local server, found  = w.hdata_get_list(h_server, "irc_servers"), false
      while server ~= "" do
         if w.hdata_string(h_server, server, "name") == server_name then
            found = true
            break
         end
         server = w.hdata_pointer(h_server, server, "next_server")
      end
      if found then
         local h_channel = w.hdata_get("irc_channel")
         local channel = w.hdata_pointer(h_server, server, "channels")
         while channel ~= "" do
            local buf_ptr = w.hdata_pointer(h_channel, channel, "buffer")
            g.buffers[buf_ptr] = nil
            set_all_nicks_visibility(buf_ptr, true)
            channel = w.hdata_pointer(h_channel, channel, "next_channel")
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function timer_cb()
   local start_time = os.time() - (g.config.delay * 60)
   local b = {}
   for buf_ptr, buf in pairs(g.buffers) do
      b[buf_ptr] = { hold = buf.hold, nicklist = {} }
      if not buf.hold then
         for nick_name, timestamp in pairs(buf.nicklist) do
            if timestamp < start_time then
               local nick_ptr = w.nicklist_search_nick(buf_ptr, "", nick_name)
               if nick_group_match(buf_ptr, nick_ptr) then
                  w.nicklist_nick_set(buf_ptr, nick_ptr, "visible", "0")
               end
               w.hook_hsignal_send(script_name.."_status",
                                   { buffer = buf_ptr, nick = nick_name, status = 0 })
            else
               b[buf_ptr].nicklist[nick_name] = timestamp
            end
         end
      end
   end
   g.buffers = b
end

function hook_timer()
   local delay = g.config.delay
   if g.hooks.timer then
      w.unhook(g.hooks.timer)
   end
   if delay > 0 then
      local interval = 60000
      if delay >= 10 then
         interval = interval * math.floor(delay / (math.log10(delay) * 4))
      end
      g.hooks.timer = w.hook_timer(interval, 0, 0, "timer_cb", "")
   else
      g.hooks.timer = nil
   end
end

function hook_print()
   if g.hooks.print then
      w.unhook(g.hooks.print)
   end
   g.hooks.print = w.hook_print("", g.config.tags, "", 0, "print_cb", "")
end

function cmd_toggle(buf_ptr)
   local buf = g.buffers[buf_ptr]
   if buf then
      buf.hold = not buf.hold
      local mask = g.config.groups
      local current_group = ""
      for ptr, hdata, is_group in iter_nicklist(buf_ptr) do
         if is_group then
            current_group = w.hdata_string(hdata, ptr, "name")
         else
            local flag = "1"
            local nick_name = w.hdata_string(hdata, ptr, "name")
            if not buf.hold then
               if buf.nicklist[nick_name] then
                  buf.nicklist[nick_name] = os.time()
               elseif current_group:match_list(mask, true) then
                  flag = "0"
               end
            end
            w.nicklist_nick_set(buf_ptr, ptr, "visible", flag)
         end
      end
   end
   return w.WEECHAT_RC_OK
end

function command_cb(_, buf_ptr, param)
   if param == "toggle" then
      return cmd_toggle(buf_ptr)
   end
   return w.WEECHAT_RC_OK
end

function unload_cb()
   hide_all_nicks(false)
end

main()
