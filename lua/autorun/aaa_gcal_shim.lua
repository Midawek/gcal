if SERVER then
    AddCSLuaFile()
end

GCAL = GCAL or {}
GCAL.Anims = GCAL.Anims or {}
GCAL.ActiveTracks = GCAL.ActiveTracks or {}

VManip = VManip or {}
VMLegs = VMLegs or {}

-- MW Base calls VManip() as a function.
setmetatable(VManip, getmetatable(VManip) or {
    __call = function()
        return true
    end
})

if CLIENT then
    local function GCAL_VManipFallback(_, matrix)
        return matrix or Matrix()
    end

    -- MW Base calls ent:VManip(matrix) during SetupBones.
    for _, metaName in ipairs({"Entity", "Weapon", "Player"}) do
        local meta = FindMetaTable(metaName)
        if meta and not meta.VManip then
            meta.VManip = GCAL_VManipFallback
        end
    end
end

local function StubFalse()
    return false
end

local function StubNil()
    return nil
end

local function StubZero()
    return 0
end

local function StubEmpty()
end

local function ParseRegisterArgs(arg1, arg2, arg3)
    if isstring(arg1) then
        return arg1, arg2
    end

    return arg2, arg3
end

VManip.RegisterAnim = VManip.RegisterAnim or function(self, arg1, arg2, arg3)
    local name, data = ParseRegisterArgs(arg1, arg2, arg3)
    if not name or not data then return end

    self.Anims = self.Anims or GCAL.Anims or {}
    data.__gcal_pending = "vmanip"
    self.Anims[name] = data
end

VManip.GetAnim = VManip.GetAnim or function(self, name)
    self.Anims = self.Anims or GCAL.Anims or {}
    return self.Anims[name]
end

VManip.PlayAnim = VManip.PlayAnim or StubFalse
VManip.IsActive = VManip.IsActive or StubFalse
VManip.IsValid = VManip.IsValid or StubFalse
VManip.Remove = VManip.Remove or StubEmpty
VManip.GetCurrentAnim = VManip.GetCurrentAnim or StubNil
VManip.GetVMGesture = VManip.GetVMGesture or StubNil
VManip.GetLerp = VManip.GetLerp or StubZero
VManip.GetCycle = VManip.GetCycle or StubZero
VManip.SetCycle = VManip.SetCycle or StubEmpty
VManip.IsSegmented = VManip.IsSegmented or StubFalse
VManip.GetCurrentSegment = VManip.GetCurrentSegment or StubNil
VManip.GetSegmentCount = VManip.GetSegmentCount or StubZero
VManip.IsPreventQuit = VManip.IsPreventQuit or StubFalse
VManip.QuitHolding = VManip.QuitHolding or StubEmpty
VManip.QueueAnim = VManip.QueueAnim or StubEmpty
VManip.PlaySegment = VManip.PlaySegment or StubFalse
VManip.Anims = VManip.Anims or GCAL.Anims or {}
VManip.ActiveTracks = VManip.ActiveTracks or GCAL.ActiveTracks or {}

VMLegs.RegisterAnim = VMLegs.RegisterAnim or function(self, arg1, arg2, arg3)
    local name, data = ParseRegisterArgs(arg1, arg2, arg3)
    if not name or not data then return end

    self.Anims = self.Anims or GCAL.Anims or {}
    data.__gcal_pending = "vmlegs"
    self.Anims["legs_" .. name] = data
end

VMLegs.GetAnim = VMLegs.GetAnim or function(self, name)
    self.Anims = self.Anims or GCAL.Anims or {}
    return self.Anims["legs_" .. name] or self.Anims[name]
end

VMLegs.PlayAnim = VMLegs.PlayAnim or StubFalse
VMLegs.IsActive = VMLegs.IsActive or StubFalse
VMLegs.Remove = VMLegs.Remove or StubEmpty
VMLegs.GetCurrentAnim = VMLegs.GetCurrentAnim or StubNil
VMLegs.Anims = VMLegs.Anims or GCAL.Anims or {}
