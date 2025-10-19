-- Shizen.lua — modern skeet script (compact core)
-- Version: 1.0.0
-- Author: shizen clan
-- Designed for Gamesense (skeet) Lua API

local SCRIPT = {
  name = "shizen.lua",
  version = "1.0.0",
  tag = "shizen",
}

-- Short utilities
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi
local time, random, tickcount = globals.realtime, client.random_int, globals.tickcount

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function lerp(a, b, t) return a + (b - a) * t end
local function ease_out_cubic(t) t = clamp(t, 0, 1); t = 1 - (1 - t) ^ 3; return t end
local function vec_len(x, y, z) return sqrt(x * x + y * y + (z or 0) * (z or 0)) end

-- Safe API wrappers (no-op if missing)
local function safe(fn, ...) if fn then return fn(...) end end

-- Colors
local col = {
  white = {255, 255, 255, 255},
  glow = {146, 104, 255, 255},
  accent = {200, 120, 255, 255},
  warn = {255, 90, 90, 255},
  ok = {120, 255, 180, 255},
  dim = {255, 255, 255, 120},
}

-- Fonts
local font_title = renderer.create_font and renderer.create_font("Verdana", 28, 800, {"d"}) or nil
local font_ui = renderer.create_font and renderer.create_font("Small Fonts", 12, 0, {}) or nil

-- Greetings pool (20 cozy options)
local GREETINGS = {
  "Welcome home.",
  "Breathe in. Exhale. You’re safe here.",
  "Lights are warm, crosshair is warmer.",
  "Take your time—perfection is patient.",
  "Storm outside, quiet aim within.",
  "Your tempo, your flow.",
  "Let the noise fade.",
  "We move with purpose.",
  "Precision made gentle.",
  "Soft focus. Sharp impact.",
  "All signals green.",
  "Today feels lucky.",
  "Calm hands. Clever mind.",
  "Trust your rhythm.",
  "Elegance in every tick.",
  "Just play—I'll handle the rest.",
  "Welcome back, seeker.",
  "The room hums in violet.",
  "Let’s write a better demo.",
  "Centered. Ready.",
}

-- UI grouping
local function uicb(tab, sub, name) return ui.new_checkbox(tab, sub, name) end
local function uisl(tab, sub, name, mn, mx, step, sufx) return ui.new_slider(tab, sub, name, mn, mx, step or 1, sufx) end
local function uihk(tab, sub, name, mode) return ui.new_hotkey(tab, sub, name, mode or false) end
local function uicl(tab, sub, name, r, g, b, a) return ui.new_color_picker(tab, sub, name, r, g, b, a or 255) end
local function uiml(tab, sub, name, opts) return ui.new_multiselect(tab, sub, name, opts) end
local function uicm(tab, sub, name, opts) return ui.new_combobox(tab, sub, name, opts) end

-- Refs to built-ins we may need
local ref = {
  dt = {ui.reference("RAGE", "Exploits", "Double tap")},
  fd = {ui.reference("RAGE", "Other", "Duck peek assist")},
  auto_peek = {ui.reference("MISC", "Movement", "Auto peek")},
  sp = {ui.reference("RAGE", "Aimbot", "Safe point")},
  ba = {ui.reference("RAGE", "Aimbot", "Body aim")},
  hc = {ui.reference("RAGE", "Aimbot", "Minimum hit chance")},
  md = {ui.reference("RAGE", "Aimbot", "Minimum damage")},
  aa_yaw = {ui.reference("AA", "Anti-aimbot angles", "Yaw")},
  aa_yaw_base = {ui.reference("AA", "Anti-aimbot angles", "Yaw base")},
  aa_yaw_jit = {ui.reference("AA", "Anti-aimbot angles", "Yaw jitter")},
  aa_pitch = {ui.reference("AA", "Anti-aimbot angles", "Pitch")},
  aa_fs = {ui.reference("AA", "Anti-aimbot angles", "Freestanding")},
  aa_leg = {ui.reference("AA", "Other", "Leg movement")},
  fakelag = {ui.reference("AA", "Fake lag", "Enabled")},
  fakelag_lim = {ui.reference("AA", "Fake lag", "Limit")},
  fakelag_var = {ui.reference("AA", "Fake lag", "Variance")},
  avoid_players = {ui.reference("MISC", "Movement", "Avoid players")},
  dormant = {ui.reference("RAGE", "Other", "Dormant aimbot")},
  fake_latency = {ui.reference("MISC", "Miscellaneous", "Fake latency")},
}

-- Script UI
local ui_main_enable = uicb("LUA", "A", "Shizen — enable")
local ui_greet_console = uicb("LUA", "A", "Greeting: console")
local ui_greet_splash = uicb("LUA", "A", "Greeting: splash")
local ui_theme_glow = uicb("LUA", "A", "Glow theme")
local ui_tag_enable = uicb("LUA", "A", "Clantag animation")
local ui_tag_text = ui.new_textbox("LUA", "A", "Clantag text")
local ui_tag_random_case = uicb("LUA", "A", "Clantag random case")
local ui_notify = uicb("LUA", "A", "Load notification")
local ui_console_color = uicl("LUA", "A", "Console color", 146, 104, 255, 255)

-- Modes
local ui_mode_noscope = uicb("LUA", "B", "Noscope mode")
local ui_mode_noscope_hc = uisl("LUA", "B", "Noscope hitchance", 1, 100, 1, "%")
local ui_mode_noscope_dist = uisl("LUA", "B", "Noscope max distance", 100, 4000, 10, "u")
local ui_mode_noscope_wep = uiml("LUA", "B", "Noscope weapons", {"SCAR", "SSG08", "AWP"})
local ui_mode_air = uicb("LUA", "B", "In-air mode")
local ui_mode_air_hc = uisl("LUA", "B", "In-air hitchance", 1, 100, 1, "%")
local ui_mode_air_wep = uiml("LUA", "B", "In-air weapons", {"SCAR", "SSG08", "AWP", "R8"})
local ui_ideal_dt = uicb("LUA", "B", "Ideal tick: Double tap")
local ui_ideal_fs = uicb("LUA", "B", "Ideal tick: Freestanding")
local ui_ideal_js = uicb("LUA", "B", "Ideal tick: Jump scout")

-- Visuals core
local ui_scope_overlay = uicb("LUA", "B", "Better scope overlay")
local ui_scope_gap = uisl("LUA", "B", "Scope gap", 0, 100, 1, "px")
local ui_scope_len = uisl("LUA", "B", "Scope length", 10, 400, 1, "px")
local ui_scope_spread = uicb("LUA", "B", "Scope spreads scale")
local ui_scope_aspect = uisl("LUA", "B", "Scope aspect scale", 50, 200, 1, "%")
local ui_scope_ex_h = uicb("LUA", "B", "Scope exclude horizontal")
local ui_scope_ex_v = uicb("LUA", "B", "Scope exclude vertical")
local ui_scope_color = uicl("LUA", "B", "Scope color", 255, 255, 255, 180)

local ui_hitmarker = uicb("LUA", "B", "Hitmarker")
local ui_hitmarker_time = uisl("LUA", "B", "Hitmarker time", 0, 120, 1, "t")
local ui_hitmarker_world = uicb("LUA", "B", "World damage markers")
local ui_hitmarker_color = uicl("LUA", "B", "Hitmarker color", 255, 255, 255, 255)

local ui_indicators = uicb("LUA", "B", "500$ indicators")
local ui_indicators_glow = uicb("LUA", "B", "Indicators glow")
local ui_crosshair_ind = uicb("LUA", "B", "Crosshair indicators")
local ui_crosshair_x = uisl("LUA", "B", "Crosshair X offset", -300, 300, 1, "px")
local ui_crosshair_y = uisl("LUA", "B", "Crosshair Y offset", -300, 300, 1, "px")
local ui_crosshair_main = uicl("LUA", "B", "Crosshair main color", 200, 255, 220, 240)
local ui_crosshair_watermark = uicl("LUA", "B", "Crosshair watermark color", 180, 180, 190, 220)
local ui_crosshair_glow = uicb("LUA", "B", "Crosshair glow")

local ui_arrows = uicb("LUA", "B", "Anti-aim arrows")
local ui_arrows_radius = uisl("LUA", "B", "Arrows radius", 4, 200, 1, "px")
local ui_arrows_size = uisl("LUA", "B", "Arrows size", 2, 24, 1, "px")
local ui_arrows_outline = uicb("LUA", "B", "Arrows outline")
local ui_arrows_pulse = uicb("LUA", "B", "Arrows pulsing")
local ui_arrows_show = uiml("LUA", "B", "Arrows show", {"Eye yaw", "Real", "Fake"})

local ui_logs = uicb("LUA", "B", "Logs: Chimera panel")
local ui_logs_glow = uicb("LUA", "B", "Logs glow")
local ui_logs_style = uicm("LUA", "B", "Logs style", {"Chimera", "Console panel"})

local ui_zeus_warn = uicb("LUA", "B", "Zeus warning")
local ui_ragdoll = uicb("LUA", "B", "Ragdoll animation")
local ui_viewmodel = uicb("LUA", "B", "Viewmodel changer")
local ui_vm_fov = uisl("LUA", "B", "VM FOV", 54, 120, 1, "fov")
local ui_vm_x = uisl("LUA", "B", "VM X", -10, 10, 1)
local ui_vm_y = uisl("LUA", "B", "VM Y", -10, 10, 1)
local ui_vm_z = uisl("LUA", "B", "VM Z", -10, 10, 1)

local ui_aspect = uisl("LUA", "B", "Aspect ratio", 0, 200, 1, "%")

-- AA / Manual
local ui_aa_enable = uicb("LUA", "B", "Shizen AA enable")
local ui_aa_manual = uicb("LUA", "B", "Manual yaw")
local hk_left = uihk("LUA", "B", "Manual left")
local hk_right = uihk("LUA", "B", "Manual right")
local hk_forward = uihk("LUA", "B", "Manual forward")
local ui_manual_disable_mod = uicb("LUA", "B", "Disable yaw modifiers")
local ui_aa_fs = uicb("LUA", "B", "Freestanding assist")
local ui_aa_avoid_backstab = uicb("LUA", "B", "Avoid backstab")
local ui_aa_static_body = uicb("LUA", "B", "Static body yaw")
local ui_leg_breaker = uicb("LUA", "B", "Leg breaker")
local ui_fake_lag_fluct = uicb("LUA", "B", "Fluctuate fake lag")

-- Resolver / Safety
local ui_resolver = uicb("LUA", "B", "Custom resolver")
local ui_resolver_aggr = uisl("LUA", "B", "Resolver aggression", 0, 100, 1, "%")
local ui_backtrack_safe = uicb("LUA", "B", "Prefer backtrack when unsafe")

-- Misc
local ui_unmute = uicb("LUA", "B", "Unmute muted players")
local ui_clantag_spam = uicb("LUA", "B", "Clan tag spammer")
local ui_talk = uicb("LUA", "B", "Talk: on kill/death")
local ui_talk_nowarmup = uicb("LUA", "B", "Silence during warmup")
local ui_icon_flash = uicb("LUA", "B", "Icon flash on round start")
local ui_avoid_collisions = uicb("LUA", "B", "Avoid collisions")
local ui_quick_nade = uicb("LUA", "B", "Quick nade")
local ui_super_toss = uicb("LUA", "B", "Super toss (replica)")
local ui_fast_ladder = uicb("LUA", "B", "Fast ladder")
local ui_unlock_fake_latency = uicb("LUA", "B", "Unlock fake latency")
local ui_console_panel = uicb("LUA", "B", "Console panel (colored)")

-- Config
local ui_cfg_import = ui.new_button("LUA", "B", "Import from clipboard", function() end)
local ui_cfg_export = ui.new_button("LUA", "B", "Export to clipboard", function() end)
local ui_cfg_default = ui.new_button("LUA", "B", "Load defaults", function() end)

-- Internal state
local state = {
  splash_start = 0,
  notify_until = 0,
  notify_text = nil,
  notify_col = {146, 104, 255, 255},
  hit_events = {},
  dmg_world = {},
  logs = {},
  mana = {left=false,right=false,forward=false},
  last_miss = {},
  warmup = false,
}

-- Console colored log
local function clog(r, g, b, msg)
  if client.color_log then client.color_log(r, g, b, msg) else client.log(msg) end
end

-- Greeting + splash
local function random_case(s)
  if not ui.get(ui_tag_random_case) then return s end
  local out = {}
  for i = 1, #s do
    local c = s:sub(i, i)
    if c:match("%a") and random(0, 1) == 1 then c = c:upper() else c = c:lower() end
    out[#out+1] = c
  end
  return table.concat(out)
end

local function show_greeting()
  if not ui.get(ui_main_enable) then return end
  if ui.get(ui_greet_console) then
    local r,g,b,a = ui.get(ui_console_color)
    clog(r, g, b, string.format("[%s] %s", SCRIPT.name, GREETINGS[random(1, #GREETINGS)]))
  end
  if ui.get(ui_greet_splash) then
    state.splash_start = time()
  end
  if ui.get(ui_notify) then
    state.notify_text = "Shizen loaded"
    state.notify_until = time() + 3
  end
end

-- Clantag animation
local tag_frames = {
  "シ", "シゼ", "シゼン", "シゼン·", "シゼン·S", "シゼン·Sh", "シゼン·Shi", "シゼン·Shiz", "シゼン·Shize", "シゼン·Shizen",
  "·Shizen", "Shizen", "ｓｈｉｚｅｎ", random_case("Shizen"),
}

local function update_tag()
  if not ui.get(ui_main_enable) or not ui.get(ui_tag_enable) then return end
  local custom = ui.get(ui_tag_text) or "Shizen"
  local t = time()
  local idx = (floor(t * 3) % #tag_frames) + 1
  local frame = tag_frames[idx]
  if random(0, 25) == 0 then frame = random_case(custom) end
  safe(client.set_clan_tag, frame)
end

-- Notifications renderer
local function draw_notification()
  if state.notify_until <= time() or not state.notify_text then return end
  local sw, sh = client.screen_size()
  local tleft = state.notify_until - time()
  local a = clamp(tleft / 3, 0, 1)
  local w = 220
  local h = 26
  local x = sw - w - 24
  local y = 24
  local bg = {20, 20, 24, floor(220 * a)}
  renderer.rectangle(x, y, w, h, bg[1], bg[2], bg[3], bg[4])
  renderer.text(x + 10, y + 6, 200, 120, 255, floor(255 * a), nil, 0, state.notify_text)
end

-- Splash draw
local function draw_splash()
  if state.splash_start == 0 then return end
  local elapsed = time() - state.splash_start
  if elapsed > 4 then state.splash_start = 0 return end
  local sw, sh = client.screen_size()
  local t = ease_out_cubic(clamp(elapsed / 1.4, 0, 1))
  local a = floor(255 * (elapsed < 3 and t or 1 - clamp((elapsed - 3) / 1, 0, 1)))
  local size = lerp(18, 42, t)
  local text = "Shizen"
  local tw, th = renderer.measure_text(font_title, size, text)
  local x = sw * 0.5 - tw * 0.5
  local y = sh * 0.2
  renderer.text(x, y, 146, 104, 255, a, font_title, size, text)
  renderer.text(x, y + th + 6, 210, 210, 210, a, font_ui, 12, GREETINGS[(floor(time()*2) % #GREETINGS) + 1])
end

-- Hit events + markers
client.set_event_callback("player_hurt", function(e)
  if not ui.get(ui_main_enable) then return end
  local me = entity.get_local_player()
  if client.userid_to_entindex(e.attacker) ~= me then return end
  local now = time()
  state.hit_events[#state.hit_events+1] = {t=now, dmg=e.dmg_health}
  if ui.get(ui_hitmarker_world) then
    local victim = client.userid_to_entindex(e.userid)
    if victim then
      local x, y, z = entity.get_origin(victim)
      if x then state.dmg_world[#state.dmg_world+1] = {t=now, dmg=e.dmg_health, x=x, y=y, z=z+40} end
    end
  end
end)

-- Death/Talk
client.set_event_callback("player_death", function(e)
  if not ui.get(ui_main_enable) or not ui.get(ui_talk) then return end
  if state.warmup and ui.get(ui_talk_nowarmup) then return end
  local me = entity.get_local_player()
  local attacker = client.userid_to_entindex(e.attacker)
  local victim = client.userid_to_entindex(e.userid)
  local lines_kill = {
    "ggs.","that felt inevitable.","gentle tap, harsh lesson.","you peeked the wrong calm.","just flowing."}
  local lines_death = {
    "wd, reset.","nice shot.","ok, you got me.","recalibrating...","one step back."}
  if attacker == me and victim ~= me then client.exec("say " .. lines_kill[random(1,#lines_kill)])
  elseif victim == me and attacker ~= me then client.exec("say " .. lines_death[random(1,#lines_death)]) end
end)

-- Warmup check
client.set_event_callback("round_prestart", function()
  local gr = entity.get_game_rules()
  state.warmup = gr and entity.get_prop(gr, "m_bWarmupPeriod") == 1 or false
  if ui.get(ui_icon_flash) then client.exec("gameui_activate") end
end)

-- Viewmodel / Aspect / Unmute
client.set_event_callback("net_update_end", function()
  if not ui.get(ui_main_enable) then return end
  if ui.get(ui_unmute) then client.exec("voice_enable 1") end
  if ui.get(ui_viewmodel) then
    cvar.viewmodel_fov:set_int(ui.get(ui_vm_fov))
    cvar.viewmodel_offset_x:set_int(ui.get(ui_vm_x))
    cvar.viewmodel_offset_y:set_int(ui.get(ui_vm_y))
    cvar.viewmodel_offset_z:set_int(ui.get(ui_vm_z))
  end
  if ui.get(ui_ragdoll) then
    if cvar.phys_pushscale then cvar.phys_pushscale:set_float(1.2) end
    if cvar.cl_ragdoll_gravity then cvar.cl_ragdoll_gravity:set_int(-600) end
  end
  local ar = ui.get(ui_aspect)
  if ar and cvar.r_aspectratio then cvar.r_aspectratio:set_float(ar/100) end
  update_tag()
end)

-- Resolver heuristics
client.set_event_callback("aim_miss", function(e)
  if not ui.get(ui_main_enable) or not ui.get(ui_resolver) then return end
  if e.reason ~= "resolver" and e.reason ~= "spread" then return end
  local aggr = ui.get(ui_resolver_aggr)
  if e.reason == "resolver" then
    if ref.sp[1] and ref.sp[2] then ui.set(ref.sp[1], true) ui.set(ref.sp[2], "On") end
    if ref.ba[1] and ref.ba[2] then ui.set(ref.ba[1], true) ui.set(ref.ba[2], "Prefer") end
  elseif e.reason == "spread" and ui.get(ui_backtrack_safe) then
    if ref.sp[1] and ref.sp[2] then ui.set(ref.sp[1], true) ui.set(ref.sp[2], "Only") end
  end
  state.last_miss.t = time(); state.last_miss.reason = e.reason; state.last_miss.aggr = aggr
end)

-- Hitchance modifiers: noscope / air
client.set_event_callback("setup_command", function(cmd)
  if not ui.get(ui_main_enable) then return end
  local me = entity.get_local_player()
  if not me or not entity.is_alive(me) then return end
  local weapon = entity.get_player_weapon(me)
  local wname = weapon and entity.get_classname(weapon) or ""
  local flags = entity.get_prop(me, "m_fFlags") or 0
  local on_ground = bit.band(flags, 1) == 1
  local scoped = entity.get_prop(me, "m_bIsScoped") == 1

  -- Noscope mode
  if ui.get(ui_mode_noscope) and not scoped then
    local allow = false
    local weps = ui.get(ui_mode_noscope_wep)
    for i=1,#weps do if wname:find(weps[i]) then allow = true break end end
    if allow then
      local target = ragebot.get_target and ragebot.get_target() or nil
      local dist_ok = true
      if target then
        local lx, ly, lz = entity.get_origin(me)
        local tx, ty, tz = entity.get_origin(target)
        if lx and tx then dist_ok = vec_len(lx-tx, ly-ty, (lz or 0) - (tz or 0)) <= ui.get(ui_mode_noscope_dist) end
      end
      if dist_ok and ref.hc[1] then ui.set(ref.hc[1], true); ui.set(ref.hc[2], ui.get(ui_mode_noscope_hc)) end
    end
  end

  -- In-air mode
  if ui.get(ui_mode_air) and not on_ground then
    local allow = false
    local weps = ui.get(ui_mode_air_wep)
    for i=1,#weps do if wname:find(weps[i]) then allow = true break end end
    if allow and ref.hc[1] then ui.set(ref.hc[1], true); ui.set(ref.hc[2], ui.get(ui_mode_air_hc)) end
  end

  -- Ideal tick helpers
  if ui.get(ui_ideal_dt) and ref.dt[1] then ui.set(ref.dt[1], true) end
  if ui.get(ui_ideal_fs) and ref.aa_fs[1] then ui.set(ref.aa_fs[1], true) end
  if ui.get(ui_ideal_js) and wname:find("SSG08") then cmd.in_jump = 1 end

  -- DT based peek assist color (visual cue via log)
  if ref.auto_peek[1] and ui.get(ref.auto_peek[1]) then
    if ref.dt[1] and ui.get(ref.dt[1]) then
      state.logs[#state.logs+1] = {t=time(), msg="peek: DT ready"}
    end
  end

  -- Manual AA
  if ui.get(ui_aa_enable) then
    local left = ui.get(hk_left); local right = ui.get(hk_right); local forward = ui.get(hk_forward)
    if left or right or forward then
      if ref.aa_yaw[1] then ui.set(ref.aa_yaw[1], "180") end
      if ref.aa_yaw_base[1] then
        if left then ui.set(ref.aa_yaw_base[1], "Left")
        elseif right then ui.set(ref.aa_yaw_base[1], "Right")
        elseif forward then ui.set(ref.aa_yaw_base[1], "At targets") end
      end
      if ui.get(ui_manual_disable_mod) then
        if ref.aa_yaw_jit[1] then ui.set(ref.aa_yaw_jit[1], "Off") end
      end
    end
    if ui.get(ui_aa_static_body) and ref.aa_leg[1] then ui.set(ref.aa_leg[1], "Slide walk") end
    if ui.get(ui_fake_lag_fluct) and ref.fakelag[1] then
      ui.set(ref.fakelag[1], true)
      if ref.fakelag_lim[1] then ui.set(ref.fakelag_lim[1], random(6, 14)) end
      if ref.fakelag_var[1] then ui.set(ref.fakelag_var[1], random(0, 50)) end
    end
    if ui.get(ui_leg_breaker) then
      cmd.move_yaw = (cmd.move_yaw or 0) + (random(-1,1) * random(0, 2))
    end
  end

  -- Mobility helpers
  if ui.get(ui_fast_ladder) and cmd.in_jump == 1 then
    cmd.forwardmove = 450
  end
  if ui.get(ui_quick_nade) and weapon and wname:find("Grenade") then
    if cmd.in_attack == 1 then cmd.in_attack2 = 1 end
  end
  if ui.get(ui_super_toss) and weapon and wname:find("Grenade") then
    if cmd.in_attack == 1 and cmd.in_attack2 == 1 then cmd.in_jump = 1 end
  end

  if ui.get(ui_avoid_collisions) and ref.avoid_players[1] then
    ui.set(ref.avoid_players[1], true)
  end
end)

-- Drawing visuals
local function draw_scope_overlay()
  if not ui.get(ui_scope_overlay) then return end
  local r,g,b,a = ui.get(ui_scope_color)
  local sw, sh = client.screen_size()
  local gap = ui.get(ui_scope_gap)
  local len = ui.get(ui_scope_len)
  local aspect_scale = ui.get(ui_scope_aspect) / 100
  local cx, cy = sw/2, sh/2
  local weapon = entity.get_player_weapon(entity.get_local_player())
  local spread_scale = 1
  if ui.get(ui_scope_spread) and weapon then
    local pen = entity.get_prop(weapon, "m_fAccuracyPenalty") or 0
    spread_scale = 1 + clamp(pen, 0, 1.5)
  end
  gap = floor(gap * spread_scale)
  len = floor(len * aspect_scale)
  if not ui.get(ui_scope_ex_h) then
    renderer.line(cx-gap, cy, cx-gap-len, cy, r,g,b,a)
    renderer.line(cx+gap, cy, cx+gap+len, cy, r,g,b,a)
  end
  if not ui.get(ui_scope_ex_v) then
    renderer.line(cx, cy-gap, cx, cy-gap-len, r,g,b,a)
    renderer.line(cx, cy+gap, cx, cy+gap+len, r,g,b,a)
  end
end

local function draw_hitmarkers()
  if not ui.get(ui_hitmarker) then return end
  local tmax = max(0.1, ui.get(ui_hitmarker_time)/60)
  local now = time()
  local cx, cy = client.screen_size(); cx = cx/2; cy = cy/2
  local r,g,b,a = ui.get(ui_hitmarker_color)
  for i=#state.hit_events,1,-1 do
    local e = state.hit_events[i]
    local age = now - e.t
    if age > tmax then table.remove(state.hit_events, i) else
      local f = 1 - (age / tmax)
      local s = 6 + 8 * f
      local aa = floor(255 * f)
      renderer.line(cx - s, cy - s, cx - s/2, cy - s/2, r,g,b,aa)
      renderer.line(cx + s, cy - s, cx + s/2, cy - s/2, r,g,b,aa)
      renderer.line(cx - s, cy + s, cx - s/2, cy + s/2, r,g,b,aa)
      renderer.line(cx + s, cy + s, cx + s/2, cy + s/2, r,g,b,aa)
    end
  end
  for i=#state.dmg_world,1,-1 do
    local w = state.dmg_world[i]
    local age = now - w.t
    if age > tmax then table.remove(state.dmg_world, i) else
      local sx, sy = renderer.world_to_screen(w.x, w.y, w.z)
      if sx and sy then renderer.text(sx, sy, r, g, b, floor(255 * (1 - age/tmax)), nil, 0, "-"..tostring(w.dmg)) end
    end
  end
end

local function draw_indicators()
  if not ui.get(ui_indicators) then return end
  local sw, sh = client.screen_size()
  local cx, cy = sw/2, sh/2
  local x = cx + (ui.get(ui_crosshair_x) or 12)
  local y = cy + (ui.get(ui_crosshair_y) or 16)
  local list = {}
  local function add(lbl, active, color)
    list[#list+1] = {lbl=lbl, on=active, c=color or (active and col.ok or col.dim)}
  end
  local dt_on = ref.dt[1] and ui.get(ref.dt[1]) or false
  local fd_on = ref.fd[1] and ui.get(ref.fd[1]) or false
  local fs_on = ref.aa_fs[1] and ui.get(ref.aa_fs[1]) or false
  local fl_on = ref.fakelag[1] and ui.get(ref.fakelag[1]) or false
  local md_val = ref.md[2] and ui.get(ref.md[2]) or nil
  local gr = entity.get_game_rules()
  local bomb_planted = gr and entity.get_prop(gr, "m_bBombPlanted") == 1 or false
  local me = entity.get_local_player()
  local defusing = me and entity.get_prop(me, "m_bIsDefusing") == 1 or false
  local fake_latency_amt = (ref.fake_latency and ref.fake_latency[2]) and ui.get(ref.fake_latency[2]) or 0
  local fake_latency_on = (ref.fake_latency and ref.fake_latency[1]) and ui.get(ref.fake_latency[1]) or false
  add("DT", dt_on)
  local fd_col = (dt_on and {146,104,255,255}) or nil
  add("FD", fd_on, fd_col)
  add("FS", fs_on)
  add("FL", fl_on)
  add("SAFE", ref.sp[1] and ui.get(ref.sp[1]))
  add("BA", ref.ba[1] and ui.get(ref.ba[1]))
  if md_val then add("DMG:"..tostring(md_val), true, {220,220,220,220}) end
  if fake_latency_on then add("LAT:"..tostring(fake_latency_amt), true, {200,180,255,220}) end
  if defusing then add("DEF", true, {255,120,120,220}) end
  if bomb_planted then add("BOMB", true, {255,180,120,220}) end
  local main_r, main_g, main_b, main_a = ui.get(ui_crosshair_main)
  for i=1,#list do
    local it = list[i]
    local ty = y + (i-1)*12
    if ui.get(ui_crosshair_glow) then
      renderer.text(x+1, ty+1, 0, 0, 0, 180, font_ui, 12, it.lbl)
    end
    local cr, cg, cb, ca = it.c[1], it.c[2], it.c[3], it.c[4]
    if ui.get(ui_crosshair_ind) then cr, cg, cb, ca = main_r, main_g, main_b, main_a end
    renderer.text(x, ty, cr, cg, cb, ca, font_ui, 12, it.lbl)
  end
  if ui.get(ui_crosshair_ind) and not ui.get(ui_crosshair_glow) then
    local wm_r, wm_g, wm_b, wm_a = ui.get(ui_crosshair_watermark)
    renderer.text(x, y - 14, wm_r, wm_g, wm_b, wm_a, font_ui, 12, "shizen")
  end
end

local function draw_aa_arrows()
  if not ui.get(ui_arrows) then return end
  local sw, sh = client.screen_size(); local cx, cy = sw/2, sh/2
  local size = ui.get(ui_arrows_size)
  local rad = ui.get(ui_arrows_radius)
  local yaw_real = antiaim and antiaim.get_real and antiaim.get_real() or 0
  local yaw_fake = antiaim and antiaim.get_fake and antiaim.get_fake() or 0
  local eye_pitch, eye_yaw = client.camera_angles() or 0, 0
  if type(eye_pitch) == "number" then eye_pitch, eye_yaw = client.camera_angles() end
  local pulse = ui.get(ui_arrows_pulse) and (0.6 + 0.4 * (0.5 + 0.5 * sin(time()*4))) or 1
  local function draw_arrow(angle, rr, gg, bb, aa)
    local ang = (angle + 90) * pi/180
    local x = cx + cos(ang) * rad
    local y = cy + sin(ang) * rad
    local s = size * pulse
    if ui.get(ui_arrows_outline) then
      renderer.triangle(x, y, x - s, y + s, x + s, y + s, 0, 0, 0, 200)
    end
    renderer.triangle(x, y, x - s, y + s, x + s, y + s, rr, gg, bb, aa)
  end
  local show = ui.get(ui_arrows_show)
  for i=1,#show do
    if show[i] == "Real" then draw_arrow(yaw_real, 180, 220, 255, 200) end
    if show[i] == "Fake" then draw_arrow(yaw_fake, 255, 140, 220, 180) end
    if show[i] == "Eye yaw" then draw_arrow(eye_yaw or 0, 200, 200, 200, 200) end
  end
end

local function draw_logs()
  if not ui.get(ui_logs) then return end
  local sw, sh = client.screen_size(); local x, y = 24, sh - 120
  for i=1, min(#state.logs, 6) do
    local it = state.logs[#state.logs - i + 1]
    local a = floor(255 * clamp(1 - (time() - it.t)/4, 0, 1))
    local style = ui.get(ui_logs_style) or "Chimera"
    if style == "Chimera" then
      if ui.get(ui_logs_glow) then renderer.text(x+1, y - (i-1)*14 + 1, 0, 0, 0, a, font_ui, 12, it.msg) end
      renderer.text(x, y - (i-1)*14, 210, 210, 220, a, font_ui, 12, it.msg)
    else
      -- Console panel style prints once when added (handled in callbacks)
      renderer.text(x, y - (i-1)*14, 170, 190, 210, a, font_ui, 12, it.msg)
    end
  end
end

-- Zeus warning
local function draw_zeus_warning()
  if not ui.get(ui_zeus_warn) then return end
  local me = entity.get_local_player(); if not me then return end
  local mx, my, mz = entity.get_origin(me); if not mx then return end
  local enemies = entity.get_players(true)
  for i=1,#enemies do
    local e = enemies[i]
    if entity.is_alive(e) then
      local w = entity.get_player_weapon(e)
      if w then
        local name = entity.get_classname(w) or ""
        if name:find("Taser") then
          local ex, ey, ez = entity.get_origin(e)
          if ex then
            local d = vec_len(mx-ex, my-ey, mz-ez)
            if d < 200 then
              local sx, sy = renderer.world_to_screen(ex, ey, ez+60)
              if sx and sy then renderer.text(sx, sy, 255, 80, 80, 255, font_ui, 12, "ZEUS!") end
            end
          end
        end
      end
    end
  end
end

-- Paint
client.set_event_callback("paint", function()
  if not ui.get(ui_main_enable) then return end
  draw_scope_overlay()
  draw_hitmarkers()
  draw_indicators()
  draw_aa_arrows()
  draw_logs()
  draw_zeus_warning()
  draw_notification()
  draw_splash()
  if ui.get(ui_theme_glow) then
    local sw, sh = client.screen_size()
    renderer.gradient(0, 0, sw, 2, 146,104,255,0, 146,104,255,180, true)
  end
end)

-- Logs helpers
client.set_event_callback("aim_hit", function(e)
  if not ui.get(ui_main_enable) then return end
  local msg = string.format("hit %s for %d", entity.get_player_name(e.target) or "?", e.damage or 0)
  state.logs[#state.logs+1] = {t=time(), msg=msg}
  if ui.get(ui_console_panel) then
    local r,g,b,a = ui.get(ui_console_color)
    clog(r, g, b, "[shizen] " .. msg)
  end
end)
client.set_event_callback("aim_miss", function(e)
  if not ui.get(ui_main_enable) then return end
  local msg = string.format("missed %s (%s)", entity.get_player_name(e.target) or "?", e.reason or "?")
  state.logs[#state.logs+1] = {t=time(), msg=msg}
  if ui.get(ui_console_panel) then
    local r,g,b,a = ui.get(ui_console_color)
    clog(r, g, b, "[shizen] " .. msg)
  end
end)

-- Config serialization (minimal INI-like)
local cfg_keys = {}
local function reg(key, ref)
  cfg_keys[#cfg_keys+1] = {key=key, ref=ref}
end

local function get_any(ref)
  if type(ref) == "table" and ref[1] then return ui.get(ref[1], ref[2]) end
  return ui.get(ref)
end

local function set_any(ref, value)
  if type(ref) == "table" and ref[1] then ui.set(ref[1], value, ref[2]) else ui.set(ref, value) end
end

-- Register all settings for config
local function register_all()
  local list = {
    {"main_enable", ui_main_enable},
    {"greet_console", ui_greet_console},
    {"greet_splash", ui_greet_splash},
    {"theme_glow", ui_theme_glow},
    {"tag_enable", ui_tag_enable},
    {"tag_text", ui_tag_text},
    {"tag_random_case", ui_tag_random_case},
    {"notify", ui_notify},
    {"console_color", ui_console_color},
    {"noscope", ui_mode_noscope},
    {"noscope_hc", ui_mode_noscope_hc},
    {"noscope_dist", ui_mode_noscope_dist},
    {"noscope_wep", ui_mode_noscope_wep},
    {"air", ui_mode_air},
    {"air_hc", ui_mode_air_hc},
    {"air_wep", ui_mode_air_wep},
    {"ideal_dt", ui_ideal_dt},
    {"ideal_fs", ui_ideal_fs},
    {"ideal_js", ui_ideal_js},
    {"scope_overlay", ui_scope_overlay},
    {"scope_gap", ui_scope_gap},
    {"scope_len", ui_scope_len},
    {"scope_spread", ui_scope_spread},
    {"scope_aspect", ui_scope_aspect},
    {"scope_ex_h", ui_scope_ex_h},
    {"scope_ex_v", ui_scope_ex_v},
    {"scope_color", ui_scope_color},
    {"hitmarker", ui_hitmarker},
    {"hitmarker_time", ui_hitmarker_time},
    {"hitmarker_world", ui_hitmarker_world},
    {"hitmarker_color", ui_hitmarker_color},
    {"indicators", ui_indicators},
    {"indicators_glow", ui_indicators_glow},
    {"crosshair_ind", ui_crosshair_ind},
    {"crosshair_x", ui_crosshair_x},
    {"crosshair_y", ui_crosshair_y},
    {"crosshair_main", ui_crosshair_main},
    {"crosshair_watermark", ui_crosshair_watermark},
    {"crosshair_glow", ui_crosshair_glow},
    {"arrows", ui_arrows},
    {"arrows_radius", ui_arrows_radius},
    {"arrows_size", ui_arrows_size},
    {"arrows_outline", ui_arrows_outline},
    {"arrows_pulse", ui_arrows_pulse},
    {"arrows_show", ui_arrows_show},
    {"logs", ui_logs},
    {"logs_glow", ui_logs_glow},
    {"logs_style", ui_logs_style},
    {"zeus_warn", ui_zeus_warn},
    {"ragdoll", ui_ragdoll},
    {"viewmodel", ui_viewmodel},
    {"vm_fov", ui_vm_fov},
    {"vm_x", ui_vm_x},
    {"vm_y", ui_vm_y},
    {"vm_z", ui_vm_z},
    {"aspect", ui_aspect},
    {"aa_enable", ui_aa_enable},
    {"aa_manual", ui_aa_manual},
    {"aa_fs", ui_aa_fs},
    {"aa_avoid_backstab", ui_aa_avoid_backstab},
    {"aa_static_body", ui_aa_static_body},
    {"leg_breaker", ui_leg_breaker},
    {"fake_lag_fluct", ui_fake_lag_fluct},
    {"resolver", ui_resolver},
    {"resolver_aggr", ui_resolver_aggr},
    {"backtrack_safe", ui_backtrack_safe},
    {"unmute", ui_unmute},
    {"clantag_spam", ui_clantag_spam},
    {"talk", ui_talk},
    {"talk_nowarmup", ui_talk_nowarmup},
    {"icon_flash", ui_icon_flash},
    {"avoid_collisions", ui_avoid_collisions},
    {"quick_nade", ui_quick_nade},
    {"super_toss", ui_super_toss},
    {"fast_ladder", ui_fast_ladder},
    {"unlock_fake_latency", ui_unlock_fake_latency},
    {"console_panel", ui_console_panel},
  }
  for i=1,#list do reg(list[i][1], list[i][2]) end
end
register_all()

local function encode()
  local t = {}
  for i=1,#cfg_keys do
    local it = cfg_keys[i]
    local v = get_any(it.ref)
    local ty = type(v)
    if ty == "table" then v = table.concat(v, "|") ty = "list" end
    if ty == "userdata" then ty = "color"; local r,g,b,a = ui.get(it.ref); v = table.concat({r,g,b,a}, ",") end
    t[#t+1] = it.key .. "=" .. ty .. ":" .. tostring(v)
  end
  return table.concat(t, "\n")
end

local function decode(s)
  local r = {}
  for line in string.gmatch(s or "", "[^\n]+") do
    local k, payload = line:match("([^=]+)=(.+)")
    if k and payload then
      local ty, val = payload:match("([^:]+):(.+)")
      if ty == "boolean" then r[k] = val == "true"
      elseif ty == "number" then r[k] = tonumber(val)
      elseif ty == "string" then r[k] = val
      elseif ty == "list" then
        local t = {}; for p in string.gmatch(val, "[^|]+") do t[#t+1] = p end; r[k] = t
      elseif ty == "color" then
        local rr,gg,bb,aa = val:match("(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)")
        r[k] = {tonumber(rr),tonumber(gg),tonumber(bb),tonumber(aa)}
      end
    end
  end
  return r
end

local function apply_cfg(map)
  for i=1,#cfg_keys do
    local it = cfg_keys[i]
    local v = map[it.key]
    if v ~= nil then
      if type(v) == "table" and #v == 4 and type(v[1]) == "number" then
        ui.set(it.ref, v[1], v[2], v[3], v[4])
      else
        set_any(it.ref, v)
      end
    end
  end
end

ui.set_callback(ui_cfg_export, function()
  local txt = encode()
  if clipboard and clipboard.set then clipboard.set(txt) end
  state.notify_text = "Config exported"
  state.notify_until = time() + 2.0
end)
ui.set_callback(ui_cfg_import, function()
  local txt = clipboard and clipboard.get and clipboard.get() or ""
  apply_cfg(decode(txt))
  state.notify_text = "Config imported"
  state.notify_until = time() + 2.0
end)
ui.set_callback(ui_cfg_default, function()
  ui.set(ui_main_enable, true)
  ui.set(ui_greet_console, true)
  ui.set(ui_greet_splash, true)
  ui.set(ui_theme_glow, true)
  ui.set(ui_tag_enable, true)
  ui.set(ui_notify, true)
  state.notify_text = "Defaults loaded"
  state.notify_until = time() + 2.0
end)

-- Initial greet once menu opens the first time
client.set_event_callback("shutdown", function() safe(client.set_clan_tag, "") end)
client.set_event_callback("paint_ui", function()
  if ui.get(ui_main_enable) and state.splash_start == 0 and (not state._greeted) then
    state._greeted = true
    show_greeting()
  end
end)

-- Cosmetic console color demo
ui.set_callback(ui_console_color, function()
  local r,g,b,a = ui.get(ui_console_color)
  clog(r, g, b, string.format("[%s] console color updated", SCRIPT.name))
end)

-- Clan tag spammer (fallback)
client.set_event_callback("run_command", function()
  if not ui.get(ui_main_enable) then return end
  if ui.get(ui_clantag_spam) then update_tag() end
end)

-- End of file
