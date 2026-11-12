-- GCAL multiplayer TPIK layer.
--
-- Runs on top of the existing GCAL core without changing how local playback works:
--   * The local client announces its own track start/stop/hold-quit (via the existing
--     GCALTrackStarted / GCALTrackStopped / GCALHoldQuit hooks) to the server.
--   * The server relays that to every other client together with the player entity.
--   * Every other client builds a lightweight "remote track" for that player and feeds it
--     through the very same TPIK solver (GCAL.MPInternal.ApplyThirdPersonBones) that the
--     local player uses, so both look identical.
-- Remote tracks live in their own table and never touch GCAL.ActiveTracks.

GCAL = GCAL or {}

local NET_NAME = "GCAL_MP_Sync"
local OP_START, OP_STOP, OP_HOLDQUIT = 1, 2, 3
local MAX_STRING = 96

if SERVER then
    util.AddNetworkString(NET_NAME)

    -- Token bucket per player so a client can't spam the relay.
    local BUCKET_MAX, BUCKET_REGEN = 20, 10

    net.Receive(NET_NAME, function(_, ply)
        if not IsValid(ply) then return end

        local now = CurTime()
        local tokens = ply.GCAL_MPTokens or BUCKET_MAX
        tokens = math.min(BUCKET_MAX, tokens + (now - (ply.GCAL_MPLast or now)) * BUCKET_REGEN)
        ply.GCAL_MPLast = now
        if tokens < 1 then
            ply.GCAL_MPTokens = tokens
            return
        end
        ply.GCAL_MPTokens = tokens - 1

        local op = net.ReadUInt(2)
        local trackID = net.ReadString()
        if #trackID == 0 or #trackID > MAX_STRING then return end

        local name
        if op == OP_START then
            name = net.ReadString()
            if #name == 0 or #name > MAX_STRING then return end
        elseif op ~= OP_STOP and op ~= OP_HOLDQUIT then
            return
        end

        net.Start(NET_NAME)
        net.WriteEntity(ply)
        net.WriteUInt(op, 2)
        net.WriteString(trackID)
        if name then net.WriteString(name) end
        net.SendOmit(ply)
    end)

    return
end

----------------------------------------------------------------------------------------------
-- CLIENT
----------------------------------------------------------------------------------------------

GCAL.MPEnabled = CreateClientConVar("gcal_mp_tpik", "1", true, false,
    "Render other players' GCAL TPIK animations (multiplayer).")

local function Send(op, trackID, name)
    if game.SinglePlayer() then return end
    net.Start(NET_NAME)
    net.WriteUInt(op, 2)
    net.WriteString(trackID)
    if op == OP_START then net.WriteString(name) end
    net.SendToServer()
end

-- Announce local track events -------------------------------------------------------------

hook.Add("GCALTrackStarted", "GCAL_MP_Announce", function(trackID, name, track)
    if trackID == "legs" or not track or not track.thirdperson then return end
    if track.data and track.data.local_only then return end
    Send(OP_START, tostring(trackID), tostring(name))
end)

hook.Add("GCALTrackStopped", "GCAL_MP_Announce", function(trackID, name, track)
    if trackID == "legs" or not track or not track.thirdperson then return end
    Send(OP_STOP, tostring(trackID))
end)

hook.Add("GCALHoldQuit", "GCAL_MP_Announce", function(trackID)
    if trackID == "legs" then return end
    local track = GCAL.ActiveTracks and GCAL.ActiveTracks[trackID]
    if not track or not track.thirdperson then return end
    Send(OP_HOLDQUIT, tostring(trackID))
end)

-- Remote tracks ---------------------------------------------------------------------------

local remoteTracks = {} -- [ply][trackID] = track

local function DestroyTrack(track)
    if not track then return end
    for _, key in ipairs({ "model", "camModel", "tpikModel", "thirdpersonModel", "legModel" }) do
        if IsValid(track[key]) then track[key]:Remove() end
    end
end

local function RemoveRemoteTrack(ply, trackID)
    local tracks = remoteTracks[ply]
    if not tracks or not tracks[trackID] then return end
    DestroyTrack(tracks[trackID])
    tracks[trackID] = nil
    if next(tracks) == nil then remoteTracks[ply] = nil end
end

local function RemoveAllRemoteTracks(ply)
    local tracks = remoteTracks[ply]
    if not tracks then return end
    for _, track in pairs(tracks) do DestroyTrack(track) end
    remoteTracks[ply] = nil
end

local function StartRemoteTrack(ply, trackID, name)
    local I = GCAL.MPInternal
    if not I then return end

    local anim = GCAL.Anims and GCAL.Anims[name]
    if not anim or not anim.model or anim.thirdperson == false then return end
    if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then return end
    if GCAL.IsAnimTPIKEnabled and not GCAL:IsAnimTPIKEnabled(name) then return end

    RemoveRemoteTrack(ply, trackID)

    -- Cap how many tracks one player can hold on us.
    local tracks = remoteTracks[ply]
    if tracks and table.Count(tracks) >= 4 then return end

    local track = I.CreateTrack(name, anim)
    if not track or not IsValid(track.model) then DestroyTrack(track) return end

    local ok = pcall(function()
        if not I.SetupSourceModels(track, anim) then error("setup") end
        I.ResolveFirstPersonSequence(track, name, anim)
        I.SetupThirdPerson(track, name, anim)
    end)
    if not ok or not track.thirdperson then
        DestroyTrack(track)
        return
    end

    -- The cam model is only used for first-person camera shake.
    if IsValid(track.camModel) then track.camModel:Remove() track.camModel = nil end

    track.remoteTrackID = trackID
    remoteTracks[ply] = remoteTracks[ply] or {}
    remoteTracks[ply][trackID] = track
end

net.Receive(NET_NAME, function()
    local ply = net.ReadEntity()
    local op = net.ReadUInt(2)
    local trackID = net.ReadString()
    local name = op == OP_START and net.ReadString() or nil

    if not IsValid(ply) or ply == LocalPlayer() then return end
    if not GCAL.MPEnabled:GetBool() then return end

    if op == OP_START then
        StartRemoteTrack(ply, trackID, name)
    elseif op == OP_STOP then
        RemoveRemoteTrack(ply, trackID)
    elseif op == OP_HOLDQUIT then
        local track = remoteTracks[ply] and remoteTracks[ply][trackID]
        if track then
            track.holdQuit = true
            if track.segmented then track.lastSegment = true end
        end
    end
end)

-- Per-track update: same timing logic as the core UpdateTrack, minus sounds, callbacks,
-- legacy VManip sync and anything that would touch the local player's tracks.
local function UpdateRemoteTrack(track)
    local curtime = CurTime()
    local dt = FrameTime()

    if track.delayStart and track.delayStart > 0 and curtime < track.realStartTime + track.delayStart then
        return false
    end

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

    local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
    if not track.gestureOnHold then
        track.cycle = track.cycle + dt * speedMultiplier
    end

    if not track.poseOnlyLegacy then
        if IsValid(track.model) then
            track.model:SetCycle(track.cycle)
            track.model:InvalidateBoneCache()
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

    if (curtime < track.lerpPeakTime or (track.segmented and not track.lastSegment))
        and (not track.gestureOnHold or track.gesturePastHold)
    then
        track.lerpVal = math.Clamp((track.lerpVal or 1) - (dt * 7) * track.lerpSpeedIn, 0, 1)
    elseif not track.loop and (not track.gestureOnHold or track.gesturePastHold) then
        if not track.segmented or track.lastSegment then
            track.lerpVal = math.Clamp((track.lerpVal or 1) + (dt * 7) * track.lerpSpeedOut, 0, 1)
        end
    end

    if track.cycle >= 1 and not track.loop then
        if track.segmented then
            -- Segment progression isn't synced: wait for the owner's stop message,
            -- with a failsafe so a lost packet can't leave an arm stuck forever.
            track.segmentFinished = true
            track.segmentFinishTime = track.segmentFinishTime or curtime
            return curtime - track.segmentFinishTime > 30
        end
        return true
    end

    -- Failsafe for held / looping animations whose stop message never arrived.
    if curtime - track.realStartTime > 120 then return true end

    return false
end

hook.Add("Think", "GCAL_MP_UpdateRemote", function()
    if next(remoteTracks) == nil then return end

    for ply, tracks in pairs(remoteTracks) do
        if not IsValid(ply) or not ply:Alive() or not GCAL.MPEnabled:GetBool() then
            RemoveAllRemoteTracks(ply)
        else
            for id, track in pairs(tracks) do
                if UpdateRemoteTrack(track) then
                    RemoveRemoteTrack(ply, id)
                end
            end
        end
    end
end)

hook.Add("EntityRemoved", "GCAL_MP_Cleanup", function(ent)
    if remoteTracks[ent] then RemoveAllRemoteTracks(ent) end
end)

-- Rendering -------------------------------------------------------------------------------

local MAX_DRAW_DIST_SQR = 2000 * 2000

local function CanRender(ply)
    if ply == LocalPlayer() or not remoteTracks[ply] then return false end
    if not GCAL.MPEnabled:GetBool() then return false end
    if not GCAL.InternalThirdPersonEnabled or not GCAL.ThirdPerson:GetBool() then return false end
    if ply:IsDormant() or not ply:Alive() then return false end
    if ply:GetPos():DistToSqr(EyePos()) > MAX_DRAW_DIST_SQR then return false end
    return true
end

hook.Add("PrePlayerDraw", "GCAL_MP_RenderThirdPerson", function(ply)
    if not CanRender(ply) then return end

    local I = GCAL.MPInternal
    if not I then return end

    local frame = FrameNumber()
    local needsSolve = false
    for _, track in pairs(remoteTracks[ply]) do
        if track.thirdpersonSolveFrame ~= frame then needsSolve = true break end
    end

    local baseMatrices
    if needsSolve then
        ply:InvalidateBoneCache()
        ply:SetupBones()

        baseMatrices = {}
        for bone = 0, ply:GetBoneCount() - 1 do
            local matrix = ply:GetBoneMatrix(bone)
            if matrix then baseMatrices[bone] = Matrix(matrix:ToTable()) end
        end
    end

    local weapon = ply:GetActiveWeapon()
    for _, track in pairs(remoteTracks[ply]) do
        if track.thirdpersonSolveFrame == frame then
            I.ApplyCachedThirdPersonBones(track, ply)
        elseif baseMatrices then
            I.ApplyThirdPersonBones(track, ply, weapon, baseMatrices)
        end
    end
end)

hook.Add("PostPlayerDraw", "GCAL_MP_RenderThirdPersonModels", function(ply)
    if not CanRender(ply) then return end

    for _, track in pairs(remoteTracks[ply]) do
        local model = track.thirdpersonModel
        local readyFrame = track.thirdpersonModelReadyFrame or -1
        local readyTime = track.thirdpersonModelReadyTime or 0
        if IsValid(model) and (readyFrame >= FrameNumber() - 1 or RealTime() - readyTime <= 0.1) then
            model:DrawModel()
        end
    end
end)
