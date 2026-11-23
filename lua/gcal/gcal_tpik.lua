if not CLIENT then return end

GCAL = GCAL or {}

-- Simple TPIK: direct bone copy (ARC9-style)

function GCAL.InstallTPIK(deps)
    deps = deps or {}
    local PlaceTPIKTrackModel = deps.PlaceTPIKTrackModel or deps.PlaceTrackModel
    local GetLegacyFlipState = deps.GetLegacyFlipState
    local GetTrackTargetBones = deps.GetTrackTargetBones
    local GetTrackModelScale = deps.GetTrackModelScale
    local GetTrackBlendFactor = deps.GetTrackBlendFactor or function(track, t, curve)
        return GCAL.Lerp.Legacy(t, 0, 1, curve or 1)
    end

    -- Bone lookups share core's per-entity cache (see BoneCache in gcal_core.lua).
    local BoneCache, CachedBone = deps.BoneCache, deps.CachedBone
    local childBoneCache = setmetatable({}, { __mode = "k" })

    -- Bone index or nil. Hot loops grab BoneCache(ent) once and call CachedBone directly.
    local function GetBone(ent, name)
        if not IsValid(ent) or not name then return nil end
        local idx = CachedBone(BoneCache(ent), ent, name)
        return idx >= 0 and idx or nil
    end

    local UPPER_ARM = { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm" }

    -- GetBodyGroups() builds a table of every group and submodel; only the ids are needed.
    local bodygroupIDs = {}
    local function GetBodygroupIDs(ent)
        local model = ent:GetModel() or ""
        local ids = bodygroupIDs[model]
        if not ids then
            ids = {}
            for _, bg in ipairs(ent:GetBodyGroups() or {}) do ids[#ids + 1] = bg.id end
            bodygroupIDs[model] = ids
        end
        return ids
    end

    -- model_offset ({ [bone name] = Vector }) resolved to bone indices once per model / options.
    local function GetCloneOffsetMap(track, model, cloneOffsets)
        local modelName = model:GetModel() or ""
        local cached = track.tpikCloneOffsetMap
        if cached and cached.model == modelName and cached.offsets == cloneOffsets then return cached.map end

        local map = {}
        for boneName, boneOffset in pairs(cloneOffsets) do
            local bone = GetBone(model, boneName)
            if bone then map[bone] = boneOffset end
        end
        track.tpikCloneOffsetMap = { model = modelName, offsets = cloneOffsets, map = map }
        return map
    end
    local HAND = { "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand" }

    local function GetChildren(ent, bone)
        if not IsValid(ent) or not bone or bone < 0 then return {} end
        local model = ent:GetModel() or ""
        local cache = childBoneCache[ent]
        if not cache or cache.model ~= model then
            cache = { model = model, children = {} }
            childBoneCache[ent] = cache
        end
        local children = cache.children[bone]
        if not children then
            children = ent:GetChildBones(bone) or {}
            cache.children[bone] = children
        end
        return children
    end

    local function GetSourceModel(track)
        if track and IsValid(track.tpikModel) then return track.tpikModel end
        return track and track.model or nil
    end

    local function GetOptions(track)
        if track and istable(track.tpikOptions) then return track.tpikOptions end
        if track and GCAL.GetTPIKOptions then return GCAL:GetTPIKOptions(track.name) end
        return nil
    end

    local function Opt(track, key)
        local options = GetOptions(track)
        if options then return options[key] end
        return nil
    end

    -- lock_bones / scale_bones / blend_per_bone match bone names by substring. That matching is
    -- resolved once per track and bone name instead of running string.find every frame.
    -- track.tpikBoneRules is cleared whenever the track's TPIK options change.
    local function GetBoneRules(track, boneName)
        local rules = track.tpikBoneRules
        if not rules then
            rules = {}
            track.tpikBoneRules = rules
        end

        local rule = rules[boneName]
        if rule then return rule end

        rule = { locked = false, scale = 1, blend = nil }
        for _, lockName in ipairs(Opt(track, "lock_bones") or {}) do
            if string.find(boneName, tostring(lockName), 1, true) then
                rule.locked = true
                break
            end
        end
        for scaleName, scale in pairs(Opt(track, "scale_bones") or {}) do
            if string.find(boneName, tostring(scaleName), 1, true) then
                rule.scale = tonumber(scale) or 1
                break
            end
        end
        for blendName, boneBlend in pairs(Opt(track, "blend_per_bone") or {}) do
            if string.find(boneName, tostring(blendName), 1, true) then
                rule.blend = tonumber(boneBlend)
                break
            end
        end

        rules[boneName] = rule
        return rule
    end

    local function OptAdd(track, key)
        if not GCAL.GetTPIKOptionAdd then return 0 end
        return GCAL:GetTPIKOptionAdd(track.name, key) or 0
    end

    -- Hidden material for the third-person model clone
    local hiddenMat = CreateMaterial("gcal_tpik_hidden", "UnlitGeneric", {
        ["$basetexture"] = "color/white",
        ["$translucent"] = "1",
        ["$alpha"] = "0",
        ["$vertexalpha"] = "1"
    })
    local hiddenMatName = hiddenMat:GetName()
    local armTokens = {
        "c_arm", "/arms", "_arms", "arm_", "forearm",
        "/hands", "_hands", "hand_", "glove", "sleeve", "player_shared"
    }

    local function ConfigureCloneMaterials(track)
        local model = track.thirdpersonModel
        if not IsValid(model) or track.thirdpersonMaterialsConfigured then return end
        track.thirdpersonMaterialsConfigured = true

        local extraHide = Opt(track, "hide_materials")
        if isstring(extraHide) then extraHide = { extraHide } end
        local keep = Opt(track, "keep_materials")
        if isstring(keep) then keep = { keep } end

        local visible = 0
        local autoHidden = {}
        local materials = model:GetMaterials() or {}

        for index, name in ipairs(materials) do
            local lower = string.lower(name)
            local hide = false
            local byAuto = false
            for _, token in ipairs(armTokens) do
                if string.find(lower, token, 1, true) then hide = true; byAuto = true; break end
            end
            for _, token in ipairs(extraHide or {}) do
                if string.find(lower, string.lower(tostring(token)), 1, true) then hide = true; byAuto = false; break end
            end
            for _, token in ipairs(keep or {}) do
                if string.find(lower, string.lower(tostring(token)), 1, true) then hide = false; byAuto = false; break end
            end
            if hide then
                model:SetSubMaterial(index - 1, hiddenMatName)
                if byAuto then autoHidden[#autoHidden + 1] = index - 1 end
            else
                visible = visible + 1
            end
        end

        -- If everything got hidden, restore auto-hidden ones
        if #materials > 0 and visible == 0 and #autoHidden > 0 then
            for _, idx in ipairs(autoHidden) do model:SetSubMaterial(idx) end
            visible = #autoHidden
            track.debugThirdPersonModel = "visible: material fallback"
        end
        track.thirdpersonModelHasVisibleMaterials = #materials == 0 or visible > 0
    end

    -- Third-person model clone: visual copy of the source viewmodel for props
    -- cloneShift moves the clone from the source model (placed at the eyes) to where the arms
    -- were actually solved; cloneAngles is the frame for the clone_offset_x/y/z options.
    local function PrepareClone(track, handPos, cloneShift, cloneAngles)
        local model = track.thirdpersonModel
        local source = GetSourceModel(track)
        if not IsValid(model) or Opt(track, "model") == false then return end
        if not IsValid(source) then return end

        track.thirdpersonModelReadyFrame = nil
        track.debugThirdPersonModelDistance = nil

        ConfigureCloneMaterials(track)
        if not track.thirdpersonModelHasVisibleMaterials then return end

        local maxDist = tonumber(Opt(track, "model_max_distance")) or 32
        local explicitBoneName = Opt(track, "model_bone")
        local explicitBone = isstring(explicitBoneName) and GetBone(source, explicitBoneName) or nil

        local boneDist, hitboxDist
        local function Consider(bone, pos, isHitbox)
            if not handPos or not pos then return end
            if explicitBone ~= nil and bone ~= explicitBone then return end
            local d = pos:Distance(handPos)
            if isHitbox then
                hitboxDist = hitboxDist and math.min(hitboxDist, d) or d
            else
                boneDist = boneDist and math.min(boneDist, d) or d
            end
        end

        model:SetPos(source:GetPos())
        model:SetAngles(source:GetAngles())
        model:SetModelScale(track.modelScale or 1)
        model:SetSkin(source:GetSkin())
        for _, id in ipairs(GetBodygroupIDs(source)) do
            model:SetBodygroup(id, source:GetBodygroup(id))
        end
        model:SetCycle(track.cycle or 0)
        model:SetupBones()

        -- Clone offsets: whole-clone shift + per-bone tweaks
        local cloneOffsetX = (Opt(track, "clone_offset_x") or 0) + OptAdd(track, "clone_offset_x")
        local cloneOffsetY = (Opt(track, "clone_offset_y") or 0) + OptAdd(track, "clone_offset_y")
        local cloneOffsetZ = (Opt(track, "clone_offset_z") or 0) + OptAdd(track, "clone_offset_z")
        local cloneOffsets = Opt(track, "model_offset")
        local offsetByBone = istable(cloneOffsets) and GetCloneOffsetMap(track, model, cloneOffsets) or nil

        -- Whole-clone shift: follow the solved hand, then forward/right/up offsets in render-angle space
        local shift = Vector(0, 0, 0)
        if cloneShift then shift:Add(cloneShift) end
        if cloneOffsetX ~= 0 or cloneOffsetY ~= 0 or cloneOffsetZ ~= 0 then
            if cloneAngles then
                shift:Add(cloneAngles:Forward() * cloneOffsetX + cloneAngles:Right() * cloneOffsetY + cloneAngles:Up() * cloneOffsetZ)
            else
                shift:Add(Vector(cloneOffsetX, cloneOffsetY, cloneOffsetZ))
            end
        end
        local hasShift = not shift:IsZero()

        local copies = {}
        for bone = 0, model:GetBoneCount() - 1 do
            -- GetBoneMatrix already returns a fresh copy, safe to modify.
            local m = source:GetBoneMatrix(bone) or model:GetBoneMatrix(bone)
            if m then
                copies[bone] = m
                local pos = m:GetTranslation()
                if hasShift then
                    pos = pos + shift
                    m:SetTranslation(pos)
                end
                local boneOffset = offsetByBone and offsetByBone[bone]
                if boneOffset then
                    pos = pos + boneOffset
                    m:SetTranslation(pos)
                end
                model:SetBoneMatrix(bone, m)
                model:SetBonePosition(bone, pos, m:GetAngles())
                Consider(bone, pos, false)
            end
        end

        if model.GetHitBoxCount and model.GetHitBoxBone and model.GetHitBoxBounds then
            for hb = 0, (model:GetHitBoxCount(0) or 0) - 1 do
                local bone = model:GetHitBoxBone(hb, 0)
                local mat = bone and copies[bone]
                if mat then
                    local mins, maxs = model:GetHitBoxBounds(hb, 0)
                    if mins and maxs then Consider(bone, mat * ((mins + maxs) * 0.5), true) end
                end
            end
        end

        if handPos and maxDist > 0 then
            local dist = (hitboxDist or boneDist) and math.min(hitboxDist or math.huge, boneDist or math.huge)
            if not dist then dist = source:GetPos():Distance(handPos) end
            if dist and dist > maxDist then
                track.debugThirdPersonModel = "hidden: too far"
                track.debugThirdPersonModelDistance = dist
                return
            end
            track.debugThirdPersonModelDistance = dist
        end

        track.thirdpersonModelReadyFrame = FrameNumber()
        track.thirdpersonModelReadyTime = RealTime()
        track.debugThirdPersonModel = model:GetModel()
    end

    local function ApplyCached(track, ply)
        local matrices = track.thirdpersonBoneMatrices
        if not matrices then return false end
        for bone, matrix in pairs(matrices) do
            ply:SetBoneMatrix(bone, matrix)
            ply:SetBonePosition(bone, matrix:GetTranslation(), matrix:GetAngles())
        end
        return true
    end

    -- Main TPIK solve
    local function ApplyThirdPersonBones(track, ply, weapon, baseMatrices)
        local source = GetSourceModel(track)
        if not IsValid(source) or not baseMatrices then return end

        -- Reuse cached solve if already done this frame
        if track.thirdpersonSolveFrame == FrameNumber() then
            ApplyCached(track, ply)
            return
        end

        local flip = GetLegacyFlipState(weapon)
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        -- Eye angles (local and remote players alike) so the arms follow aim pitch.
        local renderAngles = ply.EyeAngles and ply:EyeAngles() or (ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles())

        -- Place source model at eye position
        PlaceTPIKTrackModel(track, ply:EyePos(), renderAngles)
        source:SetModelScale(GetTrackModelScale(track, weapon, flip))
        source:SetupBones()

        -- Blend factor: 0 = full animation, 1 = full rest pose
        local blend = math.Clamp(GetTrackBlendFactor(track, track.lerpVal or 1, track.lerpCurve or 1), 0, 1)

        local plyCache, srcCache = BoneCache(ply), BoneCache(source)

        -- Spine position for clamping
        local spineIdx = CachedBone(plyCache, ply, "ValveBiped.Bip01_Spine4")
        local spineMatrix = spineIdx >= 0 and baseMatrices[spineIdx] or nil
        local spinePos = spineMatrix and spineMatrix:GetTranslation() or nil

        -- Offset viewmodel bones (camera space) to player body space via shoulder
        local offset = Vector(0, 0, 0)
        for _, name in ipairs(UPPER_ARM) do
            local srcIdx = CachedBone(srcCache, source, name)
            local tgtIdx = CachedBone(plyCache, ply, name)
            if srcIdx >= 0 and tgtIdx >= 0 then
                local srcM = source:GetBoneMatrix(srcIdx)
                local tgtM = baseMatrices[tgtIdx]
                if srcM and tgtM then
                    offset = tgtM:GetTranslation() - srcM:GetTranslation()
                    break
                end
            end
        end

        -- Options
        local clampRadius = (tonumber(Opt(track, "target_radius")) or 38) + OptAdd(track, "target_radius")
        local smoothing = math.Clamp((tonumber(Opt(track, "smoothing")) or 18) + OptAdd(track, "smoothing"), 0, 60)
        local smoothAlpha = smoothing > 0 and math.Clamp(1 - math.exp(-smoothing * RealFrameTime()), 0, 1) or 0

        -- Per-animation offsets from RegisterTPIKOptions, plus the global convar and per-animation
        -- cookie adjustments (cached in core).
        local adj = GCAL:GetTPIKAdjustment(track.name)
        local tpikAdjustPos, tpikAdjustAng = adj.pos, adj.ang
        local totalOffsetX = tpikAdjustPos.x + (tonumber(Opt(track, "offset_x")) or 0)
        local totalOffsetY = tpikAdjustPos.y + (tonumber(Opt(track, "offset_y")) or 0)
        local totalOffsetZ = tpikAdjustPos.z + (tonumber(Opt(track, "offset_z")) or 0)
        local tpikPosDelta = renderAngles:Forward() * totalOffsetX + renderAngles:Right() * totalOffsetY +
            renderAngles:Up() * totalOffsetZ

        local finalMatrices = {}
        local carried = {}
        local boneCount = 0
        local sourceBones = track.sourceBones

        -- Copy each mapped bone from source to player
        for k, boneName in ipairs(track.bones) do
            local tgtBoneName = targetBones[k] or boneName
            local tgtBone = CachedBone(plyCache, ply, tgtBoneName)
            if tgtBone < 0 then continue end

            local srcBone = CachedBone(srcCache, source, sourceBones and sourceBones[k] or boneName)
            if srcBone < 0 then continue end

            local srcMatrix = source:GetBoneMatrix(srcBone)
            local tgtMatrix = baseMatrices[tgtBone]
            if not srcMatrix or not tgtMatrix then continue end

            local rules = GetBoneRules(track, tgtBoneName)
            if rules.locked then
                finalMatrices[tgtBone] = tgtMatrix
                boneCount = boneCount + 1
                continue
            end

            -- Offset, clamp, then apply user adjustment
            local pos = srcMatrix:GetTranslation() + offset
            if spinePos then
                pos = Vector(
                    math.Clamp(pos.x, spinePos.x - clampRadius, spinePos.x + clampRadius),
                    math.Clamp(pos.y, spinePos.y - clampRadius, spinePos.y + clampRadius),
                    math.Clamp(pos.z, spinePos.z - clampRadius, spinePos.z + clampRadius)
                )
            end
            pos = pos + tpikPosDelta
            local srcAng = srcMatrix:GetAngles()
            local ang = Angle(srcAng.p + tpikAdjustAng.p, srcAng.y + tpikAdjustAng.y, srcAng.r + tpikAdjustAng.r)

            if rules.scale ~= 1 then
                local boneBase = tgtMatrix:GetTranslation()
                pos = boneBase + (pos - boneBase) * rules.scale
            end

            -- Optional per-bone smoothing
            if smoothing > 0 then
                local cache = track.thirdpersonTPIKSmoothing
                if not cache then
                    cache = {}
                    track.thirdpersonTPIKSmoothing = cache
                end
                local entry = cache[tgtBone]
                if not entry then
                    cache[tgtBone] = { pos = Vector(pos.x, pos.y, pos.z), ang = Angle(ang.p, ang.y, ang.r) }
                else
                    local a = smoothAlpha
                    local ep, ea = entry.pos, entry.ang
                    ep.x = ep.x + (pos.x - ep.x) * a
                    ep.y = ep.y + (pos.y - ep.y) * a
                    ep.z = ep.z + (pos.z - ep.z) * a
                    ea.p = ea.p + math.AngleDifference(ang.p, ea.p) * a
                    ea.y = ea.y + math.AngleDifference(ang.y, ea.y) * a
                    ea.r = ea.r + math.AngleDifference(ang.r, ea.r) * a
                    pos = ep
                    ang = ea
                end
            end

            -- Blend between animation pose and rest pose
            local finalBlend = rules.blend or blend
            local final = Matrix()
            final:SetTranslation(LerpVector(finalBlend, pos, tgtMatrix:GetTranslation()))
            final:SetAngles(LerpAngle(finalBlend, ang, tgtMatrix:GetAngles()))
            finalMatrices[tgtBone] = final
            boneCount = boneCount + 1
        end

        -- Carry unmapped children of arm bones. The parent's delta (solved * base^-1) is the same
        -- for every child, so it is built once per parent instead of once per child.
        local function CarryChildren(parentBone)
            if carried[parentBone] then return end
            carried[parentBone] = true
            local baseParent, solvedParent = baseMatrices[parentBone], finalMatrices[parentBone]
            local inverse = baseParent and solvedParent and baseParent:GetInverse()
            local delta = inverse and solvedParent * inverse
            for _, childBone in ipairs(GetChildren(ply, parentBone)) do
                if not finalMatrices[childBone] and delta then
                    local baseChild = baseMatrices[childBone]
                    if baseChild then finalMatrices[childBone] = delta * baseChild end
                end
                if finalMatrices[childBone] then CarryChildren(childBone) end
            end
        end

        for _, name in ipairs(UPPER_ARM) do
            local upper = CachedBone(plyCache, ply, name)
            if upper >= 0 and finalMatrices[upper] then CarryChildren(upper) end
        end

        -- Apply and cache
        track.thirdpersonBoneMatrices = finalMatrices
        track.thirdpersonSolveFrame = FrameNumber()
        ApplyCached(track, ply)

        track.debugTargetEntity = ply
        track.debugBoneCount = boneCount
        track.debugThirdPersonMode = "direct"
        track.debugThirdPersonPole = "none"
        track.debugThirdPersonRootBone = track.bones[1] or nil

        -- Find hand position for the clone model, and how far that hand ended up from where the
        -- source model has it. The prop clone gets the same shift so it stays in the hand
        -- (shoulder alignment, clamping, offsets, smoothing and blend all included).
        local handPos = nil
        local cloneShift = offset + tpikPosDelta
        for _, handName in ipairs(HAND) do
            local handBone = CachedBone(plyCache, ply, handName)
            if handBone >= 0 and finalMatrices[handBone] then
                handPos = finalMatrices[handBone]:GetTranslation()

                local srcHandName = handName
                for k, boneName in ipairs(track.bones) do
                    if (targetBones[k] or boneName) == handName then
                        srcHandName = sourceBones and sourceBones[k] or boneName
                        break
                    end
                end
                local srcHandBone = CachedBone(srcCache, source, srcHandName)
                local srcHandMatrix = srcHandBone >= 0 and source:GetBoneMatrix(srcHandBone) or nil
                if srcHandMatrix then
                    cloneShift = handPos - srcHandMatrix:GetTranslation()
                end
                break
            end
        end
        PrepareClone(track, handPos, cloneShift, renderAngles)
    end

    return {
        ApplyCachedThirdPersonBones = ApplyCached,
        ApplyThirdPersonBones = ApplyThirdPersonBones
    }
end