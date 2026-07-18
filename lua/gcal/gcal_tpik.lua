if not CLIENT then return end

GCAL = GCAL or {}

-- Simple TPIK: direct bone copy (ARC9-style). No IK solver or anchor transforms.

function GCAL.InstallTPIK(deps)
    deps = deps or {}
    local PlaceTPIKTrackModel = deps.PlaceTPIKTrackModel or deps.PlaceTrackModel
    local GetLegacyFlipState = deps.GetLegacyFlipState
    local GetTrackTargetBones = deps.GetTrackTargetBones
    local GetTrackModelScale = deps.GetTrackModelScale

    -- Bone lookup cache (keyed by entity, invalidated on model change)
    local boneIndexCache = setmetatable({}, { __mode = "k" })
    local childBoneCache = setmetatable({}, { __mode = "k" })

    local function GetBone(ent, name)
        if not IsValid(ent) or not name then return nil end
        local model = ent:GetModel() or ""
        local cache = boneIndexCache[ent]
        if not cache or cache.model ~= model then
            cache = { model = model, bones = {} }
            boneIndexCache[ent] = cache
        end
        local cached = cache.bones[name]
        if cached ~= nil then return cached ~= false and cached or nil end
        local idx = ent:LookupBone(name)
        cache.bones[name] = idx or false
        return idx
    end

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

    local function Opt(track, key, ...)
        local options = GetOptions(track)
        if options and options[key] ~= nil then return options[key] end
        local data = track and track.data or nil
        for i = 1, select("#", ...) do
            local fallback = select(i, ...)
            if data and data[fallback] ~= nil then return data[fallback] end
        end
        return nil
    end

    local function OptAdd(track, key)
        if not GCAL.GetTPIKOptionAdd then return 0 end
        return GCAL:GetTPIKOptionAdd(track.name, key) or 0
    end

    -- Hidden material for the third-person model clone (arms/hands auto-hidden)
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

        local extraHide = Opt(track, "hide_materials", "thirdperson_hide_materials")
        if isstring(extraHide) then extraHide = { extraHide } end
        local keep = Opt(track, "keep_materials", "thirdperson_keep_materials")
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

        -- If everything got hidden, restore auto-hidden ones so the clone isn't invisible
        if #materials > 0 and visible == 0 and #autoHidden > 0 then
            for _, idx in ipairs(autoHidden) do model:SetSubMaterial(idx) end
            visible = #autoHidden
            track.debugThirdPersonModel = "visible: material fallback"
        end
        track.thirdpersonModelHasVisibleMaterials = #materials == 0 or visible > 0
    end

    -- Third-person model clone: visual copy of the source viewmodel for props
    local function PrepareClone(track, handPos)
        local model = track.thirdpersonModel
        local source = GetSourceModel(track)
        if not IsValid(model) or Opt(track, "model", "thirdperson_model") == false then return end
        if not IsValid(source) then return end

        track.thirdpersonModelReadyFrame = nil
        track.debugThirdPersonModelDistance = nil

        ConfigureCloneMaterials(track)
        if not track.thirdpersonModelHasVisibleMaterials then return end

        local maxDist = tonumber(Opt(track, "model_max_distance", "thirdperson_model_max_distance")) or 32
        local explicitBoneName = Opt(track, "model_bone", "thirdperson_model_bone")
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
        model:SetModelScale(1)
        model:SetSkin(source:GetSkin())
        for _, bg in ipairs(source:GetBodyGroups() or {}) do
            model:SetBodygroup(bg.id, source:GetBodygroup(bg.id))
        end
        model:SetCycle(track.cycle or 0)
        model:SetupBones()

        local copies = {}
        for bone = 0, model:GetBoneCount() - 1 do
            local src = source:GetBoneMatrix(bone) or model:GetBoneMatrix(bone)
            if src then
                copies[bone] = Matrix(src:ToTable())
                model:SetBoneMatrix(bone, copies[bone])
                model:SetBonePosition(bone, copies[bone]:GetTranslation(), copies[bone]:GetAngles())
                Consider(bone, src:GetTranslation(), false)
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
        local renderAngles = ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles()

        -- Place source model at eye position (viewmodel bones are camera-relative)
        PlaceTPIKTrackModel(track, ply:EyePos(), renderAngles)
        source:SetModelScale(GetTrackModelScale(track, weapon, flip))
        source:SetupBones()

        -- Blend factor: 0 = full animation, 1 = full rest pose
        local blend = math.Clamp(
            (track.legacyMatrixLerp and GCAL.Lerp.Legacy or Lerp)(
                track.lerpVal or 1, 0, 1,
                track.lerpCurve or (track.data and track.data.lerp_curve) or 1
            ),
            0, 1
        )

        -- Spine position for clamping
        local spineIdx = GetBone(ply, "ValveBiped.Bip01_Spine4")
        local spinePos = nil
        if spineIdx then
            local m = baseMatrices[spineIdx]
            if m then spinePos = m:GetTranslation() end
        end

        -- Offset viewmodel bones (camera space) to player body space via shoulder
        -- Without this, viewmodel bones land at the player's feet.
        local offset = Vector(0, 0, 0)
        for _, side in ipairs({ "L", "R" }) do
            local name = "ValveBiped.Bip01_" .. side .. "_UpperArm"
            local srcIdx = GetBone(source, name)
            local tgtIdx = GetBone(ply, name)
            if srcIdx and srcIdx >= 0 and tgtIdx and tgtIdx >= 0 then
                local srcM = source:GetBoneMatrix(srcIdx)
                local tgtM = baseMatrices[tgtIdx]
                if srcM and tgtM then
                    offset = tgtM:GetTranslation() - srcM:GetTranslation()
                    break
                end
            end
        end

        -- Options
        local clampRadius = tonumber(Opt(track, "target_radius", "thirdperson_target_radius")) or 38
        clampRadius = clampRadius + OptAdd(track, "target_radius")
        local smoothing = tonumber(Opt(track, "smoothing", "thirdperson_smoothing")) or 18
        smoothing = math.Clamp(smoothing + OptAdd(track, "smoothing"), 0, 60)

        -- Per-animation offsets from RegisterTPIKOptions
        local animOffsetX = tonumber(Opt(track, "offset_x")) or 0
        local animOffsetY = tonumber(Opt(track, "offset_y")) or 0
        local animOffsetZ = tonumber(Opt(track, "offset_z")) or 0

        -- Global adjustments from convars + per-animation cookies
        local tpikAdjustPos = Vector(0, 0, 0)
        local tpikAdjustAng = Angle(0, 0, 0)
        if GCAL.GetTPIKAdjustment then
            local adj = GCAL:GetTPIKAdjustment(track.name)
            if adj then
                tpikAdjustPos = adj.pos or tpikAdjustPos
                tpikAdjustAng = adj.ang or tpikAdjustAng
            end
        end
        local tpikForward = renderAngles:Forward()
        local tpikRight = renderAngles:Right()
        local tpikUp = renderAngles:Up()
        local totalOffsetX = tpikAdjustPos.x + animOffsetX
        local totalOffsetY = tpikAdjustPos.y + animOffsetY
        local totalOffsetZ = tpikAdjustPos.z + animOffsetZ
        local tpikPosDelta = tpikForward * totalOffsetX + tpikRight * totalOffsetY + tpikUp * totalOffsetZ

        local finalMatrices = {}
        local carried = {}
        local boneCount = 0

        -- Copy each mapped bone from source to player
        for k, boneName in ipairs(track.bones) do
            local srcBoneName = track.sourceBones and track.sourceBones[k] or boneName
            local tgtBoneName = targetBones[k] or boneName
            local tgtBone = GetBone(ply, tgtBoneName)
            if not tgtBone or tgtBone < 0 then continue end

            local srcBone = GetBone(source, srcBoneName)
            local isHelper = string.EndsWith(tgtBoneName, "_Wrist") or string.EndsWith(tgtBoneName, "_Ulna")
            if not srcBone or srcBone < 0 then continue end

            local srcMatrix = source:GetBoneMatrix(srcBone)
            local tgtMatrix = baseMatrices[tgtBone]
            if not srcMatrix or not tgtMatrix then continue end

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
            local ang = Angle(
                srcMatrix:GetAngles().p + tpikAdjustAng.p,
                srcMatrix:GetAngles().y + tpikAdjustAng.y,
                srcMatrix:GetAngles().r + tpikAdjustAng.r
            )

            -- Optional per-bone smoothing
            if smoothing > 0 then
                track.thirdpersonTPIKSmoothing = track.thirdpersonTPIKSmoothing or {}
                local cache = track.thirdpersonTPIKSmoothing
                local entry = cache[tgtBone]
                if not entry then
                    entry = { pos = Vector(pos.x, pos.y, pos.z), ang = Angle(ang.p, ang.y, ang.r) }
                    cache[tgtBone] = entry
                else
                    local a = math.Clamp(1 - math.exp(-smoothing * RealFrameTime()), 0, 1)
                    entry.pos.x = entry.pos.x + (pos.x - entry.pos.x) * a
                    entry.pos.y = entry.pos.y + (pos.y - entry.pos.y) * a
                    entry.pos.z = entry.pos.z + (pos.z - entry.pos.z) * a
                    entry.ang.p = entry.ang.p + math.AngleDifference(ang.p, entry.ang.p) * a
                    entry.ang.y = entry.ang.y + math.AngleDifference(ang.y, entry.ang.y) * a
                    entry.ang.r = entry.ang.r + math.AngleDifference(ang.r, entry.ang.r) * a
                    pos = entry.pos
                    ang = entry.ang
                end
            end

            -- Blend between animation pose and rest pose
            local blendedPos = LerpVector(blend, pos, tgtMatrix:GetTranslation())
            local blendedAng = LerpAngle(blend, ang, tgtMatrix:GetAngles())

            local final = Matrix()
            final:SetTranslation(blendedPos)
            final:SetAngles(blendedAng)
            finalMatrices[tgtBone] = final
            boneCount = boneCount + 1
        end

        -- Carry unmapped children of arm bones
        local function CarryChildren(parentBone)
            if carried[parentBone] then return end
            carried[parentBone] = true
            for _, childBone in ipairs(GetChildren(ply, parentBone)) do
                if not finalMatrices[childBone] then
                    local baseParent = baseMatrices[parentBone]
                    local baseChild = baseMatrices[childBone]
                    local solvedParent = finalMatrices[parentBone]
                    if baseParent and baseChild and solvedParent then
                        local inv = Matrix(baseParent:ToTable())
                        inv:Invert()
                        finalMatrices[childBone] = solvedParent * inv * baseChild
                    end
                end
                if finalMatrices[childBone] then CarryChildren(childBone) end
            end
        end

        for _, side in ipairs({ "L", "R" }) do
            local upper = GetBone(ply, "ValveBiped.Bip01_" .. side .. "_UpperArm")
            if upper and upper >= 0 and finalMatrices[upper] then CarryChildren(upper) end
        end

        -- Apply and cache
        track.thirdpersonBoneMatrices = finalMatrices
        track.thirdpersonSolveFrame = FrameNumber()
        ApplyCached(track, ply)

        track.debugTargetEntity = tostring(ply)
        track.debugBoneCount = boneCount
        track.debugThirdPersonMode = "direct"
        track.debugThirdPersonPole = "none"
        track.debugThirdPersonRootBone = track.bones[1] or nil

        -- Find hand position for the clone model
        local handPos = nil
        for _, side in ipairs({ "L", "R" }) do
            local handBone = GetBone(ply, "ValveBiped.Bip01_" .. side .. "_Hand")
            if handBone and finalMatrices[handBone] then
                handPos = finalMatrices[handBone]:GetTranslation()
                break
            end
        end
        PrepareClone(track, handPos)
    end

    return {
        ApplyCachedThirdPersonBones = ApplyCached,
        ApplyThirdPersonBones = ApplyThirdPersonBones
    }
end