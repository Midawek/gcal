GCAL = GCAL or {}

local NET_NAME = "GCAL_MP_Sync"
local OP_SEGMENT, OP_START, OP_STOP, OP_HOLDQUIT = 0, 1, 2, 3
local MAX_STRING = 96

if SERVER then
    util.AddNetworkString(NET_NAME)

    local BUCKET_MAX, BUCKET_REGEN = 20, 10
    local START_BUCKET_MAX, START_BUCKET_REGEN = 4, 1

    local function TakeToken(ply, tokensKey, lastKey, max, regen)
        local now = CurTime()
        local tokens = ply[tokensKey] or max
        tokens = math.min(max, tokens + (now - (ply[lastKey] or now)) * regen)
        ply[lastKey] = now
        if tokens < 1 then
            ply[tokensKey] = tokens
            return false
        end
        ply[tokensKey] = tokens - 1
        return true
    end

    net.Receive(NET_NAME, function(_, ply)
        if not IsValid(ply) then return end
        if not TakeToken(ply, "GCAL_MPTokens", "GCAL_MPLast", BUCKET_MAX, BUCKET_REGEN) then return end

        local op = net.ReadUInt(2)
        local trackID = net.ReadString()
        if #trackID == 0 or #trackID > MAX_STRING then return end

        local name, lastSegment
        if op == OP_START or op == OP_SEGMENT then
            name = net.ReadString()
            if #name == 0 or #name > MAX_STRING then return end
            if op == OP_SEGMENT then
                lastSegment = net.ReadBool()
            elseif not TakeToken(ply, "GCAL_MPStartTokens", "GCAL_MPStartLast", START_BUCKET_MAX,
                    START_BUCKET_REGEN) then
                return
            end
        elseif op ~= OP_STOP and op ~= OP_HOLDQUIT then
            return
        end

        local filter
        if name then
            filter = RecipientFilter()
            filter:AddPVS(ply:EyePos())
            filter:RemovePlayer(ply)
            if filter:GetCount() == 0 then return end
        end

        net.Start(NET_NAME)
        net.WriteEntity(ply)
        net.WriteUInt(op, 2)
        net.WriteString(trackID)
        if name then net.WriteString(name) end
        if op == OP_SEGMENT then net.WriteBool(lastSegment) end
        if filter then
            net.Send(filter)
        else
            net.SendOmit(ply)
        end
    end)

    return
end

GCAL.MPEnabled = CreateClientConVar("gcal_mp_tpik", "1", true, false,
    "Render other players' GCAL TPIK animations (multiplayer).")

local function Send(op, trackID, name, lastSegment)
    if game.SinglePlayer() then return end
    net.Start(NET_NAME)
    net.WriteUInt(op, 2)
    net.WriteString(trackID)
    if op == OP_START or op == OP_SEGMENT then net.WriteString(name) end
    if op == OP_SEGMENT then net.WriteBool(lastSegment == true) end
    net.SendToServer()
end

local function ShouldSync(trackID, track)
    if trackID == "legs" or not track then return false end
    local data = track.data
    return data == nil or (data.thirdperson ~= false and not data.local_only)
end

hook.Add("GCALTrackStarted", "GCAL_MP_Announce", function(trackID, name, track)
    if not ShouldSync(trackID, track) then return end
    Send(OP_START, tostring(trackID), tostring(name))
end)

hook.Add("GCALTrackStopped", "GCAL_MP_Announce", function(trackID, name, track)
    if not ShouldSync(trackID, track) then return end
    Send(OP_STOP, tostring(trackID))
end)

hook.Add("GCALHoldQuit", "GCAL_MP_Announce", function(trackID)
    local track = GCAL.ActiveTracks and GCAL.ActiveTracks[trackID]
    if not ShouldSync(trackID, track) then return end
    Send(OP_HOLDQUIT, tostring(trackID))
end)

hook.Add("GCALPlaySegment", "GCAL_MP_Announce", function(trackID, name, sequence, lastSegment)
    local track = GCAL.ActiveTracks and GCAL.ActiveTracks[trackID]
    if not ShouldSync(trackID, track) or sequence == nil then return end
    Send(OP_SEGMENT, tostring(trackID), tostring(sequence), lastSegment)
end)

local MAX_TRACKS_PER_PLAYER = 4
local SEGMENT_STOP_TIMEOUT = 30
local TRACK_MAX_LIFETIME = 120
local MAX_DRAW_DIST_SQR = 2000 * 2000

local TRACK_MODEL_KEYS = { "model", "camModel", "tpikModel", "thirdpersonModel", "legModel" }

GCAL.MPRemoteTracks = GCAL.MPRemoteTracks or {}
local remoteTracks = GCAL.MPRemoteTracks

local function DestroyTrack(track)
    if not track then return end
    for _, key in ipairs(TRACK_MODEL_KEYS) do
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
    if ply:IsDormant() or ply:GetPos():DistToSqr(EyePos()) > MAX_DRAW_DIST_SQR then
        RemoveRemoteTrack(ply, trackID)
        return
    end

    local I = GCAL.MPInternal
    if not I then return end

    local anim = GCAL.Anims and GCAL.Anims[name]
    if not anim or not anim.model or anim.thirdperson == false then return end
    if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then return end
    if GCAL.IsAnimTPIKEnabled and not GCAL:IsAnimTPIKEnabled(name) then return end

    RemoveRemoteTrack(ply, trackID)

    local tracks = remoteTracks[ply]
    if tracks and table.Count(tracks) >= MAX_TRACKS_PER_PLAYER then return end

    local track = I.CreateTrack(name, anim)
    if not track or not IsValid(track.model) then DestroyTrack(track) return end

    local ok = pcall(function()
        if not I.SetupSourceModels(track, anim, true) then error("setup") end
        I.ResolveFirstPersonSequence(track, name, anim)
        I.SetupThirdPerson(track, name, anim)
    end)
    if not ok or not track.thirdperson then
        DestroyTrack(track)
        return
    end

    track.remoteTrackID = trackID
    remoteTracks[ply] = remoteTracks[ply] or {}
    remoteTracks[ply][trackID] = track
end

local function PlayRemoteSegment(track, sequence, lastSegment)
    if not track.segmented or track.lastSegment or not IsValid(track.model) then return end
    local seq = track.model:LookupSequence(sequence)
    if seq == -1 then return end

    local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
    track.model:ResetSequence(seq)
    track.model:SetPlaybackRate(speedMultiplier)
    if IsValid(track.camModel) then
        track.camModel:ResetSequence(seq)
        track.camModel:SetPlaybackRate(speedMultiplier)
    end
    if IsValid(track.tpikModel) and track.tpikSeqID and track.tpikSeqID ~= -1 then
        track.tpikModel:ResetSequence(track.tpikSeqID)
        track.tpikModel:SetPlaybackRate(speedMultiplier)
    end
    if IsValid(track.thirdpersonModel) then
        track.thirdpersonModel:ResetSequence(track.tpikSequenceRequested and track.tpikSeqID or seq)
        track.thirdpersonModel:SetPlaybackRate(speedMultiplier)
    end
    track.curSegment = sequence
    track.cycle = 0
    track.segmentFinished = false
    track.segmentFinishTime = nil
    track.segmentCount = (track.segmentCount or 0) + 1
    if lastSegment then
        track.lastSegment = true
        track.lerpPeakTime = CurTime() + track.lerpPeak
    end
end

net.Receive(NET_NAME, function()
    local ply = net.ReadEntity()
    local op = net.ReadUInt(2)
    local trackID = net.ReadString()
    local name = (op == OP_START or op == OP_SEGMENT) and net.ReadString() or nil
    local lastSegment = op == OP_SEGMENT and net.ReadBool() or false

    if not IsValid(ply) or ply == LocalPlayer() then return end
    if not GCAL.MPEnabled:GetBool() then return end

    if op == OP_START then
        StartRemoteTrack(ply, trackID, name)
    elseif op == OP_SEGMENT then
        local track = remoteTracks[ply] and remoteTracks[ply][trackID]
        if track then PlayRemoteSegment(track, name, lastSegment) end
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

local function UpdateRemoteTrack(track, dormant)
    local curTime = CurTime()
    GCAL.MPInternal.AdvanceTrackTiming(track, curTime, FrameTime(), dormant)

    if track.cycle >= 1 and not track.loop then
        if track.segmented and not track.lastSegment then
            track.segmentFinished = true
            track.segmentFinishTime = track.segmentFinishTime or curTime
            return curTime - track.segmentFinishTime > SEGMENT_STOP_TIMEOUT
        end
        if track.segmented then return track.lerpVal >= 1 end
        return true
    end

    if curTime - track.realStartTime > TRACK_MAX_LIFETIME then return true end

    return false
end

hook.Add("Think", "GCAL_MP_UpdateRemote", function()
    if next(remoteTracks) == nil then return end

    for ply, tracks in pairs(remoteTracks) do
        if not IsValid(ply) or not ply:Alive() or not GCAL.MPEnabled:GetBool() then
            RemoveAllRemoteTracks(ply)
        else
            local dormant = ply:IsDormant()
            for id, track in pairs(tracks) do
                if UpdateRemoteTrack(track, dormant) then
                    RemoveRemoteTrack(ply, id)
                end
            end
        end
    end
end)

hook.Add("EntityRemoved", "GCAL_MP_Cleanup", function(ent)
    if remoteTracks[ent] then RemoveAllRemoteTracks(ent) end
end)

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
        baseMatrices = I.CollectTPIKBaseMatrices(ply, remoteTracks[ply])
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
