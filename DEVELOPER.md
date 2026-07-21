# GCAL: GMod Compliant Armature Layer

### Developer Documentation :3

GCAL is a modern, modular offhand animation library for Garry's Mod. It serves as a superior, backward-compatible replacement for the legacy VManip system.

---

## 0. How GCAL Works

GCAL is built around a simple idea: an addon registers animation data once, then asks GCAL to play that animation on a named runtime track. GCAL owns the clientside animation model, advances its cycle once per rendered frame, reads the animated source bones from that model, and writes the resulting transforms onto the correct viewmodel, hands entity, or thirdperson player bones.

The important pieces are:

| Piece | What it does |
| :---- | :----------- |
| Animation registry | `GCAL.Anims[name]` stores static data from `GCAL:RegisterAnim`. |
| Active tracks | `GCAL.ActiveTracks[trackID]` stores runtime playback state such as cycle, lerp, hold state, models, and sounds. |
| Source model | A hidden clientside model created from the registered `model`; GCAL reads the animated bones from this. |
| Target entity | The entity GCAL writes bones to. This is usually the viewmodel or player hands entity, but weapon-base strategies can choose another entity. |
| Track ID | The slot an animation plays in. Different track IDs can run at the same time. Starting a new animation on the same track replaces the old one. |
| TPIK options | `GCAL.TPIKOptions[name]` stores thirdperson-only solver and prop-rendering settings. |

### Playback Lifecycle

Most native animations follow this flow:

1. Your addon calls `GCAL:RegisterAnim(name, data)` during clientside initialization.
2. Your addon calls `GCAL:Play(name, trackID)` when gameplay wants the gesture.
3. GCAL creates hidden clientside models, resolves the sequence, initializes cycle/lerp state, and stores the runtime track in `GCAL.ActiveTracks`.
4. Every rendered frame, GCAL advances each track once, updates model cycles, plays scheduled sounds, and updates hold/segment state.
5. During viewmodel/hands rendering, GCAL places the hidden source model, reads source bone matrices, and applies them to the selected target bones.
6. When the animation finishes, is stopped, or is replaced on the same track, GCAL removes its clientside models and fires stop hooks.

Thirdperson uses the same track timing. It does not run a second copy of the animation; it reuses the active track state and projects it onto the player model through TPIK when possible.

### Firstperson vs Thirdperson

Firstperson rendering is direct bone copying/blending from the hidden animation model into the active viewmodel or hands entity. It is the primary, most stable path.

Thirdperson rendering is a retargeting problem. Player models have different proportions, weapon bases may already run their own thirdperson IK, and addon props may be weighted differently from arms. GCAL solves this with a TPIK pass: it reads shoulder, elbow, and hand goals from the animation model, solves a two-bone player arm, then carries fingers/helper bones and optional prop geometry along with that solved hand.

This means firstperson and thirdperson may need different tuning. Keep regular animation data in `RegisterAnim`; put thirdperson-only adjustments in `GCAL.TPIKOptions`.

### Native GCAL vs VManip Compatibility

Native GCAL addons should use `GCAL:RegisterAnim`, `GCAL:Play`, track IDs, and GCAL hooks directly. The VManip shim exists so older addons continue to work, but new addons should avoid depending on global VManip state such as `VManip.VMGesture` or `VManip.Cycle`.

The compatibility layer translates old VManip registrations and playback calls into GCAL tracks, adds tolerant sequence resolution, and handles known weapon-base quirks. Native code gets cleaner behavior by being explicit about hands, tracks, source bones, and TPIK options.

---

## 1. Quick Start

GCAL is globally accessible via the `GCAL` table. It also provides a shim for `VManip` and `VMLegs` for legacy support.

### Registering an Animation

```lua
GCAL:RegisterAnim("my_cool_gesture", {
    model = "weapons/c_arms_citizen.mdl", -- Path relative to models/
    lerp_peak = 0.5,                      -- Peak of the transition (0 to 1)
    speed = 1.0,                         -- Playback speed
    easing_in = "OutCubic",              -- Smooth entry (see Easing section)
    easing_out = "OutQuad",              -- Smooth exit
    hand = "left"                        -- left/second/offhand, right, or both
})
```

### Registering a Second-Hand Animation

For left-hand or "second hand" offhand animations, you no longer need to manually set the bone table and track name.

```lua
GCAL:RegisterSecondHandAnim("scanner_ping", {
    model = "weapons/c_arms_citizen.mdl",
    sequence = "scanner_ping",
    lerp_peak = 0.35,
    speed = 1.0
})
```

This is equivalent to:

```lua
GCAL:RegisterAnim("scanner_ping", {
    model = "weapons/c_arms_citizen.mdl",
    sequence = "scanner_ping",
    hand = "left"
})
```

If your model stores the pose on left-hand source bones but you want to drive the right hand, use the explicit right-hand helper and set `source_hand`:

```lua
GCAL:RegisterRightHandAnim("scanner_ping_mirrored_source", {
    model = "weapons/c_arms_citizen.mdl",
    sequence = "scanner_ping",
    source_hand = "left"
})
```

### Playing an Animation

```lua
-- Play by name. Optional second argument is the track ID.
GCAL:Play("my_cool_gesture")

-- Play on a specific track to avoid overriding others
GCAL:Play("wave_hand", "right_arm")

-- Play using the built-in helper for the registered hand
GCAL:PlaySecondHand("scanner_ping")
```

---

## 2. Advanced Animation Data

The data table passed to `RegisterAnim` supports the following fields:

| Field                | Type         | Description                                                                                                                                           |
| :------------------- | :----------- | :---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `model`              | string       | **REQUIRED.** The model containing the sequence.                                                                                                      |
| `sequence`           | string       | Explicit model sequence name. When omitted, GCAL falls back to the registered animation name and a few legacy name-resolution strategies.     |
| `lerp_peak`          | number       | Cycle at which the animation begins transitioning back (default: 0.5).                                                                                |
| `lerp_speed_in`      | number       | Lerp speed for the entry transition (default: 1).                                                                                                      |
| `lerp_speed_out`     | number       | Lerp speed for the exit transition (default: 1).                                                                                                       |
| `lerp_curve`         | number       | Easing curve exponent for the lerp (default: 1).                                                                                                       |
| `speed`              | number       | Playback rate multiplier (default: 1.0).                                                                                                              |
| `startcycle`         | number       | Cycle to start the animation at (0.0 to 1.0).                                                                                                         |
| `duration`           | number       | Manual override for the track duration (seconds). When omitted, GCAL uses the sequence duration, then `holdtime`, then `lerp_peak`, defaulting to 1. |
| `loop`               | bool         | If true, the animation repeats and never lerps out.                                                                                                   |
| `segmented`          | bool         | Segment mode. Use `GCAL:PlaySegment(trackID, sequence, lastSegment, sounds)` after `GCALSegmentFinish`.                                               |
| `holdtime`           | number       | Time in seconds after which the animation freezes (useful for interactions).                                                                          |
| `sounds`             | table        | A dictionary of `[path] = time` to play audio during playback.                                                                                        |
| `hand`               | string       | Friendly hand selector: `left`, `second`, `offhand`, `right`, or `both`. Sets default `bones` and `group_name`. Aliases: `arm`, `bone_group`, `bonegroup`. |
| `bones`              | table/string | Target bone names to manipulate, or a hand alias such as `"right"` / `"both"`. Defaults from `hand`.                                                  |
| `source_hand`        | string       | Optional source hand to read from in the animation model. Useful when the target hand is right but the model sequence is authored on left-hand bones. Aliases: `source_arm`. |
| `source_bones`       | table/string | Optional source bone names to read from. Defaults to `bones`, or from `source_hand` when provided.                                                    |
| `addon_name`         | string       | Optional display name used by GCAL's Toggle Anims tree to group animations by addon.                                                                  |
| `group_name`         | string       | Default track ID for this animation. If omitted, GCAL uses `left_arm`, `right_arm`, or `both_arms` from `hand`.                                       |
| `track` / `track_id` | string       | Friendly aliases for `group_name`.                                                                                                                    |
| `thirdperson`        | bool         | Enables projection of this track onto the local player model while rendered in thirdperson. Defaults to true.                                         |
| `cambone`             | bool         | When `true`, drives the player's first-person view angles from this track's animation attachments (VManip-style camera bone). When `false`, disables cambone for this animation. When `nil` (default), follows the global `gcal_cambone` convar. See section 11. |
| `legacy`             | bool         | Marks this as a VManip legacy animation. Enables tolerant name matching and disables arc9-style bone copies. Most VManip addons set this automatically. |
| `block_code`         | bool         | Marks this animation as a code blocker while its track is active. Other addon code can check `GCAL:IsCodeBlocked(scope)` and return early.             |
| `block_code_scope`   | string       | Optional scope name for `block_code`, so unrelated systems can continue running.                                                                       |
| `preventquit`        | bool         | If true, `GCAL:QuitHolding` will not release this hold state.                                                                                          |
| `easing_in`          | string       | Easing function for the entry transition.                                                                                                             |
| `easing_out`         | string       | Easing function for the exit transition.                                                                                                              |
| `locktoply`          | bool         | If true, pins the animation to the player's view. The model is placed at `EyePos()` with a 25% blend between view and viewmodel angles.              |
| `assurepos`          | bool         | If true, parents the gesture model to the viewmodel each frame. The strictest lock — guarantees perfect alignment but costs a reparent per weapon swap.  |

---

## 3. Hand Authoring Helpers

GCAL has high-level helpers for common hand layouts:

```lua
GCAL:RegisterHandAnim("left_press", "left", {
    model = "myaddon/c_left_press.mdl"
})

GCAL:RegisterHandAnim("right_press", "right", {
    model = "myaddon/c_right_press.mdl"
})

GCAL:RegisterSecondHandAnim("offhand_press_alt", {
    model = "myaddon/c_left_press.mdl"
})

GCAL:RegisterBothHandsAnim("two_hand_panel", {
    model = "myaddon/c_two_hand_panel.mdl"
})
```

Accepted hand aliases:

| Meaning                 | Accepted values                                                           |
| :---------------------- | :------------------------------------------------------------------------ |
| Left / second / offhand | `left`, `left_arm`, `l`, `second`, `second_hand`, `secondhand`, `offhand` |
| Right hand              | `right`, `right_arm`, `r`                                                 |
| Both hands              | `both`, `both_hands`, `bothhands`, `both_arms`, `dual`                    |

The helper sets:

| Hand                          | Default bones           | Default track |
| :---------------------------- | :---------------------- | :------------ |
| `left` / `second` / `offhand` | `GCAL.GROUPS.LEFT_ARM`  | `left_arm`    |
| `right`                       | `GCAL.GROUPS.RIGHT_ARM` | `right_arm`   |
| `both`                        | `GCAL.GROUPS.BOTH_ARMS` | `both_arms`   |

You can still override `bones`, `group_name`, `track`, or `track_id` when you need a custom setup.

### Target Hand vs. Source Hand

`hand` decides which viewmodel bones GCAL writes to. `source_hand` decides which bones GCAL reads from in your animation model.

Most animations can omit `source_hand`:

```lua
GCAL:RegisterSecondHandAnim("offhand_button", {
    model = "myaddon/c_left_hand_button.mdl"
})
```

Use `source_hand` when reusing a left-authored animation on the right hand:

```lua
GCAL:RegisterHandAnim("right_hand_from_left_source", "right", {
    model = "myaddon/c_left_authored_button.mdl",
    source_hand = "left"
})
```

### Model and Sequence Authoring Guidelines

GCAL expects the registered model to be a clientside model under `models/` with a sequence GCAL can resolve. The model can be a regular c_arms-style model, a VManip-style animation model, or an addon-owned gesture model that includes the bones you want GCAL to read.

For predictable results:

- Use ValveBiped arm bone names when possible, such as `ValveBiped.Bip01_L_UpperArm`, `ValveBiped.Bip01_L_Forearm`, and `ValveBiped.Bip01_L_Hand`.
- Make sure the source model actually contains the source bones listed by `source_bones` or implied by `source_hand`.
- Put props that should appear in thirdperson inside the registered animation model when possible. GCAL's thirdperson prop clone is pulled from the registered addon model, not from GCAL-local models.
- Use `sequence` when the registered animation name does not exactly match the model sequence.
- If the firstperson sequence is not a good thirdperson pose, use `GCAL:RegisterTPIKOptions(name, { sequence = "..." })` instead of changing the firstperson registration.
- Keep one logical gesture per animation name. If the same model has several sequences, register several GCAL animations that share the same `model` but use different `sequence` values.

Minimal shared-model pattern:

```lua
local MODEL = "myaddon/c_shared_tools.mdl"

GCAL:RegisterSecondHandAnim("tool_raise", {
    model = MODEL,
    sequence = "tool_raise",
    addon_name = "My Addon"
})

GCAL:RegisterSecondHandAnim("tool_press", {
    model = MODEL,
    sequence = "tool_press",
    addon_name = "My Addon"
})
```

---

## 3.5. Native API Equivalents to Legacy VManip Functions

GCAL provides a clean `GCAL:`-prefixed API for addons that want to inspect runtime state without depending on the `VManip` compatibility shim. These are the preferred natives for new addons:

| Legacy VManip pattern | Native GCAL equivalent | Description |
| :-- | :-- | :-- |
| `VManip:GetVMGesture()` | `GCAL:GetGestureModel(trackID)` | Returns the gesture model entity for a track, or `nil`. |
| `VManip:GetVMGestures()` / similar multi-gesture queries | `GCAL:GetAllGestureModels()` | Returns `{ trackID = model, ... }` for every active non-legs track. |
| `VManip.VMCam` (global) | `GCAL:GetCamModel(trackID)` | Returns the cambone model entity (camera-bone attachment source). |
| `VManip.VMGesture` (global) | `GCAL:GetGestureModel(trackID)` | Single-gesture query per track. |
| Inspecting the world-model entity | `GCAL:GetTPIKModel(trackID)` | Returns the TPIK source model (third-person world-model clone source). |
| Iterating registered anim names | `GCAL:GetAnimationNames()` | Returns a list of all names in `GCAL.Anims`. |
| `VManip.IsActive` for any non-legacy track | `GCAL:IsTrackActive(trackID)` | Standard per-track query. |
| Enumerating active tracks | `GCAL:GetActiveTrackIDs()` | Returns a list of all track IDs currently active. |
| `VManip:Remove()` (single) | `GCAL:StopTrack(trackID)` | Standard per-track stop. |
| Stopping everything at once | `GCAL:StopAllTracks()` | Iterates and stops every active track. |
| `VManip:GetCycle()` | `GCAL:GetCycle(trackID)` | Returns the current animation cycle (0..1). |
| `VManip:SetCycle(newcycle)` | `GCAL:SetCycle(trackID, cycle)` | Sets the current cycle and continues from there. |
| `VManip:GetLerp()` | `GCAL:GetLerp(trackID)` | Returns the current weapon/anim blend value. |
| `VManip:GetCurrentAnim()` | `GCAL:GetCurrentAnim(trackID)` | Returns the active animation name. |
| `VManip:IsSegmented()` | `GCAL:IsSegmented(trackID)` | Returns whether the active track is segmented. |
| `VManip:GetCurrentSegment()` | `GCAL:GetCurrentSegment(trackID)` | Returns the current segment name. |
| `VManip:GetSegmentCount()` | `GCAL:GetSegmentCount(trackID)` | Returns how many segments have played. |
| `VManip:IsPreventQuit()` | `GCAL:IsPreventQuit(trackID)` | Returns whether the track resists hold release. |
| `VManip:QueueAnim(name)` | `GCAL:QueueAnim(name, trackID)` | Queues an animation to play when the track becomes free. |
| `VManip:QuitHolding(anim)` | `GCAL:QuitHolding(trackID, animToStop)` | Standard hold release. |
| `VManip:PlaySegment(seq, last, sounds)` | `GCAL:PlaySegment(trackID, sequence, lastSegment, soundTable)` | Standard segmented play. |
| `VManip:IsValid()` | `GCAL:IsTrackActive(trackID)` | Equivalent. |
| Querying `VManip.VMatrixlerp` (read) | `GCAL:GetLerp(trackID)` | Returns the current blend (1 = weapon, 0 = full anim). |
| Checking if the active anim loops | `GCAL:IsLooping(trackID)` | Returns `true`/`false`. |
| Querying anim duration | `GCAL:GetTrackDuration(trackID)` | Returns the track's effective duration in seconds. |

Example — porting an old VManip addon to natives:

```lua
-- Legacy
local gesture = VManip.VMGesture
if IsValid(gesture) then gesture:SetPos(...) end

-- Native
local gesture = GCAL:GetGestureModel("left_arm")
if IsValid(gesture) then gesture:SetPos(...) end
```

All native functions are safe to call when the track is not active (they return `nil`/`false` instead of erroring), so you can poll them from `Think` without guards.

---

## 4. The Multi-Track System

Unlike legacy systems, GCAL can play multiple animations at once by using different `trackID`s.

- **Left Arm:** Usually uses the `left_arm` track.
- **Right Arm:** Usually uses the `right_arm` track.
- **Both Arms:** Usually uses the `both_arms` track.
- **Legs:** Handled via the special `legs` track.
- **Custom:** You can define any string as a track ID!

Example:

```lua
GCAL:Play("watch_check", "left_arm")
GCAL:PlayHand("hand_signal", "right")
-- Both will play simultaneously without glitching!
```

Track IDs are intentionally simple strings. GCAL does not require every addon to share the built-in names, but you should prefer the standard tracks unless you have a reason not to:

- Use `left_arm`, `right_arm`, or `both_arms` for normal hand gestures.
- Use a custom track when an animation is logically independent from the normal hand slot.
- Use the same custom track for mutually exclusive animations in the same subsystem.
- Avoid creating a new unique track every time you play an animation; tracks are runtime slots, not event IDs.

Example custom track:

```lua
GCAL:RegisterSecondHandAnim("scanner_insert", {
    model = "myaddon/c_scanner.mdl",
    sequence = "scanner_insert",
    group_name = "scanner_device"
})

GCAL:RegisterSecondHandAnim("scanner_remove", {
    model = "myaddon/c_scanner.mdl",
    sequence = "scanner_remove",
    group_name = "scanner_device"
})

GCAL:Play("scanner_insert") -- Uses scanner_device by default.
```

If `scanner_remove` starts while `scanner_insert` is still active on `scanner_device`, GCAL stops the old track first. Other tracks keep playing.

### Native Track Control

Native GCAL addons do not need to use the legacy `VManip` shim for advanced control. GCAL exposes track-aware helpers directly:

```lua
GCAL:GetAnim("watch_check")
GCAL:GetTrack("left_arm")
GCAL:IsTrackActive("left_arm")
GCAL:GetCurrentAnim("left_arm")
GCAL:GetLerp("left_arm")
GCAL:GetCycle("left_arm")
GCAL:SetCycle("left_arm", 0.5)
GCAL:StopTrack("left_arm")
```

For animations that should pause your addon's own follow-up logic while they play, register them with `block_code`:

```lua
GCAL:RegisterSecondHandAnim("scanner_insert", {
    model = "myaddon/c_scanner_insert.mdl",
    block_code = true,
    block_code_scope = "myaddon_scanner"
})

hook.Add("Think", "MyAddon_ScannerLogic", function()
    if GCAL:IsCodeBlocked("myaddon_scanner") then return end

    -- Continue regular scanner logic only after scanner_insert finishes.
end)
```

This does not literally pause Lua execution globally. It exposes a scoped runtime gate so cooperating addon code can stop itself for the lifetime of the animation.

For held animations:

```lua
GCAL:RegisterAnim("radio_hold", {
    model = "myaddon/c_radio.mdl",
    holdtime = 0.35
})

GCAL:Play("radio_hold", "left_arm")
GCAL:QuitHolding("left_arm")
```

For queued follow-up animations:

```lua
GCAL:QueueAnim("radio_lower", "left_arm")
```

Queued animations are track-specific, so a queued `left_arm` animation can begin as soon as that track becomes free while other tracks keep running.

For segmented animations:

```lua
GCAL:RegisterAnim("tool_sequence", {
    model = "myaddon/c_tool.mdl",
    segmented = true
})

hook.Add("GCALSegmentFinish", "MyAddon_ToolSequence", function(trackID, animName, segment, lastSegment, segmentCount)
    if trackID == "left_arm" and animName == "tool_sequence" then
        GCAL:PlaySegment(trackID, "tool_loop", false)
    end
end)
```

Useful native hooks:

| Hook                                                                       | Purpose                                                        |
| :------------------------------------------------------------------------- | :------------------------------------------------------------- |
| `GCALTrackStarted(trackID, animName, track)`                               | Fired after a track starts.                                    |
| `GCALTrackStopped(trackID, animName, track)`                               | Fired after a track stops.                                     |
| `GCALCodeBlockStarted(trackID, animName, track, scope)`                    | Fired when a `block_code` animation starts.                    |
| `GCALCodeBlockStopped(trackID, animName, track, scope)`                    | Fired when a `block_code` animation stops.                     |
| `GCALPreHoldQuit(trackID, animName, animToStop)`                           | Return `false` to block a native hold release.                 |
| `GCALHoldQuit(trackID, animName, animToStop)`                              | Fired after a native hold release is accepted.                 |
| `GCALSegmentFinish(trackID, animName, segment, lastSegment, segmentCount)` | Fired when a segmented animation reaches the end of a segment. |
| `GCALPrePlaySegment(trackID, animName, sequence, lastSegment)`             | Return `false` to block a native segment change.               |
| `GCALPlaySegment(trackID, animName, sequence, lastSegment)`                | Fired after a native segment starts.                           |

---

## 5. Thirdperson Support

GCAL can project active arm tracks onto the local player model while the local player is rendered in thirdperson. The feature is experimental and enabled through `gcal_thirdperson`.

```lua
GCAL:RegisterSecondHandAnim("radio_press", {
    model = "myaddon/c_radio_press.mdl",
    thirdperson = true
})
```

GCAL's TPIK is a **direct bone copy** solver (ARC9-style): it reads each mapped bone's animated matrix from the source viewmodel, offsets the entire arm into player body-space using the upper arm (shoulder) as a reference, clamps the position to `Spine4 ± target_radius` to prevent stretching, blends the result with the player model's rest pose, and writes the final matrices to the player model. There is no IK solver and no anchor transform, so the system works with **any** armature — standard ValveBiped, QCI-included, or fully custom. A separate clone of the animation's registered model renders addon-owned props such as spray cans or tablets; obvious viewmodel arm materials are hidden automatically.

TPIK-specific per-animation settings live in `GCAL.TPIKOptions`, not the main `RegisterAnim` table:

```lua
GCAL:RegisterTPIKOptions("radio_hold", {
    sequence = "radio_hold_thirdperson",
    model = true,
    model_bone = "ValveBiped.Bip01_L_Hand",
    model_max_distance = 32,
    hide_materials = { "extra_sleeve" },
    keep_materials = { "tablet_screen" },
    target_radius = 38,
    smoothing = 18,
    offset_x = 0,   -- forward/back
    offset_y = 0,   -- right/left
    offset_z = 0,   -- up/down
})
```

You can also assign directly with `GCAL.TPIKOptions.radio_hold = { ... }`. Use `sequence` when the firstperson sequence is not suitable for thirdperson posing. GCAL keeps the normal `model`/`camModel` on the firstperson sequence and creates a separate hidden TPIK source model on the requested sequence. The thirdperson prop clone follows the TPIK sequence too, so addon-owned props stay matched to the thirdperson arm pose.

`RegisterTPIKOptions` validates option keys against a whitelist — unknown keys print a console warning. Deprecated keys (`pole_source`, `pole_native`) also warn. Option types are normalized (`number` via `tonumber`, `bool` via `tobool`, `string` via `tostring`).

Valid TPIK option keys:

| Key | Type | Default | Description |
| :-- | :-- | :-- | :-- |
| `sequence` | string | — | TPIK-specific sequence name (falls back to firstperson sequence). Aliases: `anim`, `animation`. |
| `model` | bool | true | Enables the thirdperson prop clone. `false` disables it. |
| `model_bone` | string | — | Limits prop-distance validation to one source-model bone. |
| `model_max_distance` | string | 32 | Hides the prop if the nearest hitbox/bone is farther than this. `0` disables the check. |
| `hide_materials` | table | — | Additional material name tokens to hide on the prop clone. |
| `keep_materials` | table | — | Material name tokens to preserve (overrides auto-hide). |
| `target_radius` | number | 38 | Spine-relative clamp radius for bone positions. Prevents stretching. |
| `smoothing` | number | 18 | Per-bone exponential smoothing speed. `0` disables smoothing. |
| `offset_x` | number | 0 | Forward/back position offset in render-angle space. |
| `offset_y` | number | 0 | Right/left position offset. |
| `offset_z` | number | 0 | Up/down position offset. |
| `pole_source` | number | — | **Deprecated.** Ignored (IK solver removed). |
| `pole_native` | number | — | **Deprecated.** Ignored (IK solver removed). |

The per-animation `offset_x/y/z` values are added on top of the global convar adjustments (`gcal_tpik_offset_x/y/z`) and per-animation cookie adjustments. They are applied after clamping, so they can push the arm beyond the clamp range.

Thirdperson rendering is selected by method: ARC9 weapons with active native TPIK use `arc9_tpik`, and all other weapons (including ARC9 weapons without native TPIK) use `normal`. The `arc9_tpik` method waits for ARC9's native `ARC9_TPIK_PostSolve` hook before overlaying active GCAL tracks. When ARC9's native TPIK is disabled, GCAL falls back to its own direct-bone-copy TPIK instead of disabling thirdperson entirely. This works because GCAL's TPIK is now a simple bone copy (ARC9-style) rather than the old IK solver that could interfere with ARC9's rendering.

Track timing is advanced once per rendered frame through a shared updater. Firstperson and thirdperson hooks only render the resulting state, so drawing both views cannot shorten an animation or skip short clips.

The playground exposes separate TPIK adjustment sliders under the global controls and under each animation's right-click adjustment menu. `gcal_anim_offset_*` and `gcal_anim_angle_*` affect normal firstperson placement. `gcal_tpik_offset_*` and `gcal_tpik_angle_*` are applied after the source-to-player offset and clamping, so they nudge the final thirdperson pose. `gcal_tpik_target_radius_add` and `gcal_tpik_smoothing_add` are additive nudges on top of each animation's registered TPIK values.

---

## 6. Easing Functions

GCAL includes a built-in easing library for natural movement. Available options:

- `Linear`
- `InQuad`, `OutQuad`, `InOutQuad`
- `InCubic`, `OutCubic`, `InOutCubic`
- `OutElastic` (Great for "snappy" or "bouncy" movements)
- `Legacy` (Matches the original VManip power-curve behavior)

---

## 7. Legacy Compatibility

If your addon already uses VManip, you don't need to change anything!

- `VManip:RegisterAnim` is automatically redirected to `GCAL:RegisterAnim`.
- `VMLegs:PlayAnim` is redirected to the GCAL legs track.
- GCAL automatically scans all addons for `vmanip/anims/*.lua` and imports them.
- Legacy helpers such as `VManip:QueueAnim`, `VManip:QuitHolding(anim)`, `VManip:PlaySegment`, `VManip:GetCycle`, and camera attachment offsets are supported.
- Legacy sequence resolution is tolerant of common old-addon mistakes: GCAL tries the registered animation name, an explicit `sequence`, a lowercase name, normalized and partial normalized legacy-name matches, a `c_vmanip...` model-filename match, and the only model sequence when one exists.
- If a legacy model reports zero sequences, GCAL can fall back to a compatible surrogate animation or a pose-only compatibility mode instead of hard-failing immediately.
- Chen patch behavior for flipped viewmodels, player legs, and MWBase/TFA/ArcCW special handling is built into the compatibility layer.
- Legacy flipped-viewmodel handling follows the weapon's current `ViewModelFlip` value for the target arm side, while `ViewModelFlipDefault != ViewModelFlip` controls source-model mirroring. Native GCAL tracks keep their registered hand/bone targets instead of being globally remapped by legacy flip state.

### Migrating From VManip To Natives

If you maintain a VManip-style addon and want to switch to GCAL natives, the shim keeps everything working — no rush. When you're ready, replace the legacy patterns with the natives from section 3.5. Here are the most common migrations:

**Reading the gesture model**

```lua
-- VManip
local vm = VManip.VMGesture
if IsValid(vm) then vm:SetPos(...) end

-- GCAL
local vm = GCAL:GetGestureModel("left_arm")
if IsValid(vm) then vm:SetPos(...) end
```

Note: GCAL uses per-track lookups. If your addon supports multiple tracks, pick the right one (`"left_arm"`, `"right_arm"`, `"both_arms"`, or your custom track ID).

**Polling the lerp / cycle / current anim**

```lua
-- VManip
local cycle = VManip.Cycle
local lerp = VManip.VMatrixlerp
local anim = VManip.CurGesture

-- GCAL
local cycle = GCAL:GetCycle("left_arm")
local lerp = GCAL:GetLerp("left_arm")
local anim = GCAL:GetCurrentAnim("left_arm")
```

All GCAL getters take the track ID and return `nil`/`0` if the track is not active. They are safe to call from `Think` without `IsValid` checks.

**Playing and queuing**

```lua
-- VManip
VManip:PlayAnim("foo")
VManip:QueueAnim("bar")
VManip:QuitHolding()
VManip:Remove()

-- GCAL
GCAL:Play("foo")
GCAL:QueueAnim("bar", "left_arm")
GCAL:QuitHolding("left_arm")
GCAL:StopTrack("left_arm")
```

Note: `QuitHolding` and `StopTrack` take the track ID. The VManip shim's `QuitHolding()` without an arg still works for backward compat, but new code should pass the track ID.

**State guards**

```lua
-- VManip
if VManip:IsActive() and VManip:GetLerp() < 0.1 then
    -- full animation playing
end

-- GCAL
local track = GCAL:GetTrack("left_arm")
if track and track.lerpVal < 0.1 then
    -- full animation playing
end

-- or use the dedicated helper:
if GCAL:IsTrackActive("left_arm") and GCAL:GetLerp("left_arm") < 0.1 then
    -- ...
end
```

**Querying leg / foot animations**

```lua
-- VMLegs
VMLegs:PlayAnim("forward")
VMLegs:GetCurrentAnim()

-- GCAL
GCAL:Play("legs_forward", "legs")
GCAL:GetCurrentAnim("legs")
```

GCAL's legs track uses a `"legs_"` prefix when registered via `GCAL:Play` directly. The VMLegs shim still works, and registering via `VMLegs:RegisterAnim(name, data)` is equivalent to `GCAL:RegisterAnim("legs_" .. name, data)`.

**Camera-bone attachment**

```lua
-- VManip (Chen patch)
VManip.Cam_Ang = Angle(-79.75, 0, -90)
VManip.Cam_AngInt = { 1, 1, 1 }
VManip.Attachment = VManip:GetVMGesture():GetAttachment(0)

-- GCAL (per animation, via RegisterAnim)
GCAL:RegisterAnim("my_anim", {
    model = "...",
    cam_ang = Angle(-79.75, 0, -90),
    cam_angint = { 1, 1, 1 },
    cambone = true,
})
```

GCAL reads `cam_ang` / `cam_angint` from the registration data and handles the attachment lookup per frame. The `cambone` field lets you opt out per-animation, and the global convar `gcal_cambone` controls the default.

**Removing the VManip dependency**

Once all your code uses natives, you can drop the VManip shim calls. The shim itself stays in GCAL, so you can migrate one file at a time without breaking the others. After migration, consider:

- Removing the `legacy = true` flag from your registrations so GCAL uses the modern bone-copy path instead of the legacy VManip-style lerp.
- Setting explicit `bones` / `source_bones` tables on your registrations (use `GCAL.GROUPS.LEFT_ARM` / `RIGHT_ARM` / `BOTH_ARMS`) instead of relying on the `hand` field defaulting to a specific arm.
- Using `GCAL:RegisterTPIKOptions(name, { sequence = "..." })` instead of mutating `VManip.VMCam` or `VManip.Cam_Ang` directly.

### Weapon Base Strategies

GCAL resolves special weapon-base behavior through ordered clientside strategies instead of scattering one-off checks through the renderer.

Built-in strategy order:

1. `tfa`
2. `arccw`
3. `mwbase`
4. Normal GCAL rendering fallback

Each strategy can detect a weapon base, choose the viewmodel entity GCAL should render against, choose the entity that owns the target arm bones, and block legacy VManip playback during base-specific reload states.

Current built-in behavior:

| Strategy | Detection | Viewmodel handling | Notes |
| :------- | :-------- | :----------------- | :---- |
| `tfa` | `weapon.IsTFAWeapon` | Uses the owner's normal viewmodel. | Matches Chen's patch: no TFA-specific VM hook and no forced hands-first target. TFA still uses the shared `PreDrawPlayerHands` path for `UseHands` weapons, falls back to the player hands entity when the VM has no arm bones, and uses `TFA_PreReload` reload blocking. |
| `arccw` | `weapon.ArcCW` | Uses the owner's normal viewmodel. | Matches Chen's patch: `UseHands` weapons render through `PreDrawPlayerHands`, skip the generic `PostDrawViewModel` pass, and keep VM-first arm targeting. Reload playback is blocked while ArcCW reports `reloading`. |
| `arc9` | ARC9 markers or TPIK methods | Uses the owner's normal viewmodel. | Thirdperson: `arc9_tpik` layers on top of ARC9's native post-solve hook when available; otherwise falls back to `normal` (GCAL's own direct-bone-copy TPIK). |
| `mwbase` | valid `weapon.m_ViewModel` | Uses `weapon.m_ViewModel`. | Custom VM entity is used for arms and legs when present. |

To add another special weapon base, register a strategy clientside:

```lua
if CLIENT then
    GCAL:RegisterWeaponBaseStrategy("examplebase", {
        detect = function(ply, weapon)
            return IsValid(weapon) and weapon.ExampleBase
        end,

        resolveViewModel = function(ply, weapon, vm, handsEnt, context)
            return IsValid(weapon.ExampleViewModel) and weapon.ExampleViewModel or vm
        end,

        resolveLegsViewModel = function(ply, weapon, vm, handsEnt, context)
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
        end
    })
end
```

Only `detect` is required. Omit callbacks you do not need. If no strategy matches, GCAL uses the regular viewmodel and player hands entities passed by Garry's Mod. Legacy `VManipVMEntity` hooks are still respected as a fallback for external addons that provide their own compatibility hook.

### Registering Conflicting Workshop Addons

If your addon is incompatible with GCAL, register its Workshop ID clientside so GCAL can warn players when both addons are mounted:

```lua
GCAL:RegisterConflictingWorkshopAddon("1234567890", "Example Addon")
```

The first argument is your addon's Steam Workshop item ID as a string. The second argument is the display name shown in GCAL's warning output.

```lua
if CLIENT then
    GCAL:RegisterConflictingWorkshopAddon("1234567890", "My Addon")
end
```

GCAL checks mounted Workshop addons by ID and also keeps older file-based VManip detection as a fallback.

---

## 8. DynaBase Support

GCAL includes optional support for the [wOS] DynaBase Dynamic Animation Manager. It does not require DynaBase to be installed; sources are safely queued and registered only when `wOS.DynaBase` and `WOS_DYNABASE` exist.

DynaBase mounts are for player-model animation sources, not GCAL's first-person arm gestures. Use them when your addon also ships player animation mount models that should appear in DynaBase's animation manager.

### Registering a DynaBase Source

```lua
GCAL:RegisterDynaBaseSource({
    name = "My Addon Reanimations",
    type = WOS_DYNABASE and WOS_DYNABASE.REANIMATION,
    male = "models/player/myaddon/m_player_mount.mdl",
    female = "models/player/myaddon/f_player_mount.mdl",
    zombie = "models/player/myaddon/z_player_mount.mdl"
})
```

GCAL registers the source during DynaBase's `InitLoadAnimations` hook and includes the right model during `PreLoadAnimations`.

For a simpler mount declaration:

```lua
GCAL:RegisterDynaBaseMount("My Shared Animation Mount", {
    shared = "models/player/myaddon/shared_mount.mdl"
})
```

You can also provide arrays if one gender needs multiple source models:

```lua
GCAL:RegisterDynaBaseMount("My Layered Mount", {
    male = {
        "models/player/myaddon/m_base_mount.mdl",
        "models/player/myaddon/m_extra_mount.mdl"
    },
    female = "models/player/myaddon/f_base_mount.mdl"
})
```

Use `GCAL:IsDynaBaseAvailable()` if your addon wants to branch behavior when DynaBase is installed.

---

## 9. Common Addon Patterns

### Clientside Initialization

Register animations clientside after GCAL exists. If your file is loaded by an addon autorun, a simple client guard is usually enough:

```lua
if not CLIENT then return end
if not GCAL then return end

GCAL:RegisterSecondHandAnim("myaddon_ping", {
    model = "myaddon/c_ping.mdl",
    sequence = "ping",
    addon_name = "My Addon"
})
```

If your addon can load before GCAL, defer registration until a safe hook or include order you control. Do not register the same animation every frame.

### Play Without Spamming

Before playing a long gesture, check the target track:

```lua
local track = "left_arm"

if not GCAL:IsTrackActive(track) then
    GCAL:Play("myaddon_ping", track)
end
```

For actions that should replace themselves, just call `GCAL:Play` on the same track. GCAL will stop the previous runtime track cleanly.

### Block Your Own Logic While a Gesture Runs

Use `block_code` when your addon needs to wait for an animation before continuing an interaction:

```lua
GCAL:RegisterSecondHandAnim("myaddon_insert_battery", {
    model = "myaddon/c_battery.mdl",
    sequence = "insert",
    block_code = true,
    block_code_scope = "myaddon_battery"
})

hook.Add("Think", "MyAddonBatteryThink", function()
    if GCAL:IsCodeBlocked("myaddon_battery") then return end

    -- Regular battery logic.
end)
```

### Add Thirdperson TPIK Only When Needed

Start with normal firstperson registration. Add `GCAL.TPIKOptions` only when thirdperson needs a different sequence or solver tuning:

```lua
GCAL:RegisterSecondHandAnim("myaddon_spray", {
    model = "myaddon/c_spray.mdl",
    sequence = "spray_firstperson",
    addon_name = "My Addon"
})

GCAL:RegisterTPIKOptions("myaddon_spray", {
    sequence = "spray_thirdperson",
    model_bone = "ValveBiped.Bip01_L_Hand",
    model_max_distance = 24,
    target_radius = 34,
    smoothing = 14
})
```

### Recommended Naming

Use stable, namespaced animation names so other addons and users can understand debug output:

```lua
GCAL:RegisterSecondHandAnim("myaddon_tablet_open", { ... })
GCAL:RegisterSecondHandAnim("myaddon_tablet_close", { ... })
GCAL:RegisterSecondHandAnim("myaddon_tablet_press", { ... })
```

Avoid very generic names like `open`, `use`, or `idle` unless the animation is internal and cannot conflict.

---

## 10. Debugging Tools

GCAL listens for unhandled Lua errors originating from its own files. Client errors produce one rate-limited notification while full details remain in the console; server errors receive the same concise GCAL console prefix.

### Troubleshooting Checklist

If an animation does not play:

- Run `gcal_list_anims` and confirm the animation name is registered.
- Run `gcal_debug_sequences <animation>` and confirm the model exposes the sequence you expect.
- Check that `model` is relative to `models/`, for example `myaddon/c_tool.mdl`, not `models/myaddon/c_tool.mdl`.
- Confirm the target track is not already occupied if your addon is intentionally avoiding replacement with `GCAL:IsTrackActive`.
- Enable `gcal_debug 1` and watch the HUD for active track, cycle, lerp, and bone counts.

If the hand does not move:

- Confirm the source model contains the source bones GCAL is reading.
- Confirm the target viewmodel or hands entity contains the target bones GCAL is writing.
- Try explicit `hand`, `source_hand`, `bones`, or `source_bones` values instead of relying on defaults.
- Use `gcal_debug_track [track]` to inspect the selected weapon-base strategy, arm target entity, and matched bones.

If thirdperson looks wrong:

- First verify firstperson works. TPIK depends on a valid source animation.
- Add `GCAL:RegisterTPIKOptions(name, { sequence = "..." })` if the firstperson sequence is not a good thirdperson pose.
- Tune `target_radius`, `smoothing`, and `offset_x/y/z` in `GCAL.TPIKOptions`.
- Use `model = false` to isolate arm solving from prop rendering.
- Use `model_bone` and `model_max_distance` when addon props drift away from the solved hand.

Use these console commands during development:

- `gcal_debug 1`: Enables the real-time HUD and console logging.
- `gcal_playback_speed <multiplier>`: Changes global GCAL playback speed. The menu exposes this as a slider from `0.1` to `3`.
- `gcal_mute_sounds 1`: Mutes sounds emitted by GCAL animations.
- `gcal_sound_pitch <pitch>`: Changes GCAL animation sound pitch. The menu uses `75`, `100`, and `140` presets.
- `gcal_thirdperson 1`: Enables experimental projection of active GCAL arm tracks onto the local player model in thirdperson.
- `gcal_tpik_offset_x/y/z <value>`: Changes global thirdperson TPIK source placement without affecting firstperson placement.
- `gcal_tpik_angle_p/y/r <value>`: Changes global thirdperson TPIK source angle offsets.
- `gcal_tpik_target_radius_add <value>`: Adds to the thirdperson hand-goal clamp radius. Negative values tighten it; positive values loosen it.
- `gcal_tpik_pole_source_add <value>` / `gcal_tpik_pole_native_add <value>`: No longer used (IK solver removed). The convars still exist for backward compat but have no effect.
- `gcal_tpik_smoothing_add <value>`: Adds to the shoulder-local TPIK smoothing speed. The effective value is clamped to `0..60`.
- `gcal_list_anims`: Lists every animation currently registered in GCAL.
- `gcal_list_files`: Lists all legacy VManip files GCAL has discovered and loaded.
- `gcal_play <animation> [track]`: Plays a registered animation from the client console. Supports animation-name autocomplete.
- `gcal_debug_sequences <animation>`: Prints the runtime sequence list for the animation model and warns when the model exposes zero sequences.
- `gcal_debug_track [track]`: Dumps the current track state, selected weapon-base strategy, current and last arm target entity, matched bones, source/target deltas, and active flip-side information.
- `gcal_stop [track]`: Stops one track, or all active tracks when no track is provided.
- `gcal_dynabase_status`: Shows whether DynaBase is detected and lists queued GCAL DynaBase sources.
- `gcal_menu_open`: Opens the GCAL desktop-window menu.
- `gcal_debug_menu`: Dumps GCAL menu state and attempts a menu refresh.
- `gcal_debug_conflict_popup`: Force-opens the conflict warning popup, using mounted conflicts or a labeled debug preview when none are present.
- `gcal_debug_unhandled_error`: Throws a deliberate clientside GCAL error through the normal engine error pipeline. Add `conflict` to simulate engine attribution to a known conflict and test correlation output.
- `gcal_show_now`: Opens and refreshes the current GCAL menu window immediately.
- `gcal_rebuild_menu`: Removes and rebuilds the current GCAL menu window.
- `gcal_cambone <0|1>`: Toggles the global camera bone (view-angle driving) feature. The menu also exposes this as a "Cambone enabled: on/off" button.

---

## 11. Camera Bone (Cambone)

GCAL can drive the local player's first-person view angles from an animation's attachment, replicating the original VManip camera-bone feel. The feature is on by default and works for every registered animation that has an attachment on its model — no extra setup is required.

### How It Works

When a track is active and the player is in first person, GCAL reads the first attachment's world angle from a hidden clone of the gesture model (the `camModel`). Each frame, the difference between this animated angle and a reference angle (`Angle(-79.75, 0, -90)` by default) is computed, scaled per-axis by `cam_angint`, and added to the player's view angles. The result: as the gesture's camera bone swings, the player's view rotates to match.

Animations can declare their own reference/intensity via the registration table:

```lua
GCAL:RegisterAnim("my_recoil", {
    model = "myaddon/c_recoil.mdl",
    cam_ang = Angle(-79.75, 0, -90), -- reference (rest) angle for the camera attachment
    cam_angint = { 1, 1, 1 },        -- per-axis intensity multipliers (pitch, yaw, roll)
    cambone = true                   -- explicitly enable cambone for this animation
})
```

| Field        | Type          | Description                                                                                                                |
| :----------- | :------------ | :------------------------------------------------------------------------------------------------------------------------ |
| `cam_ang`    | Angle         | Reference (rest) angle of the camera attachment. Default is `Angle(-79.75, 0, -90)`.                                       |
| `cam_angint` | table         | 3-component per-axis intensity multiplier `{ pitch, yaw, roll }`. Default is `{1, 1, 1}`.                                  |
| `cambone`    | bool          | Per-animation toggle. `true` always enables cambone for this animation, `false` always disables it, `nil` follows the global convar. |

### Per-Animation Toggle

Set `cambone = false` in the registration table to disable cambone for a specific animation:

```lua
GCAL:RegisterSecondHandAnim("calm_ping", {
    model = "myaddon/c_ping.mdl",
    cambone = false                   -- never drive view angles from this animation
})
```

When `cambone = true`, GCAL will create a `camModel` for the animation regardless of the global convar. When `cambone = nil` (not set), the animation follows `gcal_cambone`. When `cambone = false`, no `camModel` is created for the animation — saving the cost of an extra clientside model.

### Global Toggle

The global convar `gcal_cambone` (default `1`) controls cambone for all tracks whose registration does not explicitly set `cambone`. Disable it with:

```
gcal_cambone 0
```

The GCAL menu exposes a "Cambone enabled: on/off" button in the Actions section that toggles this convar.

### Custom Cambone Handlers

Addons can override or augment the default VManip-style behavior by registering their own cambone handler:

```lua
GCAL:RegisterCamBoneHandler("my_recoil_dampener", 10, function(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal, handler)
    -- Dampen pitch, amplify yaw
    local delta = attachment.Ang - camAng
    angles = Angle(
        angles.p + delta.p * 0.5 * camAngInt[1],
        angles.y + delta.y * 2.0 * camAngInt[2],
        angles.r + delta.r * 1.0 * camAngInt[3]
    )
    return origin, angles, fov
end)
```

Handlers are called in **priority order** (lower first), and each handler receives the output of the previous one. The default `"vmanip"` handler is registered at priority 0 and replicates the original VManip formula. To replace it entirely, register a handler at priority 0 with the same id (it overrides the default) or call `GCAL:RemoveCamBoneHandler("vmanip")`.

Handler function signature:

```
fn(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal, handler)
  -> origin, angles, fov
```

| Argument      | Description                                                                |
| :------------ | :------------------------------------------------------------------------- |
| `id`          | The handler's registered id string.                                        |
| `track`       | The runtime track table (has `camModel`, `attachment`, `camAng`, `camAngInt`, `lerpVal`). |
| `ply`         | The local player.                                                          |
| `origin`      | Current view origin (usually unchanged).                                  |
| `angles`      | Current view angles — modify and return these.                            |
| `fov`         | Current field of view.                                                     |
| `attachment`  | The animated attachment table with `.Pos` and `.Ang`. May be `nil`.        |
| `camAng`      | The reference (rest) angle.                                                |
| `camAngInt`   | The 3-element per-axis intensity table.                                    |
| `lerpVal`     | The track's current lerp value (`1` = weapon pose, `0` = full animation). |
| `handler`     | The handler's own registered table.                                       |

API:

| Function                             | Purpose                                                                    |
| :----------------------------------- | :------------------------------------------------------------------------- |
| `GCAL:RegisterCamBoneHandler(id, priority, fn)` | Registers a new handler with the given priority.                 |
| `GCAL:RemoveCamBoneHandler(id)`      | Removes a handler by id.                                                  |
| `GCAL:ComputeCamBoneView(track, ply, origin, angles, fov)` | Internal: runs all handlers in order. Used by the `CalcView` hook. |

---

If you're seeking help, please use the discussions on addon page, Happy coding! :3
