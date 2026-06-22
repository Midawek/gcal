if not CLIENT then return end

GCAL = GCAL or {}

function GCAL.InstallTPIK(deps)
    deps = deps or {}
    local BoneLocalMatrix = deps.BoneLocalMatrix
    local PlaceTrackModel = deps.PlaceTrackModel
    local PlaceTPIKTrackModel = deps.PlaceTPIKTrackModel or PlaceTrackModel
    local GetLegacyFlipState = deps.GetLegacyFlipState
    local GetTrackTargetBones = deps.GetTrackTargetBones
    local GetTrackModelScale = deps.GetTrackModelScale

        local boneIndexCache = setmetatable({}, { __mode = "k" })
        local childBoneCache = setmetatable({}, { __mode = "k" })

        local function GetCachedBoneIndex(ent, boneName)
            if not IsValid(ent) or not boneName then return nil end

            local model = ent:GetModel() or ""
            local cache = boneIndexCache[ent]
            if not cache or cache.model ~= model then
                cache = { model = model, bones = {} }
                boneIndexCache[ent] = cache
            end

            local cached = cache.bones[boneName]
            if cached ~= nil then return cached ~= false and cached or nil end

            local bone = ent:LookupBone(boneName)
            cache.bones[boneName] = bone ~= nil and bone or false
            return bone
        end

        local function GetCachedChildBones(ent, bone)
            if not IsValid(ent) or bone == nil or bone < 0 then return {} end

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

        local function BlendBoneMatrix(animated, base, blendToBase)
            local matrix = Matrix(animated:ToTable())
            matrix:SetTranslation(LerpVector(blendToBase, animated:GetTranslation(), base:GetTranslation()))
            matrix:SetAngles(LerpAngle(blendToBase, animated:GetAngles(), base:GetAngles()))
            return matrix
        end

        local function RotateVectorBetween(vector, fromDirection, toDirection)
            local from = Vector(fromDirection.x, fromDirection.y, fromDirection.z)
            local to = Vector(toDirection.x, toDirection.y, toDirection.z)
            if from:LengthSqr() <= 0.0001 or to:LengthSqr() <= 0.0001 then return vector end
            from:Normalize()
            to:Normalize()

            local dot = math.Clamp(from:Dot(to), -1, 1)
            if dot > 0.9999 then return Vector(vector.x, vector.y, vector.z) end

            local axis = from:Cross(to)
            if axis:LengthSqr() <= 0.0001 then
                axis = from:Cross(Vector(0, 0, 1))
                if axis:LengthSqr() <= 0.0001 then
                    axis = from:Cross(Vector(0, 1, 0))
                end
            end
            axis:Normalize()

            local angle = math.acos(dot)
            local cosine = math.cos(angle)
            local sine = math.sin(angle)
            return vector * cosine
                + axis:Cross(vector) * sine
                + axis * axis:Dot(vector) * (1 - cosine)
        end

        local function AimBoneMatrix(base, baseChildPosition, origin, target)
            local baseDirection = baseChildPosition - origin
            local targetDirection = target - origin
            local matrix = Matrix(base:ToTable())
            matrix:SetTranslation(origin)
            if baseDirection:LengthSqr() <= 0.0001 or targetDirection:LengthSqr() <= 0.0001 then return matrix end

            local forward = RotateVectorBetween(base:GetForward(), baseDirection, targetDirection)
            local up = RotateVectorBetween(base:GetUp(), baseDirection, targetDirection)
            matrix:SetAngles(forward:AngleEx(up))
            return matrix
        end

        local function SolveTwoBoneIK(shoulder, target, pole, upperLength, forearmLength)
            local direction = target - shoulder
            local distance = direction:Length()
            if distance <= 0.0001 then return nil end
            direction:Normalize()

            local minimumReach = math.abs(upperLength - forearmLength) + 0.001
            local maximumReach = math.max(upperLength + forearmLength - 0.001, minimumReach)
            distance = math.Clamp(distance, minimumReach, maximumReach)
            target = shoulder + direction * distance

            local poleDirection = pole - shoulder
            poleDirection = poleDirection - direction * poleDirection:Dot(direction)
            if poleDirection:LengthSqr() <= 0.0001 then
                poleDirection = direction:Cross(Vector(0, 0, 1))
                if poleDirection:LengthSqr() <= 0.0001 then
                    poleDirection = direction:Cross(Vector(0, 1, 0))
                end
            end
            poleDirection:Normalize()

            local along = (
                upperLength * upperLength
                - forearmLength * forearmLength
                + distance * distance
            ) / (2 * distance)
            local height = math.sqrt(math.max(upperLength * upperLength - along * along, 0))
            local elbow = shoulder + direction * along + poleDirection * height

            return elbow, target
        end

        local function ClampVectorAround(origin, value, radius)
            if not origin or not value or not radius or radius <= 0 then return value end

            return Vector(
                math.Clamp(value.x, origin.x - radius, origin.x + radius),
                math.Clamp(value.y, origin.y - radius, origin.y + radius),
                math.Clamp(value.z, origin.z - radius, origin.z + radius)
            )
        end

        local function GetTorsoClampOrigin(ply, baseMatrices)
            local spine = GetCachedBoneIndex(ply, "ValveBiped.Bip01_Spine4")
            local matrix = spine and baseMatrices and baseMatrices[spine]
            return matrix and matrix:GetTranslation() or nil
        end

        local function SmoothArmTargets(track, ply, side, anchor, goal, pole)
            local data = track.data or {}
            local speed = tonumber(data.thirdperson_smoothing)
            if speed == nil then speed = 18 end
            if GCAL.GetTPIKOptionAdd then
                speed = speed + GCAL:GetTPIKOptionAdd(track.name, "smoothing")
            end
            speed = math.Clamp(speed, 0, 60)
            if speed <= 0 then
                track.thirdpersonTPIKSmoothing = nil
                return goal, pole
            end

            local anchorInverse = Matrix(anchor:ToTable())
            anchorInverse:Invert()
            local localGoal = anchorInverse * goal
            local localPole = anchorInverse * pole
            local model = IsValid(ply) and ply:GetModel() or ""
            local cache = track.thirdpersonTPIKSmoothing
            if not cache or cache.model ~= model then
                cache = { model = model }
                track.thirdpersonTPIKSmoothing = cache
            end

            local arm = cache[side]
            if not arm then
                arm = {
                    goal = Vector(localGoal.x, localGoal.y, localGoal.z),
                    pole = Vector(localPole.x, localPole.y, localPole.z)
                }
                cache[side] = arm
            else
                local alpha = math.Clamp(1 - math.exp(-speed * RealFrameTime()), 0, 1)
                arm.goal.x = arm.goal.x + (localGoal.x - arm.goal.x) * alpha
                arm.goal.y = arm.goal.y + (localGoal.y - arm.goal.y) * alpha
                arm.goal.z = arm.goal.z + (localGoal.z - arm.goal.z) * alpha
                arm.pole.x = arm.pole.x + (localPole.x - arm.pole.x) * alpha
                arm.pole.y = arm.pole.y + (localPole.y - arm.pole.y) * alpha
                arm.pole.z = arm.pole.z + (localPole.z - arm.pole.z) * alpha
            end

            return anchor * arm.goal, anchor * arm.pole
        end

        local function StabilizePole(ply, track, side, shoulder, goal, sourcePole, nativePole, renderAngles)
            local direction = goal - shoulder
            if direction:LengthSqr() <= 0.0001 then return sourcePole end
            direction:Normalize()

            renderAngles = renderAngles or (IsValid(ply) and ply.GetRenderAngles and ply:GetRenderAngles()) or Angle(0, 0, 0)
            local sideSign = side == "L" and -1 or 1
            local sidePole = shoulder
                + renderAngles:Right() * (sideSign * 12)
                - renderAngles:Up() * 6
                + direction * 4

            local data = track.data or {}
            local sourceWeight = tonumber(data.thirdperson_pole_source)
            if sourceWeight == nil then sourceWeight = 0.35 end
            if GCAL.GetTPIKOptionAdd then
                sourceWeight = sourceWeight + GCAL:GetTPIKOptionAdd(track.name, "pole_source")
            end
            sourceWeight = math.Clamp(sourceWeight, 0, 1)

            local nativeWeight = tonumber(data.thirdperson_pole_native)
            if nativeWeight == nil then nativeWeight = 0.35 end
            if GCAL.GetTPIKOptionAdd then
                nativeWeight = nativeWeight + GCAL:GetTPIKOptionAdd(track.name, "pole_native")
            end
            nativeWeight = math.Clamp(nativeWeight, 0, 1)

            local pole = LerpVector(nativeWeight, sidePole, nativePole or sidePole)
            pole = LerpVector(sourceWeight, pole, sourcePole or pole)

            local poleDelta = pole - shoulder
            local upward = poleDelta:Dot(renderAngles:Up())
            if upward > 0 then
                pole = pole - renderAngles:Up() * upward * 0.85
            end

            return pole
        end

        local hiddenThirdPersonMaterial = CreateMaterial("gcal_thirdperson_hidden", "UnlitGeneric", {
            ["$basetexture"] = "color/white",
            ["$translucent"] = "1",
            ["$alpha"] = "0",
            ["$vertexalpha"] = "1"
        })
        local hiddenThirdPersonMaterialName = hiddenThirdPersonMaterial:GetName()
        local thirdPersonArmMaterialTokens = {
            "c_arm",
            "/arms",
            "_arms",
            "arm_",
            "forearm",
            "/hands",
            "_hands",
            "hand_",
            "glove",
            "sleeve",
            "v_models",
            "viewmodel",
            "player_shared"
        }

        local function ConfigureThirdPersonModelMaterials(track)
            local model = track.thirdpersonModel
            if not IsValid(model) or track.thirdpersonMaterialsConfigured then return end
            track.thirdpersonMaterialsConfigured = true

            local hideTokens = table.Copy(thirdPersonArmMaterialTokens)
            local extraHideTokens = track.data.thirdperson_hide_materials
            if isstring(extraHideTokens) then extraHideTokens = { extraHideTokens } end
            for _, token in ipairs(extraHideTokens or {}) do
                hideTokens[#hideTokens + 1] = string.lower(tostring(token))
            end

            local keepTokens = track.data.thirdperson_keep_materials
            if isstring(keepTokens) then keepTokens = { keepTokens } end

            local visibleMaterialCount = 0
            local materials = model:GetMaterials() or {}
            for index, materialName in ipairs(materials) do
                local lowerName = string.lower(materialName)
                local hide = false
                for _, token in ipairs(hideTokens) do
                    if string.find(lowerName, token, 1, true) then
                        hide = true
                        break
                    end
                end
                for _, token in ipairs(keepTokens or {}) do
                    if string.find(lowerName, string.lower(tostring(token)), 1, true) then
                        hide = false
                        break
                    end
                end

                if hide then
                    model:SetSubMaterial(index - 1, hiddenThirdPersonMaterialName)
                else
                    visibleMaterialCount = visibleMaterialCount + 1
                end
            end

            track.thirdpersonModelHasVisibleMaterials = #materials == 0 or visibleMaterialCount > 0
        end

        local function PrepareThirdPersonModel(track, sourceToTarget)
            local model = track.thirdpersonModel
            if not IsValid(model) or track.data.thirdperson_model == false then return end

            ConfigureThirdPersonModelMaterials(track)
            if not track.thirdpersonModelHasVisibleMaterials then return end

            model:SetPos(track.model:GetPos())
            model:SetAngles(track.model:GetAngles())
            -- Source bones already contain any legacy mirror. Mirroring the visible
            -- clone again moves separately weighted props around the model origin.
            model:SetModelScale(1)
            model:SetSkin(track.model:GetSkin())
            for _, bodygroup in ipairs(track.model:GetBodyGroups() or {}) do
                model:SetBodygroup(bodygroup.id, track.model:GetBodygroup(bodygroup.id))
            end
            model:SetCycle(track.cycle or 0)
            model:SetupBones()

            for bone = 0, model:GetBoneCount() - 1 do
                local matrix = track.model:GetBoneMatrix(bone) or model:GetBoneMatrix(bone)
                if matrix and sourceToTarget then
                    local transformed = sourceToTarget * matrix
                    model:SetBoneMatrix(bone, transformed)
                    model:SetBonePosition(bone, transformed:GetTranslation(), transformed:GetAngles())
                end
            end

            track.thirdpersonModelReadyFrame = FrameNumber()
            track.debugThirdPersonModel = model:GetModel()
        end

        local function ApplyCachedThirdPersonBones(track, ply)
            local matrices = track.thirdpersonBoneMatrices
            if not matrices then return false end

            for targetBone, matrix in pairs(matrices) do
                ply:SetBoneMatrix(targetBone, matrix)
                ply:SetBonePosition(targetBone, matrix:GetTranslation(), matrix:GetAngles())
            end

            return true
        end

        local function ApplyThirdPersonBones(track, ply, weapon, baseMatrices)
            if not IsValid(track.model) or not baseMatrices then return end
            if track.thirdpersonSolveFrame == FrameNumber() then
                ApplyCachedThirdPersonBones(track, ply)
                return
            end

            local flip = GetLegacyFlipState(weapon)
            local targetBones = GetTrackTargetBones(track, weapon, flip)
            local renderAngles = ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles()
            PlaceTPIKTrackModel(track, ply:GetPos(), renderAngles)
            track.model:SetModelScale(GetTrackModelScale(track, weapon, flip))
            track.model:SetupBones()

            local blendToTarget = math.Clamp(
                (track.legacyMatrixLerp and GCAL.Lerp.Legacy or Lerp)(
                    track.lerpVal or 1,
                    0,
                    1,
                    track.lerpCurve or (track.data and track.data.lerp_curve) or 1
                ),
                0,
                1
            )
            local mappings = {}
            local mappingsByTarget = {}

            for k, boneName in ipairs(track.bones) do
                local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
                local targetBoneName = targetBones[k] or boneName
                local targetBone = GetCachedBoneIndex(ply, targetBoneName)
                if not targetBone or targetBone < 0 then continue end

                local sourceBone = GetCachedBoneIndex(track.model, sourceBoneName)
                local sourceWorld = sourceBone and sourceBone >= 0
                    and track.model:GetBoneMatrix(sourceBone)
                local targetWorld = baseMatrices[targetBone]
                if not targetWorld then continue end

                local isHelperBone = string.EndsWith(targetBoneName, "_Wrist")
                    or string.EndsWith(targetBoneName, "_Ulna")
                if not sourceWorld and not isHelperBone then continue end

                local mapping = {
                    name = targetBoneName,
                    sourceBone = sourceBone,
                    sourceWorld = sourceWorld,
                    targetBone = targetBone,
                    targetWorld = targetWorld
                }

                mappings[#mappings + 1] = mapping
                mappingsByTarget[targetBone] = mapping
            end

            local finalMatrices = {}
            local thirdPersonModelTransform
            local function SolveArm(side)
                local upperName = "ValveBiped.Bip01_" .. side .. "_UpperArm"
                local forearmName = "ValveBiped.Bip01_" .. side .. "_Forearm"
                local handName = "ValveBiped.Bip01_" .. side .. "_Hand"
                local upperBone = GetCachedBoneIndex(ply, upperName)
                local forearmBone = GetCachedBoneIndex(ply, forearmName)
                local handBone = GetCachedBoneIndex(ply, handName)
                local upper = upperBone and mappingsByTarget[upperBone]
                local forearm = forearmBone and mappingsByTarget[forearmBone]
                local hand = handBone and mappingsByTarget[handBone]
                if not upper or not forearm or not hand then return end

                local sourceUpper = upper.sourceWorld
                local sourceForearm = forearm.sourceWorld
                local sourceHand = hand.sourceWorld
                local targetUpper = upper.targetWorld
                local targetForearm = forearm.targetWorld
                local targetHand = hand.targetWorld

                local sourceAnchor = sourceUpper
                local targetAnchor = targetUpper
                local sourceUpperParent = track.model:GetBoneParent(upper.sourceBone)
                local targetUpperParent = ply:GetBoneParent(upperBone)
                if sourceUpperParent and sourceUpperParent >= 0 then
                    sourceAnchor = track.model:GetBoneMatrix(sourceUpperParent) or sourceAnchor
                end
                if targetUpperParent and targetUpperParent >= 0 then
                    targetAnchor = baseMatrices[targetUpperParent] or targetAnchor
                end

                local sourceAnchorInverse = Matrix(sourceAnchor:ToTable())
                sourceAnchorInverse:Invert()
                local sourceToTarget = Matrix(targetAnchor:ToTable()) * sourceAnchorInverse
                local shoulder = targetUpper:GetTranslation()
                local upperLength = shoulder:Distance(targetForearm:GetTranslation())
                local forearmLength = targetForearm:GetTranslation():Distance(targetHand:GetTranslation())
                local sourceLength = sourceUpper:GetTranslation():Distance(sourceForearm:GetTranslation())
                    + sourceForearm:GetTranslation():Distance(sourceHand:GetTranslation())
                if upperLength <= 0.001 or forearmLength <= 0.001 or sourceLength <= 0.001 then return end

                local scale = (upperLength + forearmLength) / sourceLength
                local mappedHand = sourceToTarget * sourceHand:GetTranslation()
                local mappedElbow = sourceToTarget * sourceForearm:GetTranslation()
                local goal = shoulder + (mappedHand - shoulder) * scale
                local data = track.data or {}
                local clampRadius = tonumber(data.thirdperson_target_radius)
                if clampRadius == nil then clampRadius = 38 end
                if GCAL.GetTPIKOptionAdd then
                    clampRadius = clampRadius + GCAL:GetTPIKOptionAdd(track.name, "target_radius")
                end
                goal = ClampVectorAround(GetTorsoClampOrigin(ply, baseMatrices), goal, clampRadius)

                local sourcePole = shoulder + (mappedElbow - shoulder) * scale
                local pole = StabilizePole(
                    ply,
                    track,
                    side,
                    shoulder,
                    goal,
                    sourcePole,
                    targetForearm:GetTranslation(),
                    renderAngles
                )
                local mappedHandMatrix = sourceToTarget * sourceHand
                goal, pole = SmoothArmTargets(
                    track,
                    ply,
                    side,
                    targetAnchor,
                    goal,
                    pole
                )
                local elbow, handGoal = SolveTwoBoneIK(
                    shoulder,
                    goal,
                    pole,
                    upperLength,
                    forearmLength
                )
                if not elbow then return end

                local solvedUpper = AimBoneMatrix(
                    targetUpper,
                    targetForearm:GetTranslation(),
                    shoulder,
                    elbow
                )
                local solvedForearm = AimBoneMatrix(
                    targetForearm,
                    targetHand:GetTranslation(),
                    elbow,
                    handGoal
                )
                local solvedHand = mappedHandMatrix
                solvedHand:SetTranslation(handGoal)

                finalMatrices[upperBone] = BlendBoneMatrix(solvedUpper, targetUpper, blendToTarget)
                finalMatrices[forearmBone] = BlendBoneMatrix(solvedForearm, targetForearm, blendToTarget)
                finalMatrices[handBone] = BlendBoneMatrix(solvedHand, targetHand, blendToTarget)

                if not thirdPersonModelTransform then
                    local sourceHandInverse = Matrix(sourceHand:ToTable())
                    sourceHandInverse:Invert()
                    thirdPersonModelTransform = Matrix(finalMatrices[handBone]:ToTable()) * sourceHandInverse
                end
            end

            SolveArm("L")
            SolveArm("R")

            local solving = {}
            local function SolveChild(mapping)
                if finalMatrices[mapping.targetBone] then return finalMatrices[mapping.targetBone] end
                if solving[mapping.targetBone] then return mapping.targetWorld end
                solving[mapping.targetBone] = true

                local targetLocal, targetParent = BoneLocalMatrix(
                    ply,
                    mapping.targetBone,
                    mapping.targetWorld,
                    baseMatrices
                )
                local parentMapping = mappingsByTarget[targetParent]
                local parentWorld
                if parentMapping then
                    parentWorld = SolveChild(parentMapping)
                else
                    parentWorld = finalMatrices[targetParent] or baseMatrices[targetParent]
                end

                if not parentWorld then
                    solving[mapping.targetBone] = nil
                    return mapping.targetWorld
                end

                local localMatrix = Matrix(targetLocal:ToTable())
                local isHelperBone = string.EndsWith(mapping.name, "_Wrist")
                    or string.EndsWith(mapping.name, "_Ulna")
                if not isHelperBone and mapping.sourceBone and mapping.sourceWorld then
                    local sourceLocal = BoneLocalMatrix(
                        track.model,
                        mapping.sourceBone,
                        mapping.sourceWorld
                    )
                    localMatrix:SetAngles(sourceLocal:GetAngles())
                end

                local animated = parentWorld * localMatrix
                finalMatrices[mapping.targetBone] = BlendBoneMatrix(
                    animated,
                    mapping.targetWorld,
                    blendToTarget
                )
                solving[mapping.targetBone] = nil
                return finalMatrices[mapping.targetBone]
            end

            for _, mapping in ipairs(mappings) do
                SolveChild(mapping)
            end
            if not thirdPersonModelTransform and mappings[1] and mappings[1].sourceWorld then
                local sourceInverse = Matrix(mappings[1].sourceWorld:ToTable())
                sourceInverse:Invert()
                thirdPersonModelTransform = Matrix(mappings[1].targetWorld:ToTable()) * sourceInverse
            end

            local carried = {}
            local function CarryArmChildren(parentBone)
                if carried[parentBone] then return end
                carried[parentBone] = true

                for _, childBone in ipairs(GetCachedChildBones(ply, parentBone)) do
                    if not finalMatrices[childBone] then
                        local baseParent = baseMatrices[parentBone]
                        local baseChild = baseMatrices[childBone]
                        local solvedParent = finalMatrices[parentBone]
                        if baseParent and baseChild and solvedParent then
                            local baseParentInverse = Matrix(baseParent:ToTable())
                            baseParentInverse:Invert()
                            finalMatrices[childBone] = solvedParent * baseParentInverse * baseChild
                        end
                    end

                    if finalMatrices[childBone] then
                        CarryArmChildren(childBone)
                    end
                end
            end

            for _, side in ipairs({ "L", "R" }) do
                local upperBone = GetCachedBoneIndex(ply, "ValveBiped.Bip01_" .. side .. "_UpperArm")
                if upperBone and upperBone >= 0 and finalMatrices[upperBone] then
                    CarryArmChildren(upperBone)
                end
            end

            track.thirdpersonBoneMatrices = finalMatrices
            track.thirdpersonSolveFrame = FrameNumber()
            ApplyCachedThirdPersonBones(track, ply)

            track.debugTargetEntity = tostring(ply)
            track.debugBoneCount = table.Count(finalMatrices)
                track.debugThirdPersonRootBone = mappings[1] and mappings[1].targetBone or nil
                track.debugThirdPersonMode = "tpik"
                track.debugThirdPersonPole = "stabilized"
                PrepareThirdPersonModel(track, thirdPersonModelTransform)
            end



    return {
        ApplyCachedThirdPersonBones = ApplyCachedThirdPersonBones,
        ApplyThirdPersonBones = ApplyThirdPersonBones
    }
end
