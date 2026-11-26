if not CLIENT then return end

GCAL = GCAL or {}

function GCAL.InstallTPIK(deps)
    deps = deps or {}
    local PlaceTPIKTrackModel = deps.PlaceTPIKTrackModel or deps.PlaceTrackModel
    local GetLegacyFlipState = deps.GetLegacyFlipState
    local GetTrackTargetBones = deps.GetTrackTargetBones
    local GetTrackModelScale = deps.GetTrackModelScale
    local GetTrackBlendFactor = deps.GetTrackBlendFactor or function(track, t, curve)
        return GCAL.Lerp.Legacy(t, 0, 1, curve or 1)
    end

    local BoneCache, CachedBone = deps.BoneCache, deps.CachedBone

    local SPINE = "ValveBiped.Bip01_Spine4"
    local UPPER_ARM = { "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_R_UpperArm" }
    local FOREARM = { "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm" }
    local HAND = { "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_R_Hand" }

    local childBoneCache = setmetatable({}, { __mode = "k" })
    local bodygroupIDs = {}

    local function GetBone(ent, name)
        if not IsValid(ent) or not name then return nil end
        local idx = CachedBone(BoneCache(ent), ent, name)
        return idx >= 0 and idx or nil
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

    local function OptAdd(track, key)
        if not GCAL.GetTPIKOptionAdd then return 0 end
        return GCAL:GetTPIKOptionAdd(track.name, key) or 0
    end

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
                if string.find(lower, string.lower(tostring(token)), 1, true) then
                    hide = true; byAuto = false; break
                end
            end
            for _, token in ipairs(keep or {}) do
                if string.find(lower, string.lower(tostring(token)), 1, true) then
                    hide = false; byAuto = false; break
                end
            end
            if hide then
                model:SetSubMaterial(index - 1, hiddenMatName)
                if byAuto then autoHidden[#autoHidden + 1] = index - 1 end
            else
                visible = visible + 1
            end
        end

        if #materials > 0 and visible == 0 and #autoHidden > 0 then
            for _, idx in ipairs(autoHidden) do model:SetSubMaterial(idx) end
            visible = #autoHidden
            track.debugThirdPersonModel = "visible: material fallback"
        end
        track.thirdpersonModelHasVisibleMaterials = #materials == 0 or visible > 0
    end

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
        local measure = handPos ~= nil and maxDist > 0

        local boneDist, hitboxDist

        model:SetPos(source:GetPos())
        model:SetAngles(source:GetAngles())
        local scale = track.modelScale or 1
        local sourceModel = source:GetModel()
        local appearance = model.gcalCloneAppearance
        if not appearance or appearance.source ~= source or appearance.sourceModel ~= sourceModel
            or appearance.scale ~= scale or appearance.skin ~= track.modelSkin
            or appearance.bodygroups ~= track.modelBodygroups then
            model:SetModelScale(scale)
            model:SetSkin(source:GetSkin())
            for _, id in ipairs(GetBodygroupIDs(source)) do
                model:SetBodygroup(id, source:GetBodygroup(id))
            end
            model.gcalCloneAppearance = {
                source = source, sourceModel = sourceModel, scale = scale,
                skin = track.modelSkin, bodygroups = track.modelBodygroups
            }
        end
        model:SetCycle(track.cycle or 0)
        model:SetupBones()

        local cloneOffsetX = (Opt(track, "clone_offset_x") or 0) + OptAdd(track, "clone_offset_x")
        local cloneOffsetY = (Opt(track, "clone_offset_y") or 0) + OptAdd(track, "clone_offset_y")
        local cloneOffsetZ = (Opt(track, "clone_offset_z") or 0) + OptAdd(track, "clone_offset_z")
        local cloneOffsets = Opt(track, "model_offset")
        local offsetByBone = istable(cloneOffsets) and GetCloneOffsetMap(track, model, cloneOffsets) or nil

        local shift = Vector(0, 0, 0)
        if cloneShift then shift:Add(cloneShift) end
        if cloneOffsetX ~= 0 or cloneOffsetY ~= 0 or cloneOffsetZ ~= 0 then
            if cloneAngles then
                shift:Add(cloneAngles:Forward() * cloneOffsetX + cloneAngles:Right() * cloneOffsetY
                    + cloneAngles:Up() * cloneOffsetZ)
            else
                shift:Add(Vector(cloneOffsetX, cloneOffsetY, cloneOffsetZ))
            end
        end
        local hasShift = not shift:IsZero()

        local copies = measure and {} or nil
        for bone = 0, model:GetBoneCount() - 1 do
            local m = source:GetBoneMatrix(bone) or model:GetBoneMatrix(bone)
            if m then
                local pos = m:GetTranslation()
                if hasShift then
                    pos:Add(shift)
                    m:SetTranslation(pos)
                end
                local boneOffset = offsetByBone and offsetByBone[bone]
                if boneOffset then
                    pos:Add(boneOffset)
                    m:SetTranslation(pos)
                end
                model:SetBoneMatrix(bone, m)
                model:SetBonePosition(bone, pos, m:GetAngles())
                if measure then
                    copies[bone] = m
                    if explicitBone == nil or bone == explicitBone then
                        local d = pos:Distance(handPos)
                        boneDist = boneDist and math.min(boneDist, d) or d
                    end
                end
            end
        end

        if measure and model.GetHitBoxCount and model.GetHitBoxBone and model.GetHitBoxBounds then
            for hb = 0, (model:GetHitBoxCount(0) or 0) - 1 do
                local bone = model:GetHitBoxBone(hb, 0)
                local mat = bone and copies[bone]
                if mat and (explicitBone == nil or bone == explicitBone) then
                    local mins, maxs = model:GetHitBoxBounds(hb, 0)
                    if mins and maxs then
                        local d = (mat * ((mins + maxs) * 0.5)):Distance(handPos)
                        hitboxDist = hitboxDist and math.min(hitboxDist, d) or d
                    end
                end
            end
        end

        if measure then
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

    local function GetShoulderOffset(ply, plyCache, source, srcCache, baseMatrices)
        for _, name in ipairs(UPPER_ARM) do
            local srcIdx = CachedBone(srcCache, source, name)
            local tgtIdx = CachedBone(plyCache, ply, name)
            if srcIdx >= 0 and tgtIdx >= 0 then
                local srcM = source:GetBoneMatrix(srcIdx)
                local tgtM = baseMatrices[tgtIdx]
                if srcM and tgtM then
                    return tgtM:GetTranslation() - srcM:GetTranslation()
                end
            end
        end
        return Vector(0, 0, 0)
    end

    local function ReadSolveOptions(track, renderAngles)
        local clampRadius = (tonumber(Opt(track, "target_radius")) or 38) + OptAdd(track, "target_radius")
        local smoothing = math.Clamp((tonumber(Opt(track, "smoothing")) or 18) + OptAdd(track, "smoothing"), 0, 60)
        local smoothAlpha = smoothing > 0 and math.Clamp(1 - math.exp(-smoothing * RealFrameTime()), 0, 1) or 0

        local adj = GCAL:GetTPIKAdjustment(track.name)
        local adjustPos = adj.pos
        local totalOffsetX = adjustPos.x + (tonumber(Opt(track, "offset_x")) or 0)
        local totalOffsetY = adjustPos.y + (tonumber(Opt(track, "offset_y")) or 0)
        local totalOffsetZ = adjustPos.z + (tonumber(Opt(track, "offset_z")) or 0)
        local posDelta = renderAngles:Forward() * totalOffsetX + renderAngles:Right() * totalOffsetY +
            renderAngles:Up() * totalOffsetZ

        return clampRadius, smoothing, smoothAlpha, adj.ang, posDelta
    end

    local function SmoothBonePose(track, key, pos, ang, alpha, refPos, refAng)
        local cache = track.thirdpersonTPIKSmoothing
        if not cache then
            cache = {}
            track.thirdpersonTPIKSmoothing = cache
        end
        if refPos then pos, ang = WorldToLocal(pos, ang, refPos, refAng) end
        local entry = cache[key]
        if not entry then
            entry = { pos = Vector(pos.x, pos.y, pos.z), ang = Angle(ang.p, ang.y, ang.r) }
            cache[key] = entry
        else
            local ep, ea = entry.pos, entry.ang
            ep.x = ep.x + (pos.x - ep.x) * alpha
            ep.y = ep.y + (pos.y - ep.y) * alpha
            ep.z = ep.z + (pos.z - ep.z) * alpha
            ea.p = ea.p + math.AngleDifference(ang.p, ea.p) * alpha
            ea.y = ea.y + math.AngleDifference(ang.y, ea.y) * alpha
            ea.r = ea.r + math.AngleDifference(ang.r, ea.r) * alpha
        end
        if refPos then return LocalToWorld(entry.pos, entry.ang, refPos, refAng) end
        return Vector(entry.pos.x, entry.pos.y, entry.pos.z), Angle(entry.ang.p, entry.ang.y, entry.ang.r)
    end

    local function GetAnchorOffset(ply, plyCache, source, srcCache, baseMatrices)
        local sum, count = Vector(0, 0, 0), 0
        for _, name in ipairs(UPPER_ARM) do
            local srcIdx = CachedBone(srcCache, source, name)
            local tgtIdx = CachedBone(plyCache, ply, name)
            if srcIdx >= 0 and tgtIdx >= 0 then
                local srcM = source:GetBoneMatrix(srcIdx)
                local tgtM = baseMatrices[tgtIdx]
                if srcM and tgtM then
                    sum:Add(tgtM:GetTranslation() - srcM:GetTranslation())
                    count = count + 1
                end
            end
        end
        if count > 1 then sum:Div(count) end
        return sum
    end

    local function BendDirection(shoulder, elbow, hand)
        local axis = hand - shoulder
        local lenSqr = axis:LengthSqr()
        if lenSqr < 1e-4 then return nil end
        local toElbow = elbow - shoulder
        local bend = toElbow - axis * (toElbow:Dot(axis) / lenSqr)
        if bend:LengthSqr() < 1e-4 then return nil end
        bend:Normalize()
        return bend
    end

    local function PlaneNormal(a, b, c)
        local n = (b - a):Cross(c - b)
        if n:LengthSqr() < 1e-4 then return nil end
        n:Normalize()
        return n
    end

    local function TransferBoneAngle(srcAng, srcDir, srcNormal, baseAng, baseDir, baseNormal, dir, normal, blend)
        local _, srcLocal = WorldToLocal(vector_origin, srcAng, vector_origin, srcDir:AngleEx(srcNormal))
        local localAng = srcLocal
        if blend > 0 then
            local _, baseLocal = WorldToLocal(vector_origin, baseAng, vector_origin, baseDir:AngleEx(baseNormal))
            localAng = blend >= 1 and baseLocal or LerpAngle(blend, srcLocal, baseLocal)
        end
        local _, worldAng = LocalToWorld(vector_origin, localAng, vector_origin, dir:AngleEx(normal))
        return worldAng
    end

    local function AlignChild(ang, childLocal, wantDir)
        local current = Vector(childLocal.x, childLocal.y, childLocal.z)
        current:Rotate(ang)
        current:Normalize()
        local axis = current:Cross(wantDir)
        local sinA = axis:Length()
        if sinA < 1e-4 then return ang end
        axis:Div(sinA)
        ang:RotateAroundAxis(axis, math.deg(math.atan2(sinA, current:Dot(wantDir))))
        return ang
    end

    local function Direction(from, to)
        local d = to - from
        d:Normalize()
        return d
    end

    local ctx = {}

    local function WriteFinal(bone, pos, ang, baseMatrix)
        local m = ctx.pool[bone]
        if not m then
            m = Matrix()
            ctx.pool[bone] = m
        end
        m:Identity()
        m:SetTranslation(pos)
        m:SetAngles(ang)
        if baseMatrix then m:SetScale(baseMatrix:GetScale()) end
        ctx.final[bone] = m
        ctx.count = ctx.count + 1
    end

    local function PropagateChildren(parent)
        local ply, base, final = ctx.ply, ctx.base, ctx.final
        local parentFinal, parentBase = final[parent], base[parent]
        if not parentFinal or not parentBase then return end
        local parentPos, parentAng = parentFinal:GetTranslation(), parentFinal:GetAngles()
        local parentBasePos, parentBaseAng = parentBase:GetTranslation(), parentBase:GetAngles()

        for _, child in ipairs(GetChildren(ply, parent)) do
            if not final[child] then
                local childBase = base[child]
                if not childBase then continue end
                local localPos, localAng = WorldToLocal(childBase:GetTranslation(), childBase:GetAngles(),
                    parentBasePos, parentBaseAng)

                local srcChild, srcParent = ctx.srcByTgt[child], ctx.srcByTgt[parent]
                local srcChildM = srcChild and ctx.source:GetBoneMatrix(srcChild)
                local srcParentM = srcParent and ctx.source:GetBoneMatrix(srcParent)
                if srcChildM and srcParentM then
                    local rules = GetBoneRules(ctx.track, ctx.nameByTgt[child])
                    local blend = rules.locked and 1 or (rules.blend or ctx.blend)
                    if blend < 1 then
                        local _, srcLocal = WorldToLocal(vector_origin, srcChildM:GetAngles(), vector_origin,
                            srcParentM:GetAngles())
                        localAng = blend <= 0 and srcLocal or LerpAngle(blend, srcLocal, localAng)
                    end
                end

                local pos, ang = LocalToWorld(localPos, localAng, parentPos, parentAng)
                WriteFinal(child, pos, ang, childBase)
            end
            PropagateChildren(child)
        end
    end

    local function SolveArm(side)
        local ply, source, base, track = ctx.ply, ctx.source, ctx.base, ctx.track
        local tU = CachedBone(ctx.plyCache, ply, UPPER_ARM[side])
        local tF = CachedBone(ctx.plyCache, ply, FOREARM[side])
        local tH = CachedBone(ctx.plyCache, ply, HAND[side])
        if tU < 0 or tF < 0 or tH < 0 then return false end

        local sU, sF, sH = ctx.srcByTgt[tU], ctx.srcByTgt[tF], ctx.srcByTgt[tH]
        if not sU or not sF or not sH then return false end
        local bU, bF, bH = base[tU], base[tF], base[tH]
        local mU, mF, mH = source:GetBoneMatrix(sU), source:GetBoneMatrix(sF), source:GetBoneMatrix(sH)
        if not bU or not bF or not bH or not mU or not mF or not mH then return false end

        local ruleU, ruleF, ruleH = GetBoneRules(track, UPPER_ARM[side]), GetBoneRules(track, FOREARM[side]),
            GetBoneRules(track, HAND[side])
        if ruleU.locked or ruleF.locked then return false end

        local shoulder, baseElbow, baseHand = bU:GetTranslation(), bF:GetTranslation(), bH:GetTranslation()
        local len1, len2 = shoulder:Distance(baseElbow), baseElbow:Distance(baseHand)
        if len1 < 0.01 or len2 < 0.01 then return false end

        local srcShoulder, srcElbow, srcHand = mU:GetTranslation(), mF:GetTranslation(), mH:GetTranslation()

        local target = srcHand + ctx.offset
        local spinePos = ctx.spinePos
        if spinePos then
            local r = ctx.clampRadius
            target.x = math.Clamp(target.x, spinePos.x - r, spinePos.x + r)
            target.y = math.Clamp(target.y, spinePos.y - r, spinePos.y + r)
            target.z = math.Clamp(target.z, spinePos.z - r, spinePos.z + r)
        end
        target:Add(ctx.posDelta)
        local handAng = mH:GetAngles()
        local adjustAng = ctx.adjustAng
        handAng.p, handAng.y, handAng.r = handAng.p + adjustAng.p, handAng.y + adjustAng.y, handAng.r + adjustAng.r

        if ruleH.scale ~= 1 then
            target = baseHand + (target - baseHand) * ruleH.scale
        end

        local pole = BendDirection(srcShoulder, srcElbow, srcHand)
        if ctx.smoothing > 0 then
            target, handAng = SmoothBonePose(track, tH, target, handAng, ctx.smoothAlpha, spinePos, ctx.spineAng)
            if pole then
                local smoothed = SmoothBonePose(track, -side, spinePos and spinePos + pole or pole, angle_zero,
                    ctx.smoothAlpha, spinePos, ctx.spineAng)
                pole = spinePos and smoothed - spinePos or smoothed
            end
        end

        local blend = ruleH.locked and 1 or (ruleH.blend or ctx.blend)
        local goal = blend <= 0 and target or LerpVector(blend, target, baseHand)
        local goalAng = blend <= 0 and handAng or LerpAngle(blend, handAng, bH:GetAngles())

        local basePole = BendDirection(shoulder, baseElbow, baseHand)
        local poleSource = "anim"
        if pole and basePole then
            if blend > 0 then pole = LerpVector(blend, pole, basePole) end
        elseif basePole then
            pole, poleSource = basePole, "player"
        elseif not pole then
            pole = ctx.right * (side == 1 and -0.5 or 0.5) - ctx.up
            poleSource = "fallback"
        end

        local toGoal = goal - shoulder
        local dist = toGoal:Length()
        local dir = dist > 1e-3 and toGoal / dist or -ctx.up
        local reach = math.Clamp(dist, math.abs(len1 - len2) + 0.01, len1 + len2 - 0.01)
        local bend = pole - dir * pole:Dot(dir)
        if bend:LengthSqr() < 1e-6 then
            bend = ctx.right * (side == 1 and -1 or 1) - ctx.up
            bend = bend - dir * bend:Dot(dir)
            if bend:LengthSqr() < 1e-6 then bend = dir:Angle():Up() end
        end
        bend:Normalize()

        local cosA = math.Clamp((len1 * len1 + reach * reach - len2 * len2) / (2 * len1 * reach), -1, 1)
        local sinA = math.sqrt(1 - cosA * cosA)
        local elbow = shoulder + dir * (len1 * cosA) + bend * (len1 * sinA)
        local hand = shoulder + dir * reach

        local normal = bend:Cross(dir)
        normal:Normalize()
        local srcNormal = PlaneNormal(srcShoulder, srcElbow, srcHand) or normal
        local baseNormal = PlaneNormal(shoulder, baseElbow, baseHand) or normal

        local upperDir, foreDir = Direction(shoulder, elbow), Direction(elbow, hand)
        local upperAng = TransferBoneAngle(mU:GetAngles(), Direction(srcShoulder, srcElbow), srcNormal,
            bU:GetAngles(), Direction(shoulder, baseElbow), baseNormal, upperDir, normal,
            ruleU.blend or ctx.blend)
        local foreAng = TransferBoneAngle(mF:GetAngles(), Direction(srcElbow, srcHand), srcNormal,
            bF:GetAngles(), Direction(baseElbow, baseHand), baseNormal, foreDir, normal,
            ruleF.blend or ctx.blend)

        local elbowLocal = WorldToLocal(baseElbow, angle_zero, shoulder, bU:GetAngles())
        local handLocal = WorldToLocal(baseHand, angle_zero, baseElbow, bF:GetAngles())
        AlignChild(upperAng, elbowLocal, upperDir)
        AlignChild(foreAng, handLocal, foreDir)

        WriteFinal(tU, shoulder, upperAng, bU)
        WriteFinal(tF, elbow, foreAng, bF)
        WriteFinal(tH, hand, goalAng, bH)
        PropagateChildren(tU)

        ctx.pole = poleSource
        return true
    end

    local function CarryChildren(ply, parentBone, baseMatrices, finalMatrices, carried)
        if carried[parentBone] then return end
        carried[parentBone] = true
        local delta
        for _, childBone in ipairs(GetChildren(ply, parentBone)) do
            if not finalMatrices[childBone] and delta ~= false then
                local baseChild = baseMatrices[childBone]
                if baseChild then
                    if delta == nil then
                        local baseParent, solvedParent = baseMatrices[parentBone], finalMatrices[parentBone]
                        local inverse = baseParent and solvedParent and baseParent:GetInverse()
                        delta = inverse and solvedParent * inverse or false
                    end
                    if delta then finalMatrices[childBone] = delta * baseChild end
                end
            end
            if finalMatrices[childBone] then
                CarryChildren(ply, childBone, baseMatrices, finalMatrices, carried)
            end
        end
    end

    local function GetCloneHandShift(track, ply, plyCache, source, srcCache, targetBones, sourceBones,
                                     finalMatrices, cloneShift)
        for _, handName in ipairs(HAND) do
            local handBone = CachedBone(plyCache, ply, handName)
            if handBone >= 0 and finalMatrices[handBone] then
                local handPos = finalMatrices[handBone]:GetTranslation()

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
                return handPos, cloneShift
            end
        end
        return nil, cloneShift
    end

    local function ApplyThirdPersonBones(track, ply, weapon, baseMatrices)
        local source = GetSourceModel(track)
        if not IsValid(source) or not baseMatrices then return end

        if track.thirdpersonSolveFrame == FrameNumber() then
            ApplyCached(track, ply)
            return
        end

        local flip = GetLegacyFlipState(weapon)
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        local renderAngles = ply.EyeAngles and ply:EyeAngles()
            or (ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles())

        PlaceTPIKTrackModel(track, ply:EyePos(), renderAngles)
        source:SetModelScale(GetTrackModelScale(track, weapon, flip))
        source:SetupBones()

        local blend = math.Clamp(GetTrackBlendFactor(track, track.lerpVal or 1, track.lerpCurve or 1), 0, 1)

        local plyCache, srcCache = BoneCache(ply), BoneCache(source)

        local spineIdx = CachedBone(plyCache, ply, SPINE)
        local spineMatrix = spineIdx >= 0 and baseMatrices[spineIdx] or nil
        local spinePos = spineMatrix and spineMatrix:GetTranslation() or nil
        local spineAng = spineMatrix and spineMatrix:GetAngles() or nil

        local useIK = Opt(track, "ik") ~= false and (not GCAL.TPIKUseIK or GCAL.TPIKUseIK:GetBool())
        local offset = useIK and GetAnchorOffset(ply, plyCache, source, srcCache, baseMatrices)
            or GetShoulderOffset(ply, plyCache, source, srcCache, baseMatrices)
        local clampRadius, smoothing, smoothAlpha, tpikAdjustAng, tpikPosDelta = ReadSolveOptions(track, renderAngles)

        local finalMatrices = {}
        local carried = {}
        local sourceBones = track.sourceBones
        local pool = track.thirdpersonMatrixPool
        if not pool then
            pool = {}
            track.thirdpersonMatrixPool = pool
        end

        local srcByTgt = track.tpikSrcByTgt or {}
        local nameByTgt = track.tpikNameByTgt or {}
        track.tpikSrcByTgt, track.tpikNameByTgt = srcByTgt, nameByTgt
        table.Empty(srcByTgt)
        table.Empty(nameByTgt)
        for k, boneName in ipairs(track.bones) do
            local tgtBoneName = targetBones[k] or boneName
            local tgtBone = CachedBone(plyCache, ply, tgtBoneName)
            local srcBone = CachedBone(srcCache, source, sourceBones and sourceBones[k] or boneName)
            if tgtBone >= 0 and srcBone >= 0 and not srcByTgt[tgtBone] then
                srcByTgt[tgtBone] = srcBone
                nameByTgt[tgtBone] = tgtBoneName
            end
        end

        ctx.ply, ctx.source, ctx.track, ctx.base = ply, source, track, baseMatrices
        ctx.plyCache, ctx.final, ctx.pool, ctx.count = plyCache, finalMatrices, pool, 0
        ctx.srcByTgt, ctx.nameByTgt, ctx.blend = srcByTgt, nameByTgt, blend
        ctx.offset, ctx.posDelta, ctx.adjustAng, ctx.clampRadius = offset, tpikPosDelta, tpikAdjustAng, clampRadius
        ctx.smoothing, ctx.smoothAlpha, ctx.spinePos, ctx.spineAng = smoothing, smoothAlpha, spinePos, spineAng
        ctx.right, ctx.up, ctx.pole = renderAngles:Right(), renderAngles:Up(), nil

        local solvedArms = 0
        if useIK then
            for side = 1, 2 do
                if SolveArm(side) then solvedArms = solvedArms + 1 end
            end
        end
        local directBones = 0

        for k, boneName in ipairs(track.bones) do
            local tgtBoneName = targetBones[k] or boneName
            local tgtBone = CachedBone(plyCache, ply, tgtBoneName)
            if tgtBone < 0 or finalMatrices[tgtBone] then continue end

            local srcBone = CachedBone(srcCache, source, sourceBones and sourceBones[k] or boneName)
            if srcBone < 0 then continue end

            local srcMatrix = source:GetBoneMatrix(srcBone)
            local tgtMatrix = baseMatrices[tgtBone]
            if not srcMatrix or not tgtMatrix then continue end

            directBones = directBones + 1
            local rules = GetBoneRules(track, tgtBoneName)
            if rules.locked then
                finalMatrices[tgtBone] = tgtMatrix
                ctx.count = ctx.count + 1
                continue
            end

            local pos = srcMatrix:GetTranslation()
            pos:Add(offset)
            if spinePos then
                pos.x = math.Clamp(pos.x, spinePos.x - clampRadius, spinePos.x + clampRadius)
                pos.y = math.Clamp(pos.y, spinePos.y - clampRadius, spinePos.y + clampRadius)
                pos.z = math.Clamp(pos.z, spinePos.z - clampRadius, spinePos.z + clampRadius)
            end
            pos:Add(tpikPosDelta)
            local ang = srcMatrix:GetAngles()
            ang.p = ang.p + tpikAdjustAng.p
            ang.y = ang.y + tpikAdjustAng.y
            ang.r = ang.r + tpikAdjustAng.r

            local tgtPos = tgtMatrix:GetTranslation()
            if rules.scale ~= 1 then
                local scale = rules.scale
                pos.x = tgtPos.x + (pos.x - tgtPos.x) * scale
                pos.y = tgtPos.y + (pos.y - tgtPos.y) * scale
                pos.z = tgtPos.z + (pos.z - tgtPos.z) * scale
            end

            if smoothing > 0 then
                pos, ang = SmoothBonePose(track, tgtBone, pos, ang, smoothAlpha, spinePos, spineAng)
            end

            local finalBlend = rules.blend or blend
            tgtPos.x = pos.x + (tgtPos.x - pos.x) * finalBlend
            tgtPos.y = pos.y + (tgtPos.y - pos.y) * finalBlend
            tgtPos.z = pos.z + (tgtPos.z - pos.z) * finalBlend

            local final = pool[tgtBone]
            if not final then
                final = Matrix()
                pool[tgtBone] = final
            end
            final:Identity()
            final:SetTranslation(tgtPos)
            if finalBlend <= 0 then
                final:SetAngles(ang)
            elseif finalBlend >= 1 then
                final:SetAngles(tgtMatrix:GetAngles())
            else
                final:SetAngles(LerpAngle(finalBlend, ang, tgtMatrix:GetAngles()))
            end
            finalMatrices[tgtBone] = final
            ctx.count = ctx.count + 1
        end

        for _, name in ipairs(UPPER_ARM) do
            local upper = CachedBone(plyCache, ply, name)
            if upper >= 0 and finalMatrices[upper] then
                CarryChildren(ply, upper, baseMatrices, finalMatrices, carried)
            end
        end

        track.thirdpersonBoneMatrices = finalMatrices
        track.thirdpersonSolveFrame = FrameNumber()
        ApplyCached(track, ply)

        track.debugTargetEntity = ply
        track.debugBoneCount = ctx.count
        track.debugThirdPersonMode = solvedArms > 0 and (directBones > 0 and "ik+direct" or "ik") or "direct"
        track.debugThirdPersonPole = ctx.pole or "none"
        track.debugThirdPersonRootBone = track.bones[1] or nil

        local handPos, cloneShift = GetCloneHandShift(track, ply, plyCache, source, srcCache, targetBones,
            sourceBones, finalMatrices, offset + tpikPosDelta)
        PrepareClone(track, handPos, cloneShift, renderAngles)
    end

    return {
        ApplyCachedThirdPersonBones = ApplyCached,
        ApplyThirdPersonBones = ApplyThirdPersonBones
    }
end
