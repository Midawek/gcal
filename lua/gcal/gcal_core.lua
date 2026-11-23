GCAL = GCAL or {}
GCAL.Anims = GCAL.Anims or {}
GCAL.ActiveTracks = GCAL.ActiveTracks or {}
GCAL.ImportedFiles = GCAL.ImportedFiles or {}
GCAL.QueuedAnims = GCAL.QueuedAnims or {}
GCAL.TPIKOptions = GCAL.TPIKOptions or {}
GCAL.CamBoneHandlers = GCAL.CamBoneHandlers or {}
GCAL.CamBoneHandlerOrder = GCAL.CamBoneHandlerOrder or {}

GCAL.GROUPS = {
    LEFT_ARM = {
        "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_L_Ulna", "ValveBiped.Bip01_L_Finger4",
        "ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42", "ValveBiped.Bip01_L_Finger3",
        "ValveBiped.Bip01_L_Finger31", "ValveBiped.Bip01_L_Finger32", "ValveBiped.Bip01_L_Finger2",
        "ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22", "ValveBiped.Bip01_L_Finger1",
        "ValveBiped.Bip01_L_Finger11", "ValveBiped.Bip01_L_Finger12", "ValveBiped.Bip01_L_Finger0",
        "ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02"
    },
    RIGHT_ARM = {
        "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_R_Wrist", "ValveBiped.Bip01_R_Ulna", "ValveBiped.Bip01_R_Finger4",
        "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42", "ValveBiped.Bip01_R_Finger3",
        "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32", "ValveBiped.Bip01_R_Finger2",
        "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22", "ValveBiped.Bip01_R_Finger1",
        "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12", "ValveBiped.Bip01_R_Finger0",
        "ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02"
    }
}
GCAL.GROUPS.BOTH_ARMS = {}
for _, boneName in ipairs(GCAL.GROUPS.LEFT_ARM) do
    GCAL.GROUPS.BOTH_ARMS[#GCAL.GROUPS.BOTH_ARMS + 1] = boneName
end
for _, boneName in ipairs(GCAL.GROUPS.RIGHT_ARM) do
    GCAL.GROUPS.BOTH_ARMS[#GCAL.GROUPS.BOTH_ARMS + 1] = boneName
end

if CLIENT then
    GCAL.Debug = CreateClientConVar("gcal_debug", "0", true, false, "Enable GCAL debug mode.")
    GCAL.ThirdPerson = CreateClientConVar("gcal_thirdperson", "1", true, false,
        "Render GCAL arm animations on the local player in thirdperson.")
    GCAL.PlaybackSpeed = CreateClientConVar("gcal_playback_speed", "1", true, false,
        "Global GCAL playback speed multiplier.")
    GCAL.MuteSounds = CreateClientConVar("gcal_mute_sounds", "0", true, false, "Mute animation sounds emitted by GCAL.")
    GCAL.SoundPitch = CreateClientConVar("gcal_sound_pitch", "100", true, false,
        "Pitch used for animation sounds emitted by GCAL.")
    GCAL.AnimationOffsetX = CreateClientConVar("gcal_anim_offset_x", "0", true, false,
        "Global GCAL animation forward/back offset.")
    GCAL.AnimationOffsetY = CreateClientConVar("gcal_anim_offset_y", "0", true, false,
        "Global GCAL animation right/left offset.")
    GCAL.AnimationOffsetZ = CreateClientConVar("gcal_anim_offset_z", "0", true, false,
        "Global GCAL animation up/down offset.")
    GCAL.AnimationAngleP = CreateClientConVar("gcal_anim_angle_p", "0", true, false,
        "Global GCAL animation pitch offset.")
    GCAL.AnimationAngleY = CreateClientConVar("gcal_anim_angle_y", "0", true, false, "Global GCAL animation yaw offset.")
    GCAL.AnimationAngleR = CreateClientConVar("gcal_anim_angle_r", "0", true, false, "Global GCAL animation roll offset.")
    GCAL.TPIKOffsetX = CreateClientConVar("gcal_tpik_offset_x", "0", true, false,
        "Global GCAL thirdperson TPIK forward/back offset.")
    GCAL.TPIKOffsetY = CreateClientConVar("gcal_tpik_offset_y", "0", true, false,
        "Global GCAL thirdperson TPIK right/left offset.")
    GCAL.TPIKOffsetZ = CreateClientConVar("gcal_tpik_offset_z", "0", true, false,
        "Global GCAL thirdperson TPIK up/down offset.")
    GCAL.TPIKAngleP = CreateClientConVar("gcal_tpik_angle_p", "0", true, false,
        "Global GCAL thirdperson TPIK pitch offset.")
    GCAL.TPIKAngleY = CreateClientConVar("gcal_tpik_angle_y", "0", true, false,
        "Global GCAL thirdperson TPIK yaw offset.")
    GCAL.TPIKAngleR = CreateClientConVar("gcal_tpik_angle_r", "0", true, false,
        "Global GCAL thirdperson TPIK roll offset.")
    GCAL.TPIKTargetRadiusAdd = CreateClientConVar("gcal_tpik_target_radius_add", "0", true, false,
        "Global GCAL thirdperson TPIK target radius adjustment.")
    GCAL.TPIKSmoothingAdd = CreateClientConVar("gcal_tpik_smoothing_add", "0", true, false,
        "Global GCAL thirdperson TPIK smoothing adjustment.")
    GCAL.CamBone = CreateClientConVar("gcal_cambone", "1", true, false,
        "Enable GCAL camera bone (view angle driving from animation attachments) for all tracks.")
    GCAL.CloneOffsetX = CreateClientConVar("gcal_clone_offset_x", "0", true, false,
        "Global GCAL thirdperson model clone forward/back offset.")
    GCAL.CloneOffsetY = CreateClientConVar("gcal_clone_offset_y", "0", true, false,
        "Global GCAL thirdperson model clone right/left offset.")
    GCAL.CloneOffsetZ = CreateClientConVar("gcal_clone_offset_z", "0", true, false,
        "Global GCAL thirdperson model clone up/down offset.")
    GCAL.InternalThirdPersonEnabled = true
    GCAL.AnimationAdjustments = GCAL.AnimationAdjustments or {}

    function GCAL:IsThirdPersonEnabled()
        return self.InternalThirdPersonEnabled == true and self.ThirdPerson ~= nil and self.ThirdPerson:GetBool()
    end

    local animationAdjustmentFields = {
        pos_x = true,
        pos_y = true,
        pos_z = true,
        ang_p = true,
        ang_y = true,
        ang_r = true,
        tpik_pos_x = true,
        tpik_pos_y = true,
        tpik_pos_z = true,
        tpik_ang_p = true,
        tpik_ang_y = true,
        tpik_ang_r = true,
        tpik_target_radius_add = true,
        tpik_smoothing_add = true,
        clone_offset_x = true,
        clone_offset_y = true,
        clone_offset_z = true
    }

    function GCAL:AnimationAdjustmentCookieKey(name, field)
        return "gcal_anim_adjust_" .. string.gsub(tostring(name), "[^%w_]", "_") .. "_" .. tostring(field)
    end

    function GCAL:GetAnimationAdjustmentValue(name, field)
        if not animationAdjustmentFields[field] then return 0 end

        name = tostring(name or "")
        local values = self.AnimationAdjustments[name]
        if not values then
            values = {}
            self.AnimationAdjustments[name] = values
        end

        local value = values[field]
        if value == nil then
            value = cookie and cookie.GetNumber and cookie.GetNumber(self:AnimationAdjustmentCookieKey(name, field), 0) or 0
            values[field] = value
        end

        return tonumber(value) or 0
    end

    local adjustmentCache = {}

    local function InvalidateAdjustmentCache(name)
        if name == nil then
            adjustmentCache = {}
        else
            adjustmentCache[tostring(name)] = nil
        end
    end
    GCAL.InvalidateAdjustmentCache = InvalidateAdjustmentCache

    for _, convarName in ipairs({
        "gcal_anim_offset_x", "gcal_anim_offset_y", "gcal_anim_offset_z",
        "gcal_anim_angle_p", "gcal_anim_angle_y", "gcal_anim_angle_r",
        "gcal_tpik_offset_x", "gcal_tpik_offset_y", "gcal_tpik_offset_z",
        "gcal_tpik_angle_p", "gcal_tpik_angle_y", "gcal_tpik_angle_r",
        "gcal_tpik_target_radius_add", "gcal_tpik_smoothing_add",
        "gcal_clone_offset_x", "gcal_clone_offset_y", "gcal_clone_offset_z"
    }) do
        cvars.AddChangeCallback(convarName, function() InvalidateAdjustmentCache() end, "GCAL_AdjustmentCache")
    end

    function GCAL:SetAnimationAdjustmentValue(name, field, value)
        if not animationAdjustmentFields[field] then return end

        name = tostring(name or "")
        self.AnimationAdjustments[name] = self.AnimationAdjustments[name] or {}
        self.AnimationAdjustments[name][field] = tonumber(value) or 0
        InvalidateAdjustmentCache(name)

        if cookie and cookie.Set then
            cookie.Set(self:AnimationAdjustmentCookieKey(name, field), tostring(self.AnimationAdjustments[name][field]))
        end
    end

    function GCAL:ClearAnimationAdjustment(name)
        name = tostring(name or "")
        self.AnimationAdjustments[name] = nil
        InvalidateAdjustmentCache(name)

        for field in pairs(animationAdjustmentFields) do
            if cookie and cookie.Set then
                cookie.Set(self:AnimationAdjustmentCookieKey(name, field), "0")
            end
        end
    end

    local function BuildAdjustment(self, name)
        local function value(convar, field)
            return convar:GetFloat() + self:GetAnimationAdjustmentValue(name, field)
        end

        local adjustment = {
            pos = Vector(value(self.AnimationOffsetX, "pos_x"), value(self.AnimationOffsetY, "pos_y"),
                value(self.AnimationOffsetZ, "pos_z")),
            ang = Angle(value(self.AnimationAngleP, "ang_p"), value(self.AnimationAngleY, "ang_y"),
                value(self.AnimationAngleR, "ang_r")),
            tpik = {
                pos = Vector(value(self.TPIKOffsetX, "tpik_pos_x"), value(self.TPIKOffsetY, "tpik_pos_y"),
                    value(self.TPIKOffsetZ, "tpik_pos_z")),
                ang = Angle(value(self.TPIKAngleP, "tpik_ang_p"), value(self.TPIKAngleY, "tpik_ang_y"),
                    value(self.TPIKAngleR, "tpik_ang_r")),
                target_radius_add = value(self.TPIKTargetRadiusAdd, "tpik_target_radius_add"),
                smoothing_add = value(self.TPIKSmoothingAdd, "tpik_smoothing_add")
            },
            option_add = {
                clone_offset_x = value(self.CloneOffsetX, "clone_offset_x"),
                clone_offset_y = value(self.CloneOffsetY, "clone_offset_y"),
                clone_offset_z = value(self.CloneOffsetZ, "clone_offset_z")
            }
        }
        adjustment.option_add.target_radius = adjustment.tpik.target_radius_add
        adjustment.option_add.smoothing = adjustment.tpik.smoothing_add
        adjustment.isZero = adjustment.pos:IsZero() and adjustment.ang:IsZero()
        return adjustment
    end

    local function CachedAdjustment(self, name)
        name = tostring(name or "")
        local adjustment = adjustmentCache[name]
        if not adjustment then
            adjustment = BuildAdjustment(self, name)
            adjustmentCache[name] = adjustment
        end
        return adjustment
    end

    function GCAL:GetAnimationAdjustment(name)
        return CachedAdjustment(self, name)
    end

    function GCAL:ApplyAnimationAdjustment(name, pos, ang)
        local adjustment = CachedAdjustment(self, name)
        if adjustment.isZero then return pos, ang end

        local offset = adjustment.pos
        local angleOffset = adjustment.ang
        local adjustedPos = pos + ang:Forward() * offset.x + ang:Right() * offset.y + ang:Up() * offset.z
        return adjustedPos, Angle(ang.p + angleOffset.p, ang.y + angleOffset.y, ang.r + angleOffset.r)
    end

    function GCAL:GetTPIKAdjustment(name)
        return CachedAdjustment(self, name).tpik
    end

    function GCAL:GetTPIKOptionAdd(name, option)
        return CachedAdjustment(self, name).option_add[option] or 0
    end
end

local function GCAL_NormalizeLegacyCompatName(value)
    value = tostring(value or "")
    value = string.gsub(value, "([a-z0-9])([A-Z])", "%1_%2")
    value = string.lower(value)
    value = string.gsub(value, "^reanim[_%-]?", "")
    value = string.gsub(value, "^anim[_%-]?", "")
    value = string.gsub(value, "^gesture[_%-]?", "")
    value = string.gsub(value, "^cmt[_%-]?", "")
    value = string.gsub(value, "[_%-%s]+anim$", "")
    value = string.gsub(value, "[_%-%s]+gesture$", "")
    value = string.gsub(value, "[_%-%s]+sequence$", "")
    value = string.gsub(value, "[_%-%s]+seq$", "")
    value = string.gsub(value, "[^%w]", "")
    return value
end

GCAL.DebugEvents = GCAL.DebugEvents or {}
local DEBUG_EVENT_LIMIT = 32
local debugEventFail = Color(255, 106, 106)
local debugEventWarn = Color(255, 176, 93)
local debugEventInfo = Color(236, 242, 255)

function GCAL:AddDebugEvent(text, color)
    if not CLIENT then return end
    local events = GCAL.DebugEvents
    events[#events + 1] = { time = RealTime(), text = tostring(text), color = color or debugEventInfo }
    if #events > DEBUG_EVENT_LIMIT then table.remove(events, 1) end
end

local function GCAL_Log(...)
    if not CLIENT or not GCAL.Debug:GetBool() then return end
    local count = select("#", ...)
    local parts = {}
    for i = 1, count do
        parts[i] = tostring(select(i, ...))
    end
    local text = table.concat(parts, " ")
    MsgC(Color(255, 255, 0), "[GCAL DEBUG] ", Color(255, 255, 255), text, "\n")

    if string.sub(text, 1, 2) ~= "  " then
        local lower = string.lower(text)
        local color = nil
        if string.find(lower, "fail", 1, true) or string.find(lower, "not found", 1, true) then
            color = debugEventFail
        elseif string.find(lower, "warning", 1, true) or string.find(lower, "suppressed", 1, true)
            or string.find(lower, "cannot", 1, true) or string.find(lower, "fallback", 1, true) then
            color = debugEventWarn
        end
        GCAL:AddDebugEvent(text, color)
    end
end

function GCAL:NormalizeHand(hand)
    hand = string.lower(tostring(hand or "left"))

    if hand == "right" or hand == "right_arm" or hand == "r" then
        return "right"
    end

    if hand == "both" or hand == "both_hands" or hand == "bothhands" or hand == "both_arms" or hand == "dual" then
        return "both"
    end

    return "left"
end

function GCAL:GetHandBones(hand)
    hand = self:NormalizeHand(hand)

    if hand == "right" then return self.GROUPS.RIGHT_ARM end
    if hand == "both" then return self.GROUPS.BOTH_ARMS end

    return self.GROUPS.LEFT_ARM
end

function GCAL:GetHandTrack(hand)
    hand = self:NormalizeHand(hand)

    if hand == "right" then return "right_arm" end
    if hand == "both" then return "both_arms" end

    return "left_arm"
end

local warnedDeprecations = {}

local function IsGCALSource(src)
    src = string.lower(tostring(src or ""))
    return string.find(src, "gcal/gcal_", 1, true) ~= nil
        or string.find(src, "gcal_init.lua", 1, true) ~= nil
        or string.find(src, "aaa_gcal_shim.lua", 1, true) ~= nil
end

local function DeprecationCallerLocation()
    for level = 3, 16 do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        if info.what ~= "C" and not IsGCALSource(info.short_src) then
            return tostring(info.short_src) .. ":" .. tostring(info.currentline)
        end
    end
    return "unknown caller"
end

function GCAL:WarnDeprecated(animName, key, message)
    local id = tostring(animName) .. "\0" .. tostring(key)
    if warnedDeprecations[id] then return end
    warnedDeprecations[id] = true

    MsgC(
        Color(255, 176, 93), "[GCAL] Deprecated: ",
        Color(239, 243, 248), "'" .. tostring(key) .. "' on '" .. tostring(animName) .. "' " .. message,
        Color(151, 163, 177), " (" .. DeprecationCallerLocation() .. ")\n"
    )
    GCAL:AddDebugEvent("deprecated '" .. tostring(key) .. "' on '" .. tostring(animName) .. "'", debugEventWarn)
end

local function ApplyDeprecations(name, data, renamed, removed)
    for oldKey, newKey in pairs(renamed) do
        if data[oldKey] ~= nil then
            GCAL:WarnDeprecated(name, oldKey, "is deprecated, use '" .. newKey .. "' instead.")
            if data[newKey] == nil then data[newKey] = data[oldKey] end
            data[oldKey] = nil
        end
    end
    for key, reason in pairs(removed) do
        if data[key] ~= nil then
            GCAL:WarnDeprecated(name, key, reason)
            data[key] = nil
        end
    end
end

local ANIM_RENAMED_FIELDS = {
    onstart = "on_start",
    OnStart = "on_start",
    onfinish = "on_finish",
    OnFinish = "on_finish",
    oninterrupt = "on_interrupt",
    OnInterrupt = "on_interrupt",
    easeintime = "ease_in_time",
    easeouttime = "ease_out_time",
    soundvolume = "sound_volume",
    soundlevel = "sound_level",
    soundflags = "sound_flags",
    blendweight = "blend_weight",
    modelscale = "model_scale",
    modelskin = "model_skin",
    modelbodygroups = "model_bodygroups",
    gunmode = "gun_mode",
    gunbones = "gun_bones",
    bonegroup = "bone_group",
}

local REMOVED_ON_CYCLE = "was removed and is ignored. Poll GCAL:GetCycle(trackID) from a Think hook instead."
local REMOVED_DELAY = "was removed and is ignored. Delay your GCAL:Play call with timer.Simple instead."
local REMOVED_CONDITION = "was removed and is ignored. Check the condition before calling GCAL:Play, "
    .. "or return false from the VManipPrePlayAnim hook."
local REMOVED_SHAKE = "was removed and is ignored. Call util.ScreenShake from on_start instead."
local REMOVED_BLEND_MODE = "was removed and is ignored (only \"normal\" was ever implemented)."
local REMOVED_FOV = "was removed and is ignored. Change the FOV from your own CalcView hook, "
    .. "scaled by 1 - GCAL:GetLerp(trackID)."
local REMOVED_VM_OFFSET = "was removed and is ignored. Offset the viewmodel from your own CalcViewModelView hook instead."
local ANIM_REMOVED_FIELDS = {
    on_cycle = REMOVED_ON_CYCLE,
    oncycle = REMOVED_ON_CYCLE,
    OnCycle = REMOVED_ON_CYCLE,
    delay_start = REMOVED_DELAY,
    delaystart = REMOVED_DELAY,
    play_condition = REMOVED_CONDITION,
    playcondition = REMOVED_CONDITION,
    condition = REMOVED_CONDITION,
    screen_shake = REMOVED_SHAKE,
    screenshake = REMOVED_SHAKE,
    blend_mode = REMOVED_BLEND_MODE,
    blendmode = REMOVED_BLEND_MODE,
    disable_pred = "was removed and is ignored (it never had an effect).",
    viewmodel_fov = REMOVED_FOV,
    vm_fov = REMOVED_FOV,
    fov = REMOVED_FOV,
    viewmodel_offset = REMOVED_VM_OFFSET,
    vm_offset = REMOVED_VM_OFFSET,
}

local ANIM_TPIK_FIELDS = {
    thirdperson_model = "model",
    thirdperson_model_bone = "model_bone",
    thirdperson_model_max_distance = "model_max_distance",
    thirdperson_hide_materials = "hide_materials",
    thirdperson_keep_materials = "keep_materials",
    thirdperson_target_radius = "target_radius",
    thirdperson_smoothing = "smoothing",
}

local TPIK_RENAMED_OPTIONS = {
    thirdperson_model = "model",
    thirdperson_model_bone = "model_bone",
    thirdperson_model_max_distance = "model_max_distance",
    thirdperson_hide_materials = "hide_materials",
    thirdperson_keep_materials = "keep_materials",
    thirdperson_target_radius = "target_radius",
    thirdperson_smoothing = "smoothing",
}

local TPIK_REMOVED_UNUSED = "was removed and is ignored (it was never implemented)."
local TPIK_REMOVED_OPTIONS = {
    pole_source = "was removed and is ignored (the IK solver is gone).",
    pole_native = "was removed and is ignored (the IK solver is gone).",
    blend_strength = "was removed and is ignored. Use blend_weight on the animation instead.",
    blend_curve = "was removed and is ignored. Use lerp_curve or easing_in / easing_out on the animation instead.",
    distance_fade = "was removed and is ignored. Remote players already stop rendering past 2000 units.",
    fade_start = "was removed and is ignored (distance_fade is gone).",
    fade_end = "was removed and is ignored (distance_fade is gone).",
    model_skin = TPIK_REMOVED_UNUSED,
    model_bodygroups = TPIK_REMOVED_UNUSED,
    model_material = TPIK_REMOVED_UNUSED,
    render_mode = TPIK_REMOVED_UNUSED,
    render_fx = TPIK_REMOVED_UNUSED,
    offset_relative_to = TPIK_REMOVED_UNUSED,
    offset_space = TPIK_REMOVED_UNUSED,
    angular_offset_x = TPIK_REMOVED_UNUSED,
    angular_offset_y = TPIK_REMOVED_UNUSED,
    angular_offset_z = TPIK_REMOVED_UNUSED,
    update_rate = TPIK_REMOVED_UNUSED,
    interpolate = TPIK_REMOVED_UNUSED,
    force_update = TPIK_REMOVED_UNUSED,
}

local TPIK_VALID_OPTIONS = {
    sequence = "string",
    model = "bool",
    model_bone = "string",
    model_max_distance = "number",
    hide_materials = "table",
    keep_materials = "table",
    target_radius = "number",
    smoothing = "number",
    offset_x = "number",
    offset_y = "number",
    offset_z = "number",
    model_offset = "table",
    clone_offset_x = "number",
    clone_offset_y = "number",
    clone_offset_z = "number",
    blend_per_bone = "table",
    lock_bones = "table",
    scale_bones = "table",
}

local TPIK_ALIASES = {
    anim = "sequence",
    animation = "sequence",
}

function GCAL:RegisterTPIKOptions(name, options)
    if not name or not istable(options) then return false end
    name = tostring(name)

    local input = table.Copy(options)
    for alias, key in pairs(TPIK_ALIASES) do
        if input[alias] ~= nil then
            if input[key] == nil then input[key] = input[alias] end
            input[alias] = nil
        end
    end

    if input.ignore_bones ~= nil then
        self:WarnDeprecated(name, "ignore_bones", "is deprecated, use 'lock_bones' instead.")
        if istable(input.ignore_bones) then
            local merged = istable(input.lock_bones) and table.Copy(input.lock_bones) or {}
            for _, boneName in ipairs(input.ignore_bones) do merged[#merged + 1] = boneName end
            input.lock_bones = merged
        end
        input.ignore_bones = nil
    end

    ApplyDeprecations(name, input, TPIK_RENAMED_OPTIONS, TPIK_REMOVED_OPTIONS)

    local clean = {}
    for key, value in pairs(input) do
        local expected = TPIK_VALID_OPTIONS[key]
        if not expected then
            ErrorNoHaltWithStack("[GCAL] RegisterTPIKOptions: unknown option '" ..
                tostring(key) .. "' for '" .. name .. "'\n")
            continue
        end
        if expected == "number" then
            clean[key] = tonumber(value) or 0
        elseif expected == "bool" then
            clean[key] = tobool(value)
        elseif expected == "string" then
            clean[key] = tostring(value)
        else
            clean[key] = value
        end
    end

    self.TPIKOptions[name] = clean
    return true
end

function GCAL:GetTPIKOptions(name)
    return self.TPIKOptions and self.TPIKOptions[tostring(name or "")] or nil
end

local DEFAULT_CAM_ANG = Angle(-79.75, 0, -90)
local DEFAULT_CAM_INTENSITY = { 1, 1, 1 }

local function DefaultCamBoneHandler(track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
    if not attachment or not attachment.Ang then return origin, angles, fov end
    local intensity = camAngInt or DEFAULT_CAM_INTENSITY
    local lerpScale = 1 - (lerpVal or 0)
    local camang = attachment.Ang - (camAng or DEFAULT_CAM_ANG)
    angles = Angle(
        angles.p + camang.p * (intensity[1] or 1) * lerpScale,
        angles.y + camang.y * (intensity[2] or 1) * lerpScale,
        angles.r + camang.r * (intensity[3] or 1) * lerpScale
    )
    return origin, angles, fov
end

local function RebuildCamBoneHandlerOrder(self)
    local order = {}
    for _, handler in pairs(self.CamBoneHandlers) do order[#order + 1] = handler end
    table.sort(order, function(a, b) return a.priority < b.priority end)
    self.CamBoneHandlerOrder = order
end

function GCAL:RegisterCamBoneHandler(id, priority, fn)
    if not id or not isfunction(fn) then return false end
    priority = tonumber(priority) or 0
    self.CamBoneHandlers[id] = { id = id, priority = priority, fn = fn }
    RebuildCamBoneHandlerOrder(self)
    return true
end

function GCAL:RemoveCamBoneHandler(id)
    if not id or not self.CamBoneHandlers[id] then return false end
    self.CamBoneHandlers[id] = nil
    RebuildCamBoneHandlerOrder(self)
    return true
end

function GCAL:ComputeCamBoneView(track, ply, origin, angles, fov)
    if not track then return origin, angles, fov end
    local attachment = track.attachment
    if not attachment or not attachment.Ang then return origin, angles, fov end
    local camAng = track.camAng or DEFAULT_CAM_ANG
    local camAngInt = track.camAngInt or DEFAULT_CAM_INTENSITY
    local lerpVal = track.lerpVal or 1
    for _, handler in ipairs(self.CamBoneHandlerOrder) do
        origin, angles, fov = handler.fn(handler.id, track, ply, origin, angles, fov, attachment, camAng, camAngInt,
            lerpVal, handler)
    end
    return origin, angles, fov
end

GCAL:RegisterCamBoneHandler("vmanip", 0,
    function(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
        return DefaultCamBoneHandler(track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
    end)

function GCAL:NormalizeGunMode(mode)
    if mode == true then return "follow" end
    mode = string.lower(tostring(mode or ""))
    if mode == "follow" or mode == "hand" or mode == "1" then return "follow" end
    if mode == "animated" or mode == "anim" or mode == "animation" or mode == "2" then return "animated" end
    return nil
end

local function LerpSpeedFromTime(seconds, fallbackSpeed)
    seconds = tonumber(seconds)
    if seconds and seconds > 0 then return 1 / (7 * seconds) end
    return fallbackSpeed or 1
end

function GCAL:PrepareAnimData(data, hand, name)
    if not data then return data end
    name = name or "<unnamed>"

    ApplyDeprecations(name, data, ANIM_RENAMED_FIELDS, ANIM_REMOVED_FIELDS)

    if data.model then
        local modelPath = tostring(data.model)
        if string.StartsWith(modelPath, "models/") then
            data.model = string.sub(modelPath, 8)
        end
    end

    hand = self:NormalizeHand(hand or data.hand or data.arm or data.bone_group or data.bonegroup)
    data.hand = hand
    data.bones = isstring(data.bones) and self:GetHandBones(data.bones) or data.bones or self:GetHandBones(hand)
    data.source_hand = data.source_hand or data.source_arm
    data.source_bones = isstring(data.source_bones) and self:GetHandBones(data.source_bones) or data.source_bones
    data.source_bones = data.source_bones or (data.source_hand and self:GetHandBones(data.source_hand)) or data.bones
    data.group_name = data.track or data.track_id or data.group_name or self:GetHandTrack(hand)
    data.block_code = data.block_code ~= nil and tobool(data.block_code) or false
    if data.cambone ~= nil then
        data.cambone = tobool(data.cambone)
    end

    if data.can_interrupt == nil then
        data.can_interrupt = true
    else
        data.can_interrupt = tobool(data.can_interrupt)
    end

    data.lerp_speed_in = LerpSpeedFromTime(data.ease_in_time, data.lerp_speed_in)
    data.lerp_speed_out = LerpSpeedFromTime(data.ease_out_time, data.lerp_speed_out)

    local volume = tonumber(data.sound_volume)
    if volume and volume > 1 then
        self:WarnDeprecated(name, "sound_volume",
            "is now a 0-1 volume. Values above 1 are used as sound_level; set sound_level instead.")
        if data.sound_level == nil then data.sound_level = volume end
        volume = nil
    end
    data.sound_volume = volume and math.Clamp(volume, 0, 1) or 1
    data.sound_level = tonumber(data.sound_level) or 75
    data.sound_flags = tonumber(data.sound_flags) or 0

    data.gun_mode = self:NormalizeGunMode(data.gun_mode)
    data.local_only = data.local_only ~= nil and tobool(data.local_only) or false

    return data
end

local GetTPIKOptionsForAnim
local GetTPIKSequenceName
local ResolveTPIKSequence

local function ApplyAnimDataToTrack(track, data)
    local easingInName = data.easing_in or "Legacy"
    local easingOutName = data.easing_out or "Legacy"

    track.data = data
    track.bones = data.bones or GCAL.GROUPS.LEFT_ARM
    track.sourceBones = data.source_bones or data.bones or GCAL.GROUPS.LEFT_ARM
    track.speed = data.speed or 1

    track.lerpPeak = data.lerp_peak or 0.5
    track.lerpCurve = data.lerp_curve or 1
    track.lerpSpeedIn = data.lerp_speed_in or 1
    track.lerpSpeedOut = data.lerp_speed_out or 1
    track.legacyMatrixLerp = easingInName == "Legacy" and easingOutName == "Legacy"
    track.easingIn = easingInName ~= "Legacy" and GCAL.Lerp.Get(easingInName) or nil
    track.easingOut = easingOutName ~= "Legacy" and GCAL.Lerp.Get(easingOutName) or nil
    track.blendWeight = data.blend_weight

    track.thirdperson = GCAL.InternalThirdPersonEnabled and GCAL.ThirdPerson:GetBool() and data.thirdperson ~= false
        and not data.legacy and (not GCAL.IsAnimTPIKEnabled or GCAL:IsAnimTPIKEnabled(track.name))
    track.tpikOptions = GetTPIKOptionsForAnim and GetTPIKOptionsForAnim(track.name) or nil
    track.tpikSequenceRequested = GetTPIKSequenceName and GetTPIKSequenceName(track.name) or nil
    track.tpikBoneRules = nil

    track.canInterrupt = data.can_interrupt ~= false
    track.onStartCallback = data.on_start
    track.onFinishCallback = data.on_finish
    track.onInterruptCallback = data.on_interrupt

    track.soundVolume = data.sound_volume or 1
    track.soundLevel = data.sound_level or 75
    track.soundFlags = data.sound_flags or 0

    track.gunMode = data.gun_mode
    track.gunBones = data.gun_bones
    track.gunBonePairs = nil

    track.modelScale = data.model_scale
    track.modelSkin = data.model_skin
    track.modelBodygroups = data.model_bodygroups

    track.blockCode = data.block_code or false
    track.blockCodeScope = data.block_code_scope
    track.preventQuit = data.preventquit or false
    track.segmented = data.segmented or false
    track.camboneEnabled = (data.cambone == nil) or tobool(data.cambone)
    track.camAng = data.cam_ang or DEFAULT_CAM_ANG
    track.camAngInt = data.cam_angint or DEFAULT_CAM_INTENSITY
end

local function RefreshActiveTrack(track, data)
    if not IsValid(track.model) then return end

    local oldTpikSeqID = track.tpikSeqID
    ApplyAnimDataToTrack(track, data)

    if data.locktoply ~= nil then
        track.lockZ = data.locktoply and EyePos().z or 0
    end
    if data.loop ~= nil then track.loop = data.loop end
    if data.holdtime ~= nil then
        track.holdTimeData = data.holdtime
        if data.holdtime and not track.holdTime then
            track.holdTime = track.startTime + data.holdtime
        end
    end

    if track.tpikSequenceRequested and ResolveTPIKSequence then
        track.tpikSeqID, track.tpikSequenceName = ResolveTPIKSequence(track, track.name, data)
        if IsValid(track.tpikModel) and track.tpikSeqID and track.tpikSeqID ~= -1
            and oldTpikSeqID ~= track.tpikSeqID then
            track.tpikModel:ResetSequence(track.tpikSeqID)
        end
    end

    if IsValid(track.thirdpersonModel) and oldTpikSeqID ~= track.tpikSeqID then
        track.thirdpersonModel:ResetSequence(track.tpikSeqID or track.seqID)
    end

    track.soundsDone = nil
    track.camAttachmentID = nil
    track.thirdpersonMaterialsConfigured = nil
    track.thirdpersonBoneMatrices = nil
    track.thirdpersonSolveFrame = nil
    track.thirdpersonModelReadyFrame = nil
end

function GCAL:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end
    if not name or not data then return end

    self:PrepareAnimData(data, nil, name)

    local movedTPIK
    for oldKey, optionKey in pairs(ANIM_TPIK_FIELDS) do
        if data[oldKey] ~= nil then
            self:WarnDeprecated(name, oldKey, "belongs in GCAL:RegisterTPIKOptions as '" .. optionKey .. "' now.")
            movedTPIK = movedTPIK or {}
            movedTPIK[optionKey] = data[oldKey]
            data[oldKey] = nil
        end
    end
    if movedTPIK then
        local existing = self:GetTPIKOptions(name)
        if existing then
            for key, value in pairs(existing) do movedTPIK[key] = value end
        end
        self:RegisterTPIKOptions(name, movedTPIK)
    end

    data.addon_name = data.addon_name or data.addon or data.source_addon or GCAL.CurrentRegistrationSource or "GCAL"
    GCAL_Log("Registering animation:", name)
    self.Anims[name] = data

    for _, track in pairs(self.ActiveTracks or {}) do
        if track.name == name then
            RefreshActiveTrack(track, data)
        end
    end
end

function GCAL:RegisterHandAnim(name, hand, data)
    if not name or not data then return end

    data.hand = hand
    return self:RegisterAnim(name, data)
end

function GCAL:RegisterSecondHandAnim(name, data)
    return self:RegisterHandAnim(name, "left", data)
end

function GCAL:RegisterRightHandAnim(name, data)
    return self:RegisterHandAnim(name, "right", data)
end

function GCAL:RegisterBothHandsAnim(name, data)
    return self:RegisterHandAnim(name, "both", data)
end

function GCAL:PlayHand(name, hand, trackID)
    return self:Play(name, trackID or self:GetHandTrack(hand))
end

function GCAL:PlaySecondHand(name, trackID)
    return self:PlayHand(name, "left", trackID)
end

function GCAL:GetAnim(name)
    return self.Anims[name]
end

function GCAL:GetTrack(trackID)
    return self.ActiveTracks[trackID]
end

function GCAL:IsTrackActive(trackID)
    local track = self:GetTrack(trackID)
    return track ~= nil and (not CLIENT or IsValid(track.model))
end

function GCAL:GetCurrentAnim(trackID)
    local track = self:GetTrack(trackID)
    return track and track.name
end

function GCAL:GetLerp(trackID)
    local track = self:GetTrack(trackID)
    return track and track.lerpVal or 0
end

function GCAL:GetCycle(trackID)
    local track = self:GetTrack(trackID)
    return track and track.cycle or 0
end

function GCAL:SetCycle(trackID, cycle)
    local track = self:GetTrack(trackID)
    if not track then return false end

    track.cycle = cycle
    return true
end

function GCAL:IsSegmented(trackID)
    local track = self:GetTrack(trackID)
    return track and track.segmented or false
end

function GCAL:GetCurrentSegment(trackID)
    local track = self:GetTrack(trackID)
    return track and track.curSegment
end

function GCAL:GetSegmentCount(trackID)
    local track = self:GetTrack(trackID)
    return track and track.segmentCount or 0
end

function GCAL:IsPreventQuit(trackID)
    local track = self:GetTrack(trackID)
    return track and track.preventQuit or false
end

function GCAL:IsCodeBlocked(scope)
    for _, track in pairs(self.ActiveTracks or {}) do
        if track.blockCode and (scope == nil or track.blockCodeScope == nil or track.blockCodeScope == scope) then
            return true, track
        end
    end

    return false, nil
end

function GCAL:GetCodeBlockers(scope)
    local blockers = {}

    for trackID, track in pairs(self.ActiveTracks or {}) do
        if track.blockCode and (scope == nil or track.blockCodeScope == nil or track.blockCodeScope == scope) then
            blockers[trackID] = track
        end
    end

    return blockers
end

function GCAL:GetGestureModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.model or nil
end

function GCAL:GetCamModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.camModel or nil
end

function GCAL:GetTPIKModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.tpikModel or nil
end

function GCAL:GetAllGestureModels()
    local out = {}
    for trackID, track in pairs(self.ActiveTracks or {}) do
        if trackID ~= "legs" and IsValid(track.model) then
            out[trackID] = track.model
        end
    end
    return out
end

function GCAL:GetAnimationNames()
    local out = {}
    for name in pairs(self.Anims or {}) do
        out[#out + 1] = name
    end
    return out
end

function GCAL:GetActiveTrackIDs()
    local out = {}
    for trackID in pairs(self.ActiveTracks or {}) do
        out[#out + 1] = trackID
    end
    return out
end

function GCAL:IsLooping(trackID)
    local track = self:GetTrack(trackID)
    return track ~= nil and track.loop == true
end

function GCAL:GetTrackDuration(trackID)
    local track = self:GetTrack(trackID)
    return track and track.duration or nil
end

function GCAL:StopAllTracks()
    for _, trackID in ipairs(self:GetActiveTrackIDs()) do
        self:StopTrack(trackID)
    end
end

if CLIENT then
    local EyeAngles = EyeAngles
    local EyePos = EyePos

    local curtime = 0
    local scalevec = Vector(1, 1, 1)
    local scaleflipvec = Vector(1, 1, -1)
    local angleFlip = Angle(180, 0, 0)
    local angleZero = Angle(0, 0, 0)

    local SyncLegacyVManipFields
    local posparentcache

    local function NormalizeModelPath(modelPath)
        if not modelPath then return "" end

        modelPath = tostring(modelPath)
        if string.StartsWith(modelPath, "models/") then
            modelPath = string.sub(modelPath, 8)
        end

        return "models/" .. modelPath
    end

    local function CreateTrack(name, anim)
        local now = CurTime()
        local track = {
            name = name,
            startTime = now,
            realStartTime = now,
            cycle = anim.startcycle or 0,
            lerpVal = 1, -- 1 = weapon pose, 0 = full animation
            lastLerpVal = 1,
            model = ClientsideModel(NormalizeModelPath(anim.model), RENDERGROUP_BOTH),
            lerpPeakTime = now + (anim.lerp_peak or 0.5),
            holdTime = anim.holdtime and (now + anim.holdtime) or nil,
            holdTimeData = anim.holdtime,
            holdQuit = false,
            gestureOnHold = false,
            gesturePastHold = false,
            loop = anim.loop or false,
            segmentFinished = false,
            lastSegment = false,
            segmentCount = 0,
            lockZ = anim.locktoply and EyePos().z or 0,
            soundsPlayed = {},
            legacyStarted = false,
            poseOnlyLegacy = false,
        }
        ApplyAnimDataToTrack(track, anim)
        return track
    end

    local function ApplyModelSettings(track, ent)
        if not IsValid(ent) then return end
        if track.modelScale then ent:SetModelScale(track.modelScale) end
        if track.modelSkin then ent:SetSkin(track.modelSkin) end
        if track.modelBodygroups then
            for bg, value in pairs(track.modelBodygroups) do
                ent:SetBodygroup(bg, value)
            end
        end
    end

    local function SetupSourceModels(track, anim, skipCamModel)
        if not IsValid(track.model) then
            GCAL_Log("Failed: Invalid model path: models/" .. tostring(anim.model))
            return false
        end
        track.model:SetNoDraw(true)
        track.model:SetupBones()
        ApplyModelSettings(track, track.model)

        if not skipCamModel and track.camboneEnabled and GCAL.CamBone:GetBool()
            and not IsValid(track.camModel) then
            track.camModel = ClientsideModel(NormalizeModelPath(anim.model), RENDERGROUP_BOTH)
        end
        if IsValid(track.camModel) then
            track.camModel:SetNoDraw(true)
            track.camModel:SetPos(vector_origin)
            track.camModel:SetAngles(angle_zero)
            track.camModel:SetupBones()
            ApplyModelSettings(track, track.camModel)
        end
        return true
    end

    local function CreateTrackModelCopy(track, sequence)
        local ent = ClientsideModel(track.model:GetModel(), RENDERGROUP_BOTH)
        if not IsValid(ent) then return nil end
        ent:SetNoDraw(true)
        ent:ResetSequenceInfo()
        ent:SetPlaybackRate(1)
        ent:ResetSequence(sequence)
        ApplyModelSettings(track, ent)
        return ent
    end

    local function ResolveSequence(track, animName, anim, sequenceOverride)
        local explicitSequence = sequenceOverride or anim.sequence
        local candidates = {}
        local seen = {}

        local function AddCandidate(sequenceName, reason)
            sequenceName = tostring(sequenceName or "")
            if sequenceName == "" or seen[sequenceName] then return end

            seen[sequenceName] = true
            candidates[#candidates + 1] = {
                name = sequenceName,
                reason = reason
            }
        end

        AddCandidate(animName, "animation name")
        AddCandidate(explicitSequence, "explicit sequence")

        if anim.legacy then
            local lowerAnimName = string.lower(tostring(animName or ""))
            if lowerAnimName ~= tostring(animName or "") then
                AddCandidate(lowerAnimName, "lowercase animation name")
            end

            local modelBaseName = string.GetFileFromFilename(anim.model or "")
            modelBaseName = string.StripExtension(modelBaseName)

            if string.StartsWith(modelBaseName, "c_vmanip") then
                AddCandidate(string.sub(modelBaseName, 9), "model filename")
            end

            if track.model.GetSequenceList then
                local sequenceList = track.model:GetSequenceList() or {}

                local function NormalizeLegacyName(value)
                    value = string.lower(tostring(value or ""))
                    value = string.gsub(value, "^reanim[_%-]?", "")
                    value = string.gsub(value, "^anim[_%-]?", "")
                    value = string.gsub(value, "^gesture[_%-]?", "")
                    value = string.gsub(value, "[_%-%s]+anim$", "")
                    value = string.gsub(value, "[_%-%s]+gesture$", "")
                    value = string.gsub(value, "[_%-%s]+sequence$", "")
                    value = string.gsub(value, "[_%-%s]+seq$", "")
                    value = string.gsub(value, "[^%w]", "")
                    return value
                end

                local function GetLegacyTokens(value)
                    value = tostring(value or "")
                    value = string.gsub(value, "([a-z0-9])([A-Z])", "%1_%2")
                    value = string.lower(value)

                    local tokens = {}
                    for token in string.gmatch(value, "[%w]+") do
                        if token ~= "" then
                            tokens[#tokens + 1] = token
                        end
                    end

                    return tokens
                end

                local ignoredLegacyTokens = {
                    anim = true,
                    animation = true,
                    gesture = true,
                    sequence = true,
                    seq = true,
                    reanim = true,
                    vmanip = true,
                    vm = true,
                    cmt = true
                }

                local function AddTokenSubsequenceTargets(value, addTarget)
                    local tokens = GetLegacyTokens(value)
                    if #tokens == 0 then return end

                    for startIndex = 1, #tokens do
                        for endIndex = #tokens, startIndex, -1 do
                            local subset = {}
                            for tokenIndex = startIndex, endIndex do
                                local token = tokens[tokenIndex]
                                if not ignoredLegacyTokens[token] then
                                    subset[#subset + 1] = token
                                end
                            end

                            if #subset > 0 then
                                addTarget(table.concat(subset, ""))
                            end
                        end
                    end
                end

                local normalizedTargets = {}
                local function AddNormalizedTarget(value)
                    local normalized = NormalizeLegacyName(value)
                    if normalized ~= "" then
                        normalizedTargets[normalized] = true
                    end
                end

                AddNormalizedTarget(animName)
                AddNormalizedTarget(explicitSequence)
                AddTokenSubsequenceTargets(animName, AddNormalizedTarget)
                AddTokenSubsequenceTargets(explicitSequence, AddNormalizedTarget)

                if string.StartsWith(modelBaseName, "c_vmanip") then
                    AddNormalizedTarget(string.sub(modelBaseName, 9))
                end
                AddTokenSubsequenceTargets(modelBaseName, AddNormalizedTarget)

                local normalizedMatches = {}
                local partialNormalizedMatches = {}
                local seenPartialMatches = {}
                for _, sequenceName in ipairs(sequenceList) do
                    local normalizedSequenceName = NormalizeLegacyName(sequenceName)
                    if normalizedTargets[normalizedSequenceName] then
                        normalizedMatches[#normalizedMatches + 1] = sequenceName
                    else
                        for normalizedTarget in pairs(normalizedTargets) do
                            if #normalizedTarget >= 4 and (
                                    string.find(normalizedSequenceName, normalizedTarget, 1, true) or
                                    string.find(normalizedTarget, normalizedSequenceName, 1, true)
                                ) then
                                if not seenPartialMatches[sequenceName] then
                                    partialNormalizedMatches[#partialNormalizedMatches + 1] = sequenceName
                                    seenPartialMatches[sequenceName] = true
                                end
                                break
                            end
                        end
                    end
                end

                if #normalizedMatches == 1 then
                    AddCandidate(normalizedMatches[1], "normalized legacy match")
                elseif #partialNormalizedMatches == 1 then
                    AddCandidate(partialNormalizedMatches[1], "partial normalized legacy match")
                end

                if #sequenceList == 1 then
                    AddCandidate(sequenceList[1], "only model sequence")
                end
            end
        end

        for _, candidate in ipairs(candidates) do
            local seqID = track.model:LookupSequence(candidate.name)
            if seqID ~= -1 then
                if candidate.name ~= animName then
                    GCAL_Log("Sequence resolver: using '" ..
                        tostring(candidate.name) ..
                        "' from " .. tostring(candidate.reason) .. " for '" .. tostring(animName) .. "'.")
                end
                return seqID, candidate.name
            end
        end

        GCAL_Log("Sequence resolution failed for '" .. tostring(animName) .. "'")
        GCAL_Log("  Model: " .. tostring(track.model:GetModel()))
        GCAL_Log("  Tried candidates:")
        for _, candidate in ipairs(candidates) do
            GCAL_Log("    - '" .. candidate.name .. "' from " .. candidate.reason)
        end

        if track.model.GetSequenceList then
            local sequenceList = track.model:GetSequenceList() or {}
            if #sequenceList > 0 then
                GCAL_Log("  Model has " .. #sequenceList .. " sequences:")
                for i, seqName in ipairs(sequenceList) do
                    GCAL_Log("    [" .. i .. "] " .. seqName)
                    for _, candidate in ipairs(candidates) do
                        if string.lower(seqName) == string.lower(candidate.name) then
                            GCAL_Log("  Found case-insensitive match! Using '" .. seqName .. "'")
                            local seqID = track.model:LookupSequence(seqName)
                            if seqID ~= -1 then
                                return seqID, seqName
                            end
                        end
                    end
                end
            else
                GCAL_Log("  WARNING: GetSequenceList() returned 0 sequences!")
                GCAL_Log("  This usually means the model hasn't finished loading.")
            end
        else
            GCAL_Log("  WARNING: Model does not have GetSequenceList() method!")
        end

        return -1, nil
    end

    GetTPIKOptionsForAnim = function(animName)
        return GCAL.GetTPIKOptions and GCAL:GetTPIKOptions(animName) or nil
    end

    GetTPIKSequenceName = function(animName)
        local options = GetTPIKOptionsForAnim(animName)
        if not options then return nil end

        return options.sequence or options.anim or options.animation
    end

    ResolveTPIKSequence = function(track, animName, anim)
        local sequenceName = GetTPIKSequenceName(animName)
        sequenceName = sequenceName and tostring(sequenceName) or ""
        if sequenceName == "" then return track.seqID, track.sequenceName end

        return ResolveSequence(track, sequenceName, anim, sequenceName)
    end

    local function FindLegacySurrogateAnim(name)
        local target = GCAL_NormalizeLegacyCompatName(name)
        if target == "" then return nil end

        local exactMatch
        local partialMatch

        for otherName, otherAnim in pairs(GCAL.Anims or {}) do
            if otherName ~= name and otherAnim and otherAnim.model then
                local normalizedOther = GCAL_NormalizeLegacyCompatName(otherName)
                if normalizedOther ~= "" then
                    if normalizedOther == target then
                        exactMatch = {
                            name = otherName,
                            data = otherAnim
                        }
                        break
                    end

                    if not partialMatch and (
                            (#target >= 4 and string.find(normalizedOther, target, 1, true)) or
                            (#normalizedOther >= 4 and string.find(target, normalizedOther, 1, true))
                        ) then
                        partialMatch = {
                            name = otherName,
                            data = otherAnim
                        }
                    end
                end
            end
        end

        return exactMatch or partialMatch
    end

    local function StartTrackSequence(track)
        track.model:ResetSequenceInfo()
        track.model:SetPlaybackRate(1)
        track.model:ResetSequence(track.seqID)
        track.duration = math.max(track.model:SequenceDuration(track.seqID), 0.01)
        if IsValid(track.camModel) then
            track.camModel:ResetSequenceInfo()
            track.camModel:SetPlaybackRate(1)
            track.camModel:ResetSequence(track.seqID)
        end
    end

    local function TryLegacySurrogate(track, name)
        local surrogate = FindLegacySurrogateAnim(name)
        if not surrogate then return false end

        local surrogateModel = ClientsideModel(NormalizeModelPath(surrogate.data.model), RENDERGROUP_BOTH)
        local surrogateCamModel = nil
        if track.camboneEnabled and GCAL.CamBone:GetBool() then
            surrogateCamModel = ClientsideModel(NormalizeModelPath(surrogate.data.model), RENDERGROUP_BOTH)
        end

        if not IsValid(surrogateModel) then
            if IsValid(surrogateCamModel) then surrogateCamModel:Remove() end
            return false
        end
        surrogateModel:SetNoDraw(true)
        if IsValid(surrogateCamModel) then
            surrogateCamModel:SetNoDraw(true)
            surrogateCamModel:SetPos(vector_origin)
            surrogateCamModel:SetAngles(angle_zero)
        end

        local surrogateTrack = { model = surrogateModel, data = surrogate.data }
        local seqID = ResolveSequence(surrogateTrack, surrogate.name, surrogate.data)
        if seqID == -1 then
            if IsValid(surrogateModel) then surrogateModel:Remove() end
            if IsValid(surrogateCamModel) then surrogateCamModel:Remove() end
            return false
        end

        if IsValid(track.model) then track.model:Remove() end
        if IsValid(track.camModel) then track.camModel:Remove() end
        track.model = surrogateModel
        track.camModel = surrogateCamModel
        track.seqID = seqID
        track.sequenceName = surrogate.data.sequence or surrogate.name

        StartTrackSequence(track)
        GCAL_Log("Legacy fallback: using surrogate animation '" .. tostring(surrogate.name) ..
            "' for '" .. tostring(name) .. "'.")
        return true
    end

    local function UsePoseOnlyLegacy(track, name, anim)
        track.poseOnlyLegacy = true
        track.duration = math.max(anim.duration or anim.holdtime or anim.lerp_peak or 1, 0.01)
        GCAL_Log("Legacy fallback: using pose-only mode for '" .. tostring(name) ..
            "' because the model reported zero sequences.")
    end

    local function ResolveFirstPersonSequence(track, name, anim)
        local sequenceList = track.model.GetSequenceList and (track.model:GetSequenceList() or {}) or {}
        track.seqID, track.sequenceName = ResolveSequence(track, name, anim)

        if track.seqID ~= -1 then
            StartTrackSequence(track)
            return
        end

        if anim.legacy and #sequenceList == 0 then
            if TryLegacySurrogate(track, name) then return end
            UsePoseOnlyLegacy(track, name, anim)
            return
        end

        GCAL_Log("Failed: Sequence not found in model!")
        track.model:Remove()
        if IsValid(track.camModel) then track.camModel:Remove() end
        error("GCAL_Play_NoSequence", 0) -- GCAL:Play matches this exact string
    end

    local function SetupThirdPerson(track, name, anim)
        track.tpikSeqID, track.tpikSequenceName = ResolveTPIKSequence(track, name, anim)
        if track.tpikSeqID == -1 then
            GCAL_Log("TPIK sequence not found, falling back to firstperson sequence for:", name)
            track.tpikSeqID = track.seqID
            track.tpikSequenceName = track.sequenceName
        end

        if not track.thirdperson then return end

        if track.tpikSeqID ~= track.seqID or track.tpikSequenceRequested then
            track.tpikModel = CreateTrackModelCopy(track, track.tpikSeqID)
            if track.tpikModel then track.tpikModel:SetCycle(track.cycle) end
        end

        track.thirdpersonModel = CreateTrackModelCopy(track, track.tpikSeqID or track.seqID)
    end

    local function EmitTrackSound(ply, track, soundPath)
        ply:EmitSound(soundPath, track.soundLevel or 75, GCAL.SoundPitch:GetInt(), track.soundVolume or 1, CHAN_AUTO,
            track.soundFlags or 0)
    end

    local function HandleSounds(track)
        if track.soundsDone or GCAL.MuteSounds:GetBool() then return end
        local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
        local sounds = track.data.sounds
        local played = track.soundsPlayed

        if not sounds or next(sounds) == nil then
            if overridePath then
                local ply = LocalPlayer()
                if IsValid(ply) then
                    EmitTrackSound(ply, track, overridePath)
                end
            end
            track.soundsDone = true
            return
        end

        local elapsed = CurTime() - track.startTime
        local pending = false
        for soundPath, time in pairs(sounds) do
            if not played[soundPath] then
                if elapsed >= time then
                    local ply = LocalPlayer()
                    if IsValid(ply) then
                        EmitTrackSound(ply, track, overridePath or soundPath)
                    end
                    played[soundPath] = true
                else
                    pending = true
                end
            end
        end
        if not pending then track.soundsDone = true end
    end

    local function LegacyAnimAllowed(name, trackID, anim)
        if not anim.legacy then return true end

        vmatrixpeakinfo = anim.lerp_peak or 0.5
        VManip_modelname = anim.model
        vmanipholdtime = anim.holdtime or 0

        local ply = LocalPlayer()
        if not IsValid(ply) or ply:InVehicle() or not ply:Alive() then return false end
        if ply:GetViewEntity() ~= ply and not GCAL.ActiveTracks[trackID] then return false end

        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return false end
        if weapon:GetHoldType() == "duel" then return false end
        if GCAL.ActiveTracks[trackID] then return false end

        local vm = ply:GetViewModel()
        local bypass = hook.Run("VManipPreActCheck", name, vm)
        if bypass or not IsValid(vm) then return true end

        if type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return false end
        local cycle = math.Round(vm:GetCycle(), 2)
        if vm:GetSequenceActivity(vm:GetSequence()) == ACT_VM_RELOAD and (cycle < 0.99 and cycle > 0) then
            return false
        end
        return true
    end

    local function ParsePlayArgs(arg1, arg2)
        if isstring(arg1) then return arg1, arg2 end
        return arg2, nil
    end

    function GCAL:Play(arg1, arg2)
        local name, trackID = ParsePlayArgs(arg1, arg2)
        GCAL_Log("Attempting to play:", name)

        if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then
            GCAL_Log("Suppressed: Animation '" .. tostring(name) .. "' is disabled in the GCAL menu.")
            hook.Run("GCALAnimSuppressed", name, trackID)
            return true
        end

        local anim = GCAL.Anims[name]
        if not anim then
            GCAL_Log("Failed: Animation '" .. tostring(name) .. "' not found in registry!")
            return false
        end
        if not anim.model then
            GCAL_Log("Failed: Animation '" .. tostring(name) .. "' has no model set!")
            return false
        end

        trackID = trackID or anim.group_name or "default"

        if not LegacyAnimAllowed(name, trackID, anim) then return false end
        if hook.Run("VManipPrePlayAnim", name) == false then return false end

        local existingTrack = GCAL.ActiveTracks[trackID]
        if existingTrack and not existingTrack.canInterrupt then
            GCAL_Log("Cannot interrupt current animation on track '" .. tostring(trackID) .. "', queueing instead")
            self:QueueAnim(name, trackID)
            return true
        end

        local track = CreateTrack(name, anim)
        if not SetupSourceModels(track, anim) then
            if IsValid(track.camModel) then track.camModel:Remove() end
            return false
        end

        local ok, err = pcall(ResolveFirstPersonSequence, track, name, anim)
        if not ok then
            if err == "GCAL_Play_NoSequence" then return false end
            if IsValid(track.model) then track.model:Remove() end
            if IsValid(track.camModel) then track.camModel:Remove() end
            error(err, 0)
        end

        SetupThirdPerson(track, name, anim)

        if GCAL.ActiveTracks[trackID] then
            local oldTrack = GCAL.ActiveTracks[trackID]
            if oldTrack.onInterruptCallback and isfunction(oldTrack.onInterruptCallback) then
                pcall(oldTrack.onInterruptCallback, trackID, oldTrack.name, name)
            end
            GCAL:StopTrack(trackID)
        end

        GCAL.ActiveTracks[trackID] = track

        if trackID == "legacy_left_arm" then SyncLegacyVManipFields(track) end
        if track.blockCode then
            hook.Run("GCALCodeBlockStarted", trackID, name, track, track.blockCodeScope)
        end

        if track.onStartCallback and isfunction(track.onStartCallback) then
            pcall(track.onStartCallback, trackID, name, track)
        end

        hook.Run("GCALTrackStarted", trackID, name, track)
        GCAL_Log("Started playback successfully! Track:", trackID)
        return true
    end

    function GCAL:StopTrack(trackID)
        local track = GCAL.ActiveTracks[trackID]
        if track then
            GCAL_Log("Stopping track:", trackID)
            if IsValid(track.model) then track.model:Remove() end
            if IsValid(track.camModel) then track.camModel:Remove() end
            if IsValid(track.tpikModel) then track.tpikModel:Remove() end
            if IsValid(track.thirdpersonModel) then track.thirdpersonModel:Remove() end
            if IsValid(track.legModel) then track.legModel:Remove() end
            if trackID == "legacy_left_arm" then
                posparentcache = nil
                vmatrixpeakinfo = vmatrixpeakinfo or 0
                VManip_modelname = VManip_modelname or ""
                vmanipholdtime = vmanipholdtime or 0
                SyncLegacyVManipFields(nil)
            end
            GCAL.ActiveTracks[trackID] = nil
            if track.blockCode then
                hook.Run("GCALCodeBlockStopped", trackID, track.name, track, track.blockCodeScope)
            end
            hook.Run("GCALTrackStopped", trackID, track.name, track)
            if trackID == "legacy_left_arm" then
                hook.Run("VManipRemove")
            end
        end
    end

    function GCAL:QuitHolding(trackID, animToStop)
        local track = self:GetTrack(trackID)
        if not track then return false end
        if hook.Run("GCALPreHoldQuit", trackID, track.name, animToStop) == false then return false end

        if (not animToStop and not track.preventQuit) or track.name == animToStop then
            track.holdQuit = true
            if track.segmented then track.lastSegment = true end
            hook.Run("GCALHoldQuit", trackID, track.name, animToStop)
            return true
        end

        return false
    end

    function GCAL:QueueAnim(name, trackID)
        local anim = self:GetAnim(name)
        if not anim then return false end

        trackID = trackID or anim.group_name or "default"
        self.QueuedAnims[trackID] = name
        return true
    end

    function GCAL:PlaySegment(trackID, sequence, lastSegment, soundTable)
        local track = self:GetTrack(trackID)
        if not track then return false end
        if not track.segmented or not track.segmentFinished or track.lastSegment then return false end
        if not IsValid(track.model) or track.model:LookupSequence(sequence) == -1 then return false end
        if hook.Run("GCALPrePlaySegment", trackID, track.name, sequence, lastSegment) == false then return false end

        local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
        track.model:ResetSequence(sequence)
        track.model:SetPlaybackRate(speedMultiplier)
        if IsValid(track.camModel) then
            track.camModel:ResetSequence(sequence)
            track.camModel:SetPlaybackRate(speedMultiplier)
        end
        if IsValid(track.tpikModel) and track.tpikSeqID and track.tpikSeqID ~= -1 then
            track.tpikModel:ResetSequence(track.tpikSeqID)
            track.tpikModel:SetPlaybackRate(speedMultiplier)
        end
        local thirdPersonSequence = track.tpikSequenceRequested and track.tpikSeqID or sequence
        if IsValid(track.thirdpersonModel) then
            track.thirdpersonModel:ResetSequence(thirdPersonSequence)
            track.thirdpersonModel:SetPlaybackRate(speedMultiplier)
        end
        track.curSegment = sequence
        track.cycle = 0
        track.segmentFinished = false
        track.segmentCount = track.segmentCount + 1
        if lastSegment then
            track.lastSegment = true
            track.lerpPeakTime = CurTime() + track.lerpPeak
        end

        if soundTable then
            for soundPath, time in pairs(soundTable) do
                timer.Simple(time, function()
                    if self:GetCurrentAnim(trackID) == track.name and IsValid(LocalPlayer())
                        and LocalPlayer():Alive() then
                        if not GCAL.MuteSounds:GetBool() then
                            local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
                            EmitTrackSound(LocalPlayer(), track, overridePath or soundPath)
                        end
                    end
                end)
            end
        end

        hook.Run("GCALPlaySegment", trackID, track.name, sequence, lastSegment)
        return true
    end

    SyncLegacyVManipFields = function(track)
        if not VManip then return end
        if track then
            VManip.VMGesture = track.model
            VManip.VMCam = track.camModel
            VManip.AssurePos = track.data.assurepos or false
            VManip.LockToPly = track.data.locktoply or false
            VManip.LockZ = track.lockZ or 0
            VManip.Cam_Ang = track.camAng
            VManip.Cam_AngInt = track.camAngInt
            VManip.StartCycle = track.data.startcycle or 0
            VManip.CurGesture = track.name
            VManip.CurGestureData = track.data
            VManip.VMatrixlerp = track.lerpVal or 1
            VManip.Cycle = track.cycle or 0
            VManip.Speed = track.speed or 1
            VManip.Lerp_Peak = track.lerpPeakTime or 0
            VManip.Lerp_Speed_In = track.lerpSpeedIn or 1
            VManip.Lerp_Speed_Out = track.lerpSpeedOut or 1
            VManip.Lerp_Curve = track.lerpCurve or 1
            VManip.Duration = track.duration or 0
            VManip.Loop = track.loop or false
            VManip.HoldTime = track.holdTime
            VManip.HoldTimeData = track.holdTimeData
            VManip.HoldQuit = track.holdQuit or false
            VManip.GestureOnHold = track.gestureOnHold or false
            VManip.GesturePastHold = track.gesturePastHold or false
            VManip.BlockCode = track.blockCode or false
            VManip.BlockCodeScope = track.blockCodeScope
            VManip.PreventQuit = track.preventQuit or false
            VManip.Segmented = track.segmented or false
            VManip.SegmentFinished = track.segmentFinished or false
            VManip.CurSegment = track.curSegment
            VManip.LastSegment = track.lastSegment or false
            VManip.SegmentCount = track.segmentCount or 0
            VManip.Attachment = track.attachment
        else
            VManip.VMGesture = nil
            VManip.VMCam = nil
            VManip.AssurePos = false
            VManip.LockToPly = false
            VManip.LockZ = 0
            VManip.Cam_Ang = DEFAULT_CAM_ANG
            VManip.Cam_AngInt = nil
            VManip.StartCycle = 0
            VManip.CurGesture = nil
            VManip.CurGestureData = nil
            VManip.VMatrixlerp = 1
            VManip.Cycle = 0
            VManip.Speed = nil
            VManip.Lerp_Peak = 0
            VManip.Lerp_Speed_In = nil
            VManip.Lerp_Speed_Out = nil
            VManip.Lerp_Curve = nil
            VManip.Duration = 0
            VManip.Loop = nil
            VManip.HoldTime = nil
            VManip.HoldTimeData = nil
            VManip.HoldQuit = false
            VManip.GestureOnHold = false
            VManip.GesturePastHold = false
            VManip.BlockCode = false
            VManip.BlockCodeScope = nil
            VManip.PreventQuit = false
            VManip.Segmented = false
            VManip.SegmentFinished = false
            VManip.CurSegment = nil
            VManip.LastSegment = false
            VManip.SegmentCount = 0
            VManip.Attachment = nil
        end
    end

    local function AdvanceTrackTiming(track, now, dt)
        local looped = false
        if track.loop then
            if track.cycle >= 1 then
                track.lerpPeakTime = now + track.lerpPeak
                track.cycle = 0
                looped = true
            end
            if track.holdQuit then track.loop = false end
        end

        if track.holdTime then
            if now >= track.holdTime and not track.gestureOnHold and not track.gesturePastHold
                and not track.holdQuit then
                track.gestureOnHold = true
            elseif track.holdQuit and track.gestureOnHold then
                track.gestureOnHold = false
                track.gesturePastHold = true
                track.lerpPeakTime = now + track.lerpPeak - (track.holdTimeData or 0)
            end
        end

        local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
        if not track.gestureOnHold then
            track.cycle = track.cycle + dt * speedMultiplier
        end

        if not track.poseOnlyLegacy then
            if IsValid(track.model) then
                track.model:SetCycle(track.cycle)
                track.model:InvalidateBoneCache()
            end
            if IsValid(track.camModel) then
                track.camModel:SetCycle(track.cycle)
                track.camModel:InvalidateBoneCache()
            end
            if IsValid(track.tpikModel) then
                track.tpikModel:SetPlaybackRate(speedMultiplier)
                track.tpikModel:SetCycle(track.cycle)
                track.tpikModel:InvalidateBoneCache()
            end
            if IsValid(track.thirdpersonModel) then
                track.thirdpersonModel:SetPlaybackRate(speedMultiplier)
                track.thirdpersonModel:SetCycle(track.cycle)
                track.thirdpersonModel:InvalidateBoneCache()
            end
        end

        local notHeld = not track.gestureOnHold or track.gesturePastHold
        if (now < track.lerpPeakTime or (track.segmented and not track.lastSegment)) and notHeld then
            track.lerpVal = math.Clamp(track.lerpVal - (dt * 7) * track.lerpSpeedIn, 0, 1)
        elseif not track.loop and notHeld and (not track.segmented or track.lastSegment) then
            track.lerpVal = math.Clamp(track.lerpVal + (dt * 7) * track.lerpSpeedOut, 0, 1)
        end

        return looped
    end

    local function FinishTrack(track, trackID)
        if track.onFinishCallback and isfunction(track.onFinishCallback) then
            pcall(track.onFinishCallback, trackID, track.name, track)
        end
        GCAL:StopTrack(trackID)
    end

    local function UpdateTrack(track, trackID)
        curtime = CurTime()

        HandleSounds(track)

        if AdvanceTrackTiming(track, curtime, FrameTime()) then
            track.startTime = curtime
            table.Empty(track.soundsPlayed)
            track.soundsDone = nil
        end

        if trackID == "legacy_left_arm" then
            if track.lastLerpVal == 1 and track.lerpVal < 1 and not track.legacyStarted then
                track.legacyStarted = true
                hook.Run("VManipPostPlayAnim", track.name)
            end
        end

        if track.cycle >= 1 and not track.loop then
            if track.segmented and not track.segmentFinished then
                track.segmentFinished = true
                hook.Run("GCALSegmentFinish", trackID, track.name, track.curSegment, track.lastSegment,
                    track.segmentCount)
                hook.Run("VManipSegmentFinish", track.name, track.curSegment, track.lastSegment, track.segmentCount)
            elseif track.segmented and track.lastSegment then
                if track.lerpVal >= 1 then
                    FinishTrack(track, trackID)
                    return true
                end
            elseif not track.segmented then
                FinishTrack(track, trackID)
                return true
            end
        end

        if trackID == "legacy_left_arm" then
            SyncLegacyVManipFields(track)
        end

        track.lastLerpVal = track.lerpVal

        return false
    end

    local flipState = {
        lefty = false,
        flippedNow = false,
        flipmode = false,
        targetRight = false,
        targetBones = nil,
        targetSide = "left_arm"
    }
    local function GetLegacyFlipState(weapon)
        local validWeapon = IsValid(weapon)
        local isScripted = validWeapon and weapon.IsScripted and weapon:IsScripted() or false
        local lefty = isScripted and tobool(weapon.ViewModelFlipDefault) or false
        local flippedNow = validWeapon and tobool(weapon.ViewModelFlip) or false
        local flipmode = validWeapon and lefty ~= flippedNow or false
        flipState.lefty = lefty
        flipState.flippedNow = flippedNow
        flipState.flipmode = flipmode
        flipState.targetRight = lefty
        flipState.targetBones = lefty and GCAL.GROUPS.RIGHT_ARM or GCAL.GROUPS.LEFT_ARM
        flipState.targetSide = lefty and "right_arm" or "left_arm"
        return flipState
    end

    local function TrackUsesLegacyFlip(track)
        return track and track.data and track.data.legacy
    end

    local function GetTrackTargetBones(track, weapon, flip)
        if TrackUsesLegacyFlip(track) then return flip.targetBones end

        return track.bones
    end

    local function GetTrackSourceAngleOffset(track, weapon, flip)
        if TrackUsesLegacyFlip(track) and flip.flipmode then return angleFlip end

        return angleZero
    end

    local function GetTrackModelScale(track, weapon, flip)
        if TrackUsesLegacyFlip(track) and flip.flipmode then return -1 end

        return 1
    end

    local function PlaceTrackModel(track, pos, ang)
        local adjustedPos, adjustedAng = GCAL:ApplyAnimationAdjustment(track.name, pos, ang)
        track.model:SetAngles(adjustedAng)
        track.model:SetPos(adjustedPos)
    end

    local function PlaceTPIKTrackModel(track, pos, ang)
        local sourceModel = IsValid(track.tpikModel) and track.tpikModel or track.model
        if not IsValid(sourceModel) then return end
        sourceModel:SetAngles(ang)
        sourceModel:SetPos(pos)
    end

    local function DrawGShaderFriendlyModel(model, flags)
        if not IsValid(model) then return end

        model:DrawModel(flags)
    end

    local boneCaches = setmetatable({}, { __mode = "k" })
    local function BoneCache(ent)
        local model = ent:GetModel() or ""
        local cache = boneCaches[ent]
        if not cache or cache.__model ~= model then
            cache = { __model = model }
            boneCaches[ent] = cache
        end
        return cache
    end

    local function CachedBone(cache, ent, name)
        local idx = cache[name]
        if idx == nil then
            idx = ent:LookupBone(name) or -1
            cache[name] = idx
        end
        return idx
    end

    -- Writes into m; callers pass the fresh copy GetBoneMatrix returns.
    local LerpMatrixInto
    if isfunction(FindMetaTable("VMatrix").Unpack) and isfunction(FindMetaTable("VMatrix").SetUnpacked) then
        LerpMatrixInto = function(m, target, f)
            local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16 = m:Unpack()
            local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16 = target:Unpack()
            m:SetUnpacked(
                a1 + (b1 - a1) * f, a2 + (b2 - a2) * f, a3 + (b3 - a3) * f, a4 + (b4 - a4) * f,
                a5 + (b5 - a5) * f, a6 + (b6 - a6) * f, a7 + (b7 - a7) * f, a8 + (b8 - a8) * f,
                a9 + (b9 - a9) * f, a10 + (b10 - a10) * f, a11 + (b11 - a11) * f, a12 + (b12 - a12) * f,
                a13 + (b13 - a13) * f, a14 + (b14 - a14) * f, a15 + (b15 - a15) * f, a16 + (b16 - a16) * f)
            return m
        end
    else
        LerpMatrixInto = function(m, target, f)
            local mt, tt = m:ToTable(), target:ToTable()
            for i = 1, 4 do
                local mi, ti = mt[i], tt[i]
                for j = 1, 4 do mi[j] = mi[j] + (ti[j] - mi[j]) * f end
            end
            return Matrix(mt)
        end
    end

    local ULNA_L = "ValveBiped.Bip01_L_Ulna"
    local FOREARM_L = "ValveBiped.Bip01_L_Forearm"

    local function IsBlendingIn(track)
        return (CurTime() < (track.lerpPeakTime or 0) or (track.segmented and not track.lastSegment))
            and (not track.gestureOnHold or track.gesturePastHold)
    end

    local function GetTrackBlendFactor(track, t, curve)
        local fn = track.easingIn
        if fn ~= track.easingOut and not IsBlendingIn(track) then
            fn = track.easingOut
        end
        local factor
        if fn then
            factor = fn(t, 0, 1, 1)
        else
            factor = GCAL.Lerp.Legacy(t, 0, 1, curve or 1)
        end

        local weight = tonumber(track.blendWeight)
        if weight then
            factor = 1 - (1 - factor) * math.Clamp(weight, 0, 1)
        end
        return factor
    end
    GCAL.GetTrackBlendFactor = GetTrackBlendFactor

    include("gcal/gcal_tpik.lua")
    local tpik = GCAL.InstallTPIK({
        GetTrackBlendFactor = GetTrackBlendFactor,
        PlaceTrackModel = PlaceTrackModel,
        PlaceTPIKTrackModel = PlaceTPIKTrackModel,
        GetLegacyFlipState = GetLegacyFlipState,
        GetTrackTargetBones = GetTrackTargetBones,
        GetTrackModelScale = GetTrackModelScale,
        BoneCache = BoneCache,
        CachedBone = CachedBone
    })
    local ApplyCachedThirdPersonBones = tpik.ApplyCachedThirdPersonBones
    local ApplyThirdPersonBones = tpik.ApplyThirdPersonBones
    GCAL.MPInternal = {
        CreateTrack = CreateTrack,
        SetupSourceModels = SetupSourceModels,
        ResolveFirstPersonSequence = ResolveFirstPersonSequence,
        SetupThirdPerson = SetupThirdPerson,
        AdvanceTrackTiming = AdvanceTrackTiming,
        ApplyThirdPersonBones = ApplyThirdPersonBones,
        ApplyCachedThirdPersonBones = ApplyCachedThirdPersonBones
    }

    GCAL.WeaponBaseStrategies = GCAL.WeaponBaseStrategies or {}

    local function EntityHasAnyBone(ent, bones)
        if not IsValid(ent) or not bones then return false end

        local cache = BoneCache(ent)
        for _, boneName in ipairs(bones) do
            if CachedBone(cache, ent, boneName) >= 0 then return true end
        end

        return false
    end

    local STRATEGY_CACHE_SECONDS = 0.5
    local strategyCache = setmetatable({}, { __mode = "k" })

    function GCAL:RegisterWeaponBaseStrategy(id, strategy)
        if not id or not strategy or not isfunction(strategy.detect) then return false end

        strategy.id = id
        strategyCache = setmetatable({}, { __mode = "k" })
        for k, existing in ipairs(self.WeaponBaseStrategies) do
            if existing.id == id then
                self.WeaponBaseStrategies[k] = strategy
                return true
            end
        end

        self.WeaponBaseStrategies[#self.WeaponBaseStrategies + 1] = strategy
        return true
    end

    function GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not IsValid(weapon) then return nil end

        local now = RealTime()
        local cached = strategyCache[weapon]
        if cached and cached.ply == ply and now < cached.expires then
            return cached.strategy or nil
        end

        local found = false
        for _, strategy in ipairs(self.WeaponBaseStrategies or {}) do
            if strategy.detect(ply, weapon) then
                found = strategy
                break
            end
        end

        strategyCache[weapon] = { ply = ply, strategy = found, expires = now + STRATEGY_CACHE_SECONDS }
        return found or nil
    end

    function GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy)
        strategy = strategy or self:GetWeaponBaseStrategy(ply, weapon)
        if strategy and strategy.thirdPersonMethod then
            local method = strategy.thirdPersonMethod(ply, weapon, strategy)
            if method then return method end
        end

        return "normal"
    end

    function GCAL:FindArmTarget(vm, handsEnt, targetBones)
        if EntityHasAnyBone(vm, targetBones) then return vm end
        if EntityHasAnyBone(handsEnt, targetBones) then return handsEnt end

        return vm
    end

    local OWN_VM_ENTITY_HOOK = "GCAL_Compat_StrategyVMEntity"
    local function HasForeignVMEntityListener()
        if GAMEMODE and GAMEMODE.VManipVMEntity then return true end
        local listeners = hook.GetTable and hook.GetTable().VManipVMEntity
        if not listeners then return false end
        for name in pairs(listeners) do
            if name ~= OWN_VM_ENTITY_HOOK then return true end
        end
        return false
    end

    function GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        local strategy = self:GetWeaponBaseStrategy(ply, weapon)
        local context = {
            strategy = strategy,
            strategy_id = strategy and strategy.id or "normal",
            ply = ply,
            weapon = weapon,
            vm = vm,
            handsEnt = handsEnt
        }

        if strategy and strategy.resolveViewModel then
            local resolved = strategy.resolveViewModel(ply, weapon, vm, handsEnt, context)
            if IsValid(resolved) then context.vm = resolved end
        elseif HasForeignVMEntityListener() then
            local resolved = hook.Run("VManipVMEntity", ply, weapon)
            if IsValid(resolved) then
                context.strategy_id = "hook"
                context.vm = resolved
            end
        end

        return context
    end

    function GCAL:ResolveArmTarget(context, targetBones)
        if not context then return nil end

        local strategy = context.strategy
        if strategy and strategy.resolveArmTarget then
            local target = strategy.resolveArmTarget(context.ply, context.weapon, context.vm, context.handsEnt,
                targetBones, context)
            if IsValid(target) then return target end
        end

        return self:FindArmTarget(context.vm, context.handsEnt, targetBones)
    end

    local function ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags, renderContext, skipVMSetup)
        if not IsValid(track.model) or not IsValid(vm) then return end
        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        local flip = GetLegacyFlipState(weapon)
        local flipmode = flip.flipmode
        local flipped = (track.lerpVal <= 0.5 and scaleflipvec or scalevec)
        local sourceAngleOffset = GetTrackSourceAngleOffset(track, weapon, flip)

        if track.data.assurepos then
            if posparentcache ~= weapon then
                posparentcache = weapon
                track.model:SetParent(nil)
                PlaceTrackModel(track, EyePos(), vm:GetAngles() + sourceAngleOffset)
                track.model:SetParent(vm)
            end
        end

        if track.data.locktoply then
            local eyeang = ply:EyeAngles()
            local eyepos = EyePos()
            local vmang = vm:GetAngles()
            local finang = eyeang - vmang
            finang.y = 0
            local newang = eyeang + (finang * 0.25)
            PlaceTrackModel(track, eyepos, newang + sourceAngleOffset)
        elseif not track.data.assurepos then
            local eyeang, eyepos = EyeAngles(), EyePos()
            PlaceTrackModel(track, eyepos, eyeang + sourceAngleOffset)
        end

        if not skipVMSetup then
            vm:SetupBones()
            if IsValid(handsEnt) then
                handsEnt:SetupBones()
            end
        end

        track.model:SetModelScale(GetTrackModelScale(track, weapon, flip))
        track.model:SetupBones()
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        DrawGShaderFriendlyModel(track.model, flags)
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local rigpick = GCAL.GROUPS.LEFT_ARM
        local targetRig = flip.targetBones
        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetRig)
        if not IsValid(targetEnt) then return end
        if not skipVMSetup or (targetEnt ~= vm and targetEnt ~= handsEnt) then
            targetEnt:SetupBones()
        end

        local boneCount = 0
        local factor = (track.lerpVal or 1) ^ (track.lerpCurve or 1)
        local scaleVec = flip.targetRight and flipped or scalevec
        local sourceCache, targetCache = BoneCache(track.model), BoneCache(targetEnt)

        for k, boneName in ipairs(rigpick) do
            local sourceBoneName = boneName == ULNA_L and FOREARM_L or boneName
            local sourceBone = CachedBone(sourceCache, track.model, sourceBoneName)
            if sourceBone < 0 then continue end

            local targetBone = CachedBone(targetCache, targetEnt, targetRig[k] or boneName)
            if targetBone < 0 then continue end

            local gestureMatrix = track.model:GetBoneMatrix(sourceBone)
            if not gestureMatrix then continue end

            local m
            if factor == 0 then
                m = gestureMatrix
            else
                local targetBoneMatrix = targetEnt:GetBoneMatrix(targetBone)
                if not targetBoneMatrix then continue end
                m = LerpMatrixInto(gestureMatrix, targetBoneMatrix, factor)
            end

            m:SetScale(scaleVec)
            targetEnt:SetBoneMatrix(targetBone, m)
            boneCount = boneCount + 1
        end

        if IsValid(handsEnt) and handsEnt ~= targetEnt then
            handsEnt:InvalidateBoneCache()
        end
        track.debugTargetEntity = targetEnt
        track.debugBoneCount = boneCount
    end

    local function ApplyBones(track, vm, handsEnt, ply, weapon, thirdperson, suppressSourceDraw, flags, renderContext,
                              skipVMSetup)
        if not IsValid(vm) or not track.bones then return end
        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        if thirdperson then
            ApplyThirdPersonBones(track, vm, weapon, renderContext and renderContext.thirdpersonBaseMatrices)
            return
        end

        if not skipVMSetup then
            vm:SetupBones()
            if IsValid(handsEnt) and handsEnt ~= vm then
                handsEnt:SetupBones()
            end
        end

        local flip = GetLegacyFlipState(weapon)
        local useLegacyFlip = TrackUsesLegacyFlip(track)
        local flipmode = useLegacyFlip and flip.flipmode or false
        local sourceAngleOffset = GetTrackSourceAngleOffset(track, weapon, flip)
        local eyeang, eyepos = EyeAngles(), EyePos()
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetBones)
        if not IsValid(targetEnt) then return end
        if not skipVMSetup or (targetEnt ~= vm and targetEnt ~= handsEnt) then
            targetEnt:SetupBones()
        end

        if track.data.legacy or track.data.locktoply or track.data.assurepos then
            PlaceTrackModel(track, eyepos, eyeang + sourceAngleOffset)
        else
            PlaceTrackModel(track, vm:GetPos(), vm:GetAngles() + sourceAngleOffset)
        end

        track.model:SetModelScale(GetTrackModelScale(track, weapon, flip))
        track.model:SetupBones()
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        if not suppressSourceDraw then
            DrawGShaderFriendlyModel(track.model, flags)
        end
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local boneCount = 0
        local lerpVal = track.lerpVal
        local blendFactor = GetTrackBlendFactor(track, lerpVal, track.lerpCurve or 1)
        local scaleVec = useLegacyFlip and flip.targetRight and lerpVal <= 0.5 and scaleflipvec or scalevec
        local sourceBones = track.sourceBones
        local sourceCache, targetCache = BoneCache(track.model), BoneCache(targetEnt)

        for k, boneName in ipairs(track.bones) do
            local sourceBoneName = sourceBones and sourceBones[k] or boneName
            if sourceBoneName == ULNA_L then sourceBoneName = FOREARM_L end
            local modelBone = CachedBone(sourceCache, track.model, sourceBoneName)
            if modelBone < 0 then continue end

            local targetBone = CachedBone(targetCache, targetEnt, targetBones[k] or boneName)
            if targetBone < 0 then continue end

            local modelMatrix = track.model:GetBoneMatrix(modelBone)
            if not modelMatrix then continue end

            local m
            -- Exactly 0, not <= 0: OutElastic overshoot gives negative factors that must still lerp.
            if blendFactor == 0 then
                m = modelMatrix
            elseif blendFactor == 1 then
                m = targetEnt:GetBoneMatrix(targetBone)
                if not m then continue end
            else
                local targetMatrix = targetEnt:GetBoneMatrix(targetBone)
                if not targetMatrix then continue end
                m = LerpMatrixInto(modelMatrix, targetMatrix, blendFactor)
            end

            m:SetScale(scaleVec)
            targetEnt:SetBoneMatrix(targetBone, m)
            boneCount = boneCount + 1
        end

        if IsValid(handsEnt) and handsEnt ~= targetEnt then
            handsEnt:InvalidateBoneCache()
        end
        track.debugTargetEntity = targetEnt
        track.debugBoneCount = boneCount
    end

    local gunBoneCache = setmetatable({}, { __mode = "k" })
    local function GetGunBoneCache(ent)
        local model = ent:GetModel() or ""
        local cache = gunBoneCache[ent]
        if not cache or cache.model ~= model then
            cache = { model = model, children = {}, isArm = {} }
            gunBoneCache[ent] = cache
        end
        return cache
    end

    local function GetGunChildBones(ent, bone)
        local cache = GetGunBoneCache(ent)
        local children = cache.children[bone]
        if not children then
            children = ent:GetChildBones(bone) or {}
            cache.children[bone] = children
        end
        return children
    end

    local function IsArmBone(ent, bone)
        local cache = GetGunBoneCache(ent)
        local isArm = cache.isArm[bone]
        if isArm == nil then
            local name = ent:GetBoneName(bone)
            isArm = not name or name == "__INVALIDBONE__" or string.find(name, "Bip01", 1, true) ~= nil
            cache.isArm[bone] = isArm
        end
        return isArm
    end

    local gunBoneCandidates = {
        "ValveBiped.weapon_bone", "weapon_bone", "Weapon", "weapon", "tag_weapon", "j_gun", "v_weapon"
    }

    local function ResolveGunMode(track)
        return track.gunMode
    end

    function GCAL:GetGunMode(trackID)
        local track = self:GetTrack(trackID)
        return track and ResolveGunMode(track) or nil
    end

    local function GetGunBonePairs(track)
        if track.gunBonePairs then return track.gunBonePairs end

        local out = {}
        local bones = track.gunBones
        if isstring(bones) then
            out[1] = { bones, bones }
        elseif istable(bones) then
            for key, value in pairs(bones) do
                if isnumber(key) then
                    out[#out + 1] = { tostring(value), tostring(value) }
                else
                    out[#out + 1] = { tostring(key), tostring(value) }
                end
            end
        else
            for _, name in ipairs(gunBoneCandidates) do
                out[#out + 1] = { name, name, true }
            end
        end

        track.gunBonePairs = out
        return out
    end

    local function BlendGunMatrix(sourceMatrix, targetMatrix, blendFactor)
        local m = blendFactor == 0 and sourceMatrix or LerpMatrixInto(sourceMatrix, targetMatrix, blendFactor)
        m:SetScale(scalevec)
        return m
    end

    local function GunDelta(oldMatrix, newMatrix)
        local inverse = oldMatrix:GetInverse()
        if not inverse then return nil end
        return newMatrix * inverse
    end

    local function CarryGunChildren(ent, parentBone, parentOld, parentNew, solved, out)
        local delta
        local moved = 0
        for _, child in ipairs(GetGunChildBones(ent, parentBone)) do
            if not solved[child] then
                if delta == nil then
                    delta = GunDelta(parentOld, parentNew) or false
                end
                if not delta then return moved end
                local childOld = ent:GetBoneMatrix(child)
                if childOld then
                    local childNew = delta * childOld
                    solved[child] = true
                    if not IsArmBone(ent, child) then
                        out[child] = childNew
                        moved = moved + 1
                    end
                    moved = moved + CarryGunChildren(ent, child, childOld, childNew, solved, out)
                end
            end
        end
        return moved
    end

    local function ApplyGunBones(track, vm, weapon, renderContext, mode)
        if not IsValid(track.model) or not track.bones or not track.data then return end
        if TrackUsesLegacyFlip(track) then return end

        local flip = GetLegacyFlipState(weapon)
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetBones)
        if not IsValid(targetEnt) then return end
        if targetEnt ~= vm then targetEnt:SetupBones() end

        if track.data.locktoply or track.data.assurepos then
            PlaceTrackModel(track, EyePos(), EyeAngles())
        else
            PlaceTrackModel(track, vm:GetPos(), vm:GetAngles())
        end
        track.model:SetModelScale(1)
        track.model:SetupBones()

        local blendFactor = GetTrackBlendFactor(track, track.lerpVal or 1, track.lerpCurve or 1)

        local roots = {}
        local solved = { [targetEnt] = {} }
        local rightHandOld, rightHandNew
        local sourceCache, targetCache = BoneCache(track.model), BoneCache(targetEnt)
        for k, boneName in ipairs(track.bones) do
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            if sourceBoneName == ULNA_L then sourceBoneName = FOREARM_L end
            local modelBone = CachedBone(sourceCache, track.model, sourceBoneName)
            if modelBone < 0 then continue end

            local modelMatrix = track.model:GetBoneMatrix(modelBone)
            if not modelMatrix then continue end

            local targetBoneName = targetBones[k] or boneName
            local targetBone = CachedBone(targetCache, targetEnt, targetBoneName)
            if targetBone < 0 then continue end

            local targetMatrix = targetEnt:GetBoneMatrix(targetBone)
            if not targetMatrix then continue end

            local newMatrix = BlendGunMatrix(modelMatrix, targetMatrix, blendFactor)
            solved[targetEnt][targetBone] = true
            roots[#roots + 1] = { targetEnt, targetBone, targetMatrix, newMatrix }
            if targetBoneName == "ValveBiped.Bip01_R_Hand" then
                rightHandOld, rightHandNew = targetMatrix, newMatrix
            end
        end
        if #roots == 0 then return end

        local out = { [targetEnt] = {} }
        solved[vm] = solved[vm] or {}
        out[vm] = out[vm] or {}

        local drivenOld, drivenNew
        local gunMoved = 0
        if mode == "animated" then
            local vmCache = BoneCache(vm)
            for _, pair in ipairs(GetGunBonePairs(track)) do
                local sourceBone = CachedBone(sourceCache, track.model, pair[1])
                local gunBone = CachedBone(vmCache, vm, pair[2])
                if sourceBone >= 0 and gunBone >= 0 and not solved[vm][gunBone] then
                    local sourceMatrix = track.model:GetBoneMatrix(sourceBone)
                    local gunMatrix = vm:GetBoneMatrix(gunBone)
                    if sourceMatrix and gunMatrix then
                        local newMatrix = BlendGunMatrix(sourceMatrix, gunMatrix, blendFactor)
                        solved[vm][gunBone] = true
                        out[vm][gunBone] = newMatrix
                        roots[#roots + 1] = { vm, gunBone, gunMatrix, newMatrix }
                        gunMoved = gunMoved + 1
                        if not drivenOld then drivenOld, drivenNew = gunMatrix, newMatrix end
                        if pair[3] then break end
                    end
                end
            end
        end

        local carried = 0
        for _, root in ipairs(roots) do
            local ent = root[1]
            local moved = CarryGunChildren(ent, root[2], root[3], root[4], solved[ent], out[ent])
            if ent == vm then carried = carried + moved end
        end

        local driverOld, driverNew = drivenOld or rightHandOld, drivenNew or rightHandNew
        local rigid = false
        if carried == 0 and driverOld then
            local delta = GunDelta(driverOld, driverNew)
            if delta then
                for bone = 0, vm:GetBoneCount() - 1 do
                    if not solved[vm][bone] and not IsArmBone(vm, bone) then
                        local matrix = vm:GetBoneMatrix(bone)
                        if matrix then
                            out[vm][bone] = delta * matrix
                            carried = carried + 1
                            rigid = true
                        end
                    end
                end
            end
        end

        for ent, matrices in pairs(out) do
            for bone, matrix in pairs(matrices) do
                ent:SetBoneMatrix(bone, matrix)
            end
        end

        track.debugGunMode = mode
            .. ((mode == "animated" and gunMoved == 0) and " (no gun bone matched, following hand)" or "")
            .. (rigid and " [rigid]" or "")
        track.debugGunBoneCount = gunMoved + carried
    end

    local function SnapshotTrackIDs(buffer)
        local count = 0
        for id in pairs(GCAL.ActiveTracks) do
            count = count + 1
            buffer[count] = id
        end
        for i = count + 1, #buffer do buffer[i] = nil end
        return buffer
    end
    local gunTrackIDs, updateTrackIDs, renderTrackIDs = {}, {}, {}

    local tpikBaseBones = setmetatable({}, { __mode = "k" })
    local function GetTPIKBaseBones(ply)
        local model = ply:GetModel() or ""
        local entry = tpikBaseBones[ply]
        if entry and entry.model == model then return entry.bones end

        local bones, seen = {}, {}
        local cache = BoneCache(ply)
        local function AddTree(bone, recurse)
            if bone < 0 or seen[bone] then return end
            seen[bone] = true
            bones[#bones + 1] = bone
            if not recurse then return end
            for _, child in ipairs(ply:GetChildBones(bone) or {}) do AddTree(child, true) end
        end
        AddTree(CachedBone(cache, ply, "ValveBiped.Bip01_Spine4"), false)
        AddTree(CachedBone(cache, ply, "ValveBiped.Bip01_L_UpperArm"), true)
        AddTree(CachedBone(cache, ply, "ValveBiped.Bip01_R_UpperArm"), true)

        tpikBaseBones[ply] = { model = model, bones = bones }
        return bones
    end

    local function CollectTPIKBaseMatrices(ply, tracks)
        local matrices = {}
        for _, bone in ipairs(GetTPIKBaseBones(ply)) do
            matrices[bone] = ply:GetBoneMatrix(bone)
        end

        local cache = BoneCache(ply)
        for _, track in pairs(tracks) do
            if track.thirdperson and track.bones then
                for _, name in ipairs(track.bones) do
                    local bone = CachedBone(cache, ply, name)
                    if bone >= 0 and matrices[bone] == nil then
                        matrices[bone] = ply:GetBoneMatrix(bone)
                    end
                end
            end
        end
        return matrices
    end
    GCAL.MPInternal.CollectTPIKBaseMatrices = CollectTPIKBaseMatrices

    local frameContext = { frame = -1 }
    local function GetFrameRenderContext(ply, weapon, vm, handsEnt)
        local cached = frameContext
        local frame = FrameNumber()
        if cached.frame == frame and cached.ply == ply and cached.weapon == weapon
            and cached.inputVM == vm and cached.handsEnt == handsEnt then
            return cached.context
        end

        local context = GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        cached.frame, cached.ply, cached.weapon, cached.inputVM, cached.handsEnt, cached.context =
            frame, ply, weapon, vm, handsEnt, context
        return context
    end

    local function ProcessQueuedTracks()
        if not next(GCAL.QueuedAnims) then return end
        local ready
        for queuedTrackID, queuedName in pairs(GCAL.QueuedAnims) do
            if not GCAL.ActiveTracks[queuedTrackID] then
                ready = ready or {}
                ready[#ready + 1] = { queuedTrackID, queuedName }
            end
        end
        if not ready then return end

        for _, entry in ipairs(ready) do
            local queuedTrackID, queuedName = entry[1], entry[2]
            if GCAL.QueuedAnims[queuedTrackID] == queuedName and not GCAL.ActiveTracks[queuedTrackID] then
                GCAL.QueuedAnims[queuedTrackID] = nil
                GCAL:Play(queuedName, queuedTrackID)
            end
        end
    end

    local lastTrackUpdateFrame = -1
    local function UpdateTracksForFrame()
        local frame = FrameNumber()
        if lastTrackUpdateFrame == frame then return false end
        lastTrackUpdateFrame = frame

        local ply = LocalPlayer()
        if IsValid(ply) and not ply:Alive() then
            if GCAL.ActiveTracks["legacy_left_arm"] then GCAL:StopTrack("legacy_left_arm") end
            if GCAL.ActiveTracks["legs"] then GCAL:StopTrack("legs") end
        end

        ProcessQueuedTracks()

        for _, id in ipairs(SnapshotTrackIDs(updateTrackIDs)) do
            local track = GCAL.ActiveTracks[id]
            if track then
                UpdateTrack(track, id)
            end
        end

        if not GCAL.ActiveTracks["legacy_left_arm"] and VManip and VManip.QueuedAnim then
            local queued = VManip.QueuedAnim
            VManip.QueuedAnim = nil
            VManip:PlayAnim(queued)
        end

        return true
    end

    local lastHandsRenderFrame = -1
    local lastVMRenderFrame = -1
    local renderTracksBusy = false
    local renderTracksBusyFrame = -1
    local function RenderTracks(hands, vm, ply, weapon, flags, fromHandsHook)
        local frame = FrameNumber()
        if renderTracksBusy and renderTracksBusyFrame == frame then return end
        if not IsValid(vm) then return end
        -- One pass per frame: GM:PostDrawViewModel calls PreDrawPlayerHands, so both hooks fire.
        if lastHandsRenderFrame == frame or lastVMRenderFrame == frame then return end
        if fromHandsHook then
            lastHandsRenderFrame = frame
        else
            lastVMRenderFrame = frame
        end

        renderTracksBusy = true
        renderTracksBusyFrame = frame

        UpdateTracksForFrame()

        if next(GCAL.ActiveTracks) == nil then
            renderTracksBusy = false
            return
        end

        local handsEnt = IsValid(hands) and hands or (IsValid(ply) and ply:GetHands() or nil)
        local renderContext = GetFrameRenderContext(ply, weapon, vm, handsEnt)
        vm = renderContext.vm

        if IsValid(vm) then vm:SetupBones() end
        if IsValid(handsEnt) and handsEnt ~= vm then handsEnt:SetupBones() end
        local skipVMSetup = true

        for _, id in ipairs(SnapshotTrackIDs(renderTrackIDs)) do
            local track = GCAL.ActiveTracks[id]
            if not track then continue end
            if id == "legacy_left_arm" and IsValid(ply) and not ply:Alive() then
                GCAL:StopTrack(id)
                continue
            end

            if id == "legs" then
                continue
            end

            if id == "legacy_left_arm" then
                ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags, renderContext, skipVMSetup)
            else
                ApplyBones(track, vm, handsEnt, ply, weapon, false, false, flags, renderContext, skipVMSetup)
            end
        end

        renderTracksBusy = false
    end

    local function RenderThirdPersonTracks(ply, methodOverride, forcedWeapon)
        if next(GCAL.ActiveTracks) == nil or ply ~= LocalPlayer() then return end
        if not GCAL:IsThirdPersonEnabled() then return end
        if not IsValid(ply) or not ply:Alive() then return end
        local viewEntity = ply.GetViewEntity and ply:GetViewEntity() or ply
        if not ply:ShouldDrawLocalPlayer() and viewEntity == ply then return end

        local weapon = IsValid(forcedWeapon) and forcedWeapon or ply:GetActiveWeapon()
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        local method = methodOverride or GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy)
        local hostedByWeaponTPIK = method == "arc9_tpik"
        if hostedByWeaponTPIK and not methodOverride then return end

        UpdateTracksForFrame()
        if next(GCAL.ActiveTracks) == nil then return end

        local needsSolve = false
        for id, track in pairs(GCAL.ActiveTracks) do
            if id ~= "legs"
                and track.thirdperson
                and track.thirdpersonSolveFrame ~= FrameNumber()
            then
                needsSolve = true
                break
            end
        end

        local renderContext
        if needsSolve then
            if not hostedByWeaponTPIK then
                ply:InvalidateBoneCache()
                ply:SetupBones()
            end

            renderContext = {
                thirdpersonBaseMatrices = CollectTPIKBaseMatrices(ply, GCAL.ActiveTracks)
            }
        end

        for id, track in pairs(GCAL.ActiveTracks) do
            if id == "legs" or not track.thirdperson then continue end

            if track.thirdpersonSolveFrame == FrameNumber() then
                ApplyCachedThirdPersonBones(track, ply)
            elseif renderContext then
                ApplyBones(track, ply, nil, ply, weapon, true, false, nil, renderContext)
            end

            track.debugThirdPersonHost = method
        end
    end

    local lastGunBonesFrame = -1
    hook.Add("PreDrawViewModel", "GCAL_GunBones", function(vm, ply, weapon)
        if next(GCAL.ActiveTracks) == nil then return end
        if not IsValid(vm) or not IsValid(weapon) or ply ~= LocalPlayer() then return end

        local frame = FrameNumber()
        if lastGunBonesFrame == frame then return end

        local wanted = false
        for id, track in pairs(GCAL.ActiveTracks) do
            if id ~= "legs" and id ~= "legacy_left_arm" and ResolveGunMode(track) then
                wanted = true
                break
            end
        end
        if not wanted then return end
        lastGunBonesFrame = frame

        if type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        local renderContext = GetFrameRenderContext(ply, weapon, vm, ply:GetHands())
        local targetVM = renderContext.vm
        if not IsValid(targetVM) then return end
        targetVM:SetupBones()

        for _, id in ipairs(SnapshotTrackIDs(gunTrackIDs)) do
            local track = GCAL.ActiveTracks[id]
            if track and id ~= "legs" and id ~= "legacy_left_arm" then
                local mode = ResolveGunMode(track)
                if mode then
                    ApplyGunBones(track, targetVM, weapon, renderContext, mode)
                else
                    track.debugGunMode = nil
                    track.debugGunBoneCount = nil
                end
            end
        end
    end)

    hook.Add("Think", "GCAL_ThinkUpdateTracks", function()
        UpdateTracksForFrame()
    end)

    hook.Add("PreDrawPlayerHands", "GCAL_RenderHands", function(hands, vm, ply, weapon, flags)
        RenderTracks(hands, vm, ply, weapon, flags, true)
    end)

    -- Removes a hook left by older versions on lua refresh.
    hook.Remove("PostDrawViewModel", "GCAL_RenderVM")
    -- Name must stay "VManip": MW Base calls hook.GetTable().PostDrawViewModel.VManip directly.
    hook.Add("PostDrawViewModel", "VManip", function(vm, ply, weapon, flags)
        RenderTracks(nil, vm, ply, weapon, flags, false)
    end)

    hook.Add("PrePlayerDraw", "GCAL_RenderThirdPerson", function(ply)
        RenderThirdPersonTracks(ply)
    end)

    hook.Add("ARC9_TPIK_PostSolve", "GCAL_RenderARC9ThirdPerson", function(weapon, ply)
        if next(GCAL.ActiveTracks) == nil or ply ~= LocalPlayer() then return end
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not strategy then return end
        if GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy) ~= "arc9_tpik" then return end

        RenderThirdPersonTracks(ply, "arc9_tpik", weapon)
    end)

    hook.Add("PostPlayerDraw", "GCAL_RenderThirdPersonModels", function(ply)
        if next(GCAL.ActiveTracks) == nil or ply ~= LocalPlayer() then return end
        if not GCAL:IsThirdPersonEnabled() then return end

        for _, track in pairs(GCAL.ActiveTracks) do
            local model = track.thirdpersonModel
            local readyFrame = track.thirdpersonModelReadyFrame or -1
            local readyTime = track.thirdpersonModelReadyTime or 0
            if track.thirdperson
                and (readyFrame >= FrameNumber() - 1 or RealTime() - readyTime <= 0.1)
                and IsValid(model)
            then
                track.debugThirdPersonModelDrawFrame = FrameNumber()
                model:DrawModel()
            end
        end
    end)

    hook.Add("PreDrawViewModels", "GCAL_RenderLegs", function()
        local track = GCAL.ActiveTracks["legs"]
        if not track or not GCAL.Legs then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() or ply:ShouldDrawLocalPlayer() then return end
        GCAL.Legs:Update(ply)
        if IsValid(track.model) then
            track.model:SetupBones()
            track.model:DrawModel()
        end
    end)

    hook.Add("NeedsDepthPass", "GCAL_VManipCamAttachment", function()
        if next(GCAL.ActiveTracks) == nil or not GCAL.CamBone:GetBool() then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if not IsValid(track.camModel) then continue end

            if track.camAttachmentID == nil then
                local attachments = track.camModel:GetAttachments() or {}
                track.camAttachmentID = attachments[1] and attachments[1].id or false
            end
            if track.camAttachmentID then
                track.camModel:SetupBones()
                track.attachment = track.camModel:GetAttachment(track.camAttachmentID)
            end
        end
    end)

    local inCalcView = false
    hook.Add("CalcView", "GCAL_VManipCam", function(ply, origin, angles, fov, znear, zfar)
        if inCalcView or next(GCAL.ActiveTracks) == nil then return end
        if not GCAL.CamBone:GetBool() then return end
        if ply:GetViewEntity() ~= ply then return end
        if ply:ShouldDrawLocalPlayer() then return end

        local needsView = false
        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if track.attachment and (track.lerpVal or 1) < 1 then
                needsView = true; break
            end
        end
        if not needsView then return end

        inCalcView = true
        local ok, composed = pcall(hook.Run, "CalcView", ply, origin, angles, fov, znear, zfar)
        inCalcView = false
        if not ok then
            ErrorNoHaltWithStack(composed)
            composed = {}
        end
        if not istable(composed) then composed = {} end
        local baseOrigin = composed.origin or origin
        local baseAngles = composed.angles or angles
        local baseFov = composed.fov or fov

        local newOrigin, newAngles, newFov = baseOrigin, baseAngles, baseFov
        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if not track.attachment then continue end
            newOrigin, newAngles, newFov = GCAL:ComputeCamBoneView(track, ply, newOrigin, newAngles, newFov)
        end

        local view = {}
        for k, v in pairs(composed) do view[k] = v end
        view.origin = newOrigin
        view.angles = newAngles
        view.fov = newFov
        return view
    end)

    -- Removes a hook left by older versions on lua refresh.
    hook.Remove("CalcViewModelView", "GCAL_ViewModelOffset")

    hook.Add("StartCommand", "GCAL_VManipPreventReload", function(ply, ucmd)
        if VManip and VManip:IsActive() and not ply:ShouldDrawLocalPlayer() then
            ucmd:RemoveKey(IN_RELOAD)
        end
    end)

    hook.Add("TFA_PreReload", "GCAL_VManipPreventTFAReload", function()
        if VManip and VManip:IsActive() then return "no" end
    end)

    surface.CreateFont("GCAL_DebugTitle", { font = "Roboto", size = 18, weight = 700, antialias = true })
    surface.CreateFont("GCAL_DebugText", { font = "Consolas", size = 14, weight = 500, antialias = true })

    local HUD_X = 24
    local HUD_LINE = 15
    local HUD_EVENT_SECONDS = 12

    local hudShadow = Color(0, 0, 0, 220)
    local hudTitle = Color(93, 210, 180)
    local hudTrack = Color(255, 214, 102)
    local hudText = Color(236, 242, 255)
    local hudDim = Color(151, 163, 177)
    local hudGood = Color(120, 220, 140)
    local hudWarn = Color(255, 176, 93)
    local hudBad = Color(255, 106, 106)
    local hudBarBack = Color(255, 255, 255, 40)
    local hudBarCycle = Color(93, 210, 180)
    local hudBarBlend = Color(255, 214, 102)

    local hudRows = {}
    local hudTrackIDs = {}
    local hudRowCount = 0

    local function HudRow(kind, a, b, c, d)
        hudRowCount = hudRowCount + 1
        local row = hudRows[hudRowCount]
        if not row then
            row = {}
            hudRows[hudRowCount] = row
        end
        row.kind, row.a, row.b, row.c, row.d = kind, a, b, c, d
    end

    local function HudText(text, color, indent) HudRow("text", text, color or hudText, indent or 0) end

    local function Flag(list, cond, text)
        if cond then list[#list + 1] = text end
    end

    local function FormatSeconds(value)
        return string.format("%.2fs", value or 0)
    end

    local function TrackPhase(track, now)
        if track.gestureOnHold then return "hold", hudWarn end
        if track.segmented and not track.lastSegment then return "segment", hudWarn end
        if track.loop then return "loop", hudGood end
        if now < (track.lerpPeakTime or 0) then return "in", hudGood end
        return "out", hudDim
    end

    local function AddTrackRows(trackID, track, now)
        local data = track.data or {}
        local kind = data.legacy and "legacy" or "gcal"
        HudRow("title", trackID, track.name or "?", kind, hudTrack)

        local modelPath = data.model or (IsValid(track.model) and track.model:GetModel()) or "<none>"
        HudText("model  " .. tostring(modelPath), IsValid(track.model) and hudText or hudBad, 1)

        local seqText
        if track.poseOnlyLegacy then
            seqText = "seq    <pose only, model has no sequences>"
        elseif track.seqID == nil or track.seqID == -1 then
            seqText = "seq    <not found>"
        else
            seqText = "seq    " .. tostring(track.sequenceName) .. " (#" .. tostring(track.seqID) .. ")"
        end
        HudText(seqText, (track.seqID == -1 or track.seqID == nil) and not track.poseOnlyLegacy and hudBad or hudText, 1)

        if track.tpikSequenceName and track.tpikSequenceName ~= track.sequenceName then
            HudText("tpik   " .. tostring(track.tpikSequenceName) .. " (#" .. tostring(track.tpikSeqID) .. ")", hudText, 1)
        end

        local duration = track.duration or 0
        local speed = (track.speed or 1) * GCAL.PlaybackSpeed:GetFloat()
        local cycle = track.cycle or 0
        HudRow("bar", math.Clamp(cycle, 0, 1), hudBarCycle, string.format("cycle %.3f  %s / %s  x%.2f",
            cycle, FormatSeconds(cycle * duration / math.max(speed, 0.001)),
            FormatSeconds(duration / math.max(speed, 0.001)), speed))

        local blend = 1 - (track.lerpVal or 1)
        local phase, phaseColor = TrackPhase(track, now)
        HudRow("bar", math.Clamp(blend, 0, 1), hudBarBlend, string.format("blend %.2f  %s  weight %.2f",
            blend, phase, track.blendWeight or 1), phaseColor)

        local info = {}
        info[#info + 1] = "bones " .. tostring(track.debugBoneCount or 0)
        if data.sounds and next(data.sounds) then
            info[#info + 1] = "sounds " .. table.Count(track.soundsPlayed or {}) .. "/" .. table.Count(data.sounds)
        end
        if track.segmented then
            info[#info + 1] = "segment " .. tostring((track.segmentCount or 0) + 1)
                .. (track.lastSegment and " (last)" or "")
        end
        if track.holdTimeData then
            info[#info + 1] = "hold " .. FormatSeconds(track.holdTimeData) .. (track.holdQuit and " (released)" or "")
        end
        if track.debugGunMode then
            info[#info + 1] = "gun " .. tostring(track.debugGunMode)
                .. " [" .. tostring(track.debugGunBoneCount or 0) .. "]"
        end
        HudText(table.concat(info, "  ·  "), hudText, 1)

        local flags = {}
        Flag(flags, track.thirdperson, IsValid(track.thirdpersonModel) and "tpik" or "tpik (no model)")
        Flag(flags, IsValid(track.camModel), track.attachment and "cambone" or "cambone (no attachment)")
        Flag(flags, data.locktoply, "locktoply")
        Flag(flags, data.assurepos, "assurepos")
        Flag(flags, track.canInterrupt == false, "no-interrupt")
        Flag(flags, track.preventQuit, "prevent-quit")
        Flag(flags, track.blockCode, "blocks " .. tostring(track.blockCodeScope or "all code"))
        Flag(flags, GCAL.QueuedAnims[trackID] ~= nil, "queued: " .. tostring(GCAL.QueuedAnims[trackID]))
        if #flags > 0 then HudText(table.concat(flags, "  "), hudWarn, 1) end

        HudRow("gap")
    end

    local hudFont
    local function DrawShadowText(text, font, x, y, color, measure)
        if font ~= hudFont then
            surface.SetFont(font)
            hudFont = font
        end
        surface.SetTextColor(hudShadow.r, hudShadow.g, hudShadow.b, hudShadow.a)
        surface.SetTextPos(x + 1, y + 1)
        surface.DrawText(text)
        surface.SetTextColor(color.r, color.g, color.b, color.a or 255)
        surface.SetTextPos(x, y)
        surface.DrawText(text)
        if measure then return (surface.GetTextSize(text)) end
        return 0
    end

    hook.Add("HUDPaint", "GCAL_DebugHUD", function()
        if not GCAL.Debug:GetBool() then return end
        hudFont = nil

        local now = CurTime()
        local real = RealTime()
        hudRowCount = 0

        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        HudRow("title", "GCAL debug", string.format("%d anims · %d tracks", table.Count(GCAL.Anims or {}),
            table.Count(GCAL.ActiveTracks)), nil, hudTitle)
        if IsValid(weapon) then
            local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
            local flip = GetLegacyFlipState(weapon)
            HudText("weapon " .. weapon:GetClass() .. "  base " .. tostring(strategy and strategy.id or "default")
                .. (flip.flipmode and "  flipped" or ""), hudDim)
        else
            HudText("weapon <none>", hudDim)
        end
        local toggles = {}
        Flag(toggles, GCAL.ThirdPerson and GCAL.ThirdPerson:GetBool(), "tpik")
        Flag(toggles, GCAL.CamBone:GetBool(), "cambone")
        Flag(toggles, GCAL.MuteSounds:GetBool(), "muted")
        Flag(toggles, GCAL.PlaybackSpeed:GetFloat() ~= 1, string.format("speed x%.2f", GCAL.PlaybackSpeed:GetFloat()))
        if #toggles > 0 then HudText("on: " .. table.concat(toggles, " "), hudDim) end
        HudRow("gap")

        local ids = SnapshotTrackIDs(hudTrackIDs)
        table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
        if #ids == 0 then
            HudText("no active tracks", hudDim)
            HudRow("gap")
        end
        for i = 1, #ids do
            local track = GCAL.ActiveTracks[ids[i]]
            if track then AddTrackRows(ids[i], track, now) end
        end

        local events = GCAL.DebugEvents
        local shown = false
        for i = #events, math.max(1, #events - 7), -1 do
            local event = events[i]
            if real - event.time <= HUD_EVENT_SECONDS then
                if not shown then
                    HudRow("title", "recent events", nil, nil, hudTitle)
                    shown = true
                end
                HudText(string.format("%5.1fs  %s", real - event.time, event.text), event.color)
            end
        end

        local height = 0
        for i = 1, hudRowCount do
            local kind = hudRows[i].kind
            height = height + ((kind == "title" and 20) or (kind == "gap" and 6) or (kind == "bar" and 17) or HUD_LINE)
        end

        local x = HUD_X
        local y = math.max(8, math.floor(ScrH() * 0.5 - height * 0.5))
        for i = 1, hudRowCount do
            local row = hudRows[i]
            local kind = row.kind
            if kind == "title" then
                local w = DrawShadowText(tostring(row.a), "GCAL_DebugTitle", x, y, row.d or hudTitle, row.b ~= nil)
                if row.b then
                    local w2 = DrawShadowText(tostring(row.b), "GCAL_DebugText", x + w + 8, y + 3, hudText, row.c ~= nil)
                    if row.c then
                        DrawShadowText("[" .. row.c .. "]", "GCAL_DebugText", x + w + w2 + 14, y + 3, hudDim)
                    end
                end
                y = y + 20
            elseif kind == "gap" then
                y = y + 6
            elseif kind == "bar" then
                local bx, barWidth = x + 12, 120
                surface.SetDrawColor(hudShadow)
                surface.DrawRect(bx + 1, y + 6, barWidth, 3)
                surface.SetDrawColor(hudBarBack)
                surface.DrawRect(bx, y + 5, barWidth, 3)
                surface.SetDrawColor(row.b)
                surface.DrawRect(bx, y + 5, math.floor(barWidth * row.a), 3)
                DrawShadowText(row.c, "GCAL_DebugText", bx + barWidth + 8, y, row.d or hudText)
                y = y + 17
            else
                DrawShadowText(row.a, "GCAL_DebugText", x + row.c * 12, y, row.b)
                y = y + HUD_LINE
            end
        end
    end)

    local consoleTitle = Color(93, 210, 180)
    local consoleText = Color(236, 242, 255)
    local consoleWarn = Color(255, 176, 93)
    local consoleError = Color(255, 106, 106)
    local consoleDelta = Color(200, 220, 255)

    local function TrackLine(label, value)
        MsgC(consoleText, " - " .. label .. ": " .. tostring(value) .. "\n")
    end

    concommand.Add("gcal_list_anims", function()
        local names = {}

        for name in pairs(GCAL.Anims or {}) do
            names[#names + 1] = tostring(name)
        end

        table.sort(names)
        MsgC(consoleTitle, "[GCAL] Registered animations (" .. #names .. "):\n")

        for _, name in ipairs(names) do
            local anim = GCAL.Anims[name] or {}
            MsgC(consoleText, " - " .. name .. " [" .. tostring(anim.group_name or "default") .. "]\n")
        end
    end)

    local function AnimAutocomplete(command, args)
        local needle = string.lower(string.Trim(args or ""))
        local matches = {}

        for name in pairs(GCAL.Anims or {}) do
            name = tostring(name)
            if needle == "" or string.StartsWith(string.lower(name), needle) then
                matches[#matches + 1] = command .. " " .. name
            end
        end

        table.sort(matches)
        return matches
    end

    concommand.Add("gcal_play", function(_, _, args)
        local name = args[1]
        local trackID = args[2]

        if not name or name == "" then
            MsgC(consoleWarn, "[GCAL] Usage: gcal_play <animation> [track]\n")
            return
        end

        if not GCAL.Anims[name] then
            MsgC(consoleError, "[GCAL] Unknown animation: " .. tostring(name) .. "\n")
            return
        end

        if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then
            MsgC(consoleWarn, "[GCAL] Animation is disabled: " .. tostring(name) .. "\n")
            return
        end

        if GCAL:Play(name, trackID) then
            MsgC(consoleTitle,
                "[GCAL] Playing " .. tostring(name) .. (trackID and (" on " .. tostring(trackID)) or "") .. "\n")
        else
            MsgC(consoleError, "[GCAL] Could not play " .. tostring(name) .. "\n")
        end
    end, AnimAutocomplete, "Play a registered GCAL animation. Usage: gcal_play <animation> [track]")

    concommand.Add("gcal_debug_sequences", function(_, _, args)
        local target = args[1]
        if not target or target == "" then
            MsgC(consoleWarn, "[GCAL] Usage: gcal_debug_sequences <animation> | <model.mdl> [sequence]\n")
            return
        end

        local modelPath, sequenceName
        local anim = GCAL.Anims[target]
        if anim then
            if not anim.model then
                MsgC(consoleError, "[GCAL] Animation has no model: " .. tostring(target) .. "\n")
                return
            end
            modelPath = anim.model
            sequenceName = anim.sequence or target
            MsgC(consoleTitle, "[GCAL] Sequence debug for animation " .. tostring(target) .. "\n")
            MsgC(consoleText, " - explicit sequence: " .. tostring(anim.sequence or "<none>") .. "\n")
        elseif string.EndsWith(string.lower(target), ".mdl") then
            modelPath = target
            sequenceName = args[2]
            MsgC(consoleTitle, "[GCAL] Sequence debug for model " .. tostring(target) .. "\n")
        else
            MsgC(consoleError, "[GCAL] Unknown animation (and not a .mdl path): " .. tostring(target) .. "\n")
            return
        end

        local normalizedPath = NormalizeModelPath(modelPath)
        MsgC(consoleText, " - model: " .. normalizedPath .. "\n")

        local model = ClientsideModel(normalizedPath, RENDERGROUP_BOTH)
        if not IsValid(model) then
            MsgC(consoleError, "[GCAL] Could not create model: " .. normalizedPath .. "\n")
            MsgC(consoleWarn, "   ! Check that the file exists at: garrysmod/" .. normalizedPath .. "\n")
            return
        end

        model:SetNoDraw(true)
        model:SetupBones()

        local sequenceList = model.GetSequenceList and (model:GetSequenceList() or {}) or {}
        MsgC(consoleText, " - sequences (" .. tostring(#sequenceList) .. "):\n")

        if #sequenceList == 0 then
            MsgC(consoleWarn, "   ! Model loaded with zero sequences. It is a prop/ragdoll without animations,\n")
            MsgC(consoleWarn, "     failed to load completely, or is missing its .vvd/.vtx files.\n")
            model:Remove()
            return
        end

        for i, name in ipairs(sequenceList) do
            MsgC(consoleText, "   [" .. i .. "] " .. tostring(name) .. "\n")
        end

        if sequenceName and sequenceName ~= "" then
            local seqID = model:LookupSequence(sequenceName)
            if seqID ~= -1 then
                MsgC(consoleTitle, " ✓ Sequence '" .. sequenceName .. "' found (ID: " .. seqID .. ")\n")
                MsgC(consoleText, "   - Duration: " .. model:SequenceDuration(seqID) .. " seconds\n")
            else
                MsgC(consoleError, " ✗ Sequence '" .. sequenceName .. "' NOT FOUND\n")
                local lowerTarget = string.lower(sequenceName)
                for _, name in ipairs(sequenceList) do
                    if string.lower(name) == lowerTarget then
                        MsgC(consoleWarn,
                            "   ! Case-insensitive match: '" .. name .. "'. Fix the case in your registration.\n")
                    end
                end
            end
        end

        model:Remove()
    end, AnimAutocomplete,
        "Print the sequences of a registered animation's model, or of any model. "
            .. "Usage: gcal_debug_sequences <animation> | <model.mdl> [sequence]")

    concommand.Add("gcal_debug_track", function(_, _, args)
        local trackID = args[1] or "legacy_left_arm"
        local track = GCAL.ActiveTracks[trackID]

        if not track then
            MsgC(consoleWarn, "[GCAL] No active track: " .. tostring(trackID) .. "\n")
            return
        end

        MsgC(consoleTitle, "[GCAL] Track debug for " .. tostring(trackID) .. "\n")
        TrackLine("anim", track.name)
        TrackLine("model", track.data and track.data.model or "<none>")
        TrackLine("sequence", track.sequenceName or "<none>")
        TrackLine("seqID", track.seqID)
        TrackLine("cycle", math.Round(track.cycle or 0, 4))
        TrackLine("lerp", math.Round(track.lerpVal or 0, 4))
        TrackLine("blockCode", track.blockCode or false)
        TrackLine("blockCodeScope", track.blockCodeScope or "<global>")
        TrackLine("poseOnlyLegacy", track.poseOnlyLegacy or false)
        TrackLine("thirdperson", track.thirdperson or false)
        TrackLine("thirdperson root bone", track.debugThirdPersonRootBone or "<not cached>")
        TrackLine("thirdperson mode", track.debugThirdPersonMode or "<not evaluated>")
        TrackLine("thirdperson host", track.debugThirdPersonHost or "gcal")
        TrackLine("thirdperson model", track.debugThirdPersonModel or "<not rendered>")
        TrackLine("thirdperson model valid", IsValid(track.thirdpersonModel))
        TrackLine("thirdperson model visible materials", track.thirdpersonModelHasVisibleMaterials)
        TrackLine("thirdperson model ready frame", track.thirdpersonModelReadyFrame or "<none>")
        TrackLine("thirdperson model draw frame", track.debugThirdPersonModelDrawFrame or "<none>")
        TrackLine("thirdperson model distance", track.debugThirdPersonModelDistance or "<none>")
        TrackLine("last arm target entity", track.debugTargetEntity or "<none>")
        TrackLine("debugBoneCount", track.debugBoneCount or 0)
        TrackLine("gun mode", track.debugGunMode or "off")
        TrackLine("gun bones moved", track.debugGunBoneCount or 0)

        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        local vm = IsValid(ply) and ply:GetViewModel() or nil
        local handsEnt = IsValid(ply) and ply:GetHands() or nil
        local renderContext = GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        vm = renderContext.vm

        if not IsValid(vm) then
            MsgC(consoleWarn, " - no valid viewmodel entity\n")
            return
        end

        TrackLine("weapon strategy", renderContext.strategy_id)

        local flip = GetLegacyFlipState(weapon)
        if IsValid(weapon) then
            TrackLine("weapon class", weapon:GetClass())
            TrackLine("ViewModelFlipDefault", flip.lefty)
            TrackLine("ViewModelFlip", flip.flippedNow)
            TrackLine("flipmode", flip.flipmode)
            TrackLine("legacy target side", flip.targetSide)
        end

        vm:SetupBones()
        if IsValid(handsEnt) then handsEnt:SetupBones() end
        if IsValid(track.model) then track.model:SetupBones() end

        local targetBones = track.bones or {}
        if track.data and track.data.legacy then
            targetBones = flip.targetBones
        end

        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetBones)
        if not IsValid(targetEnt) then
            MsgC(consoleWarn, " - no valid arm target entity\n")
            return
        end

        TrackLine("arm target entity", targetEnt)

        local matched = 0
        local samples = 0
        for k, boneName in ipairs(track.bones or {}) do
            local targetBoneName = boneName
            if track.data and track.data.legacy then
                targetBoneName = flip.targetBones[k] or boneName
            end
            local targetBone = targetEnt:LookupBone(targetBoneName)
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            if sourceBoneName == ULNA_L then sourceBoneName = FOREARM_L end
            local modelBone = IsValid(track.model) and track.model:LookupBone(sourceBoneName) or nil
            if targetBone ~= nil and targetBone >= 0 and modelBone ~= nil and modelBone >= 0 then
                matched = matched + 1
                MsgC(consoleText, "   * " .. tostring(targetBoneName) .. " <- " .. tostring(sourceBoneName) .. "\n")

                if samples < 3 then
                    local targetMatrix = targetEnt:GetBoneMatrix(targetBone)
                    local sourceMatrix = track.model:GetBoneMatrix(modelBone)
                    if targetMatrix and sourceMatrix then
                        local targetPos = targetMatrix:GetTranslation()
                        local sourcePos = sourceMatrix:GetTranslation()
                        local delta = sourcePos - targetPos
                        MsgC(consoleDelta, "     source-target delta: "
                            .. string.format("%.3f, %.3f, %.3f", delta.x, delta.y, delta.z) .. "\n")
                        samples = samples + 1
                    end
                end
            end
        end

        TrackLine("matched bones", matched)
    end, nil, "Debug an active GCAL track. Usage: gcal_debug_track [track]")

    concommand.Add("gcal_stop", function(_, _, args)
        local trackID = args[1]

        if trackID and trackID ~= "" then
            GCAL:StopTrack(trackID)
            MsgC(consoleTitle, "[GCAL] Stopped track " .. tostring(trackID) .. "\n")
            return
        end

        local stopped = 0
        for _, activeTrackID in ipairs(GCAL:GetActiveTrackIDs()) do
            GCAL:StopTrack(activeTrackID)
            stopped = stopped + 1
        end

        MsgC(consoleTitle, "[GCAL] Stopped " .. tostring(stopped) .. " active track(s)\n")
    end, nil, "Stop one GCAL track, or every active track when no track is provided. Usage: gcal_stop [track]")

    net.Receive("VManip_SimplePlay", function()
        local anim = net.ReadString()
        VManip:PlayAnim(anim)
    end)

    net.Receive("GCAL_Play", function()
        local anim = net.ReadString()
        local trackID = net.ReadString()
        if trackID == "" then trackID = nil end
        GCAL:Play(anim, trackID)
    end)

    net.Receive("GCAL_Stop", function()
        local trackID = net.ReadString()
        if trackID == "" then
            GCAL:StopAllTracks()
        else
            GCAL:StopTrack(trackID)
        end
    end)

    net.Receive("VManip_StopHold", function()
        local anim = net.ReadString()
        if anim == "" then
            VManip:QuitHolding()
        else
            VManip:QuitHolding(anim)
        end
    end)
end

if SERVER then
    function GCAL:Play(arg1, arg2, recipients)
        local name, trackID
        if isstring(arg1) then
            name, trackID = arg1, arg2
        else
            name, trackID = arg2, nil
        end

        if not name then return false end

        net.Start("GCAL_Play")
        net.WriteString(name)
        net.WriteString(trackID or "")
        if recipients then
            net.Send(recipients)
        else
            net.Broadcast()
        end

        return true
    end

    function GCAL:StopTrack(trackID, recipients)
        net.Start("GCAL_Stop")
        net.WriteString(trackID or "")
        if recipients then
            net.Send(recipients)
        else
            net.Broadcast()
        end
    end

    function GCAL:StopAllTracks(recipients)
        self:StopTrack(nil, recipients)
    end
end
