-- GCAL: GMod Compliant Armature Layer
-- Core Engine

GCAL = GCAL or {}
GCAL.Anims = GCAL.Anims or {}
GCAL.ActiveTracks = GCAL.ActiveTracks or {}
GCAL.ImportedFiles = GCAL.ImportedFiles or {}
GCAL.QueuedAnims = GCAL.QueuedAnims or {}

-- Define Groups Early
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
    GCAL.ThirdPerson = CreateClientConVar("gcal_thirdperson", "1", true, false, "Render GCAL arm animations on the local player in thirdperson.")
    GCAL.PlaybackSpeed = CreateClientConVar("gcal_playback_speed", "1", true, false, "Global GCAL playback speed multiplier.")
    GCAL.MuteSounds = CreateClientConVar("gcal_mute_sounds", "0", true, false, "Mute animation sounds emitted by GCAL.")
    GCAL.SoundPitch = CreateClientConVar("gcal_sound_pitch", "100", true, false, "Pitch used for animation sounds emitted by GCAL.")
    GCAL.InternalThirdPersonEnabled = false

    function GCAL:IsThirdPersonEnabled()
        return self.InternalThirdPersonEnabled and self.ThirdPerson:GetBool()
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

local function GCAL_Log(...)
    if not CLIENT or not GCAL.Debug:GetBool() then return end
    MsgC(Color(255, 255, 0), "[GCAL DEBUG] ", Color(255, 255, 255), table.concat({...}, " "), "\n")
end

function GCAL:NormalizeHand(hand)
    hand = string.lower(tostring(hand or "left"))

    if hand == "right" or hand == "right_arm" or hand == "r" then
        return "right"
    end

    if hand == "both" or hand == "both_hands" or hand == "bothhands" or hand == "both_arms" or hand == "dual" then
        return "both"
    end

    if hand == "left" or hand == "left_arm" or hand == "l" or hand == "second" or hand == "second_hand" or hand == "secondhand" or hand == "offhand" then
        return "left"
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

function GCAL:PrepareAnimData(data, hand)
    if not data then return data end

    hand = self:NormalizeHand(hand or data.hand or data.arm or data.bone_group or data.bonegroup)
    data.hand = hand
    data.bones = isstring(data.bones) and self:GetHandBones(data.bones) or data.bones or self:GetHandBones(hand)
    data.source_hand = data.source_hand or data.source_arm
    data.source_bones = isstring(data.source_bones) and self:GetHandBones(data.source_bones) or data.source_bones
    data.source_bones = data.source_bones or (data.source_hand and self:GetHandBones(data.source_hand)) or data.bones
    data.group_name = data.track or data.track_id or data.group_name or self:GetHandTrack(hand)

    return data
end

-- Robust Registration
function GCAL:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end

    if not name or not data then return end
    self:PrepareAnimData(data)
    data.addon_name = data.addon_name or data.addon or data.source_addon or GCAL.CurrentRegistrationSource or "GCAL"
    
    GCAL_Log("Registering animation:", name)
    GCAL.Anims[name] = data
end
GCAL.RegisterAnim = GCAL.RegisterAnim

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

if CLIENT then
    local EyeAngles = EyeAngles
    local EyePos = EyePos

    local curtime = 0
    local scalevec = Vector(1, 1, 1)
    local scaleflipvec = Vector(1, 1, -1)
    local properang = Angle(-79.750, 0, -90)
    local tableintensity = {1, 1, 1}
    local angleFlip = Angle(180, 0, 0)
    local angleZero = Angle(0, 0, 0)

    local SyncLegacyVManipFields

    local function ResolveSequence(track, animName, anim)
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
        AddCandidate(anim.sequence, "explicit sequence")

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
                AddNormalizedTarget(anim.sequence)
                AddTokenSubsequenceTargets(animName, AddNormalizedTarget)
                AddTokenSubsequenceTargets(anim.sequence, AddNormalizedTarget)

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
                    GCAL_Log("Sequence resolver: using '" .. tostring(candidate.name) .. "' from " .. tostring(candidate.reason) .. " for '" .. tostring(animName) .. "'.")
                end
                return seqID, candidate.name
            end
        end

        return -1, nil
    end

    local function FindLegacySurrogateAnim(name, currentAnim)
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

    function GCAL:Play(arg1, arg2)
        local name, trackID
        if isstring(arg1) then
            name, trackID = arg1, arg2
        else
            -- Probably GCAL:Play("name")
            name, trackID = arg2, nil
        end

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
        if anim.legacy then
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
            if not bypass and IsValid(vm) then
                if type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return false end
                local cycle = math.Round(vm:GetCycle(), 2)
                if vm:GetSequenceActivity(vm:GetSequence()) == ACT_VM_RELOAD and (cycle < 0.99 and cycle > 0) then return false end
            end
        end

        if hook.Run("VManipPrePlayAnim", name) == false then return false end

        local easingInName = anim.easing_in or "OutQuad"
        local easingOutName = anim.easing_out or "OutQuad"
        local legacyMatrixLerp = easingInName == "Legacy" or easingOutName == "Legacy"
        
        local track = {
            name = name,
            data = anim,
            startTime = CurTime(),
            cycle = anim.startcycle or 0,
            lerpVal = 1, -- Matches VMatrixlerp (1 = Weapon, 0 = Animation)
            model = ClientsideModel("models/" .. anim.model, RENDERGROUP_BOTH),
            camModel = ClientsideModel("models/" .. anim.model, RENDERGROUP_BOTH),
            speed = anim.speed or 1,
            lerpSpeedIn = anim.lerp_speed_in or 1,
            lerpSpeedOut = anim.lerp_speed_out or 1,
            easingIn = GCAL.Lerp.Get(easingInName == "Legacy" and "OutQuad" or easingInName),
            easingOut = GCAL.Lerp.Get(easingOutName == "Legacy" and "OutQuad" or easingOutName),
            lerpPeak = anim.lerp_peak or 0.5,
            lerpPeakTime = CurTime() + (anim.lerp_peak or 0.5),
            legacyMatrixLerp = legacyMatrixLerp,
            lerpCurve = anim.lerp_curve or 1,
            holdTime = anim.holdtime and (CurTime() + anim.holdtime) or nil,
            holdTimeData = anim.holdtime,
            holdQuit = false,
            gestureOnHold = false,
            gesturePastHold = false,
            preventQuit = anim.preventquit or false,
            loop = anim.loop or false,
            segmented = anim.segmented or false,
            segmentFinished = false,
            curSegment = nil,
            lastSegment = false,
            segmentCount = 0,
            camAng = anim.cam_ang or properang,
            camAngInt = anim.cam_angint or tableintensity,
            lockZ = anim.locktoply and EyePos().z or 0,
            attachment = nil,
            bones = anim.bones or GCAL.GROUPS.LEFT_ARM,
            sourceBones = anim.source_bones or anim.bones or GCAL.GROUPS.LEFT_ARM,
            soundsPlayed = {},
            thirdperson = GCAL.InternalThirdPersonEnabled and anim.thirdperson ~= false,
            lastLerpVal = 1,
            legacyStarted = false,
            poseOnlyLegacy = false
        }
        
        if not IsValid(track.model) then 
            GCAL_Log("Failed: Invalid model path: models/" .. tostring(anim.model))
            if IsValid(track.camModel) then track.camModel:Remove() end
            return false 
        end
        
        track.model:SetNoDraw(true)
        if IsValid(track.camModel) then
            track.camModel:SetNoDraw(true)
        end

        local sequenceList = track.model.GetSequenceList and (track.model:GetSequenceList() or {}) or {}
        track.seqID, track.sequenceName = ResolveSequence(track, name, anim)
        
        if track.seqID == -1 then
            if anim.legacy and #sequenceList == 0 then
                local surrogate = FindLegacySurrogateAnim(name, anim)
                if surrogate then
                    local surrogateModel = ClientsideModel("models/" .. surrogate.data.model, RENDERGROUP_BOTH)
                    local surrogateCamModel = ClientsideModel("models/" .. surrogate.data.model, RENDERGROUP_BOTH)

                    if IsValid(surrogateModel) then
                        surrogateModel:SetNoDraw(true)
                    end
                    if IsValid(surrogateCamModel) then
                        surrogateCamModel:SetNoDraw(true)
                    end

                    if IsValid(surrogateModel) then
                        local surrogateTrack = {
                            model = surrogateModel,
                            data = surrogate.data
                        }
                        local surrogateSeqID, surrogateSequenceName = ResolveSequence(surrogateTrack, surrogate.name, surrogate.data)
                        if surrogateSeqID ~= -1 then
                            if IsValid(track.model) then track.model:Remove() end
                            if IsValid(track.camModel) then track.camModel:Remove() end

                            track.model = surrogateModel
                            track.camModel = surrogateCamModel
                            track.seqID = surrogateSeqID
                            track.sequenceName = surrogateSequenceName

                            track.model:ResetSequenceInfo()
                            track.model:SetPlaybackRate(1)
                            track.model:ResetSequence(track.seqID)
                            track.duration = math.max(track.model:SequenceDuration(track.seqID), 0.01)

                            if IsValid(track.camModel) then
                                track.camModel:ResetSequenceInfo()
                                track.camModel:SetPlaybackRate(1)
                                track.camModel:ResetSequence(track.seqID)
                            end

                            GCAL_Log("Legacy fallback: using surrogate animation '" .. tostring(surrogate.name) .. "' for '" .. tostring(name) .. "'.")
                        else
                            if IsValid(surrogateModel) then surrogateModel:Remove() end
                            if IsValid(surrogateCamModel) then surrogateCamModel:Remove() end
                        end
                    elseif IsValid(surrogateCamModel) then
                        surrogateCamModel:Remove()
                    end
                end

                if track.seqID == -1 then
                    track.poseOnlyLegacy = true
                    track.duration = math.max(anim.duration or anim.holdtime or anim.lerp_peak or 1, 0.01)
                    GCAL_Log("Legacy fallback: using pose-only mode for '" .. tostring(name) .. "' because the model reported zero sequences.")
                end
            else
                GCAL_Log("Failed: Sequence not found in model!")
                track.model:Remove()
                if IsValid(track.camModel) then track.camModel:Remove() end
                return false
            end
        else
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
        
        if GCAL.ActiveTracks[trackID] then
            GCAL:StopTrack(trackID)
        end
        
        GCAL.ActiveTracks[trackID] = track
        if trackID == "legacy_left_arm" then
            SyncLegacyVManipFields(track)
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
            if IsValid(track.legModel) then track.legModel:Remove() end
            if trackID == "legacy_left_arm" then
                vmatrixpeakinfo = vmatrixpeakinfo or 0
                VManip_modelname = VManip_modelname or ""
                vmanipholdtime = vmanipholdtime or 0
                SyncLegacyVManipFields(nil)
            end
            GCAL.ActiveTracks[trackID] = nil
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
        if not self:GetAnim(name) then return false end

        local anim = self:GetAnim(name)
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

        track.model:ResetSequence(sequence)
        if IsValid(track.camModel) then track.camModel:ResetSequence(sequence) end
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
                    if self:GetCurrentAnim(trackID) == track.name and IsValid(LocalPlayer()) and LocalPlayer():Alive() then
                        if not GCAL.MuteSounds:GetBool() then
                            local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
                            LocalPlayer():EmitSound(overridePath or soundPath, 75, GCAL.SoundPitch:GetInt())
                        end
                    end
                end)
            end
        end

        hook.Run("GCALPlaySegment", trackID, track.name, sequence, lastSegment)
        return true
    end

    local function HandleSounds(track)
        if GCAL.MuteSounds:GetBool() then return end
        local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
        local soundCount = track.data.sounds and table.Count(track.data.sounds) or 0
        if soundCount == 0 then
            if overridePath and not track.soundsPlayed.__custom_start then
                local ply = LocalPlayer()
                if IsValid(ply) then ply:EmitSound(overridePath, 75, GCAL.SoundPitch:GetInt()) end
                track.soundsPlayed.__custom_start = true
            end
            return
        end

        local elapsed = CurTime() - track.startTime
        for soundPath, time in pairs(track.data.sounds) do
            if elapsed >= time and not track.soundsPlayed[soundPath] then
                local ply = LocalPlayer()
                if IsValid(ply) then ply:EmitSound(overridePath or soundPath, 75, GCAL.SoundPitch:GetInt()) end
                track.soundsPlayed[soundPath] = true
            end
        end
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
            VManip.Cam_Ang = properang
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
            VManip.PreventQuit = false
            VManip.Segmented = false
            VManip.SegmentFinished = false
            VManip.CurSegment = nil
            VManip.LastSegment = false
            VManip.SegmentCount = 0
            VManip.Attachment = nil
        end
    end

    local function UpdateTrack(track, trackID)
        track.data = track.data or {}
        track.startTime = track.startTime or CurTime()
        track.cycle = track.cycle or 0
        track.speed = track.speed or 1
        track.duration = track.duration or 1
        track.lerpPeak = track.lerpPeak or track.data.lerp_peak or 0.5
        track.lerpPeakTime = track.lerpPeakTime or (CurTime() + track.lerpPeak)
        track.lerpSpeedIn = track.lerpSpeedIn or track.data.lerp_speed_in or 1
        track.lerpSpeedOut = track.lerpSpeedOut or track.data.lerp_speed_out or 1
        track.lerpCurve = track.lerpCurve or track.data.lerp_curve or 1
        if track.loop == nil then track.loop = track.data.loop or false end
        if track.segmented == nil then track.segmented = track.data.segmented or false end
        track.segmentCount = track.segmentCount or 0
        track.holdTimeData = track.holdTimeData or track.data.holdtime
        if not track.holdTime and track.holdTimeData then track.holdTime = track.startTime + track.holdTimeData end
        track.easingIn = track.easingIn or GCAL.Lerp.OutQuad
        track.easingOut = track.easingOut or GCAL.Lerp.OutQuad
        track.soundsPlayed = track.soundsPlayed or {}
        track.lastLerpVal = track.lastLerpVal or track.lerpVal or 1

        local dt = FrameTime()
        HandleSounds(track)

        curtime = CurTime()

        if track.loop then
            if track.cycle >= 1 then
                track.lerpPeakTime = curtime + track.lerpPeak
                track.cycle = 0
            end
            if track.holdQuit then track.loop = false end
        end

        if track.holdTime then
            if curtime >= track.holdTime and not track.gestureOnHold and not track.gesturePastHold and not track.holdQuit then
                track.gestureOnHold = true
            elseif track.holdQuit and track.gestureOnHold then
                track.gestureOnHold = false
                track.gesturePastHold = true
                track.lerpPeakTime = curtime + track.lerpPeak - (track.holdTimeData or 0)
            end
        end

        if not track.gestureOnHold then
            track.cycle = track.cycle + dt * track.speed * GCAL.PlaybackSpeed:GetFloat()
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
        end

        if (curtime < track.lerpPeakTime or (track.segmented and not track.lastSegment)) and (not track.gestureOnHold or track.gesturePastHold) then
            track.lerpVal = math.Clamp((track.lerpVal or 1) - (dt * 7) * track.lerpSpeedIn, 0, 1)
        elseif not track.loop and (not track.gestureOnHold or track.gesturePastHold) then
            if not track.segmented or track.lastSegment then
                track.lerpVal = math.Clamp((track.lerpVal or 1) + (dt * 7) * track.lerpSpeedOut, 0, 1)
            end
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
                hook.Run("GCALSegmentFinish", trackID, track.name, track.curSegment, track.lastSegment, track.segmentCount)
                hook.Run("VManipSegmentFinish", track.name, track.curSegment, track.lastSegment, track.segmentCount)
            elseif track.segmented and track.lastSegment then
                if track.lerpVal >= 1 then GCAL:StopTrack(trackID) return true end
            elseif not track.segmented then
                GCAL:StopTrack(trackID)
                return true
            end
        end

        if trackID == "legacy_left_arm" then
            SyncLegacyVManipFields(track)
        end

        track.lastLerpVal = track.lerpVal

        return false
    end

    local function BuildThirdPersonMatrix(track, vm, targetBone, modelBone, vmMatrix, modelMatrix, thirdpersonState)
        if not thirdpersonState.targetRoot or not thirdpersonState.modelRoot then
            thirdpersonState.targetRoot = vmMatrix
            thirdpersonState.modelRoot = modelMatrix

            local modelRootInverse = Matrix(modelMatrix:ToTable())
            modelRootInverse:Invert()
            thirdpersonState.rootRemap = Matrix(vmMatrix:ToTable()) * modelRootInverse
        end

        -- Move the entire animated source chain into the player arm's shoulder space
        -- in one shot. Rebuilding bone-by-bone from the player chain leaks the
        -- weapon-hold pose back into the forearm and hand.
        return thirdpersonState.rootRemap * modelMatrix
    end

    local flipState = { lefty = false, flippedNow = false, flipmode = false, targetRight = false, targetBones = nil, targetSide = "left_arm" }
    local function GetLegacyFlipState(weapon)
        local validWeapon = IsValid(weapon)
        local lefty = validWeapon and tobool(weapon.ViewModelFlipDefault) or false
        local flippedNow = validWeapon and tobool(weapon.ViewModelFlip) or false
        local flipmode = validWeapon and lefty ~= flippedNow or false
        flipState.lefty = lefty
        flipState.flippedNow = flippedNow
        flipState.flipmode = flipmode
        flipState.targetRight = flipmode
        flipState.targetBones = flipmode and GCAL.GROUPS.RIGHT_ARM or GCAL.GROUPS.LEFT_ARM
        flipState.targetSide = flipmode and "right_arm" or "left_arm"
        return flipState
    end

    local function DrawGShaderFriendlyModel(model, flags)
        if not IsValid(model) then return end

        model:DrawModel(flags)
    end

    local function UsesMWBaseViewModel(weapon)
        return IsValid(weapon) and IsValid(weapon.m_ViewModel)
    end

    local posparentcache
    local function ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags)
        if not IsValid(track.model) or not IsValid(vm) then return end
        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        local flip = GetLegacyFlipState(weapon)
        local flipmode = flip.flipmode
        local flipped = (track.lerpVal <= 0.5 and scaleflipvec or scalevec)
        local sourceAngleOffset = flipmode and angleFlip or angleZero

        if track.data.assurepos then
            if posparentcache ~= weapon then
                posparentcache = weapon
                track.model:SetParent(nil)
                track.model:SetPos(EyePos())
                track.model:SetAngles(vm:GetAngles() + sourceAngleOffset)
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
            track.model:SetAngles(newang + sourceAngleOffset)
            track.model:SetPos(eyepos)
        elseif not track.data.assurepos then
            local eyeang, eyepos = EyeAngles(), EyePos()
            track.model:SetAngles(eyeang + sourceAngleOffset)
            track.model:SetPos(eyepos)
        end

        vm:SetupBones()
        if IsValid(handsEnt) then
            handsEnt:SetupBones()
        end

        track.model:SetupBones()
        track.model:SetModelScale(flipmode and -1 or 1)
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        DrawGShaderFriendlyModel(track.model, flags)
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local rigpick = GCAL.GROUPS.LEFT_ARM
        local targetRig = flip.targetBones
        local boneCount = 0
        local lerpVal = track.lerpVal
        local lerpCurve = track.lerpCurve or 1
        local legacyLerp = GCAL.Lerp.Legacy

        for k, boneName in ipairs(rigpick) do
            local sourceBoneName = boneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or boneName
            local sourceBone = track.model:LookupBone(sourceBoneName)
            if sourceBone == nil or sourceBone < 0 then continue end

            local gestureMatrix = track.model:GetBoneMatrix(sourceBone)
            local targetBone = vm:LookupBone(targetRig[k] or boneName)

            if targetBone ~= nil and targetBone >= 0 and gestureMatrix ~= nil then
                local targetBoneMatrix = vm:GetBoneMatrix(targetBone)
                if targetBoneMatrix then
                    local targetTable = targetBoneMatrix:ToTable()
                    local gestureTable = gestureMatrix:ToTable()

                    for i, row in pairs(gestureTable) do
                        for j, value in pairs(row) do
                            gestureTable[i][j] = legacyLerp(lerpVal, value, targetTable[i][j], lerpCurve)
                        end
                    end

                    local m = Matrix(gestureTable)
                    m:SetScale(flip.targetRight and flipped or scalevec)
                    vm:SetBoneMatrix(targetBone, m)
                    boneCount = boneCount + 1
                end
            end
        end

        if IsValid(handsEnt) then
            handsEnt:InvalidateBoneCache()
        end
        track.debugBoneCount = boneCount
    end

    local function ApplyBones(track, vm, handsEnt, ply, weapon, thirdperson, suppressSourceDraw, flags)
        if not IsValid(vm) or not track.bones then return end

        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        vm:SetupBones()
        if IsValid(handsEnt) and handsEnt ~= vm then
            handsEnt:SetupBones()
        end

        local flip = GetLegacyFlipState(weapon)
        local flipmode = flip.flipmode
        local eyeang, eyepos = EyeAngles(), EyePos()
        
        if thirdperson then
            local renderAngles = vm.GetRenderAngles and vm:GetRenderAngles() or vm:GetAngles()
            track.model:SetAngles(renderAngles)
            track.model:SetPos(vm:GetPos())
        elseif track.data.legacy then
            track.model:SetAngles(flipmode and eyeang + angleFlip or eyeang)
            track.model:SetPos(eyepos)
        elseif track.data.locktoply or track.data.assurepos then
            track.model:SetAngles(flipmode and eyeang + angleFlip or eyeang)
            track.model:SetPos(eyepos)
        else
            track.model:SetAngles(vm:GetAngles())
            track.model:SetPos(vm:GetPos())
        end

        track.model:SetModelScale(flipmode and -1 or 1)
        track.model:SetupBones()
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        if not thirdperson and not suppressSourceDraw then
            DrawGShaderFriendlyModel(track.model, flags)
        end
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local boneCount = 0
        local curve = track.lerpCurve or track.data.lerp_curve or 1
        local lerpVal = track.lerpVal
        local matrixLerp = track.legacyMatrixLerp and GCAL.Lerp.Legacy or Lerp
        local scaleVec = flip.lefty and lerpVal <= 0.5 and scaleflipvec or scalevec
        local thirdpersonState = thirdperson and {} or nil

        for k, boneName in ipairs(track.bones) do
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            sourceBoneName = sourceBoneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or sourceBoneName
            local modelBone = track.model:LookupBone(sourceBoneName)
            if not modelBone or modelBone < 0 then continue end

            local modelMatrix = track.model:GetBoneMatrix(modelBone)
            if modelMatrix then
                local targetBoneName = flip.targetBones[k] or boneName
                local targetBone = vm:LookupBone(targetBoneName)
                if not targetBone or targetBone < 0 then continue end

                local targetMatrix = vm:GetBoneMatrix(targetBone)
                if not targetMatrix then continue end

                local finalMatrix = modelMatrix
                if thirdperson then
                    finalMatrix = BuildThirdPersonMatrix(track, vm, targetBone, modelBone, targetMatrix, modelMatrix, thirdpersonState)
                end

                local mTable = finalMatrix:ToTable()
                local targetTable = targetMatrix:ToTable()

                for i = 1, 4 do
                    local mi, ti = mTable[i], targetTable[i]
                    for j = 1, 4 do
                        mi[j] = matrixLerp(lerpVal, mi[j], ti[j], curve)
                    end
                end

                local m = Matrix(mTable)
                m:SetScale(scaleVec)
                vm:SetBoneMatrix(targetBone, m)
                boneCount = boneCount + 1
            end
        end

        if IsValid(handsEnt) and handsEnt ~= vm then
            handsEnt:InvalidateBoneCache()
        end
        track.debugBoneCount = boneCount
    end

    local curtimecheck = 0
    local function ProcessQueuedTracks()
        if not next(GCAL.QueuedAnims) then return end
        for queuedTrackID, queuedName in pairs(GCAL.QueuedAnims) do
            if not GCAL.ActiveTracks[queuedTrackID] and GCAL:Play(queuedName, queuedTrackID) then
                GCAL.QueuedAnims[queuedTrackID] = nil
            end
        end
    end

    local renderTracksBusy = false
    local function RenderTracks(hands, vm, ply, weapon, flags, fromHandsHook)
        if renderTracksBusy then return end
        if not IsValid(vm) then return end

        renderTracksBusy = true
        local handsEnt = IsValid(hands) and hands or (IsValid(ply) and ply:GetHands() or nil)
        if IsValid(handsEnt) then
            handsEnt:SetupBones()
        end

        curtime = CurTime()
        local alreadyUpdated = curtime == curtimecheck and !gui.IsGameUIVisible()
        if not alreadyUpdated then
            curtimecheck = curtime
            ProcessQueuedTracks()
        end

        if next(GCAL.ActiveTracks) == nil then
            if not alreadyUpdated and VManip and VManip.QueuedAnim and VManip:PlayAnim(VManip.QueuedAnim) then
                VManip.QueuedAnim = nil
            end
            renderTracksBusy = false
            return
        end

        local vment = hook.Run("VManipVMEntity", ply, weapon)
        if IsValid(vment) then vm = vment end

        for id, track in pairs(GCAL.ActiveTracks) do
            if id == "legacy_left_arm" and IsValid(ply) and not ply:Alive() then
                GCAL:StopTrack(id)
                continue
            end

            if id == "legs" then 
                if not alreadyUpdated then
                    UpdateTrack(track, id)
                end
                continue 
            end
            
            if not alreadyUpdated and UpdateTrack(track, id) then continue end
            if id == "legacy_left_arm" then
                ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags)
            else
                ApplyBones(track, vm, handsEnt, ply, weapon, false, false, flags)
            end
        end

        if IsValid(handsEnt) then handsEnt:InvalidateBoneCache() end
        renderTracksBusy = false
    end

    local thirdpersonFrame = 0
    local function RenderThirdPersonTracks(ply)
        if not GCAL:IsThirdPersonEnabled() then return end
        if ply ~= LocalPlayer() or not IsValid(ply) or not ply:Alive() then return end
        local viewEntity = ply.GetViewEntity and ply:GetViewEntity() or ply
        if not ply:ShouldDrawLocalPlayer() and viewEntity == ply then return end
        if next(GCAL.ActiveTracks) == nil then return end
        if thirdpersonFrame == FrameNumber() then return end
        thirdpersonFrame = FrameNumber()

        local weapon = ply:GetActiveWeapon()
        local alreadyUpdated = CurTime() == curtimecheck and not gui.IsGameUIVisible()
        ply:SetupBones()

        for id, track in pairs(GCAL.ActiveTracks) do
            if id == "legs" or not track.thirdperson then continue end
            if not alreadyUpdated and UpdateTrack(track, id) then continue end

            ApplyBones(track, ply, nil, ply, weapon, true)
        end
    end

    hook.Add("PreDrawPlayerHands", "GCAL_RenderHands", function(hands, vm, ply, weapon, flags)
        RenderTracks(hands, vm, ply, weapon, flags, true)
    end)

    hook.Add("PostDrawViewModel", "VManip", function(vm, ply, weapon, flags)
        if not IsValid(weapon) or not weapon:IsScripted() then return end
        RenderTracks(nil, vm, ply, weapon, flags, false)
    end)

    hook.Add("PostDrawViewModel", "GCAL_RenderVM", function(vm, ply, weapon, flags)
        if not IsValid(weapon) or not weapon:IsScripted() or weapon.UseHands then return end
        RenderTracks(nil, vm, ply, weapon, flags, false)
    end)

    hook.Add("PrePlayerDraw", "GCAL_RenderThirdPerson", function(ply)
        RenderThirdPersonTracks(ply)
    end)

    hook.Add("PreDrawViewModels", "GCAL_RenderLegs", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() or ply:ShouldDrawLocalPlayer() then return end
        local track = GCAL.ActiveTracks["legs"]
        if not track or not GCAL.Legs then return end
        GCAL.Legs:Update(ply)
        if IsValid(track.model) then
            track.model:SetupBones()
            track.model:DrawModel()
        end
    end)

    hook.Add("HUDPaint", "GCAL_DebugHUD", function()
        if not GCAL.Debug:GetBool() then return end
        local x, y = 50, 50
        draw.SimpleText("--- GCAL DEBUG HUD ---", "DermaDefault", x, y, Color(255, 255, 0))
        y = y + 20
        draw.SimpleText("Active Tracks: " .. table.Count(GCAL.ActiveTracks), "DermaDefault", x, y, Color(255, 255, 255))
        y = y + 20
        for id, track in pairs(GCAL.ActiveTracks) do
            draw.SimpleText("Track: " .. id, "DermaDefault", x + 10, y, Color(0, 255, 0))
            y = y + 15
            draw.SimpleText(" - Anim: " .. tostring(track.name), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Cycle: " .. math.Round(track.cycle, 3), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Lerp: " .. math.Round(track.lerpVal, 3), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Bones: " .. (track.debugBoneCount or 0), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 20
        end
    end)

    concommand.Add("gcal_list_anims", function()
        local names = {}

        for name in pairs(GCAL.Anims or {}) do
            names[#names + 1] = tostring(name)
        end

        table.sort(names)
        MsgC(Color(93, 210, 180), "[GCAL] Registered animations (" .. #names .. "):\n")

        for _, name in ipairs(names) do
            local anim = GCAL.Anims[name] or {}
            MsgC(Color(236, 242, 255), " - " .. name .. " [" .. tostring(anim.group_name or "default") .. "]\n")
        end
    end)

    local function GCAL_AnimAutocomplete(command, args)
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
            MsgC(Color(255, 176, 93), "[GCAL] Usage: gcal_play <animation> [track]\n")
            return
        end

        if not GCAL.Anims[name] then
            MsgC(Color(255, 106, 106), "[GCAL] Unknown animation: " .. tostring(name) .. "\n")
            return
        end

        if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then
            MsgC(Color(255, 176, 93), "[GCAL] Animation is disabled: " .. tostring(name) .. "\n")
            return
        end

        if GCAL:Play(name, trackID) then
            MsgC(Color(93, 210, 180), "[GCAL] Playing " .. tostring(name) .. (trackID and (" on " .. tostring(trackID)) or "") .. "\n")
        else
            MsgC(Color(255, 106, 106), "[GCAL] Could not play " .. tostring(name) .. "\n")
        end
    end, GCAL_AnimAutocomplete, "Play a registered GCAL animation. Usage: gcal_play <animation> [track]")

    concommand.Add("gcal_debug_sequences", function(_, _, args)
        local name = args[1]
        if not name or name == "" then
            MsgC(Color(255, 176, 93), "[GCAL] Usage: gcal_debug_sequences <animation>\n")
            return
        end

        local anim = GCAL.Anims[name]
        if not anim then
            MsgC(Color(255, 106, 106), "[GCAL] Unknown animation: " .. tostring(name) .. "\n")
            return
        end

        if not anim.model then
            MsgC(Color(255, 106, 106), "[GCAL] Animation has no model: " .. tostring(name) .. "\n")
            return
        end

        local model = ClientsideModel("models/" .. anim.model, RENDERGROUP_BOTH)
        if not IsValid(model) then
            MsgC(Color(255, 106, 106), "[GCAL] Could not create model: models/" .. tostring(anim.model) .. "\n")
            return
        end

        model:SetNoDraw(true)

        MsgC(Color(93, 210, 180), "[GCAL] Sequence debug for " .. tostring(name) .. "\n")
        MsgC(Color(236, 242, 255), " - model: " .. tostring(anim.model) .. "\n")
        MsgC(Color(236, 242, 255), " - explicit sequence: " .. tostring(anim.sequence or "<none>") .. "\n")

        local sequenceList = model.GetSequenceList and (model:GetSequenceList() or {}) or {}
        MsgC(Color(236, 242, 255), " - sequences (" .. tostring(#sequenceList) .. "):\n")
        if #sequenceList == 0 then
            MsgC(Color(255, 176, 93), "   ! model loaded with zero sequences; this usually means the model content is missing, broken, or not actually the animated asset GCAL expects.\n")
        end
        for _, sequenceName in ipairs(sequenceList) do
            MsgC(Color(236, 242, 255), "   * " .. tostring(sequenceName) .. "\n")
        end

        model:Remove()
    end, GCAL_AnimAutocomplete, "Print the runtime model sequence list for a registered animation. Usage: gcal_debug_sequences <animation>")

    concommand.Add("gcal_debug_track", function(_, _, args)
        local trackID = args[1] or "legacy_left_arm"
        local track = GCAL.ActiveTracks[trackID]

        if not track then
            MsgC(Color(255, 176, 93), "[GCAL] No active track: " .. tostring(trackID) .. "\n")
            return
        end

        MsgC(Color(93, 210, 180), "[GCAL] Track debug for " .. tostring(trackID) .. "\n")
        MsgC(Color(236, 242, 255), " - anim: " .. tostring(track.name) .. "\n")
        MsgC(Color(236, 242, 255), " - model: " .. tostring(track.data and track.data.model or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - sequence: " .. tostring(track.sequenceName or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - seqID: " .. tostring(track.seqID) .. "\n")
        MsgC(Color(236, 242, 255), " - cycle: " .. tostring(math.Round(track.cycle or 0, 4)) .. "\n")
        MsgC(Color(236, 242, 255), " - lerp: " .. tostring(math.Round(track.lerpVal or 0, 4)) .. "\n")
        MsgC(Color(236, 242, 255), " - poseOnlyLegacy: " .. tostring(track.poseOnlyLegacy or false) .. "\n")
        MsgC(Color(236, 242, 255), " - debugBoneCount: " .. tostring(track.debugBoneCount or 0) .. "\n")

        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        local vm = IsValid(ply) and ply:GetViewModel() or nil
        local vment = hook.Run("VManipVMEntity", ply, weapon)
        if IsValid(vment) then vm = vment end

        if not IsValid(vm) then
            MsgC(Color(255, 176, 93), " - no valid viewmodel entity\n")
            return
        end

        local flip = GetLegacyFlipState(weapon)
        if IsValid(weapon) then
            MsgC(Color(236, 242, 255), " - weapon class: " .. tostring(weapon:GetClass()) .. "\n")
            MsgC(Color(236, 242, 255), " - ViewModelFlipDefault: " .. tostring(flip.lefty) .. "\n")
            MsgC(Color(236, 242, 255), " - ViewModelFlip: " .. tostring(flip.flippedNow) .. "\n")
            MsgC(Color(236, 242, 255), " - flipmode: " .. tostring(flip.flipmode) .. "\n")
            MsgC(Color(236, 242, 255), " - legacy target side: " .. tostring(flip.targetSide) .. "\n")
        end

        vm:SetupBones()
        if IsValid(track.model) then track.model:SetupBones() end

        local matched = 0
        local samples = 0
        for k, boneName in ipairs(track.bones or {}) do
            local targetBoneName = boneName
            if track.data and track.data.legacy then
                targetBoneName = flip.targetBones[k] or boneName
            end
            local targetBone = vm:LookupBone(targetBoneName)
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            sourceBoneName = sourceBoneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or sourceBoneName
            local modelBone = IsValid(track.model) and track.model:LookupBone(sourceBoneName) or nil
            if targetBone ~= nil and targetBone >= 0 and modelBone ~= nil and modelBone >= 0 then
                matched = matched + 1
                MsgC(Color(236, 242, 255), "   * " .. tostring(targetBoneName) .. " <- " .. tostring(sourceBoneName) .. "\n")

                if samples < 3 then
                    local targetMatrix = vm:GetBoneMatrix(targetBone)
                    local sourceMatrix = track.model:GetBoneMatrix(modelBone)
                    if targetMatrix and sourceMatrix then
                        local targetPos = targetMatrix:GetTranslation()
                        local sourcePos = sourceMatrix:GetTranslation()
                        local delta = sourcePos - targetPos
                        MsgC(
                            Color(200, 220, 255),
                            "     source-target delta: " ..
                            string.format("%.3f, %.3f, %.3f", delta.x, delta.y, delta.z) .. "\n"
                        )
                        samples = samples + 1
                    end
                end
            end
        end

        MsgC(Color(236, 242, 255), " - matched bones: " .. tostring(matched) .. "\n")
    end, nil, "Debug an active GCAL track. Usage: gcal_debug_track [track]")

    concommand.Add("gcal_stop", function(_, _, args)
        local trackID = args[1]

        if trackID and trackID ~= "" then
            GCAL:StopTrack(trackID)
            MsgC(Color(93, 210, 180), "[GCAL] Stopped track " .. tostring(trackID) .. "\n")
            return
        end

        local stopped = 0
        for activeTrackID in pairs(GCAL.ActiveTracks or {}) do
            GCAL:StopTrack(activeTrackID)
            stopped = stopped + 1
        end

        MsgC(Color(93, 210, 180), "[GCAL] Stopped " .. tostring(stopped) .. " active track(s)\n")
    end, nil, "Stop one GCAL track, or every active track when no track is provided. Usage: gcal_stop [track]")

    hook.Add("NeedsDepthPass", "GCAL_VManipCamAttachment", function()
        local track = GCAL.ActiveTracks["legacy_left_arm"]
        if not track then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then
            GCAL:StopTrack("legacy_left_arm")
            return
        end

        if IsValid(track.camModel) then
            track.camModel:SetupBones()
            local attachments = track.camModel:GetAttachments()
            if #attachments > 0 then
                track.attachment = track.camModel:GetAttachment(attachments[1].id)
            end
        end
    end)

    hook.Add("CalcView", "GCAL_VManipCam", function(ply, origin, angles, fov, self)
        if self == true then return end
        local track = GCAL.ActiveTracks["legacy_left_arm"]
        if not track or not track.attachment then return end
        if ply:GetViewEntity() ~= ply or ply:ShouldDrawLocalPlayer() then return end

        local camang = track.attachment.Ang - (track.camAng or properang)
        angles.x = angles.x + camang.x * (track.camAngInt[1] or 1)
        angles.y = angles.y + camang.y * (track.camAngInt[2] or 1)
        angles.z = angles.z + camang.z * (track.camAngInt[3] or 1)
    end)

    hook.Add("StartCommand", "GCAL_VManipPreventReload", function(ply, ucmd)
        if VManip and VManip:IsActive() and not ply:ShouldDrawLocalPlayer() then
            ucmd:RemoveKey(IN_RELOAD)
        end
    end)

    hook.Add("TFA_PreReload", "GCAL_VManipPreventTFAReload", function()
        if VManip and VManip:IsActive() then return "no" end
    end)

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
        if trackID == "" then trackID = "default" end
        GCAL:StopTrack(trackID)
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
end
