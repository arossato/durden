--
-- most of these functions come mapped via the waybridge- handler as subseg
-- requests, though the same setup and mapping need to work via reset-adopt
-- as well, hence the separation.
--
-- the big work item here is resize related, most of durden is written as
-- forced independent resizes, while wayland only really functions with
-- deferred, client driven ones.
--
-- thus, in_drag_rz, maximimize needs reworking, we need to do some autocrop,
-- pan for tiling and resize/constraints that account for the geometry of the
-- surface.
--
local toplevel_lut = {};
local log, fmt = suppl_add_logfn("wayland");

-- criterion: if the window has input focus (though according to spec
-- it can loose focus during drag for unspecified reasons) and the mouse
-- is clicked, we toggle canvas- drag.
toplevel_lut["move"] = function(wnd, ...)
	if (active_display().selected == wnd) then
		wnd:set_drag_move();
	end

	log("toplevel:move");
end

toplevel_lut["maximize"] = function(wnd)
	log("toplevel:maximize");
	if (wnd.space and wnd.space.mode == "float") then
		wnd:toggle_maximize();
	end
end

toplevel_lut["demaximize"] = function(wnd)
	log("toplevel:demaximize");
	if (wnd.space and wnd.space.mode == "float") then
		wnd:toggle_maximize();
	end
end

toplevel_lut["menu"] = function(wnd)
	log("toplevel:menu");
	if (active_display().selected == wnd) then
		dispatch_symbol("/target");
	end
end

local function set_dragrz_state(wnd, mask, from_wl)
	local props = image_storage_properties(wnd.canvas);

-- accumulator gets subtracted the difference between the acked event
-- and the delta that has occured since then
	wnd.last_w = props.width;
	wnd.last_h = props.height;
	wnd.rz_acc_x = 0;
	wnd.rz_acc_y = 0;
	wnd.rz_ofs_x = 0;
	wnd.rz_ofs_y = 0;

-- different masking/moving value interpretation
	if (not from_wl) then
		mask = {
			mask[1],
			mask[2],
			mask[1] < 0 and -1 or 0,
			mask[2] < 0 and -1 or 0
		};
	end

-- if we have geometry, then we need to offset our hints or the initial
-- drag will get a 'jump' based on this difference
	if (wnd.geom) then
		wnd.rz_ofs_x = -(props.width - wnd.geom[3]);
		wnd.rz_ofs_y = -(props.height - wnd.geom[4]);
	end

-- this will be reset on the completion of the drag
	wnd.on_drag_rz =
	function(wnd, ctx, vid, dx, dy, last)
		dx = dx * mask[1];
		dy = dy * mask[2];
		wnd.move_mask = {mask[3], mask[4]};
		wnd.rz_acc_x = wnd.rz_acc_x + dx;
		wnd.rz_acc_y = wnd.rz_acc_y + dy;

		local tdm = wnd.dispmask;
		if (not last) then
			tdm = bit.bor(tdm, TD_HINT_CONTINUED);
		end
		wnd:displayhint(
			wnd.last_w + wnd.rz_acc_x + wnd.rz_ofs_x,
			wnd.last_h + wnd.rz_acc_y + wnd.rz_ofs_y, tdm
		);
	end
end

toplevel_lut["resize"] = function(wnd, dx, dy)
	log(fmt("toplevel:resize:edge_x=%d:edge_y=%d", dx, dy));
	if (active_display().selected ~= wnd or wnd.space.mode ~= "float") then
		return;
	end

-- the dx/dy message comes from a hint as to which side is being dragged
-- we need to mask the canvas- drag event handler accordingly
	dx = tonumber(dx);
	dy = tonumber(dy);
	dx = math.clamp(dx, -1, 1);
	dy = math.clamp(dy, -1, 1);
	local mask = {dx, dy, dx < 0 and -1 or 0, dy < 0 and -1 or 0};

	set_dragrz_state(wnd, mask, true);
end

-- try and center but don't go out of screen boundaries
local function center_to(wnd, parent)
	local dw = wnd.width;
	local dh = wnd.height;

	if (parent.space and parent.space.mode == "float") then
		wnd.max_w = parent.width * 0.8;
		wnd.max_h = parent.height * 0.8;
		dw = wnd.max_w;
		dh = wnd.max_h;
		wnd:displayhint(wnd.max_w, wnd.max_h);
	end

	wnd:move(parent.x, parent.y, false, true, true, false);
end

local function float_reparent(wnd, parent)
	parent:add_overlay("wayland", color_surface(1, 1, 0, 0, 0), {
		stretch = true,
		blend = 0.5,
		mouse_handler = {
			click = function(ctx)
-- this should select the deepest child window in the chain
				parent:to_front();
				wnd:select();
				wnd:to_front();
			end,
			drag = function(ctx, vid, dx, dy)
-- in float, this should of course move the window
				wnd:move(dx, dy, false, false, true, false);
				parent:move(dx, dy, false, false, true, false);
			end
		},
	});

	parent.old_protect = parent.delete_protect;

-- override the parent selection to move to the new window, UNLESS
-- another toplevel window has already performed this action
	if (not parent.old_select) then
		parent.old_select = parent.select;
		parent.select = function(...)
			if (wnd.select) then
				wnd:select(...)
			end
		end
	end

-- since the surface might not have been presented yet, we want to
-- try and center on the first resize event as well
	wnd.pending_center = parent;
	center_to(wnd, parent);

-- track the reference so we know the state of the window on release
	parent.indirect_child = wnd;
	wnd.indirect_parent = parent;
end

local function tile_reparent(wnd, parent)
-- one possible tactic here is to 'hide' the parent and swap-out the
-- children, the way we used to have 'alternates' - and then have a
-- way to restore (window deletion)
end

-- this is also triggered on_destroy for the toplevel window so the id
-- always gets relinked before
local function set_parent(wnd, id)
	if (id == 0) then
		local ip = wnd.indirect_parent;
		if (ip and ip.anchor) then
			assert(ip.indirect_child == wnd);
			ip:drop_overlay("wayland");
			ip.delete_protect = ip.old_protect;
			local pvid = image_parent(ip.anchor);
			ip.old_protect = nil;
			ip.select = ip.old_select;
			ip.indirect_child = nil;
			ip.old_select = nil;
		end
		wnd.indirect_parent = nil;
		return;
	end

	local parent = wayland_wndcookie(id);
	if (parent == wnd) then
		log("toplevel:parent_error=self");
		return;
	end

	if (parent.indirect_child and parent.indirect_child ~= wnd) then
		log("toplevel:parent_error=collision");
		return;
	end

	if (not parent or not parent.add_overlay) then
		log("toplevel:parent_error=unknown");
		return;
	end

-- switch selection (brings to front), dim the parent and make it invincible
-- delete protect, input block, select block (delete will unset)
	if (active_display().selected == parent) then
		wnd:select();
	end

	if (parent.geom) then
-- geom isn't respected, viewport tests should do something with this
		log("toplevel:geom_eimpl");
	end

-- let reparented window inherit crop values, unless other ones have been
-- set, this should cover what fits with gtk3 at least
	if (parent.crop_values and not wnd.crop_values) then
		wnd:set_crop(parent.crop_values[1], parent.crop_values[2],
			parent.crop_values[3], parent.crop_values[4]);
	end

	if (parent.space.mode == "float") then
		float_reparent(wnd, parent);
	else
		tile_reparent(wnd, parent);
	end
end

function wayland_toplevel_handler(wnd, source, status)
	if (status.kind == "terminated") then
		wayland_lostwnd(source);
		wnd:destroy();
		return;

	elseif (status.kind == "registered") then
		wnd:set_guid(status.guid);

-- reparenting to another surface, this may or may not also grab input
	elseif (status.kind == "viewport") then
		log("toplevel:parent=" .. tostring(status.parent));
		set_parent(wnd, status.parent);

-- wayland doesn't distinguish between registered immutable title and current
-- identity, so we just map that directly to the window title
	elseif (status.kind == "ident") then
		wnd:set_title(status.message);

	elseif (status.kind == "message") then
		local opts = string.split(status.message, ":");
		if (not opts or not opts[1]) then
			log("toplevel:error_message=invalid format");
			return;
		end

		if (opts[1] == "shell" and opts[2] == "xdg_top") then
			if (not opts[3]) then
-- no-op, first message sets this
			elseif (not toplevel_lut[opts[3]]) then
				log(fmt("toplevel:error=unknown command:command=%s", opts[3]));
			else
				toplevel_lut[opts[3]](wnd, opts[4], opts[5]);
			end
		elseif (opts[1] == "geom") then
			local x, y, w, h;
			x = tonumber(opts[2]);
			y = tonumber(opts[3]);
			w = tonumber(opts[4]);
			h = tonumber(opts[5]);

-- Some clients send this practically every frame, only update if it has
-- actually updated, same with region cropping. This is not entirely correct
-- when there's subsurfaces that define the outer rim of the geometry. The
-- safeguard in such cases (no good test case right now) is to cache/only
-- use the geometry crop when there are no subsurfaces that resolve to
-- outside the toplevel.
			if (w and y and w and h) then
				if (not wnd.geom or (wnd.geom[1] ~= x or
					wnd.geom[2] ~= y or wnd.geom[3] ~= w or wnd.geom[4] ~= h)) then
					wnd.geom = {x, y, w, h};
-- new geometry, if we're set to autocrop then do that, if we have an
-- impostor defined, update it now
				end
			end
			if (#opts ~= 5) then
				log("toplevel:geometry_error=invalid arguments");
				return;
			end
		elseif (opts[1] == "scale") then
-- don't really care right now, part otherwise is just to set the
-- resolved factor to wnd:resize_effective
		elseif (opts[1] == "decor") then
			if opts[2] and opts[2] == "ssd" then
				wnd.show_titlebar = true
				wnd:set_titlebar(true, true)
				wnd.want_shadow = gconfig_get("shadow_style") ~= "none"
				wnd:resize(wnd.width, wnd.height, true, true);
			else
				wnd.show_titlebar = false
				wnd:set_titlebar(false, true)
				wnd.want_shadow = false
				if valid_vid(wnd.shadow) then
					delete_image(wnd.shadow)
				end
				wnd:resize(wnd.width, wnd.height, true, true);
			end
		else
			log(fmt("toplevel:error=unknown type:raw=%s", status.message));
		end

	elseif (status.kind == "segment_request") then
		log("toplevel:error=segment_request not permitted");

	elseif (status.kind == "resized") then
		if (wnd.ws_attach) then
			wnd:ws_attach();
			wnd.meta_dragmove = true;
		end

-- note, this will force + mask to avoid a cascade - since we're in 'client driven'
-- mode - the non-masked resize would trigger a [resize->displayhint->client_resize->..]
-- loop that can bounce based on rounding issues.
		wnd:resize_effective(status.width, status.height, true, true);

		log(fmt("toplevel:resized:w=%d:h=%d", status.width, status.height));

-- deferred from drag resize where the move should match the config change
		if (wnd.move_mask) then
			local dx = status.width - wnd.last_w;
			local dy = status.height - wnd.last_h;
			wnd.rz_acc_x = wnd.rz_acc_x - dx;
			wnd.rz_acc_y = wnd.rz_acc_y - dy;
			wnd:move(dx * wnd.move_mask[1],
				dy * wnd.move_mask[2], false, false, true, false);
			wnd.move_mask = nil;

-- and similar action for toplevel reparenting
		elseif (wnd.pending_center and wnd.pending_center.x) then
			center_to(wnd, wnd.pending_center);
			wnd.pending_center = nil;
		end

-- apply autocrop- auto-impostor
		if (wnd.last_w ~= status.width or wnd.last_h ~= status.height) then

		end

		wnd.last_w = status.width;
		wnd.last_h = status.height;
	end
end

wl_destroy = function(wnd, was_selected)
-- if a toplevel was set previously
	if (wnd.indirect_parent and wnd.indirect_parent.anchor) then
		local ip = wnd.indirect_parent;
		set_parent(wnd, 0);
		if (was_selected) then
			ip:select();
		end
	end

-- deregister the toplevel tracking
	if (wnd.bridge and wnd.bridge.wl_children) then
		wnd.bridge.wl_children[wnd.external] = nil;
	end
end

local function wl_resize(wnd, neww, newh, efw, efh)
	local props = image_storage_properties(wnd.canvas);
	local nefw = efw;
	local nefh = efh;

	if (wnd.geom) then
		nefw = wnd.geom[3] + (efw - wnd.last_w);
		nefh = wnd.geom[4] + (efh - wnd.last_h);
	end

	log(fmt(
		"toplevel:resize_hook:name=%s:inw=%d:inh=%d:efw=%d:efh=%d:outw=%d:outh=%d",
		wnd.name, neww, newh, efw, efh, nefw, nefh)
	);

	local dw = wnd.dh_pad_w;
	local dh = wnd.dh_pad_h;

-- manually toggle this off/on to prevent cascades
	if (wnd.space.mode == "float") then
		wnd:displayhint(nefw + dw, nefh + dh, wnd.dispmask);
-- for automatic modes, we just use the suggested max and subtract any decorations
	else
		wnd:displayhint(
			wnd.max_w - dw - wnd.pad_top - wnd.pad_bottom,
			wnd.max_h - dh - wnd.pad_left - wnd.pad_right,
			wnd.dispmask
		);
	end
end

local toplevel_menu = {
	{
		name = "debug",
		label = "Debug Bridge",
		kind = "action",
		description = "Send a debug window to the bridge client",
		validator = function()
			local wnd = active_display().selected;
			return wnd.bridge and valid_vid(wnd.bridge.external, TYPE_FRAMESERVER);
		end,
		handler = wayland_debug_wnd,
	}
};

return {
	atype = "wayland-toplevel",
	actions = {
		{
			name = "wayland",
			label = "Wayland",
			description = "Wayland specific window management options",
			submenu = true,
			kind = "action",
			eval = function()
				return false
			end,
			handler = toplevel_menu
		}
	},
	init = function(atype, wnd, source)
		wnd.last_w = 0;
		wnd.last_h = 0;
		wnd.drag_rz_enter = set_dragrz_state;
		wnd:add_handler("destroy", wl_destroy);
		wnd:add_handler("resize", wl_resize);
	end,
	props = {
		kbd_period = 0,
		kbd_delay = 0,
		centered = true,
		scalemode = "client",
		filtermode = FILTER_NONE,
		rate_unlimited = true,
-- all wayland windows connected to the same client need the same clipboard
		clipboard_block = true,
		font_block = true,
		block_rz_hint = false,
-- all allocations go on the parent
		allowed_segments = {},
	},
	dispatch = {}
};
