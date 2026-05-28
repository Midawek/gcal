# GCAL: GMod Compliant Armature Layer

### Developer Documentation :3

GCAL is a modern, modular offhand animation library for Garry's Mod. It serves as a superior, backward-compatible replacement for the legacy VManip system.

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
| `thirdperson`        | bool         | Reserved for the unfinished thirdperson projection path. Currently ignored while thirdperson support is internally disabled.                          |
| `block_code`         | bool         | Marks this animation as a code blocker while its track is active. Other addon code can check `GCAL:IsCodeBlocked(scope)` and return early. Aliases: `stop_code`, `block_execution`, `stop_execution`, `pause_code`. |
| `block_code_scope`   | string       | Optional scope name for `block_code`, so unrelated systems can continue running. Aliases: `code_block_scope`, `block_scope`, `scope`.                 |
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

GCAL contains an unfinished thirdperson projection path, but it is currently internally disabled and not used at runtime.

```lua
GCAL:RegisterSecondHandAnim("radio_press", {
    model = "myaddon/c_radio_press.mdl",
    thirdperson = true -- Reserved for future use while support is disabled internally.
})
```

The `thirdperson` field and `gcal_thirdperson` convar are kept for future work, but the internal gate currently prevents tracks from enabling or rendering thirdperson projection.

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

## 9. Debugging Tools

Use these console commands during development:

- `gcal_debug 1`: Enables the real-time HUD and console logging.
- `gcal_playback_speed <multiplier>`: Changes global GCAL playback speed. The menu exposes this as a slider from `0.1` to `3`.
- `gcal_mute_sounds 1`: Mutes sounds emitted by GCAL animations.
- `gcal_sound_pitch <pitch>`: Changes GCAL animation sound pitch. The menu uses `75`, `100`, and `140` presets.
- `gcal_thirdperson 1`: Reserved for the unfinished thirdperson projection path; ignored while the internal gate is disabled.
- `gcal_list_anims`: Lists every animation currently registered in GCAL.
- `gcal_list_files`: Lists all legacy VManip files GCAL has discovered and loaded.
- `gcal_play <animation> [track]`: Plays a registered animation from the client console. Supports animation-name autocomplete.
- `gcal_debug_sequences <animation>`: Prints the runtime sequence list for the animation model and warns when the model exposes zero sequences.
- `gcal_debug_track [track]`: Dumps the current track state, selected weapon-base strategy, current and last arm target entity, matched bones, source/target deltas, and active flip-side information.
- `gcal_stop [track]`: Stops one track, or all active tracks when no track is provided.
- `gcal_dynabase_status`: Shows whether DynaBase is detected and lists queued GCAL DynaBase sources.
- `gcal_menu_open`: Opens the GCAL desktop-window menu.
- `gcal_debug_menu`: Dumps GCAL menu state and attempts a menu refresh.
- `gcal_show_now`: Opens and refreshes the current GCAL menu window immediately.
- `gcal_rebuild_menu`: Removes and rebuilds the current GCAL menu window.

---

If you're seeking help, please use the discussions on addon page, Happy coding! :3
