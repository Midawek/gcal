# GCAL: GMod Compliant Armature Layer

### Developer Documentation :3

GCAL is a modular offhand animation library for Garry's Mod and a backward-compatible replacement for VManip. This page is for addon authors who want to register and play hand animations with GCAL, or port VManip addons to it.

## Contents

1. [Overview](#1-overview)
2. [Getting started](#2-getting-started)
3. [Registering animations](#3-registering-animations)
4. [Playback and tracks](#4-playback-and-tracks)
5. [Runtime query API](#5-runtime-query-api)
6. [Hooks reference](#6-hooks-reference)
7. [Thirdperson (TPIK)](#7-thirdperson-tpik)
8. [Camera bone (cambone)](#8-camera-bone-cambone)
9. [Weapon-base strategies](#9-weapon-base-strategies)
10. [Multiplayer and networking](#10-multiplayer-and-networking)
11. [Migrating from VManip and VMLegs](#11-migrating-from-vmanip-and-vmlegs)
12. [Debugging](#12-debugging)
13. [Convar reference](#13-convar-reference)
14. [Integrations](#14-integrations)
15. [Deprecated and removed fields](#15-deprecated-and-removed-fields)

---

## 1. Overview

An addon registers animation data once, then asks GCAL to play it on a named **track**. For every playing track GCAL owns a hidden clientside model, advances its cycle once per rendered frame, reads the animated bones from it and writes them onto the viewmodel, the hands entity, or (in thirdperson) the player model.

| Piece | What it is |
| :---- | :--------- |
| `GCAL.Anims[name]` | Registry of static data from `GCAL:RegisterAnim`. |
| `GCAL.ActiveTracks[trackID]` | Runtime state of each playing track: cycle, blend (`lerpVal`), hold/segment state, models. |
| `GCAL.QueuedAnims[trackID]` | One queued animation name per track. |
| `GCAL.TPIKOptions[name]` | Thirdperson-only settings from `GCAL:RegisterTPIKOptions`. |
| Source model | Hidden `ClientsideModel` of the registered `model`. GCAL reads the animated bones from it. |
| Target entity | The entity GCAL writes bones to: the viewmodel if it has the target bones, otherwise the player's hands entity. Weapon-base strategies can override this. |
| Track ID | A runtime slot. Different tracks play at the same time; starting an animation on a busy track replaces the old one (unless it can't be interrupted, see [4](#4-playback-and-tracks)). |

### Lifecycle

1. Your addon calls `GCAL:RegisterAnim(name, data)` during clientside initialization.
2. Your addon calls `GCAL:Play(name, trackID)` when gameplay wants the gesture.
3. GCAL creates the source model(s), resolves the sequence and stores the track in `GCAL.ActiveTracks`.
4. Once per frame a shared updater advances every track (cycle, blend, sounds, hold/segment state) and starts queued animations. The render hooks only draw the result, so drawing both firstperson and thirdperson can't speed an animation up or skip short clips.
5. In the viewmodel pass GCAL places the source model, draws it (so props authored into it are visible), and blends its bone matrices into the target's.
6. When the animation finishes, is stopped, or is replaced, GCAL removes its models and fires the stop hooks.

### Firstperson vs thirdperson

Firstperson is a direct bone copy/blend from the source model onto the viewmodel or hands. It is the primary, most stable path.

Thirdperson reuses the same track timing; it does not run a second copy of the animation. GCAL's TPIK is also a direct bone copy, not an IK solver: each mapped bone is moved into the player's body space using the upper arm as reference, clamped to a box around `Spine4`, smoothed per bone, blended with the player's pose and written to the player model. Unmapped child bones follow, and a clone of the registered model renders addon props on the player's hand. Player models and weapon bases differ, so thirdperson often needs its own tuning: keep regular data in `RegisterAnim`, and put thirdperson-only tuning in `GCAL:RegisterTPIKOptions`.

### Native GCAL vs VManip compatibility

Native addons use `GCAL:RegisterAnim`, `GCAL:Play`, track IDs and GCAL hooks. The `VManip`/`VMLegs` shim keeps old addons working: their animations are registered with `legacy = true` and play on the `legacy_left_arm` track, with tolerant sequence lookup, VManip flip handling and the VManip globals synced every frame. Legacy animations get no TPIK, `gun_mode` or `blend_weight`, to encourage porting. New code should not depend on `VManip.*` globals such as `VManip.VMGesture` or `VManip.Cycle`. Section [11](#11-migrating-from-vmanip-and-vmlegs) covers porting.

---

## 2. Getting started

### Load order and realm

GCAL loads from `lua/autorun/gcal_init.lua` on both realms. Registration, playback and rendering are clientside; the server can only tell clients to play or stop animations ([10](#10-multiplayer-and-networking)).

`lua/autorun/aaa_gcal_shim.lua` runs before almost everything else and creates the `GCAL` table plus stub `VManip`/`VMLegs` tables, so VManip registrations made before GCAL loads are kept and imported later. Because the `GCAL` table can exist before GCAL itself has loaded, check for a function rather than the table:

```lua
-- lua/autorun/client/myaddon_gcal.lua
if not GCAL or not GCAL.RegisterAnim then return end

GCAL:RegisterSecondHandAnim("myaddon_ping", {
    model = "myaddon/c_ping.mdl",
    sequence = "ping",
    addon_name = "My Addon"
})
```

Files in `lua/autorun/client/` run after the shared `lua/autorun/` files, so GCAL is ready by then. If your file can run earlier, register from a hook you control (for example `InitPostEntity`). Register once, never every frame.

### Register

```lua
GCAL:RegisterSecondHandAnim("myaddon_ping", {
    model = "myaddon/c_ping.mdl", -- relative to models/ (a leading "models/" is stripped)
    sequence = "ping",
    lerp_peak = 0.5,              -- seconds after start before blending back out
    easing_in = "OutCubic",
    easing_out = "OutQuad"
})
```

`GCAL:RegisterAnim(name, data)` and the hand helpers return `true` on success and `false` for a missing name or data table. GCAL normalizes `data` in place. Re-registering a name that is currently playing updates the running track, which helps when hot-reloading.

### Play from the client

```lua
GCAL:Play("myaddon_ping")                 -- on the animation's registered track (left_arm here)
GCAL:Play("myaddon_ping", "myaddon_slot") -- on an explicit track
GCAL:PlaySecondHand("myaddon_ping")       -- always on left_arm unless you pass a track
```

`GCAL:Play` returns `false` when the animation isn't registered, has no model, its sequence can't be found, or something blocked it (a weapon-base strategy, `VManipPrePlayAnim`, legacy checks). It returns `true` when the animation starts, gets queued, or was skipped because the player disabled it in the GCAL menu (`GCALAnimSuppressed` fires).

To avoid restarting a long gesture, check the track first. For actions that should replace themselves, just call `GCAL:Play` again on the same track.

```lua
if not GCAL:IsTrackActive("left_arm") then
    GCAL:Play("myaddon_ping")
end
```

### Play from the server

```lua
GCAL:Play("myaddon_ping", nil, ply)       -- recipients: a player, a table of players or a CRecipientFilter
GCAL:Play(ply, "myaddon_ping", "left_arm") -- recipients first also works
GCAL:Play("myaddon_ping")                 -- no recipients: broadcast
```

The animation must be registered on the clients. See [10](#10-multiplayer-and-networking) for stopping tracks from the server.

### Recommended naming

Every addon and every imported VManip animation shares one registry, so use stable, namespaced names. They also keep debug output and the menu readable:

```lua
GCAL:RegisterSecondHandAnim("myaddon_tablet_open", { ... })
GCAL:RegisterSecondHandAnim("myaddon_tablet_close", { ... })
GCAL:RegisterSecondHandAnim("myaddon_tablet_press", { ... })
```

Avoid generic names like `open`, `use`, or `idle` unless the animation is internal and cannot conflict.

---

## 3. Registering animations

### Hand helpers and aliases

```lua
GCAL:RegisterHandAnim("myaddon_left_press", "left", { model = "myaddon/c_left_press.mdl" })
GCAL:RegisterSecondHandAnim("myaddon_offhand_press", { model = "myaddon/c_left_press.mdl" })   -- hand = "left"
GCAL:RegisterRightHandAnim("myaddon_right_press", { model = "myaddon/c_right_press.mdl" })     -- hand = "right"
GCAL:RegisterBothHandsAnim("myaddon_two_hand_panel", { model = "myaddon/c_two_hand_panel.mdl" }) -- hand = "both"
```

Each helper sets `data.hand` and calls `GCAL:RegisterAnim`.

| Hand | Accepted values | Default `bones` | Default track |
| :--- | :-------------- | :-------------- | :------------ |
| Left / second / offhand | `left`, `left_arm`, `l`, `second`, `second_hand`, `secondhand`, `offhand`, and any unrecognized value | `GCAL.GROUPS.LEFT_ARM` | `left_arm` |
| Right | `right`, `right_arm`, `r` | `GCAL.GROUPS.RIGHT_ARM` | `right_arm` |
| Both | `both`, `both_hands`, `bothhands`, `both_arms`, `dual` | `GCAL.GROUPS.BOTH_ARMS` | `both_arms` |

The `GCAL.GROUPS` lists hold the ValveBiped upper arm, forearm, hand, wrist, ulna and finger bones for each side. `GCAL:NormalizeHand(hand)` returns `"left"`, `"right"` or `"both"`; `GCAL:GetHandBones(hand)` and `GCAL:GetHandTrack(hand)` return the defaults above.

**Target hand vs source hand.** `hand` picks the viewmodel bones GCAL writes to; `source_hand` picks the bones it reads from your model. Use `source_hand` to drive the right hand from a left-authored sequence:

```lua
GCAL:RegisterRightHandAnim("myaddon_scanner_ping_right", {
    model = "myaddon/c_scanner.mdl",
    sequence = "scanner_ping",
    source_hand = "left"
})
```

Bones are paired by index: `source_bones[k]` drives `bones[k]`. `ValveBiped.Bip01_L_Ulna` is always read from the source model's `L_Forearm`.

### Field reference

**Model and sequence**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `model` | string | **required** | Model containing the sequence, relative to `models/`. A leading `models/` is stripped. |
| `sequence` | string | animation name | Sequence to play. GCAL looks up the animation name first, then `sequence`, then a case-insensitive match, so a model sequence named like the animation wins. |
| `model_scale` | number | 1 | Scale of the source animation model (mirrored under legacy flip). The thirdperson prop clone uses it too. |
| `model_skin` | number | | Skin of the source model. |
| `model_bodygroups` | table | | `{ [bodygroupID] = value, ... }` for the source model. |

**Timing**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `speed` | number | 1 | Cycles per second. Like VManip, GCAL advances the cycle by `FrameTime() * speed * gcal_playback_speed`, so at `speed = 1` the whole sequence takes one second whatever its authored length. Use `speed = 1 / authoredSeconds` to play at the authored rate. |
| `startcycle` | number | 0 | Cycle to start at (0 to 1). |
| `loop` | bool | false | Wraps the cycle and never blends out. `GCAL:QuitHolding(trackID)` ends the loop; `GCAL:StopTrack` cuts it. |
| `holdtime` | number | | Seconds after start at which the cycle freezes until `GCAL:QuitHolding`. |
| `preventquit` | bool | false | `GCAL:QuitHolding(trackID)` without an animation name won't release this hold. `QuitHolding(trackID, name)` still does. |
| `segmented` | bool | false | Segment mode, see [Segments](#segments). |
| `duration` | number | | Only read by the legacy pose-only fallback (a `legacy` model reporting zero sequences), where it sets the reported duration (falling back to `holdtime`, `lerp_peak`, then 1). Normal animations report the sequence duration. |

**Blending and easing**

`lerpVal` is the blend: 1 = weapon pose, 0 = full animation. A track blends in until `lerp_peak`, then blends back out. A non-looping, non-segmented track ends the moment its cycle reaches 1, so keep `lerp_peak` plus the blend-out shorter than the clip or the arm snaps back.

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `lerp_peak` | number | 0.5 | Seconds after start at which the blend-out begins. Compared against `CurTime()`; not scaled by `speed` or `gcal_playback_speed`. Re-armed on every loop, when the last segment starts, and after a hold release (`lerp_peak - holdtime` from the release). |
| `lerp_speed_in` / `lerp_speed_out` | number | 1 | Blend rate. A full blend takes `1 / (7 * lerp_speed)` seconds (about 0.14 s at 1). |
| `ease_in_time` / `ease_out_time` | number | | Blend durations in seconds. Override `lerp_speed_in` / `lerp_speed_out`. |
| `easing_in` / `easing_out` | string | `"Legacy"` | Easing used while blending in / out. |
| `lerp_curve` | number | 1 | Exponent of the `Legacy` easing (`t ^ lerp_curve`). Applies to whichever side is still `Legacy`. |
| `blend_weight` | number | 1 | Caps how strongly the animation overrides the pose (0 to 1), in firstperson and TPIK. Ignored on the `legacy_left_arm` track. |

Easing names: `Linear`, `InQuad`, `OutQuad`, `InOutQuad`, `InCubic`, `OutCubic`, `InOutCubic`, `OutElastic` (overshoots, good for snappy or bouncy moves) and `Legacy` (VManip's power curve). The functions live in `GCAL.Lerp` with the signature `fn(t, b, c, d)`; `GCAL.Lerp.Get(name)` returns one, falling back to `OutQuad` for unknown names.

**Bones and tracks**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `hand` | string | `"left"` | Target hand, see the alias table. Aliases: `arm`, `bone_group`. Unknown values mean left. |
| `bones` | table/string | from `hand` | Target bone names, or a hand alias such as `"right"`. |
| `source_hand` | string | | Hand to read in the source model. Alias: `source_arm`. |
| `source_bones` | table/string | `bones` | Source bone names or a hand alias, paired by index with `bones`. |
| `group_name` | string | from `hand` | Default track. `track` and `track_id` are aliases and take precedence, in the order `track`, `track_id`, `group_name`. |
| `addon_name` | string | see text | Group label in the menu's Toggle Anims tree. Aliases: `addon`, `source_addon`. Defaults to the file name for imported `vmanip/anims` files, otherwise `"GCAL"`. |

**Sound**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `sounds` | table | | `{ [path] = seconds }` after track start; replayed each loop. Played on the local player at `gcal_sound_pitch`. A custom sound set in the menu replaces every path. |
| `sound_volume` | number | 1 | Volume, 0 to 1. Values above 1 warn and are used as `sound_level`. |
| `sound_level` | number | 75 | Sound level (attenuation). |
| `sound_flags` | number | 0 | `SND_*` flags. |

**Camera** (see [8](#8-camera-bone-cambone))

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `cambone` | bool | nil | `false` opts this animation out and skips its camera model. `nil` and `true` both follow `gcal_cambone`; the convar turns cambone off for every animation. |
| `cam_ang` | Angle | `Angle(-79.75, 0, -90)` | Rest angle of the camera attachment. |
| `cam_angint` | table | `{ 1, 1, 1 }` | Per-axis intensity `{ pitch, yaw, roll }`. |

**Gun**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `gun_mode` | string/bool | off | `"follow"` (also `true`, `"hand"`, `"1"`) carries the weapon's bones along with the animated hand so the gun stays in the grip; if the gun isn't parented to the hand bones, every non-arm viewmodel bone moves rigidly with the right hand. `"animated"` (also `"anim"`, `"animation"`, `"2"`) copies the gun bone(s) from the source model and carries the rest of the gun with them. Any other value is off. Firstperson only; ignored for `legacy` animations. |
| `gun_bones` | string/table | auto | For `"animated"`: a bone name, a list, or a map `{ ["source model bone"] = "viewmodel bone" }`. When omitted GCAL uses the first of `ValveBiped.weapon_bone`, `weapon_bone`, `Weapon`, `weapon`, `tag_weapon`, `j_gun`, `v_weapon` found in both models; with no match it behaves like `"follow"`. |

**Behaviour**

| Field | Type | Default | Description |
| :---- | :--- | :------ | :---------- |
| `can_interrupt` | bool | true | `false`: `GCAL:Play` on the busy track queues instead of replacing. |
| `on_start`, `on_finish`, `on_interrupt` | function | | Callbacks, see [Callbacks](#callbacks). |
| `block_code` | bool | false | Marks the animation as a code blocker while it plays, see [block_code](#blocking-your-own-code-block_code). |
| `block_code_scope` | string | | Scope for `block_code`. Without one it blocks every scope. |
| `thirdperson` | bool | true | `false` disables TPIK and multiplayer sync for this animation. |
| `local_only` | bool | false | Never sent to other players. |
| `locktoply` | bool | false | Places the source model at the eye instead of the viewmodel. On `legacy_left_arm` it also blends 25% between view and viewmodel angles, like VManip. |
| `assurepos` | bool | false | On `legacy_left_arm`, parents the source model to the viewmodel (re-parented on weapon switch). On other tracks it acts like `locktoply`. |
| `legacy` | bool | false | VManip mode, set by the shim. |

`legacy = true` enables tolerant sequence resolution (lowercase name, normalized and partial name matches, a `c_vmanip<name>` model filename, the model's only sequence), a surrogate or pose-only fallback for models reporting zero sequences, VManip flip handling, eye-placed source models, VManip's start checks (see [11](#11-migrating-from-vmanip-and-vmlegs)) and `VManipPreActCheck`. It disables TPIK and `gun_mode`.

### Model authoring guidelines

GCAL expects a model under `models/` with a sequence it can resolve: a regular c_arms-style model, a VManip-style animation model, or an addon-owned gesture model containing the bones GCAL should read.

- Use ValveBiped arm bone names where possible (`ValveBiped.Bip01_L_UpperArm`, `ValveBiped.Bip01_L_Forearm`, `ValveBiped.Bip01_L_Hand`, fingers).
- Make sure the source model contains the bones implied by `source_bones` / `source_hand`, and the viewmodel or hands contain `bones`.
- Put props inside the animation model. GCAL draws the source model in firstperson, and the thirdperson prop clone is made from the same registered model, never from GCAL's own models.
- Author for VManip timing: one cycle per second at `speed = 1`.
- Use `sequence` when the animation name doesn't match the model's sequence.
- If the firstperson sequence is a poor thirdperson pose, add `GCAL:RegisterTPIKOptions(name, { sequence = "..." })` instead of changing the firstperson registration.
- Keep one gesture per animation name. Several registrations can share a model with different `sequence` values:

```lua
local MODEL = "myaddon/c_shared_tools.mdl"

GCAL:RegisterSecondHandAnim("myaddon_tool_raise", { model = MODEL, sequence = "tool_raise", addon_name = "My Addon" })
GCAL:RegisterSecondHandAnim("myaddon_tool_press", { model = MODEL, sequence = "tool_press", addon_name = "My Addon" })
```

---

## 4. Playback and tracks

### Standard and custom tracks

| Track | Used by |
| :---- | :------ |
| `left_arm` | Native left / second-hand animations. |
| `right_arm` | Native right-hand animations. |
| `both_arms` | Native both-hands animations. |
| `legacy_left_arm` | VManip animations registered through the shim. |
| `legs` | VMLegs animations. |
| any other string | Custom tracks. |

```lua
GCAL:Play("myaddon_watch_check", "left_arm")
GCAL:PlayHand("myaddon_hand_signal", "right") -- right_arm, both play at once
```

`GCAL:PlayHand(name, hand, trackID)` plays on `trackID` or the hand's standard track, ignoring the animation's registered track. `GCAL:PlaySecondHand(name, trackID)` is `PlayHand(name, "left", trackID)`.

- Use `left_arm`, `right_arm` or `both_arms` for normal hand gestures.
- Use a custom track when an animation is logically independent of the normal hand slot, and share it between mutually exclusive animations of one subsystem.
- Tracks are runtime slots, not event IDs. Don't create a new track every time you play something.
- Two tracks writing the same bones (for example `left_arm` and `legacy_left_arm`) overlap; avoid it.
- On death `legacy_left_arm` and `legs` stop automatically; other tracks keep running.

```lua
GCAL:RegisterSecondHandAnim("myaddon_scanner_insert", {
    model = "myaddon/c_scanner.mdl",
    sequence = "scanner_insert",
    track = "myaddon_scanner"
})

GCAL:RegisterSecondHandAnim("myaddon_scanner_remove", {
    model = "myaddon/c_scanner.mdl",
    sequence = "scanner_remove",
    track = "myaddon_scanner"
})

GCAL:Play("myaddon_scanner_insert") -- plays on myaddon_scanner
```

If `myaddon_scanner_remove` starts while `myaddon_scanner_insert` is still playing, the old one is replaced (its `on_interrupt` runs). Other tracks keep playing.

Control functions (client): `GCAL:StopTrack(trackID)`, `GCAL:StopAllTracks()`, `GCAL:QueueAnim(name, trackID)`, `GCAL:QuitHolding(trackID, animToStop)`, `GCAL:PlaySegment(trackID, sequence, lastSegment, sounds)`.

### Interrupting and queueing

`GCAL:QueueAnim(name, trackID)` stores one animation per track (default: the animation's registered track) and plays it as soon as the track is free. A second `QueueAnim` on the same track overwrites the first. When the playing animation has `can_interrupt = false`, `GCAL:Play` on its track queues automatically and returns `true`. Explicitly stopping a track (`GCAL:StopTrack`, `GCAL:StopAllTracks`, `gcal_stop`) also drops its queued animation; a natural finish or a replacement keeps it.

```lua
local MODEL = "myaddon/c_tablet.mdl"

GCAL:RegisterSecondHandAnim("myaddon_tablet_open", {
    model = MODEL,
    sequence = "open",
    can_interrupt = false, -- Play on this track queues while it runs
    on_finish = function(trackID, animName, track)
        if GCAL.QueuedAnims[trackID] then return end -- a close was requested meanwhile, let it play
        GCAL:Play("myaddon_tablet_idle", trackID)
    end,
    on_interrupt = function(trackID, oldAnim, newAnim)
        print(oldAnim .. " was interrupted by " .. newAnim)
    end
})

GCAL:RegisterSecondHandAnim("myaddon_tablet_idle", { model = MODEL, sequence = "idle", loop = true })
GCAL:RegisterSecondHandAnim("myaddon_tablet_close", { model = MODEL, sequence = "close" })

GCAL:Play("myaddon_tablet_open")
GCAL:Play("myaddon_tablet_close") -- queued, plays when tablet_open finishes
```

### Holding

```lua
GCAL:RegisterSecondHandAnim("myaddon_radio_hold", {
    model = "myaddon/c_radio.mdl",
    holdtime = 0.35
})

GCAL:Play("myaddon_radio_hold")
-- later:
GCAL:QuitHolding("left_arm")                       -- releases unless the animation has preventquit
GCAL:QuitHolding("left_arm", "myaddon_radio_hold") -- releases only that animation, even with preventquit
```

`QuitHolding` returns `true` when the release is accepted. It runs `GCALPreHoldQuit` (return `false` to block) and fires `GCALHoldQuit`. It also ends a `loop` and marks a segmented track's current segment as the last.

### Segments

A `segmented` animation stays blended in across several sequences of its model. When a segment's cycle reaches 1 GCAL fires `GCALSegmentFinish`; answer with `GCAL:PlaySegment(trackID, sequence, lastSegment, sounds)`. After the last segment ends and the blend-out completes, the track stops.

```lua
GCAL:RegisterSecondHandAnim("myaddon_tool", {
    model = "myaddon/c_tool.mdl",
    sequence = "tool_start",
    segmented = true
})

hook.Add("GCALSegmentFinish", "MyAddon_Tool", function(trackID, animName, segment, lastSegment, segmentCount)
    if animName ~= "myaddon_tool" or lastSegment then return end

    if segmentCount == 0 then
        GCAL:PlaySegment(trackID, "tool_loop", false)
    else
        GCAL:PlaySegment(trackID, "tool_end", true)
    end
end)
```

`PlaySegment` returns `false` unless the track is segmented, its current segment has finished, the last segment hasn't been played yet, and the sequence exists. `sounds` is `{ [path] = seconds }` from the segment start. `GCALPrePlaySegment` can block it. Segment changes are synced to other players ([10](#10-multiplayer-and-networking)).

### Callbacks

| Field | Signature | When |
| :---- | :-------- | :--- |
| `on_start` | `fn(trackID, animName, track)` | After the track is active, before `GCALTrackStarted`. |
| `on_finish` | `fn(trackID, animName, track)` | After a natural finish (not `StopTrack` or replacement). The track is already stopped (its models are removed), so calling `GCAL:Play` from here chains animations. |
| `on_interrupt` | `fn(trackID, oldAnimName, newAnimName)` | When another `GCAL:Play` replaces it on the same track. |

Errors inside callbacks are printed with a stack trace; playback continues.

### Blocking your own code (block_code)

`block_code` doesn't pause Lua. It exposes a gate that cooperating code checks so it can stop itself while the animation plays:

```lua
GCAL:RegisterSecondHandAnim("myaddon_insert_battery", {
    model = "myaddon/c_battery.mdl",
    sequence = "insert",
    block_code = true,
    block_code_scope = "myaddon_battery"
})

hook.Add("Think", "MyAddon_BatteryThink", function()
    if GCAL:IsCodeBlocked("myaddon_battery") then return end

    -- Regular battery logic, resumes after the insert animation.
end)
```

- `GCAL:IsCodeBlocked(scope)` returns `true, track` when an active `block_code` track matches, otherwise `false, nil`. A track matches when its scope equals `scope`, when it has no scope (it blocks every scope), or when `scope` is nil (any blocker).
- `GCAL:GetCodeBlockers(scope)` returns `{ [trackID] = track }` for every matching track.
- `GCALCodeBlockStarted` / `GCALCodeBlockStopped` fire when a blocker starts and stops.

### Recipes

Conditions and delays belong in your own code:

```lua
local ply = LocalPlayer()
if IsValid(ply) and ply:GetVelocity():Length() < 5 then -- only while standing still
    timer.Simple(0.2, function() GCAL:Play("myaddon_binoculars") end)
end
```

React to playback progress by polling the cycle:

```lua
hook.Add("Think", "MyAddon_ReloadClick", function()
    local track = GCAL:GetTrack("left_arm")
    if not track or track.name ~= "myaddon_reload" then return end

    if track.cycle >= 0.5 and not track.myClickPlayed then
        track.myClickPlayed = true
        LocalPlayer():EmitSound("weapons/reload_click.wav")
    end
end)
```

---

## 5. Runtime query API

Every getter is safe to call when the track isn't active, so you can poll from `Think` without guards. Tracks only exist on the client.

| Function | Returns |
| :------- | :------ |
| `GCAL:GetAnim(name)` | Registered (normalized) data, or nil. |
| `GCAL:GetAnimationNames()` | List of registered animation names. |
| `GCAL:GetTPIKOptions(name)` | Registered TPIK options, or nil. |
| `GCAL:GetTrack(trackID)` | Runtime track table (`name`, `cycle`, `lerpVal`, `data`, `model`, `camModel`, `attachment`, ...), or nil. Read it; don't restructure it. |
| `GCAL:GetActiveTrackIDs()` | List of active track IDs. |
| `GCAL:IsTrackActive(trackID)` | `true` while the track exists with a valid model. |
| `GCAL:GetCurrentAnim(trackID)` | Animation name, or nil. |
| `GCAL:GetCycle(trackID)` | Cycle 0 to 1 (0 when inactive). |
| `GCAL:SetCycle(trackID, cycle)` | Jumps to `cycle` and continues from there; `false` when inactive. |
| `GCAL:GetLerp(trackID)` | Blend, 1 = weapon pose, 0 = full animation. Returns 0 when inactive, so pair it with `IsTrackActive`. |
| `GCAL:IsLooping(trackID)` | `true` / `false`. |
| `GCAL:GetTrackDuration(trackID)` | The sequence's authored duration in seconds (not the playback length, see `speed`), or nil. |
| `GCAL:IsSegmented(trackID)` | `true` / `false`. |
| `GCAL:GetCurrentSegment(trackID)` | Sequence of the current segment (nil before the first `PlaySegment`). |
| `GCAL:GetSegmentCount(trackID)` | Segments played through `PlaySegment` (0 when inactive). |
| `GCAL:IsPreventQuit(trackID)` | `true` / `false`. |
| `GCAL:GetGunMode(trackID)` | `"follow"`, `"animated"` or nil. |
| `GCAL:IsCodeBlocked(scope)` | `true, track` or `false, nil`. |
| `GCAL:GetCodeBlockers(scope)` | `{ [trackID] = track }`. |
| `GCAL:GetGestureModel(trackID)` | Hidden source model, or nil. |
| `GCAL:GetCamModel(trackID)` | Camera model used for cambone, or nil. |
| `GCAL:GetTPIKModel(trackID)` | Separate TPIK source model (only exists when a TPIK `sequence` is set), or nil. |
| `GCAL:GetAllGestureModels()` | `{ [trackID] = model }` for every active track except `legs`. |
| `GCAL:IsThirdPersonEnabled()` | Whether `gcal_thirdperson` is on. |
| `GCAL:IsAnimEnabled(name)` / `GCAL:IsAnimSuppressed(name)` | Whether the player enabled / disabled the animation in the menu. |
| `GCAL:IsAnimTPIKEnabled(name)` | Whether the player left TPIK on for the animation. |
| `GCAL:GetAnimSoundOverride(name)` | Custom sound path set in the menu, or nil. |
| `GCAL:GetWeaponBaseStrategy(ply, weapon)` | Matching strategy table, or nil. |
| `GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy)` | `"arc9_tpik"` or `"normal"`. |
| `GCAL:IsDynaBaseAvailable()` | Whether DynaBase is installed. |

### Animation adjustments

Players can offset each animation from the menu (right-click an animation, "Edit offsets/TPIK..."). The values are stored in cookies and added to the global convars. Clientside.

| Function | Description |
| :------- | :---------- |
| `GCAL:GetAnimationAdjustmentValue(name, field)` | Stored per-animation value (0 when unset). |
| `GCAL:SetAnimationAdjustmentValue(name, field, value)` | Stores and persists a value. |
| `GCAL:ClearAnimationAdjustment(name)` | Resets every field of the animation. |
| `GCAL:GetAnimationAdjustment(name)` | Combined convar + per-animation table `{ pos, ang, tpik, option_add, isZero }` (cached). |
| `GCAL:ApplyAnimationAdjustment(name, pos, ang)` | Returns `pos, ang` with the firstperson adjustment applied (offset along `ang`'s forward/right/up). |
| `GCAL:GetTPIKAdjustment(name)` | `{ pos, ang, target_radius_add, smoothing_add }`. |
| `GCAL:GetTPIKOptionAdd(name, option)` | Additive for `clone_offset_x/y/z`, `target_radius` or `smoothing`. |

Fields: `pos_x/y/z`, `ang_p/y/r` (firstperson), `tpik_pos_x/y/z`, `tpik_ang_p/y/r`, `tpik_target_radius_add`, `tpik_smoothing_add`, `clone_offset_x/y/z`. Unknown fields are ignored.

### Advanced

| Function | Description |
| :------- | :---------- |
| `GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)` | `{ strategy, strategy_id, ply, weapon, vm, handsEnt }`, with `vm` already replaced by the strategy's `resolveViewModel` or a `VManipVMEntity` result. |
| `GCAL:ResolveArmTarget(context, targetBones)` | Entity to write arm bones to: the strategy's `resolveArmTarget`, else `FindArmTarget`. |
| `GCAL:FindArmTarget(vm, handsEnt, targetBones)` | `vm` if it has any target bone, else `handsEnt` if it does, else `vm`. |
| `GCAL:NormalizeGunMode(mode)` | `"follow"`, `"animated"` or nil. |
| `GCAL:WarnDeprecated(animName, key, message)` | Prints one `[GCAL] Deprecated:` warning per animation and key, with the calling file and line. Usable for your own fields. |
| `GCAL:AddDebugEvent(text, color)` | Adds a line to the debug HUD's event list. |

---

## 6. Hooks reference

### GCAL hooks

| Hook | Arguments | When |
| :--- | :-------- | :--- |
| `GCALTrackStarted` | `trackID, animName, track` | After a track starts (after `on_start`). |
| `GCALTrackStopped` | `trackID, animName, track` | After a track stops for any reason. |
| `GCALAnimSuppressed` | `name, trackID` | `GCAL:Play` skipped an animation the player disabled. `trackID` is what was passed and may be nil. |
| `GCALCodeBlockStarted` / `GCALCodeBlockStopped` | `trackID, animName, track, scope` | A `block_code` track starts / stops. |
| `GCALPreHoldQuit` | `trackID, animName, animToStop` | `GCAL:QuitHolding`. Return `false` to block. |
| `GCALHoldQuit` | `trackID, animName, animToStop` | A hold release was accepted (also from `VManip:QuitHolding`). |
| `GCALSegmentFinish` | `trackID, animName, segment, lastSegment, segmentCount` | A segment reached the end of its cycle. |
| `GCALPrePlaySegment` | `trackID, animName, sequence, lastSegment` | `GCAL:PlaySegment`. Return `false` to block. |
| `GCALPlaySegment` | `trackID, animName, sequence, lastSegment` | After a segment starts. |

### VManip-compatible hooks GCAL fires

| Hook | Arguments | When |
| :--- | :-------- | :--- |
| `VManipPrePlayAnim` | `name` | Every `GCAL:Play`, on any track. Return `false` to block. Strategy `prePlayAnim` callbacks run through it. |
| `VManipPostPlayAnim` | `name` | `legacy_left_arm` only: the first frame the blend leaves the weapon pose. |
| `VManipPreActCheck` | `name, vm` | Legacy animations only, before the reload checks. Return `true` to skip them. |
| `VManipPreRemove` | `name` | `VManip:Remove()` while the legacy track is active (blend < 1). |
| `VManipRemove` | none | After `legacy_left_arm` stops. |
| `VManipSegmentFinish` | `name, segment, lastSegment, segmentCount` | Any track, together with `GCALSegmentFinish`. |
| `VManipPreHoldQuit` | `name, animToStop` | `VManip:QuitHolding` only. Return `false` to block. |
| `VManipHoldQuit` | `name, animToStop` | `VManip:QuitHolding` was accepted. |
| `VManipPrePlaySegment` | `name, sequence, lastSegment` | `VManip:PlaySegment` only. Return `false` to block. |
| `VManipPlaySegment` | `name, sequence, lastSegment` | After `VManip:PlaySegment`. |
| `VManipVMEntity` | `ply, weapon` | When building the render context, if no strategy with a `resolveViewModel` matches the weapon and another addon listens. Return an entity to render against instead of the viewmodel. |

---

## 7. Thirdperson (TPIK)

When the local player is drawn in thirdperson (`ShouldDrawLocalPlayer()` or another view entity) and `gcal_thirdperson` is on (the default), GCAL projects active arm tracks onto the player model. Whether a track uses TPIK is decided when it starts: `gcal_thirdperson` must be on, the animation must not set `thirdperson = false` or be `legacy`, and the player must not have turned TPIK off for it in the menu ("Toggle TPIK Anims").

### How it works

Each frame, for each TPIK track:

1. The TPIK source model (the TPIK `sequence` copy, or the firstperson source model) is placed at the player's eye with the eye angles, scaled by `model_scale`.
2. The source's animated hand becomes the hand target: offset by the difference between the player's and the source model's shoulders (the midpoint of both upper arms), then clamped per axis to `Spine4 ± target_radius`.
3. `offset_x/y/z`, `gcal_tpik_offset_*` and the per-animation TPIK adjustment are added after the clamp, so they can push past it. `gcal_tpik_angle_*` is added to the hand's angles.
4. The target and hand angles are smoothed (`smoothing`) relative to `Spine4`, so hands don't trail behind a moving player. The blend with the player's pose (`blend_per_bone` overrides it) moves the target, the hand angles and the elbow direction toward the player's own pose.
5. A two-bone IK solve places the upper arm, forearm and hand using the player model's own bone lengths, so the arm never stretches or detaches. The elbow bends the way the animation's elbow does. If the target is out of reach, the arm points at it fully extended.
6. Bone twist and finger poses are copied from the animation relative to their parent bone; unmapped children (helper bones, finger tips) follow their parent. The result is cached for the frame and written to the player model.

An arm is solved with IK only when its `UpperArm`, `Forearm` and `Hand` are all mapped and none of `UpperArm` / `Forearm` is in `lock_bones`. Other mapped bones, or every bone when `ik = false` or `gcal_tpik_ik 0`, use the older direct method: each bone is copied from the source with the shoulder offset and clamp, then blended per bone.

This works with any player model that has the ValveBiped arm bones (plus `Spine4` for the clamp and smoothing).

### Options reference

```lua
GCAL:RegisterTPIKOptions("myaddon_radio_hold", {
    sequence = "radio_hold_thirdperson",
    ik = true,
    model = true,
    model_bone = "ValveBiped.Bip01_L_Hand",
    model_max_distance = 32,
    hide_materials = { "extra_sleeve" },
    keep_materials = { "tablet_screen" },
    target_radius = 38,
    smoothing = 18,
    offset_x = 0, -- forward/back
    offset_y = 0, -- right/left
    offset_z = 0  -- up/down
})
```

`GCAL:RegisterTPIKOptions(name, options)` returns `true` / `false` and replaces any options previously registered for that name. Unknown keys print an error with a stack trace; renamed and removed keys print a one-time deprecation warning ([15](#15-deprecated-and-removed-fields)). Values are coerced: numbers through `tonumber` (0 on failure), bools through `tobool`, strings through `tostring`. Assigning `GCAL.TPIKOptions[name] = { ... }` directly skips validation. Options are read when a track starts or its animation is re-registered.

| Key | Type | Default | Description |
| :-- | :--- | :------ | :---------- |
| `sequence` | string | firstperson sequence | Thirdperson-only sequence; falls back to the firstperson one if not found. Aliases: `anim`, `animation`. The prop clone follows it too. |
| `ik` | bool | true | Solves the arms with two-bone IK. `false` uses the direct bone copy. |
| `model` | bool | true | Enables the prop clone. `false` disables it. |
| `model_bone` | string | | Only this source bone counts for the distance check. |
| `model_max_distance` | number | 32 | Hides the clone when its nearest hitbox center or bone is farther than this from the player's hand. 0 disables the check. |
| `hide_materials` | table/string | | Extra material-name substrings to hide on the clone. |
| `keep_materials` | table/string | | Material-name substrings to keep visible; beats auto-hiding and `hide_materials`. |
| `target_radius` | number | 38 | Half-size of the clamp box around `Spine4`. |
| `smoothing` | number | 18 | Per-bone smoothing speed, clamped to 0..60. 0 disables smoothing. |
| `offset_x` / `offset_y` / `offset_z` | number | 0 | Forward / right / up offset in eye-angle space, after the clamp. |
| `blend_per_bone` | table | | `{ [nameSubstring] = blend }`: fixed blend for matching bones (0 = full animation, 1 = player's pose). Replaces the track's blend in and out for those bones. |
| `lock_bones` | table | | Bone-name substrings kept at the player's pose. Locking a `Hand` keeps the IK target at the player's hand; locking an `UpperArm` or `Forearm` turns IK off for that arm. |
| `scale_bones` | table | | `{ [nameSubstring] = scale }`: scales each matching bone's distance from its rest position. With IK only the `Hand` entry is used (it scales the target). |
| `model_offset` | table | | `{ [boneName] = Vector(x, y, z) }`: world-space offset per prop-clone bone. |
| `clone_offset_x` / `clone_offset_y` / `clone_offset_z` | number | 0 | Forward / right / up offset of the whole prop clone, in eye-angle space. |

Bone rules match by plain substring of the player bone name. When several `scale_bones` or `blend_per_bone` keys match one bone, which one wins is undefined, so keep keys distinct.

```lua
GCAL:RegisterTPIKOptions("myaddon_spray", {
    sequence = "spray_tp",
    lock_bones = { "Finger" },                             -- fingers keep the player's pose
    scale_bones = { ["Hand"] = 0.8, ["UpperArm"] = 1.1 },  -- hand closer to the body
    blend_per_bone = { ["Forearm"] = 0.3 }                 -- forearm stays 70% animated
})
```

### Prop clone

A second clientside model of the registered model, playing the TPIK sequence, renders addon props (spray cans, tablets) on the player. Each frame it copies the source pose, shifted so the source hand lands on the player's solved hand, then adds `clone_offset_*`, `gcal_clone_offset_*`, the per-animation clone adjustment and `model_offset`. It uses `model_scale` and the source model's skin and bodygroups.

Materials whose names look like viewmodel arms (`c_arm`, `/arms`, `_arms`, `arm_`, `forearm`, `/hands`, `_hands`, `hand_`, `glove`, `sleeve`, `player_shared`) are hidden automatically. If that would hide every material, they are restored.

```lua
GCAL:RegisterTPIKOptions("myaddon_tablet", {
    clone_offset_x = 1,                                              -- whole prop 1 unit forward
    model_offset = { ["ValveBiped.Bip01_L_Hand"] = Vector(0, 0, -2) } -- and this bone 2 units down
})
```

### ARC9

On ARC9 weapons with native TPIK available (`ARC9.TPIK.NativeExtensionPoints`, `arc9_tpik` on, weapon not `NoTPIK`), the render method is `arc9_tpik`: GCAL waits for ARC9's `ARC9_TPIK_PostSolve` hook and overlays its tracks on ARC9's pose. Everywhere else, including ARC9 weapons without native TPIK, the method is `normal`: GCAL's own pass in `PrePlayerDraw`. A strategy chooses the method with `thirdPersonMethod` ([9](#9-weapon-base-strategies)).

### Global tuning

`gcal_tpik_offset_x/y/z`, `gcal_tpik_angle_p/y/r`, `gcal_tpik_target_radius_add`, `gcal_tpik_smoothing_add` and `gcal_clone_offset_x/y/z`, plus the per-animation TPIK adjustments from the menu, are added on top of the registered options. `gcal_anim_offset_*` and `gcal_anim_angle_*` only affect firstperson.

Other players' animations are covered in [10](#10-multiplayer-and-networking).

---

## 8. Camera bone (cambone)

GCAL can drive the local player's firstperson view from the first attachment of the animation's model, replicating VManip's camera bone. It is on by default for every animation whose model has an attachment.

When a track starts with `gcal_cambone` on and the animation's `cambone` isn't `false`, GCAL creates a hidden camera model (`camModel`) at the world origin playing the same sequence. Each frame it reads that model's first attachment. In `CalcView` (firstperson, view entity is the player, while some track's blend is below 1) GCAL first runs the other `CalcView` hooks, then passes the result through the cambone handlers for each track. The default handler, `"vmanip"` at priority 0, adds `(attachment.Ang - cam_ang) * cam_angint * (1 - lerpVal)` to the view angles.

```lua
GCAL:RegisterAnim("myaddon_look", {
    model = "myaddon/c_look.mdl",
    cam_ang = Angle(-79.75, 0, -90), -- rest angle of the camera attachment
    cam_angint = { 1, 1, 1 }         -- pitch, yaw, roll intensity
})

GCAL:RegisterSecondHandAnim("myaddon_calm_ping", {
    model = "myaddon/c_ping.mdl",
    cambone = false -- never moves the view, no camera model is created
})
```

`cambone = true` behaves like leaving it unset: `gcal_cambone 0` disables cambone for every animation. The menu's "Cambone enabled" button toggles the convar. The fields are listed in [3](#3-registering-animations).

### Custom cambone handlers

`GCAL:RegisterCamBoneHandler(id, priority, fn)` adds a handler. All handlers run in priority order (lower first) for every track with an attachment, each receiving the previous handler's output. Registering an existing id replaces it; `GCAL:RemoveCamBoneHandler(id)` removes it. Both return `true` / `false`. Replacing or removing `"vmanip"` changes cambone for every addon.

```
fn(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal, handler)
  -> origin, angles, fov
```

| Argument | Description |
| :------- | :---------- |
| `id` | The handler's id. |
| `track` | Runtime track (`name`, `camModel`, `attachment`, `lerpVal`, ...). |
| `ply` | The local player. |
| `origin`, `angles`, `fov` | View so far. Return them, modified or not. |
| `attachment` | `{ Pos, Ang }` of the camera attachment. Never nil when handlers run. |
| `camAng`, `camAngInt` | The track's `cam_ang` and `cam_angint`. |
| `lerpVal` | Blend, 1 = weapon pose, 0 = full animation. Scale your effect by `1 - lerpVal` so it fades with the animation. |
| `handler` | The handler's table `{ id, priority, fn }`. |

To give one animation its own camera response, zero its `cam_angint` so the default handler adds nothing for it, then handle it yourself:

```lua
GCAL:RegisterAnim("myaddon_recoil", {
    model = "myaddon/c_recoil.mdl",
    cam_angint = { 0, 0, 0 } -- the default "vmanip" handler adds nothing for this animation
})

GCAL:RegisterCamBoneHandler("myaddon_recoil", 10,
    function(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
        if track.name ~= "myaddon_recoil" then return origin, angles, fov end

        local delta = attachment.Ang - camAng
        local weight = 1 - lerpVal
        return origin, Angle(
            angles.p + delta.p * 0.5 * weight, -- dampened pitch
            angles.y + delta.y * 2.0 * weight, -- amplified yaw
            angles.r + delta.r * weight
        ), fov
    end)
```

`GCAL:ComputeCamBoneView(track, ply, origin, angles, fov)` runs the handler chain for one track; GCAL's `CalcView` hook uses it.

---

## 9. Weapon-base strategies

Special weapon-base behaviour lives in clientside strategies instead of one-off checks in the renderer. GCAL checks them in order and uses the first whose `detect` returns true (cached per weapon for 0.5 s). Built-in order: `tfa`, `arccw`, `arc9`, `mwbase`. New strategies are appended; registering an existing id replaces it in place. With no match GCAL uses the regular viewmodel and hands entity.

| Strategy | Detection | Behaviour |
| :------- | :-------- | :-------- |
| `tfa` | `weapon.IsTFAWeapon` | Owner's viewmodel. |
| `arccw` | `weapon.ArcCW` | Owner's viewmodel. Blocks every GCAL animation while `GetNWBool("reloading")`. Legacy reload checks are skipped while the crosshair is drawn or the viewmodel cycle is past 0.99. |
| `arc9` | `ARC9`, `ARC9Weapon`, `Base == "arc9_base"`, or `DoTPIK` + `GetWM` | Owner's viewmodel. Blocks animations while `GetReloading()`. Thirdperson method `arc9_tpik` when available ([7](#7-thirdperson-tpik)). |
| `mwbase` | valid `weapon.m_ViewModel` | Renders against `weapon.m_ViewModel`. Blocks animations while `GetIsReloading()`. |

For every strategy the arm target is the viewmodel when it has any target bone, otherwise the hands entity (`GCAL:FindArmTarget`), unless the strategy sets `resolveArmTarget`. Separately, while a VManip animation is active (blend < 1) GCAL strips `IN_RELOAD` in firstperson and returns `"no"` from `TFA_PreReload`.

```lua
if CLIENT then
    GCAL:RegisterWeaponBaseStrategy("examplebase", {
        detect = function(ply, weapon)
            return IsValid(weapon) and weapon.ExampleBase
        end,

        resolveViewModel = function(ply, weapon, vm, handsEnt, context)
            return IsValid(weapon.ExampleViewModel) and weapon.ExampleViewModel or vm
        end,

        resolveArmTarget = function(ply, weapon, vm, handsEnt, targetBones, context)
            return GCAL:FindArmTarget(vm, handsEnt, targetBones)
        end,

        prePlayAnim = function(ply, weapon, animName, strategy)
            if weapon.GetIsReloading and weapon:GetIsReloading() then return false end
        end,

        preActCheck = function(ply, weapon, animName, vm, strategy)
            if IsValid(vm) and vm:GetCycle() > 0.99 then return true end
        end,

        thirdPersonMethod = function(ply, weapon, strategy)
            return "normal"
        end
    })
end
```

| Callback | Called | Return |
| :------- | :----- | :----- |
| `detect(ply, weapon)` | **Required.** Strategy lookup. | Truthy if the strategy handles this weapon. |
| `resolveViewModel(ply, weapon, vm, handsEnt, context)` | Each frame, building the render context. | Entity to render against (invalid keeps `vm`). When present, `VManipVMEntity` listeners aren't consulted. |
| `resolveArmTarget(ply, weapon, vm, handsEnt, targetBones, context)` | Per track, per frame. | Entity to write arm bones to (invalid falls back to `FindArmTarget`). |
| `prePlayAnim(ply, weapon, animName, strategy)` | Every `GCAL:Play`, through `VManipPrePlayAnim`. | `false` blocks the animation, native and legacy alike. |
| `preActCheck(ply, weapon, animName, vm, strategy)` | Legacy animations only, through `VManipPreActCheck`. | `true` skips the reload checks. |
| `thirdPersonMethod(ply, weapon, strategy)` | Thirdperson rendering. | `"arc9_tpik"` or `"normal"`. Any other value renders like `"normal"`. |

Omit callbacks you don't need. The built-ins also define `resolveLegsViewModel`, but it is only reachable through a `VManipLegsVMEntity` hook that GCAL itself never runs, so legs don't use strategies.

---

## 10. Multiplayer and networking

### Server API

The server doesn't play animations; it tells clients to.

| Function | Description |
| :------- | :---------- |
| `GCAL:Play(name, trackID, recipients)` | Clients run `GCAL:Play(name, trackID)`. `recipients` is a player, a table of players or a `CRecipientFilter`; nil broadcasts. |
| `GCAL:Play(ply_or_filter, name, trackID)` | Same, with recipients first. |
| `GCAL:StopTrack(trackID, recipients)` | Clients stop `trackID` (every track when nil). |
| `GCAL:StopAllTracks(recipients)` | Clients stop every track. |

The server doesn't check the registry; the animation must be registered on the clients. The legacy `VManip_SimplePlay` and `VManip_StopHold` net messages still work for old server code.

### Thirdperson sync

When a track starts on a client and its animation doesn't set `thirdperson = false` or `local_only` (and it isn't on `legs`), GCAL tells the server, which relays the start to the players in the sender's PVS. Stops, hold releases and segment changes follow. Sync doesn't depend on the sender's own `gcal_thirdperson`. `local_only` tracks never send anything.

A receiving client builds its own copy of the track and renders it on that player through the normal TPIK path when:

- `gcal_mp_tpik` (default 1) and its own `gcal_thirdperson` are on;
- the animation is registered there, enabled in its menu, with TPIK left on;
- the sender isn't dormant and is within 2000 units. Starts for dormant or distant players are skipped.

Each player can have at most 4 remote tracks, and the server rate-limits sync messages per player. Only the thirdperson pose and the prop clone are replicated: no firstperson, cambone, sounds or gun mode. Legacy VManip animations never sync.

---

## 11. Migrating from VManip and VMLegs

If your addon uses VManip it keeps working without changes. When you're ready, port it file by file; the shim stays in GCAL.

### What the shim does

- `VManip:RegisterAnim(name, data)` registers a legacy animation on `legacy_left_arm`. It copies only `model`, `sequence`, `lerp_peak`, `lerp_speed_in`, `lerp_speed_out`, `lerp_curve`, `speed`, `startcycle`, `loop`, `holdtime`, `sounds`, `preventquit`, `block_code`, `block_code_scope`, `locktoply`, `assurepos`, `cam_ang`, `cam_angint`, `segmented` and `addon_name` / `addon`, and forces left-arm bones, `Legacy` easing, `legacy = true` and `thirdperson = false`.
- `lua/vmanip/anims/*.lua` from every addon is included automatically on both realms (and scanned again shortly after `InitPostEntity`); `addon_name` defaults to the file name.
- Registrations made before GCAL loads are held by `aaa_gcal_shim.lua` and imported once it does.
- `VManip:PlayAnim(name)` plays on `legacy_left_arm`. Like VManip it refuses while that track is busy, in a vehicle, when dead, without a weapon, with the `duel` hold type, or during a viewmodel reload. `VManip:QueueAnim` has its own queue slot.
- The VManip globals (`VManip.VMGesture`, `VMCam`, `Cam_Ang`, `Cam_AngInt`, `CurGesture`, `CurGestureData`, `VMatrixlerp`, `Cycle`, `Attachment`, ...) are synced from that track every frame. `VManip()` is callable and `Entity:VManip(matrix)` exists, for MW Base.
- Legacy flip handling targets the arm from the weapon's `ViewModelFlipDefault`, and `ViewModelFlipDefault ~= ViewModelFlip` mirrors the source model. Native tracks keep their registered hand and aren't remapped. Chen's patch behaviour for flipped viewmodels, player legs and TFA/ArcCW/MW Base is built into the compat layer and the strategies.
- `VMLegs:RegisterAnim(name, data)` registers `"legs_" .. name` on the `legs` track. It copies only `model`, `speed`, `forwardboost` and `upwardboost`, and forces `sequence = name`.
- `VMLegs:PlayAnim(name)` plays that animation and builds the player-legs model (your player model bonemerged to the animation, upper body hidden). `GCAL:Play("legs_" .. name, "legs")` is not equivalent: it plays the animation model without player legs. Keep using `VMLegs:PlayAnim` for legs.

### API mapping

`t` is the track ID: `"left_arm"` (or your own track) for native animations, `"legacy_left_arm"` for animations still registered through VManip.

| VManip / VMLegs | GCAL native |
| :-------------- | :---------- |
| `VManip:RegisterAnim(name, data)` | `GCAL:RegisterSecondHandAnim(name, data)` with an explicit `sequence` |
| `VManip:PlayAnim(name)` | `GCAL:Play(name)` |
| `VManip:IsActive()` (blend < 1) | `GCAL:IsTrackActive(t) and GCAL:GetLerp(t) < 1` |
| `VManip:IsValid()` | `GCAL:IsTrackActive(t)` |
| `VManip:Remove()`, `VManip:Reset()` | `GCAL:StopTrack(t)` (also drops the queued animation) |
| `VManip:GetVMGesture()`, `VManip.VMGesture` | `GCAL:GetGestureModel(t)` |
| `VManip.VMCam` | `GCAL:GetCamModel(t)` |
| `VManip.Cam_Ang`, `VManip.Cam_AngInt` | `cam_ang`, `cam_angint` registration fields |
| `VManip.Attachment` | `GCAL:GetTrack(t).attachment` |
| `VManip:GetCurrentAnim()`, `VManip.CurGesture` | `GCAL:GetCurrentAnim(t)` |
| `VManip:GetCycle()`, `VManip:SetCycle(c)`, `VManip.Cycle` | `GCAL:GetCycle(t)`, `GCAL:SetCycle(t, c)` |
| `VManip:GetLerp()`, `VManip.VMatrixlerp` | `GCAL:GetLerp(t)` |
| `VManip:IsSegmented()`, `GetCurrentSegment()`, `GetSegmentCount()`, `IsPreventQuit()` | Same names on `GCAL` with `(t)` |
| `VManip:QueueAnim(name)` | `GCAL:QueueAnim(name, t)` |
| `VManip:QuitHolding(anim)` | `GCAL:QuitHolding(t, anim)` |
| `VManip:PlaySegment(seq, last, sounds)` | `GCAL:PlaySegment(t, seq, last, sounds)` |
| `VManip:GetAnim(name)` | `GCAL:GetAnim(name)` |
| `VManipPostPlayAnim` | `GCALTrackStarted` (fires at start, not when the blend begins) |
| `VManipRemove` | `GCALTrackStopped` |
| `VManipSegmentFinish`, `VManipPrePlaySegment`, `VManipPlaySegment` | `GCALSegmentFinish`, `GCALPrePlaySegment`, `GCALPlaySegment` (track ID first) |
| `VManipPreHoldQuit`, `VManipHoldQuit` | `GCALPreHoldQuit`, `GCALHoldQuit` |
| `VManipPrePlayAnim` | Unchanged; it fires for native animations too |
| `VManip_SimplePlay` net message from the server | Server `GCAL:Play(name, t, recipients)` |
| `VMLegs:PlayAnim(name)` | Keep it; no native call builds the player legs |
| `VMLegs:GetCurrentAnim()` | `GCAL:GetCurrentAnim("legs")` (keeps the `legs_` prefix) |

### Porting example

```lua
-- VManip
VManip:RegisterAnim("myaddon_grab", { model = "c_vmanip_grab.mdl", lerp_peak = 0.5 })
VManip:PlayAnim("myaddon_grab")
local gesture = VManip.VMGesture
local lerp = VManip.VMatrixlerp

-- GCAL
GCAL:RegisterSecondHandAnim("myaddon_grab", {
    model = "c_vmanip_grab.mdl",
    sequence = "grab", -- be explicit: native lookup isn't tolerant
    lerp_peak = 0.5
})
GCAL:Play("myaddon_grab")
local gesture = GCAL:GetGestureModel("left_arm")
local lerp = GCAL:GetLerp("left_arm")

-- Optional, now possible: thirdperson tuning
GCAL:RegisterTPIKOptions("myaddon_grab", { sequence = "grab_tp", target_radius = 35, smoothing = 20 })
```

After porting:

- Remove any `legacy = true` and pass `sequence` explicitly.
- Use a native track instead of sharing `legacy_left_arm`.
- Native animations don't block reloads and skip VManip's start checks. If you relied on that, use a strategy `prePlayAnim`, `VManipPrePlayAnim`, `block_code` or your own checks.
- Put thirdperson tweaks in `GCAL:RegisterTPIKOptions`, not in `VManip.*` globals.

---

## 12. Debugging

### Debug HUD

`gcal_debug 1` turns on console logging (`[GCAL DEBUG]`) and the debug HUD on the left of the screen:

- a header with the number of registered animations and active tracks;
- the weapon line: class, matched strategy (`default` when none), and `flipped` in legacy flip mode;
- the global toggles row, for example `on: tpik cambone muted speed x1.50`;
- per track: track ID, animation and `[gcal]` / `[legacy]`; the model; the resolved sequence (red when not found, or pose-only); the TPIK sequence row when it differs; cycle and blend bars with phase (`in`, `out`, `hold`, `loop`, `segment`) and weight; bones moved, sounds played, segment, hold and gun mode; flags such as `tpik`, `cambone`, `locktoply`, `assurepos`, `no-interrupt`, `prevent-quit`, `blocks <scope>` and `queued: <name>`;
- recent events: the last 8 events from the past 12 seconds, colour-coded (failures, warnings, deprecations). Add your own with `GCAL:AddDebugEvent(text, color)`.

GCAL also listens for unhandled Lua errors from its own files and from known conflicting addons. It prints a short `[GCAL]` summary with the first Lua frames and, on the client, one rate-limited notification; full details stay in the console.

### Commands

| Command | Description |
| :------ | :---------- |
| `gcal_list_anims` | Lists registered animations with their default track. |
| `gcal_play <animation> [track]` | Plays a registered animation. Autocompletes names. |
| `gcal_stop [track]` | Stops one track, or every track; also drops their queued animations. |
| `gcal_debug_sequences <animation>` | Lists the model's sequences, checks the one the animation uses, warns about zero-sequence models and suggests case fixes. |
| `gcal_debug_sequences <model.mdl> [sequence]` | Same for any model, without registering an animation. |
| `gcal_debug_track [track]` | Dumps a track: state, TPIK info, weapon strategy, flip state, arm target entity, matched bones and source/target deltas. Defaults to `legacy_left_arm`; native animations play on `left_arm` (or their own track), so pass it. |
| `gcal_menu_open` | Opens the GCAL menu. It also opens from the "GCAL" icon on the C-menu desktop. |

### Troubleshooting checklist

If an animation does not play:

- Run `gcal_list_anims` and confirm the animation is registered on the client.
- Run `gcal_debug_sequences <animation>` and confirm the model exposes the sequence you expect.
- Check whether the player disabled it in the menu (`GCALAnimSuppressed`) or a weapon-base strategy blocks it (reloading).
- If the track is held by a `can_interrupt = false` animation, the new one was queued.
- Legacy animations refuse to start while `legacy_left_arm` is busy (see [11](#11-migrating-from-vmanip-and-vmlegs)).
- Enable `gcal_debug 1` and read the recent events.

If the hand does not move:

- Confirm the source model contains the source bones GCAL reads and the viewmodel or hands contain the target bones (the HUD's `bones` count).
- Try explicit `hand`, `source_hand`, `bones` or `source_bones` values instead of relying on defaults.
- Use `gcal_debug_track <track>` to inspect the weapon-base strategy, arm target entity and matched bones.

If the timing is off:

- The cycle runs at `speed` cycles per second, not at the sequence's authored rate.
- If the arm snaps back at the end, `lerp_peak` plus the blend-out is longer than the clip.

If thirdperson looks wrong:

- Verify firstperson first. TPIK copies the same source animation.
- Add a TPIK `sequence` if the firstperson sequence is a poor thirdperson pose.
- Tune `target_radius`, `smoothing`, `offset_x/y/z`, `model_offset` and `clone_offset_x/y/z`, or use the menu's per-animation TPIK sliders.
- Set `model = false` to separate the arm copy from the prop clone.
- Use `model_bone` and `model_max_distance` when a prop vanishes or drifts away from the hand.
- The player model needs ValveBiped arm bones and `Spine4`.

---

## 13. Convar reference

All convars are clientside and saved.

| Convar | Default | Description |
| :----- | :------ | :---------- |
| `gcal_debug` | 0 | Debug HUD and console logging. |
| `gcal_thirdperson` | 1 | Project GCAL tracks onto the local player in thirdperson; also needed to see other players' synced animations. |
| `gcal_mp_tpik` | 1 | Receive and render other players' TPIK animations. |
| `gcal_cambone` | 1 | Camera bone for all animations. |
| `gcal_playback_speed` | 1 | Global playback speed multiplier (menu slider 0.1 to 3). |
| `gcal_mute_sounds` | 0 | Mutes animation sounds. |
| `gcal_sound_pitch` | 100 | Animation sound pitch (menu presets 75, 100, 140). |
| `gcal_anim_offset_x/y/z` | 0 | Firstperson forward / right / up offset of the source model. |
| `gcal_anim_angle_p/y/r` | 0 | Firstperson angle offset of the source model. |
| `gcal_tpik_ik` | 1 | Two-bone IK for thirdperson arms. 0 uses the direct bone copy for every animation. |
| `gcal_tpik_offset_x/y/z` | 0 | Thirdperson offset, applied after the clamp. |
| `gcal_tpik_angle_p/y/r` | 0 | Added to each TPIK bone's angles. |
| `gcal_tpik_target_radius_add` | 0 | Added to `target_radius`. Negative tightens, positive loosens. |
| `gcal_tpik_smoothing_add` | 0 | Added to `smoothing`; the result is clamped to 0..60. |
| `gcal_clone_offset_x/y/z` | 0 | Offset of the thirdperson prop clone. |
| `gcal_menu_keep_open` | 1 | Keeps the menu window open after releasing the context menu key. |
| `gcal_conflict_popup` | 1 | Shows the conflicting-addon popup at startup. |

---

## 14. Integrations

### DynaBase

GCAL has optional support for the [wOS] DynaBase Dynamic Animation Manager. DynaBase doesn't need to be installed: sources are queued and only registered when `wOS.DynaBase` and `WOS_DYNABASE` exist.

DynaBase mounts are player-model animation sources, not GCAL's firstperson arm gestures. Use them when your addon also ships player animation mount models that should appear in DynaBase's animation manager.

```lua
GCAL:RegisterDynaBaseSource({
    name = "My Addon Reanimations",
    type = WOS_DYNABASE and WOS_DYNABASE.REANIMATION,
    male = "models/player/myaddon/m_player_mount.mdl",
    female = "models/player/myaddon/f_player_mount.mdl",
    zombie = "models/player/myaddon/z_player_mount.mdl"
})
```

GCAL registers the source during DynaBase's `InitLoadAnimations` hook and includes the right model during `PreLoadAnimations`. For a simpler declaration, with `shared` for every gender or arrays when one gender needs several models:

```lua
GCAL:RegisterDynaBaseMount("My Shared Animation Mount", {
    shared = "models/player/myaddon/shared_mount.mdl"
})

GCAL:RegisterDynaBaseMount("My Layered Mount", {
    male = {
        "models/player/myaddon/m_base_mount.mdl",
        "models/player/myaddon/m_extra_mount.mdl"
    },
    female = "models/player/myaddon/f_base_mount.mdl"
})
```

Use `GCAL:IsDynaBaseAvailable()` to branch when DynaBase is installed.

### Registering conflicting Workshop addons

If your addon is incompatible with GCAL, register its Workshop ID clientside so GCAL warns players who mount both:

```lua
if CLIENT then
    GCAL:RegisterConflictingWorkshopAddon("1234567890", "My Addon")
end
```

The first argument is the Steam Workshop item ID as a string, the second the name shown in GCAL's warning. GCAL checks mounted Workshop addons one second after it loads, so register at load time (from autorun), not from a later hook. It also detects the legacy `autorun/client/cl_vmanip.lua` file, and uses the list to attribute Lua errors. Players can turn the popup off with `gcal_conflict_popup 0`.

---

## 15. Deprecated and removed fields

Registering with any of these still works. GCAL prints one `[GCAL] Deprecated:` console warning per animation and key, naming the file and line that registered it.

### Animation fields

**Renamed** (the old name still works for now):

| Old | New |
| :-- | :-- |
| `onstart`, `OnStart` | `on_start` |
| `onfinish`, `OnFinish` | `on_finish` |
| `oninterrupt`, `OnInterrupt` | `on_interrupt` |
| `easeintime` / `easeouttime` | `ease_in_time` / `ease_out_time` |
| `soundvolume`, `soundlevel`, `soundflags` | `sound_volume`, `sound_level`, `sound_flags` |
| `blendweight` | `blend_weight` |
| `modelscale`, `modelskin`, `modelbodygroups` | `model_scale`, `model_skin`, `model_bodygroups` |
| `gunmode`, `gunbones` | `gun_mode`, `gun_bones` |
| `bonegroup` | `bone_group` (or `hand`) |
| `thirdperson_model`, `thirdperson_model_bone`, `thirdperson_model_max_distance`, `thirdperson_hide_materials`, `thirdperson_keep_materials`, `thirdperson_target_radius`, `thirdperson_smoothing` | The same key without the prefix, in `GCAL:RegisterTPIKOptions`. Moved there automatically. |

`sound_volume` used to double as the sound level (default 75). It is now a 0-1 volume; values above 1 warn and are used as `sound_level`.

**Removed** (ignored; do this instead):

| Field | Replacement |
| :---- | :---------- |
| `on_cycle` | Poll `GCAL:GetCycle(trackID)` from a `Think` hook. |
| `delay_start` | `timer.Simple(delay, function() GCAL:Play(name) end)` |
| `play_condition` | Check your condition before calling `GCAL:Play`, or return `false` from `VManipPrePlayAnim`. |
| `screen_shake` | Call `util.ScreenShake` from `on_start`. |
| `blend_mode` | None. Only `"normal"` was ever implemented. |
| `disable_pred` | None. It never had an effect. |
| `viewmodel_fov` (`vm_fov`, `fov`) | Change the FOV from your own `CalcView` hook, scaled by `1 - GCAL:GetLerp(trackID)`. |
| `viewmodel_offset` (`vm_offset`) | Offset the viewmodel from your own `CalcViewModelView` hook. |

### TPIK options

| Key | Status |
| :-- | :----- |
| `thirdperson_model`, `thirdperson_model_bone`, `thirdperson_model_max_distance`, `thirdperson_hide_materials`, `thirdperson_keep_materials`, `thirdperson_target_radius`, `thirdperson_smoothing` | Renamed to the key without the `thirdperson_` prefix. |
| `ignore_bones` | Renamed to `lock_bones` (both keep the bone at the player's pose). Lists are merged. |
| `blend_strength` | Removed. Use `blend_weight` on the animation. |
| `blend_curve` | Removed. Use `lerp_curve` or `easing_in` / `easing_out` on the animation. |
| `distance_fade`, `fade_start`, `fade_end` | Removed. Remote players already stop rendering past 2000 units. |
| `pole_source`, `pole_native` | Removed (the IK solver is gone). |
| `model_skin`, `model_bodygroups`, `model_material`, `render_mode`, `render_fx`, `offset_relative_to`, `offset_space`, `angular_offset_x/y/z`, `update_rate`, `interpolate`, `force_update` | Removed. They were accepted but never implemented. |

---

If you're seeking help, please use the discussions on addon page, Happy coding! :3
