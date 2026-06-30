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
| `lerp_peak`          | number       | Cycle at which the animation begins transitioning back (default: 0.5).                                                                                |
| `speed`              | number       | Playback rate multiplier (default: 1.0).                                                                                                              |
| `startcycle`         | number       | Cycle to start the animation at (0.0 to 1.0).                                                                                                         |
| `loop`               | bool         | If true, the animation repeats and never lerps out.                                                                                                   |
| `segmented`          | bool         | Segment mode. Use `GCAL:PlaySegment(trackID, sequence, lastSegment, sounds)` after `GCALSegmentFinish`.                                               |
| `holdtime`           | number       | Time in seconds after which the animation freezes (useful for interactions).                                                                          |
| `sounds`             | table        | A dictionary of `[path] = time` to play audio during playback.                                                                                        |
| `hand`               | string       | Friendly hand selector: `left`, `second`, `offhand`, `right`, or `both`. Sets default `bones` and `group_name`.                                       |
| `bones`              | table/string | Target bone names to manipulate, or a hand alias such as `"right"` / `"both"`. Defaults from `hand`.                                                  |
| `source_hand`        | string       | Optional source hand to read from in the animation model. Useful when the target hand is right but the model sequence is authored on left-hand bones. |
| `source_bones`       | table/string | Optional source bone names to read from. Defaults to `bones`, or from `source_hand` when provided.                                                    |
| `addon_name`         | string       | Optional display name used by GCAL's Toggle Anims tree to group animations by addon.                                                                  |
| `group_name`         | string       | Default track ID for this animation. If omitted, GCAL uses `left_arm`, `right_arm`, or `both_arms` from `hand`.                                       |
| `track` / `track_id` | string       | Friendly aliases for `group_name`.                                                                                                                    |
| `thirdperson`        | bool         | Enables projection of this track onto the local player model while rendered in thirdperson. Defaults to true.                                         |
| `block_code`         | bool         | Marks this animation as a code blocker while its track is active. Other addon code can check `GCAL:IsCodeBlocked(scope)` and return early.             |
| `block_code_scope`   | string       | Optional scope name for `block_code`, so unrelated systems can continue running.                                                                       |
| `easing_in`          | string       | Easing function for the entry transition.                                                                                                             |
| `easing_out`         | string       | Easing function for the exit transition.                                                                                                              |
| `locktoply`          | bool         | If true, pins the animation to the player's view (ignores weapon bob).                                                                                |
| `assurepos`          | bool         | Similar to locktoply; ensures perfect alignment.                                                                                                      |

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

GCAL uses one TPIK path for thirdperson. The animation model supplies shoulder, elbow, and hand goals; GCAL solves the player model's upper arm and forearm using the player's own limb lengths, applies the animated hand orientation, and carries helper bones and fingers through the solved hierarchy. A separate clone of the animation's registered model renders addon-owned props such as spray cans or tablets; obvious viewmodel arm materials are hidden automatically. Set `thirdperson = false` for animations that should remain firstperson-only.

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
    pole_source = 0.35,
    pole_native = 0.35,
    smoothing = 18
})
```

You can also assign directly with `GCAL.TPIKOptions.radio_hold = { ... }`. Use `sequence` when the firstperson sequence is not suitable for thirdperson posing. GCAL keeps the normal `model`/`camModel` on the firstperson sequence and creates a separate hidden TPIK source model on the requested sequence. The thirdperson prop clone follows the TPIK sequence too, so addon-owned props stay matched to the thirdperson arm pose.

`model = false` disables the thirdperson prop clone. `model_bone` limits prop-distance validation to one source-model bone. `model_max_distance` controls how far transformed model hitboxes/bones may drift from the solved hand before the prop is hidden; the default is `32`, and `0` disables the guard. `hide_materials` and `keep_materials` refine automatic c-arm/glove material suppression. `target_radius`, `pole_source`, `pole_native`, and `smoothing` tune the TPIK solver; their defaults are `38`, `0.35`, `0.35`, and `18`.

Thirdperson rendering is selected by method: ARC9 weapons with active native TPIK use `arc9_tpik`, ARC9 weapons without native TPIK use `arc9_no_tpik`, and other weapon bases use `normal`. The `arc9_tpik` method waits for ARC9's native `ARC9_TPIK_PostSolve` hook before overlaying active GCAL tracks. The `arc9_no_tpik` method updates track timing but intentionally avoids player-bone and prop-clone overrides to preserve ARC9/GShaders rendering when ARC9 has no native TPIK stage.

Track timing is advanced once per rendered frame through a shared updater. Firstperson and thirdperson hooks only render the resulting state, so drawing both views cannot shorten an animation or skip short clips.

The playground exposes separate TPIK adjustment sliders under the global controls and under each animation's right-click adjustment menu. `gcal_anim_offset_*` and `gcal_anim_angle_*` affect normal firstperson placement. `gcal_tpik_offset_*` and `gcal_tpik_angle_*` are applied after source-to-player retargeting, so they move only the final thirdperson TPIK pose. `gcal_tpik_target_radius_add`, `gcal_tpik_pole_source_add`, `gcal_tpik_pole_native_add`, and `gcal_tpik_smoothing_add` are additive nudges on top of each animation's registered TPIK values. GCAL no longer applies animation-specific FOV offsets.

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
| `arc9` | ARC9 markers or TPIK methods | Uses the owner's normal viewmodel. | Thirdperson uses explicit methods: `arc9_tpik` for ARC9's native post-solve hook, or `arc9_no_tpik` for ARC9 weapons with inactive/native-disabled TPIK. `arc9_no_tpik` does not alter the thirdperson player skeleton. |
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
- Tune `target_radius`, `pole_source`, `pole_native`, and `smoothing` in `GCAL.TPIKOptions`.
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
- `gcal_tpik_pole_source_add <value>` / `gcal_tpik_pole_native_add <value>`: Adds to the TPIK elbow-pole blend weights, clamped to `0..1` after registration defaults are applied.
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

---

If you're seeking help, please use the discussions on addon page, Happy coding! :3
