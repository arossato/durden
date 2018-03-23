return {
-- background, can't be swapped in and at the end of the viewport
"layers/add=bg",
"layers/layer_bg/settings/depth=50.0",
"layers/layer_bg/settings/radius=50.0",
"layers/layer_bg/settings/fixed=true",
"layers/layer_bg/settings/ignore=true",

-- a little extra work to define a multi- mapped textured cube
"layers/layer_bg/add_model/cube=bg",
"layers/layer_bg/models/bg/faces/1/source=box/0.png", -- +x
"layers/layer_bg/models/bg/faces/2/source=box/1.png", -- -x
"layers/layer_bg/models/bg/faces/3/source=box/2.png", -- +y
"layers/layer_bg/models/bg/faces/4/source=box/3.png", -- -y
"layers/layer_bg/models/bg/faces/5/source=box/4.png", -- +z
"layers/layer_bg/models/bg/faces/6/source=box/5.png", -- -z

-- an interactive foreground layer with a transparent terminal
"layers/add=fg",
"layers/layer_fg/settings/active_scale=3",
"layers/layer_fg/settings/inactive_scale=1",
"layers/layer_fg/settings/depth=2.0",
"layers/layer_fg/settings/radius=10.0",
"layers/layer_fg/settings/spacing=0.0",
"layers/layer_fg/settings/vspacing=0.1",
"layers/layer_fg/terminal=bgalpha=128",

-- a hidden model that only gets activated on client
-- connect/disconnect and uses side by side
--"layers/layer_fg/add_model/rectangle=sbsvid",
--"layers/layer_fg/models/sbsvid/connpoint/reveal=sbsvid",
--"layers/layer_fg/models/sbsvid/stereoscopic=sbs"
};

-- "layers/layer_bg/add_model/sphere=bg",
-- "layers/layer_bg/models/bg/source=center360.png",
-- "layers/layer_bg/models/bg/connpoint/temporary=360bg",
