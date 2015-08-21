-- Copyright: 2015, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Durden is a simple tiling window manager for Arcan that
-- re-uses much of the same support scripts as the Senseye project. This
-- code module covers basic I/O and event routing, and basic setup.
--

local connection_path = "durden";

-- we run a separate tiler instance for each display, dynamic plugging /
-- hotplugging events can be configured to destroy, or "background" the
-- associated tiler (and switch between foreground / background sets of tiled
-- workspaces).
displays = {};

--
-- Every connection can get a set of additional commands and configurations
-- based on what type it has. Supported ones are registered into this table.
-- init, bindings, settings, commands
--
archtypes = {};

function durden()
	system_load("gconf.lua")(); -- configuration management
	system_load("mouse.lua")(); -- mouse gestures
	system_load("suppl.lua")(); -- convenience functions
	system_load("bbar.lua")(); -- input binding
	system_load("keybindings.lua")(); -- static key configuration
	system_load("tiler.lua")(); -- window management
	system_load("browser.lua")(); -- quick file-browser
	system_load("iostatem.lua")(); -- input repeat delay/period

-- functions exposed to user through menus, binding and scripting
	system_load("fglobal.lua")(); -- tiler- related global
	system_load("builtin/debug.lua")(); -- global event viewer
	system_load("builtin/global.lua")(); -- desktop related global
	system_load("builtin/shared.lua")(); -- shared window related global

-- can't work without a detected keyboard
	if (not input_capabilities().translated) then
		warning("arcan reported no available translation capable devices "
			.. "(keyboard), cannot continue without one.\n");
		return shutdown("", EXIT_FAILURE);
	end

-- load custom special subwindow handlers
	local res = glob_resource("atypes/*.lua", APPL_RESOURCE);
	if (res ~= nil) then
		for k,v in ipairs(res) do
			local tbl = system_load("atypes/" .. v, false);
			tbl = tbl and tbl() or nil;
			if (tbl and tbl.atype) then
				archtypes[tbl.atype] = tbl;
			end
		end
	end

	displays.main = tiler_create(VRESW, VRESH, {});
	SYMTABLE = system_load("symtable.lua")();
	mouse_setup_native(load_image("cursor/default.png"), 0, 0);

-- this opens up the 'durden' external listening point, removing it means
-- only user-input controlled execution
	new_connection();

-- dropping this call means that the only input / output available is
-- through keybindings/mice/joysticks
	control_channel = open_nonblock("durden_cmd");
	if (control_channel == nil) then
		warning("no control channel found, use: (mkfifo c durden/durden_cmd)");
	else
		warning("control channel active (durden_cmd)");
	end

-- preload cursor states
	mouse_add_cursor("drag", load_image("cursor/drag.png"), 0, 0); -- 7, 5);
	mouse_add_cursor("grabhint", load_image("cursor/grabhint.png"), 0, 0); --, 7, 10);
	mouse_add_cursor("rz_diag_l", load_image("cursor/rz_diag_l.png"), 0, 0); --, 6, 5);
	mouse_add_cursor("rz_diag_r", load_image("cursor/rz_diag_r.png"), 0, 0); -- , 6, 6);
	mouse_add_cursor("rz_down", load_image("cursor/rz_down.png"), 0, 0); -- 5, 13);
	mouse_add_cursor("rz_left", load_image("cursor/rz_left.png"), 0, 0); -- 0, 5);
	mouse_add_cursor("rz_right", load_image("cursor/rz_right.png"), 0, 0); -- 13, 5);
	mouse_add_cursor("rz_up", load_image("cursor/rz_up.png"), 0, 0); -- 5, 0);

	register_global("spawn_terminal", spawn_terminal);
	register_global("launch_bar", query_launch);

-- load saved keybindings
	dispatch_load();
	iostatem_init();
end

local function tile_changed(wnd, neww, newh, efw, efh)
	if (neww > 0 and newh > 0) then
		target_displayhint(wnd.external, neww, newh);
	end
end

function durden_launch(vid, title, prefix)
	local wnd = displays.main:add_window(vid);
	wnd.external = vid;
	wnd:set_title(title and title or "?");
	wnd:set_prefix(prefix);
	wnd:add_handler("resize", tile_changed);
	show_image(vid);
	target_updatehandler(vid, def_handler);
end

-- recovery from crash is handled just like newly launched windows
function durden_adopt(vid, kind, title)
	durden_launch(vid, title);
end

function spawn_terminal()
	local vid = launch_avfeed(
		"env=ARCAN_CONNPATH=" .. connection_path, "terminal");
	if (valid_vid(vid)) then
		durden_launch(vid, "", "terminal");
		def_handler(vid, {kind = "registered", segkind = "terminal"});
	else
		displays.main:message( "Builtin- terminal support broken" );
	end
end

function def_handler(source, stat)
	local wnd = displays.main:find_window(source);
	assert(wnd ~= nil);

	if (DEBUGLEVEL > 0 and displays.main.debug_console) then
		displays.main.debug_console:target_event(source, stat);
	end

-- registered subtype handler may say that this event should not
-- propagate to the default implementation (below)
	if (wnd.dispatch[stat.kind]) then
		if (DEBUGLEVEL > 0 and displays.main.debug_console) then
			displays.main.debug_console:event_dispatch(wnd, stat.kind, stat);
		end

		if (wnd.dispatch[stat.kind](source, stat)) then
			return;
		end
	end

	if (stat.kind == "resized") then
		wnd.space:resize();
		wnd.source_audio = stat.source_audio;
		audio_gain(stat.source_audio,
			gconfig_get("global_mute") and 0.0 or (gconfig_get("global_gain") *
			(wnd.source_gain and wnd.source_gain or 1.0))
		);
		if (wnd.space.mode == "float") then
			wnd:resize_effective(stat.width, stat.height);
		end
		image_set_txcos_default(wnd.canvas, stat.origo_ll == true);
	elseif (stat.kind == "message") then
		wnd:set_message(stat.v, gconfig_get("msg_timeout"));

	elseif (stat.kind == "terminated") then
-- if an lbar is active that requires this target window, that should be
-- dropped as well to avoid a race
		wnd:destroy();

	elseif (stat.kind == "ident") then

-- this can come multiple times if the title of the window is changed,
-- (whih happens a lot with some types)
	elseif (stat.kind == "registered") then
		local atbl = archtypes[stat.segkind];
		if (atbl == nil or wnd.atype == stat.segkind) then
			return;
		end
		wnd.atype = stat.segkind;
		wnd.source_audio = stat.source_audio;
		register_shared_atype(wnd, atbl.actions, atbl.settings, atbl.labels);
	else
--		warning("unhandled" .. stat.kind);
	end
end

function new_connection(source, status)
	if (status == nil or status.kind == "connected") then
		local vid = target_alloc(connection_path, new_connection);
		image_tracetag(vid, "nonauth_connection");

	elseif (status.kind == "resized") then
		resize_image(source, status.width, status.height);
		local wnd = displays.main:add_window(source);
		wnd.external = source;
		wnd:add_handler("resize", tile_changed);
		target_updatehandler(source, def_handler);
		tile_changed(wnd);
	end
end

--
-- line over fifo API for doing status bar updates, etc.
--
function poll_control_channel()
	local line = control_channel:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end

	local cmd = string.split(line, ":");
	cmd = cmd == nil and {} or cmd;

	if (cmd[1] == "status") then
 -- unkown command, just draw (allows us to just pipe i3status)
		local msg = string.gsub(string.sub(line, 6), "\\", "\\\\");
		local vid = render_text(
			string.format("%s \\#ffffff %s", gconfig_get("font_str"), msg));
		if (valid_vid(vid)) then
			displays.main:update_statusbar(vid);
		end
	else
		dispatch_symbol(cmd[1]);
	end
end

local mid_c = 0;
local mid_v = {0, 0};
function durden_input(iotbl, fromim)
	if (DEBUGLEVEL > 0 and displays.main.debug_wnd) then
		displays.main.debug_wnd:add_input(iotbl, fromim);
	end

	if (not fromim) then
		local it = iostatem_input(iotbl);
		if (it) then
			for k,v in ipairs(it) do
			durden_input(v, true);
			end
		end
	end

	if (iotbl.source == "mouse") then
		if (iotbl.kind == "digital") then
			mouse_button_input(iotbl.subid, iotbl.active);
		else
			mid_v[iotbl.subid+1] = iotbl.samples[1];
			mid_c = mid_c + 1;

			if (mid_c == 2) then
				mouse_absinput(mid_v[1], mid_v[2]);
				mid_c = 0;
			end
		end

	elseif (iotbl.translated) then
		local sym = SYMTABLE[ iotbl.keysym ];
-- all input and symbol lookup paths go through this routine (in fglobal.lua)
		if (not dispatch_lookup(iotbl, sym, displays.main.input_lock)) then
			local sel = displays.main.selected;
			if (sel) then
			if (valid_vid(sel.external, TYPE_FRAMESERVER)) then
-- possible injection site for higher level inputs
				target_input(sel.external, iotbl);
			elseif (sel.key_input) then
				sel:key_input(sym, iotbl);
			end
			end
		end
	end

end

function durden_display_state(action, id)
	if (action == "added") then
		if (displays[id] == nil) then
			displays[id] = {};
-- find out if there is a known profile for this display, activate
-- corresponding desired resolution, set mapping, create tiler, color
-- correction profile, RGB tuning etc.
		end
	elseif (action == "removed") then
		if (displays[id] == nil) then
			warning("lost unknown display: " .. tostring(id));
			return;
		end

-- sweep workspaces and migrate back to previous display (and toggle
-- rendertarget output on/off), destroy tiler, save settings, if workspace slot
-- is occupied, add to "orphan-" list.
	end
end

function durden_shutdown()
	gconfig_shutdown();
end

function durden_clock_pulse()
	local tt = iostatem_tick();
	if (tt) then
		for k,v in ipairs(tt) do
			durden_input(v, true);
		end
	end

--	if (CLOCK % 100) then (quick and dirty leak check)
--		print(current_context_usage());
--	end

	displays.main:tick();
	if (CLOCK % 4 == 0 and control_channel ~= nil) then
		poll_control_channel();
	end
end
