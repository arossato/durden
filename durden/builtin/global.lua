--
-- Globally available menus, settings and functions. All code here is just
-- boiler-plate mapping to engine- or support script functions.
--

local function global_valid01_uri(str)
	return true;
end

local function query_synch()
	local lst = video_synchronization();
	if (lst) then
		local res = {};
-- dynamically populated so we don't expose this globally at the moment
		for k,v in ipairs(lst) do
			res[k] = {
				name = "set_synch_" .. tostring(k),
				label = v,
				kind = "action",
				handler = function(ctx)
					video_synchronization(v);
				end
			};
		end
		return res;
	end
end

-- DPMS toggle (force-on, force-off, toggle) / all or individual
-- ICC Profile (one, all)
local display_menu = {
	{
		name = "display_rescan",
		label = "Rescan",
		kind = "action",
		handler = video_displaymodes,
	},
	{
		name = "synchronization_strategies",
		label = "Synchronization",
		kind = "action",
		hint = "Synchronization:",
		submenu = true,
		force = true,
		handler = function() return query_synch(); end
	},
};

local exit_query = {
{
	name = "shutdown_no",
	label = "No",
	kind = "action",
	handler = function() end
},
{
	name = "shutdown_yes",
	label = "Yes",
	kind = "action",
	dangerous = true,
		handler = function() shutdown(); end
	}
};

local reset_query = {
	{
		name = "reset_no",
		label = "No",
		kind = "action",
		handler = function() end
	},
	{
		name = "reset_yes",
		label = "Yes",
		kind = "action",
		dangerous = true,
		handler = function() system_collapse(APPLID); end
	},
};

local function query_dump()
	local bar = tiler_lbar(displays.main, function(ctx, msg, done, set)
		if (done) then
			zap_resource("debug/" .. msg);
			system_snapshot("debug/" .. msg);
		end
		return {};
	end);
	bar:set_label("filename (debug/):");
end

local debug_menu = {
	{
		name = "query_dump",
		label = "Dump State",
		kind = "action",
		handler = query_dump
	}
};

local system_menu = {
	{
		name = "shutdown",
		label = "Shutdown",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Shutdown?",
		handler = exit_query
	},
	{
		name = "reset",
		label = "Reset",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Reset?",
		handler = reset_query
	}
};

if (DEBUGLEVEL > 0) then
	table.insert(system_menu,{
		name = "debug",
		label = "Debug",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Debug:",
		handler = debug_menu,
	});
end

local audio_menu = {
	{
		name = "toggle_audio",
		label = "Toggle On/Off",
		kind = "action",
		handler = grab_global_function("toggle_audio")
	},
	{
		name = "global_gain",
		label = "Global Gain",
		kind = "action",
		handler = grab_global_function("query_global_gain")
	},
	{
		name = "gain_pos10",
		label = "+10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(0.1);
		end
	},
	{
		name = "gain_neg10",
		label = "-10%",
		kind = "action",
		handler = function()
			grab_global_function("gain_stepv")(-0.1);
		end
	}
};

local input_menu = {
	{
		name = "input_rebind_basic",
		kind = "action",
		label = "Rebind Basic",
		handler = grab_global_function("rebind_basic")
	},
	{
		name = "input_rebind_custom",
		kind = "action",
		label = "Bind Custom",
		handler = grab_global_function("bind_custom")
	},
	{
		name = "input_rebind_meta",
		kind = "action",
		label = "Bind Meta",
		handler = grab_global_function("rebind_meta")
	}
};

-- workspace actions:
-- 	layout (save [shallow, deep], load), display affinity,
-- 	reassign (if multiple displays), layout, shared

local function switch_ws_menu()
	local spaces = {};
	for i=1,10 do
		spaces[i] = {
			name = "switch_ws" .. tostring(i),
			kind = "action",
			label = tostring(i),
			handler = grab_global_function("switch_ws" .. tostring(i)),
		};
	end

	return spaces;
end

local workspace_layout_menu = {
	{
		name = "layout_float",
		kind = "action",
		label = "Float",
		handler = function()
			local space = displays.main.spaces[displays.main.space_ind];
			space = space and space:float() or nil;
		end
	},
	{
		name = "layout_tile",
		kind = "action",
		label = "Tile",
		handler = function()
			local space = displays.main.spaces[displays.main.space_ind];
			space = space and space:tile() or nil;
		end
	},
	{
		name = "layout_tab",
		kind = "action",
		label = "Tabbed",
		handler = function()
			local space = displays.main.spaces[displays.main.space_ind];
			space = space and space:tab() or nil;
		end
	},
	{
		name = "layout_vtab",
		kind = "action",
		label = "Tabbed Vertical",
		handler = function()
			local space = displays.main.spaces[displays.main.space_ind];
			space = space and space:vtab() or nil;
		end
	}
};

local function load_bg(fn)
	local space = displays.main.spaces[displays.main.space_ind];
	if (not space) then
		return;
	end

	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			if (valid_vid(space.background)) then
				delete_image(space.background);
			end
			space.background = src;
			space.background_name = fn;
			resize_image(src, space.wm.width, space.wm.client_height);
			link_image(src, space.anchor);
			space:bgon();
			else
			delete_image(src);
		end
	end);
end

local save_ws = {
	{
		name = "workspace_save_shallow",
		label = "Shallow",
		kind = "action",
		handler = grab_global_function("save_space_shallow")
	},
	{
		name = "workspace_save_deep",
		label = "Complete",
		kind = "action",
		handler = grab_global_function("save_space_deep")
	},
	{
		name = "workspace_save_drop",
		label = "Drop",
		kind = "action",
		eval = function()	return true; end,
		handler = grab_global_function("save_space_drop")
	}
};

local function set_ws_background()
	local imgfiles = {
	png = load_bg,
	jpg = load_bg,
	bmp = load_bg};
	browse_file({}, imgfiles, SHARED_RESOURCE, nil);
end

local function swap_ws_menu()
	local res = {};
	local wspace = displays.main.spaces[displays.main.space_ind];
	for i=1,10 do
		if (displays.main.space_ind ~= i and displays.main.spaces[i] ~= nil) then
			table.insert(res, {
				name = "workspace_swap",
				label = tostring(i),
				kind = "action",
				handler = function()
					grab_global_function("swap_ws" .. tostring(i))();
				end
			});
		end
	end
	return res;
end

local workspace_menu = {
	{
		name = "workspace_swap",
		label = "Swap",
		kind = "action",
		eval = function() return displays.main:active_spaces() > 1; end,
		submenu = true,
		force = true,
		hint = "Swap:",
		handler = swap_ws_menu
	},
	{
		name = "workspace_layout",
		label = "Layout",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Layout:",
		handler = workspace_layout_menu
	},
	{
		name = "workspace_rename",
		label = "Rename",
		kind = "action",
		handler = grab_global_function("rename_space")
	},
	{
		name = "workspace_background",
		label = "Background",
		kind = "action",
		handler = set_ws_background,
	},
	{
		name = "workspace_save",
		label = "Save",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Save Workspace:",
		handler = save_ws
	},
	{
		name = "workspace_switch",
		label = "Switch",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Switch To:",
		handler = switch_ws_menu
	},
	{
		name = "workspace_name",
		label = "Find",
		kind = "action",
		handler = function() grab_global_function("switch_ws_byname")(); end
	}
};

local function imgwnd(fn)
	load_image_asynch(fn, function(src, stat)
		if (stat.kind == "loaded") then
			local wnd = displays.main:add_window(src, {scalemode = "stretch"});
			string.gsub(fn, "\\", "\\\\");
			wnd:set_title("image:" .. fn);
		elseif (valid_vid(src)) then
			delete_image(src);
		end
	end);
end

local function dechnd(source, status)
	print("status.kind:", status.kind);
end

local function decwnd(fn)
	launch_decode(fn, function(source, status)
		if (status.kind == "terminated") then
			delete_image(source);
		elseif (status.kind == "connected") then
			local wnd = displays.main:add_window(source);
			wnd.external = source;
			wnd.resize_hook = tile_changed;
			target_updatehandler(source, dechnd);
			tile_changed(wnd);
		end
	end);
end

local function browse_internal()
	local ffmts = {
	jpg = imgwnd,
	png = imgwnd,
	bmp = imgwnd};
-- Don't have a good way to query decode for extensions at the moment,
-- would be really useful in cases like this (might just add an info arg and
-- then export through message, coreopt or similar).
	for i,v in ipairs({"mp3", "flac", "wmv", "mkv", "avi", "asf", "flv",
		"mpeg", "mov", "mp4", "ogg"}) do
		ffmts[v] = decwnd;
	end

	browse_file({}, ffmts, SHARED_RESOURCE, nil);
end

local toplevel = {
	{
		name = "open",
		label = "Open",
		kind = "action",
		handler = query_uriopen
	},
	{
		name = "browse",
		label = "Browse",
		kind = "action",
		handler = browse_internal
	},
	{
		name = "global_menu",
		label = "Global Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("global_actions")();
		end,
	},
	{
		name = "target_menu",
		label = "Window Menu",
		kind = "action",
		invisible = true,
		handler = function()
			grab_global_function("target_actions")
		end
	},
	{
		name = "workspace",
		label = "Workspace",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Workspace:",
		handler = workspace_menu
	},
	{
		name = "display",
		label = "Display",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Displays:",
		handler = display_menu
	},
	{
		name = "audio",
		label = "Audio",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Audio:",
		handler = audio_menu
	},
	{
		name = "input",
		label = "Input",
		kind = "action",
		submenu = true,
		force = true,
		hint = "Input:",
		handler = input_menu
	},
	{
		name = "system",
		label = "System",
		kind = "action",
		submenu = true,
		force = true,
		hint = "System:",
		handler = system_menu
	},
};

global_actions = function(trigger_function)
	if (IN_CUSTOM_BIND) then
		return launch_menu(displays.main, {
			list = toplevel,
			trigger = trigger_function,
			show_invisible = true
		}, true, "Bind:");
	else
		return launch_menu(displays.main, {list = toplevel,
			trigger = trigger_function}, true, "Action:");
	end
end

register_global("global_actions", global_actions);

-- audio
register_global("audio_mute_all", audio_mute);

--display
register_global("display_rescan", display_rescan);
register_global("query_synch", display_synch);

--system
register_global("query_exit", query_exit);
register_global("exit", shutdown);
register_global("query_reset", query_reset);
register_global("reset", function() system_collapse(APPLID); end);
