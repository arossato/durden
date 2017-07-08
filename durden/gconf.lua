-- Copyright 2015-2017, Björn Ståhl
-- License: 3-Clause BSD
-- Reference: http://durden.arcan-fe.com
-- Description: Global / Persistent configuration management copied from
-- senseye, tracks default font, border, layout and other settings.
--

-- here for the time being, will move with internationalization
LBL_YES = "yes";
LBL_NO = "no";
LBL_BIND_COMBINATION = "Press and hold the desired combination, %s to Cancel";
LBL_BIND_KEYSYM = "Press and hold single key to bind keysym %s, %s to Cancel";
LBL_BIND_COMBINATION_REP = "Press and hold or repeat- press, %s to Cancel";
LBL_UNBIND_COMBINATION = "Press and hold the combination to unbind, %s to Cancel";
LBL_METAGUARD = "Query Rebind in %d keypresses";
LBL_METAGUARD_META = "Rebind (meta keys) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_BASIC = "Rebind (basic keys) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_MENU = "Rebind (global menu) in %.2f seconds, %s to Cancel";
LBL_METAGUARD_TMENU = "Rebind (target menu) in %.2f seconds, %s to Cancel";

HC_PALETTE = {
	"\\#efd469",
	"\\#43abc9",
	"\\#cd594a",
	"\\#b5c689",
	"\\#f58b4c"
};

local defaults = {
	msg_timeout = 100,
	tbar_timeout = 200,
	font_def = "default.ttf",
	font_fb = "emoji.ttf",
	font_sz = 18,
	font_hint = 2,
	font_str = "",
	text_color = "\\#aaaaaa",
	label_color = "\\#ffff00",
	borderw = 1,
	bordert = 1,

-- right now, the options are 'none' and 'auto'
	preview_mode = "auto",
	first_run = true,

-- should entries that request a password show the input as *** chars
	passmask = false,

--
-- advanced lockscreen features, not currently mapped to UI
-- lock_ok = "!/some/path/like/resume_all",
-- lock_on = "!/some/path/like/suspend_all"
-- lock_fail_1 = "!/system/output=fail_once",
-- lock_fail_10 = "!/system/shutdown/ok",
--

-- default window dimensions (relative tiler size) for windows
-- created in float mode with unknown starting size
	float_defw = 0.3,
	float_defh = 0.2,

-- default encoder setting, used by suppl when building string. We don't
-- have a way to query the span of these parameters yet (like available
-- codecs).
	enc_fps = 30,
	enc_srate = -1,
	enc_vcodec = "H264",
	enc_vpreset = 8,
	enc_container = "mkv",
	enc_presilence = 0,
	enc_vbr = 0,

-- SECURITY: set _path to :disabled to disable these features, or enable
-- whitelist and modify whitelist.lua to set allowed commands and paths
	extcon_path = "durden",
	status_path = "status",
	control_path = "control",
	output_path = "output",
	whitelist = false,

-- SECURITY: set to "full" to allow clients that request authentication tokens
-- against the GPU to let those tokens go through. This can compromise security
-- or safety as the privileges given for such a token may expose buffer contents
-- or queue GPU resources that may compromise the display server.
	gpu_auth = "none",

-- SECURITY: set to passive, active, full or none depending on the default
-- access permissions to any client that requests to manage gamma or clipboard
	gamma_access = "none",
	clipboard_access = "none",

-- if > 0, wait n ticks before re-activating external connection path
-- (default clock, ~25 == 1s.)
	extcon_rlimit = 25,
-- ignore rlimit first n ticks after startup (allow initial start burst)
	extcon_startdelay = 100,
-- if n > 0: while >= n external windows, disable external windows (
-- requires extcon_rlimit > 0 as it uses the same timer when evaluating)
	extcon_wndlimit = 0,
-- limit subwindows per connection, also covers hidden windows (e.g. clipboard)
	subwnd_limit = 10,

-- only enabled manually, only passive for now
	remote_port = 5900,
	remote_pass = "guest",

-- MANUAL/REQUIRES RESTART: setting this to true possibly reduces latency,
-- Performance footprint etc. but prevents certain features like selective
-- desktop sharing and multiple displays.
	display_simple = false,
	display_shader = "basic",

-- on dedicated- fullscreen, switch rendertarget refreshrate to the following
-- cloclvalue (0, disabled entirely, -n every n frame, n every n tick
	display_fs_rtrate = 2,

-- some people can't handle the flash transition between workspaces,
-- setting this to a higher value adds animation fade in/out
	transition = 10,
	animation = 10,

-- (none, move-h, move-v, fade)
	ws_transition_in = "fade",
	ws_transition_out = "fade",
	ws_autodestroy = true,
	ws_autoadopt = true,
	ws_default = "tile",

-- preview covers the generation / tracking of a downsampled / filtered
-- copy of each workstation based on the current rendertarget. It's also used
-- for features like brightness based transition speed scaling, ambience LEDs,
-- lockscreen and lbar background
	ws_preview = false,
	ws_preview_scale = 0.3,
	ws_preview_shader = "noalpha",
	ws_preview_rate = 5,
	ws_preview_metrics = false,

-- per window toggle, global default here
	hide_titlebar = false,

-- %(fmt-char) p (tag) t (title) i (ident) a (archetype)
-- optional character limit after each entry, whitespace breaks out of fmt-char
	titlebar_ptn = "%p %t - %i",

-- we repeat regular mouse/mstate properties here to avoid a separate
-- path for loading / restoring / updating
	mouse_focus_event = "click", -- motion, hover
	mouse_remember_position = true,
	mouse_factor = 1.0,
	mouse_autohide = true,
	mouse_reveal = true,
	mouse_dblclick = 12,
	mouse_hidetime = 120,
	mouse_hovertime = 40,
	mouse_dragdelta = 4,
	mouse_cursorset = "default",

-- disable all mouse management and related menus
	mouse_block = false,

-- > 0, the minimum clock-delta before a button is accepted again
	mouse_debounce_1 = 0,
	mouse_debounce_2 = 0,
	mouse_debounce_3 = 0,
	mouse_debounce_4 = 0,
	mouse_debounce_5 = 0,
	mouse_debounce_6 = 0,
	mouse_debounce_7 = 0,
	mouse_debounce_8 = 0,

-- used for keyboard- move step size in float mode
	float_tile_sz = {16, 16},
	float_tbar_override = false,

-- used as a workaround for mouse-control issues when we cannot get
-- relative samples etc. due to being in a windows mode with different
-- scaling parameters, SDL on OSX for instance.
	mouse_hardlock = false,

-- "native' or "nonnative", while native is more energy- efficient as mouse
-- motion do not contribute to a full refresh, it may be bugged on some
-- platforms and have problems with multiple monitors right now.
	mouse_mode = "nonnative",
	mouse_scalef = 1.0,

-- default classifier for unknown touch devices
	mt_classifier = "relmouse",

-- audio settings
	global_gain = 1.0,
	gain_fade = 10,
	global_mute = false,

-- default keyboard repeat rate for all windows, some archetypes have
-- default overrides and individual windows can have strong overrides
	kbd_period = 4,
	kbd_delay = 600,

-- accepted values: m1, m2, none
	meta_lock = "m2",
	meta_stick_time = 0,
	meta_dbltime = 10,

-- built-in terminal defaults
	term_autosz = true, -- will ignore cellw / cellh and use font testrender
	term_cellw = 12,
	term_cellh = 12,
	term_font_sz = 12,
	term_font_hint = 2,
	term_font = "hack.ttf",
	term_bgcol = {0x00, 0x00, 0x00},
	term_fgcol = {0xff, 0xff, 0xff},
	term_opa = 1.0,
	term_palette = "",
	term_append_arg = "", -- ci=ind,r,g,b to override individual colors

-- input bar graphics
	lbar_dim = 0.8,
	lbar_tpad = 4,
	lbar_bpad = 0,
	lbar_spacing = 10,
	lbar_sz = 12, -- dynamically recalculated on font changes
	lbar_bg = {0x33, 0x33, 0x33},
	lbar_textstr = "\\#cccccc ",
	lbar_alertstr = "\\#ff0000 ",
	lbar_labelstr = "\\#00ff00 ",
	lbar_menulblstr = "\\#ffff00 ",
	lbar_menulblselstr = "\\#ffff00 ",
	lbar_helperstr = "\\#ffffff ",
	lbar_errstr = "\\#ff4444 ",
	lbar_caret_w = 2,
	lbar_caret_h = 16,
	lbar_caret_col = {0x00, 0xff, 0x00},
	lbar_seltextstr = "\\#ffffff ",
	lbar_seltextbg = {0x44, 0x66, 0x88},
	lbar_itemspace = 10,
	lbar_textsz = 12,

-- binding bar
	bind_waittime = 30,
	bind_repeat = 5,

-- sbar
	sbar_tpad = 2,
	sbar_bpad = 2,
	sbar_sz = 12, -- dynamically recalculated on font changes
	sbar_textstr = "\\#00ff00 ",
	sbar_alpha = 0.3,
	sbar_pos = "top",
	sbar_hud = false, -- show only on HUD (global/target menu)

-- titlebar
	tbar_sz = 12, -- dynamically recalculated on font changes
	tbar_tpad = 2,
	tbar_bpad = 2,
	tbar_text = "left", -- left, center, right
	tbar_textstr = "\\#ffffff ",
	pretiletext_color = "\\#ffffff ",

-- LWA specific settings, only really useful for development / debugging
	lwa_autores = true
};

local listeners = {};
function gconfig_listen(key, id, fun)
	if (listeners[key] == nil) then
		listeners[key] = {};
	end
	listeners[key][id] = fun;
end

-- for tools and other plugins to enable their own values
function gconfig_register(key, val)
	if (not defaults[key]) then
		local v = get_key(key);
		if (v ~= nil) then
			if (type(val) == "number") then
				v = tonumber(v);
			elseif (type(val) == "boolean") then
				v = v == "true";
			end
			defaults[key] = v;
		else
			defaults[key] = val;
		end
	end
end

function gconfig_set(key, val, force)
if (type(val) ~= type(defaults[key])) then
		warning(string.format("gconfig_set(), type (%s) mismatch (%s) for key (%s)",
			type(val), type(defaults[key]), key));
		return;
	end

	defaults[key] = val;

	if (force) then
		store_key(defaults[key], tostring(val));
	end

	if (listeners[key]) then
		for k,v in pairs(listeners[key]) do
			v(key, val);
		end
	end
end

local allowed = system_load("whitelist.lua")();

-- whitelist used for control channel
local allowed = {
	input_lock_on = true,
	input_lock_off = true,
	input_lock_toggle = true
};

function allowed_commands(cmd)
	if (cmd == nil or string.len(cmd) == 0) then
		return false;
	end

	local rv = string.split(cmd, "=")[1];
	return gconfig_get("whitelist") == false or
		allowed[cmd];
end

function gconfig_get(key)
	return defaults[key];
end

local function gconfig_setup()
	for k,vl in pairs(defaults) do
		local v = get_key(k);
		if (v) then
			if (type(vl) == "number") then
				defaults[k] = tonumber(v);
-- no packing format for tables, ignore for now, since its a trusted context,
-- we can use concat / split without much issue, although store_key should
-- really support deep table serialization
			elseif (type(vl) == "table") then
				defaults[k] = defaults[k];
			elseif (type(vl) == "boolean") then
				defaults[k] = v == "true";
			else
				defaults[k] = v;
			end
		end
	end

	local ms = mouse_state();
	mouse_acceleration(defaults.mouse_factor, defaults.mouse_factor);
	ms.autohide = defaults.mouse_autohide;
	ms.hover_ticks = defaults.mouse_hovertime;
	ms.drag_delta = defaults.mouse_dragdelta;
	ms.hide_base = defaults.mouse_hidetime;
	for i=1,8 do
		ms.btns_bounce[i] = defaults["mouse_debounce_" .. tostring(i)];
	end
end

-- shouldn't store all of default overrides in database, just from a
-- filtered subset
function gconfig_shutdown()
	local ktbl = {};
	for k,v in pairs(defaults) do
		if (type(v) ~= "table") then
			ktbl[k] = tostring(v);
		end
	end

	store_key(ktbl);
end

gconfig_setup();
