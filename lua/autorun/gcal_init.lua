if SERVER then
    AddCSLuaFile("gcal/gcal_lerp.lua")
    AddCSLuaFile("gcal/gcal_core.lua")
    AddCSLuaFile("gcal/gcal_compat.lua")
    AddCSLuaFile("gcal/gcal_legs.lua")
    AddCSLuaFile("gcal/gcal_base_anims.lua")
    AddCSLuaFile("gcal/gcal_menu.lua")
    AddCSLuaFile("gcal/gcal_debug_menu.lua")
    AddCSLuaFile("autorun/client/gcal_menu_autorun.lua")
end

if CLIENT then
    GCAL = GCAL or {}
    if not GetConVar("gcal_conflict_popup") then
        CreateClientConVar("gcal_conflict_popup", "1", true, false, "Show GCAL's conflict warning popup when incompatible addons are detected.")
    end

        --[[
        Hey! This shouldn't be touched, really. 
        I try to put in addons that I know don't work.
        This list changes all the time and please let me know if anything should be changed!
        There are many ways to contact me, creating fights or trying to override it are just not the way to go about it.
        Thanks for taking the time to read this. 
        ~Midawek
        ]]
    local conflictingWorkshopAddons = {
        ["2155366756"] = "VManip (Base)",
        ["3262499127"] = "Chen's VManip Patch",
        ["3080114310"] = "VManip (Base) Remix 2024",
        ["3039950711"] = "VManip (Fix_and_function)",
        ["3425927104"] = "Vmanip Base with knockdown",
        ["2844472642"] = "Vmanip +",
        ["3714993549"] = "Vmanip (Lite)",
        ["349050451"] = "Chuck's Weaponry 2.0",
        -- ["1234567890"] = "Example Addon"
    }

    function GCAL:RegisterConflictingWorkshopAddon(workshopID, label)
        workshopID = tostring(workshopID or "")
        if workshopID == "" then return end

        conflictingWorkshopAddons[workshopID] = label or ("Workshop addon " .. workshopID)
    end

    local function GetMountedConflictingWorkshopAddons()
        local found = {}

        for _, addon in ipairs(engine.GetAddons()) do
            local workshopID = tostring(addon.wsid or "")
            local label = conflictingWorkshopAddons[workshopID]

            if label and addon.mounted then
                found[#found + 1] = {
                    id = workshopID,
                    label = label,
                    display = label .. " [" .. workshopID .. "]"
                }
            end
        end

        table.sort(found, function(a, b)
            return a.display < b.display
        end)
        return found
    end

    local function ConflictPopupEnabled()
        local convar = GetConVar("gcal_conflict_popup")
        return convar == nil or convar:GetBool()
    end

    local function ShowConflictPopup(hasLegacyFile, mountedConflicts)
        local colBg = Color(14, 16, 21, 242)
        local colPanel = Color(22, 25, 32, 248)
        local colPanelSoft = Color(30, 35, 44, 238)
        local colHeader = Color(27, 33, 41, 245)
        local colLine = Color(110, 126, 148, 78)
        local colText = Color(239, 243, 248)
        local colMuted = Color(151, 163, 177)
        local colAccent = Color(102, 207, 177)
        local colWarn = Color(241, 181, 103)
        local colBad = Color(236, 116, 121)
        local logoMaterial = Material("gcal/logo", "smooth")
        local prideLogoMaterial = Material("gcal/pridelogo", "smooth")

        local function PaintConflictButton(btn, w, h)
            btn.GCALHover = Lerp(FrameTime() * 12, btn.GCALHover or 0, btn:IsHovered() and 1 or 0)

            local a = btn.GCALHover
            local accent = btn.GCALAccent or colAccent
            local fill = Color(
                Lerp(a, colPanelSoft.r, accent.r * 0.45),
                Lerp(a, colPanelSoft.g, accent.g * 0.45),
                Lerp(a, colPanelSoft.b, accent.b * 0.45),
                225
            )

            draw.RoundedBox(5, 0, 0, w, h, fill)
            surface.SetDrawColor(accent.r, accent.g, accent.b, 50 + a * 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.RoundedBox(2, 8, 8, 3, h - 16, Color(accent.r, accent.g, accent.b, 160 + a * 60))
            draw.SimpleText(btn.GCALText or "", "GCAL.Menu.Body", 19, h * 0.5 - 1, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local lines = {
            "Conflicting addons were detected.",
            "Please disable them to prevent issues.",
            "GCAL won't work with those properly. It doesn't stop any code execution and you're free to use GCAL with them, but expect various issues.",
            "If you post a bug/issue with any of these addons on, you'll get laughed at and/or ignored. So please disable them before reporting issues regarding GCAL.",
        }

        if hasLegacyFile then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Legacy VManip files were also detected."
        end

        if #mountedConflicts > 0 then
            lines[#lines + 1] = ""
            lines[#lines + 1] = "Mounted Workshop conflicts:"

            for _, addon in ipairs(mountedConflicts) do
                lines[#lines + 1] = " - " .. addon.display
            end
        end

        surface.PlaySound("buttons/button10.wav")

        local dim = vgui.Create("DPanel")
        dim:SetSize(ScrW(), ScrH())
        dim:MakePopup()
        dim:SetKeyboardInputEnabled(false)
        dim:SetMouseInputEnabled(false)
        function dim:Paint(w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(2, 4, 8, 178))
        end

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(math.min(ScrW() - 80, 760), math.min(ScrH() - 70, 680))
        frame:Center()
        frame:MakePopup()
        frame:SetSizable(false)
        frame:SetDraggable(true)
        frame.StartTime = SysTime()
        if IsValid(frame.btnMinim) then
            frame.btnMinim:SetVisible(false)
            frame.btnMinim:SetEnabled(false)
        end
        if IsValid(frame.btnMaxim) then
            frame.btnMaxim:SetVisible(false)
            frame.btnMaxim:SetEnabled(false)
        end
        frame.OnClose = function()
            if IsValid(dim) then
                dim:Remove()
            end
        end

        function frame:Paint(w, h)
            Derma_DrawBackgroundBlur(self, self.StartTime)
            draw.RoundedBox(0, 0, 0, w, h, colBg)
            draw.RoundedBox(0, 1, 1, w - 2, h - 2, colPanel)
            draw.RoundedBox(0, 1, 1, w - 2, 92, colHeader)
            surface.SetDrawColor(colLine)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            surface.DrawLine(16, 92, w - 16, 92)

            local titleX = 16
            local prideConVar = GetConVar("gcal_pride")
            local prideEnabled = prideConVar and prideConVar:GetBool() or false
            local activeLogoMaterial = prideEnabled and prideLogoMaterial or logoMaterial
            if not activeLogoMaterial:IsError() then
                local logoAspect = activeLogoMaterial:Width() / math.max(activeLogoMaterial:Height(), 1)
                local logoMaxWidth = 112
                local logoMaxHeight = 58
                local logoWidth = math.min(logoMaxWidth, logoMaxHeight * logoAspect)
                local logoHeight = logoWidth / math.max(logoAspect, 0.01)
                local logoY = 15 + (logoMaxHeight - logoHeight) * 0.5
                local logoX = 16

                surface.SetMaterial(activeLogoMaterial)
                surface.SetDrawColor(255, 255, 255, prideEnabled and 245 or 235)
                surface.DrawTexturedRect(logoX, logoY, logoWidth, logoHeight)

                titleX = 16 + math.min(logoMaxWidth, logoMaxHeight * logoAspect) + 14
            end

            draw.SimpleText("GCAL Conflict Warning", "GCAL.Menu.Title", titleX, 15, colText, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Conflicting addons can break GCAL in unexpected ways!", "GCAL.Menu.Subtitle", titleX + 1, 47, colMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local pillText = tostring((hasLegacyFile and 1 or 0) + #mountedConflicts) .. " detected"
            draw.RoundedBox(5, w - 124, 18, 98, 22, Color(colWarn.r, colWarn.g, colWarn.b, 26))
            surface.SetDrawColor(colWarn.r, colWarn.g, colWarn.b, 150)
            surface.DrawOutlinedRect(w - 124, 18, 98, 22, 1)
            draw.SimpleText(pillText, "GCAL.Menu.Small", w - 75, 28, colWarn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local content = vgui.Create("DScrollPanel", frame)
        content:Dock(FILL)
        content:DockMargin(16, 108, 16, 104)

        local bar = content:GetVBar()
        bar:SetWide(5)
        bar.Paint = nil
        bar.btnUp.Paint = nil
        bar.btnDown.Paint = nil
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(colAccent.r, colAccent.g, colAccent.b, 115))
        end

        for _, line in ipairs(lines) do
            if line == "" then
                local spacer = content:Add("DPanel")
                spacer:Dock(TOP)
                spacer:SetTall(8)
                spacer:SetPaintBackground(false)
            else
                local row = content:Add("DPanel")
                row:Dock(TOP)
                row:DockMargin(0, 0, 0, 6)
                row:SetTall(34)
                row.GCALText = line
                row.GCALAccent = string.StartsWith(line, " - ") and colMuted or colWarn

                local label = vgui.Create("DLabel", row)
                label:Dock(FILL)
                label:DockMargin(19, 7, 10, 7)
                label:SetWrap(true)
                label:SetAutoStretchVertical(true)
                label:SetFont("GCAL.Menu.Body")
                label:SetTextColor(string.StartsWith(line, " - ") and colMuted or colText)
                label:SetText(line)

                row.PerformLayout = function(self, w)
                    label:SetWide(math.max(w - 29, 1))
                    label:SizeToContentsY()
                    self:SetTall(math.max(34, label:GetTall() + 14))
                end

                row.Paint = function(self, w, h)
                    draw.RoundedBox(5, 0, 0, w, h, Color(colPanelSoft.r, colPanelSoft.g, colPanelSoft.b, 150))
                    surface.SetDrawColor(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 48)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.RoundedBox(2, 8, 8, 3, h - 16, Color(self.GCALAccent.r, self.GCALAccent.g, self.GCALAccent.b, 110))
                end
            end
        end

        local workshopButton = vgui.Create("DButton", frame)
        workshopButton:Dock(BOTTOM)
        workshopButton:DockMargin(16, 0, 16, 8)
        workshopButton:SetTall(34)
        workshopButton:SetText("")
        workshopButton.GCALText = "Open Subscribed Addons"
        workshopButton.GCALAccent = colAccent
        workshopButton.Paint = PaintConflictButton
        workshopButton.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            local ply = LocalPlayer()
            local steamID64 = IsValid(ply) and ply:SteamID64() or ""
            if steamID64 == "" then
                gui.OpenURL("https://steamcommunity.com/workshop/browse/?appid=4000")
                return
            end

            gui.OpenURL("https://steamcommunity.com/profiles/" .. steamID64 .. "/myworkshopfiles?appid=4000&browsefilter=mysubscriptions")
        end

        local closeButton = vgui.Create("DButton", frame)
        closeButton:Dock(BOTTOM)
        closeButton:DockMargin(16, 0, 16, 16)
        closeButton:SetTall(34)
        closeButton:SetText("")
        closeButton.GCALText = "I know what I am doing, close this warning."
        closeButton.GCALAccent = colBad
        closeButton.Paint = PaintConflictButton
        closeButton.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            frame:Close()
        end

        local suppressCheck = vgui.Create("DCheckBoxLabel", frame)
        suppressCheck:Dock(BOTTOM)
        suppressCheck:DockMargin(18, 0, 16, 8)
        suppressCheck:SetTall(24)
        suppressCheck:SetText("Do not show this popup again")
        suppressCheck:SetTextColor(colMuted)
        suppressCheck:SetFont("GCAL.Menu.Body")
        suppressCheck:SetChecked(not ConflictPopupEnabled())
        suppressCheck.OnChange = function(_, checked)
            RunConsoleCommand("gcal_conflict_popup", checked and "0" or "1")
        end
    end

    include("gcal/gcal_lerp.lua")
    include("gcal/gcal_core.lua")
    include("gcal/gcal_menu.lua")
    include("gcal/gcal_compat.lua")
    include("gcal/gcal_legs.lua")
    include("gcal/gcal_base_anims.lua")
    include("gcal/gcal_debug_menu.lua")
    
    print("GCAL (Client) Initialized! :3")

    timer.Simple(1, function()
        local prideConVar = GetConVar("gcal_pride")
        if not prideConVar or not prideConVar:GetBool() then return end

        local prideColors = {
            Color(228, 3, 3),
            Color(255, 140, 0),
            Color(255, 237, 0),
            Color(0, 180, 65),
            Color(70, 130, 255),
            Color(170, 80, 210)
        }

        local function PrideChatColor(fraction)
            local scaled = math.Clamp(fraction, 0, 1) * (#prideColors - 1)
            local index = math.min(math.floor(scaled) + 1, #prideColors - 1)
            local blend = scaled - math.floor(scaled)
            local from = prideColors[index]
            local to = prideColors[index + 1]
            local lighten = 0.38

            return Color(
                Lerp(lighten, Lerp(blend, from.r, to.r), 255),
                Lerp(lighten, Lerp(blend, from.g, to.g), 255),
                Lerp(lighten, Lerp(blend, from.b, to.b), 255)
            )
        end

        local function AddPrideChatLine(text)
            local parts = {}
            local length = #text

            for i = 1, length do
                parts[#parts + 1] = PrideChatColor((i - 1) / math.max(length - 1, 1))
                parts[#parts + 1] = string.sub(text, i, i)
            end

            chat.AddText(unpack(parts))
        end

        AddPrideChatLine("GCAL proudly stands with LGBTQ+ players and creators.")
        AddPrideChatLine("You are welcome here. You belong here. Be yourself.")
    end)

    -- Conflict Detection Notice
    timer.Simple(1, function()
        local mountedConflicts = GetMountedConflictingWorkshopAddons()
        local hasLegacyFile = file.Exists("autorun/client/cl_vmanip.lua", "LUA")

        if hasLegacyFile or #mountedConflicts > 0 then
            local msg = "!!! GCAL WARNING: Conflicting Workshop addons detected! !!!"
            local msg2 = "Please disable the conflicting Workshop addons. Info in the popup."
            
            MsgC(Color(255, 0, 0), msg .. "\n")
            MsgC(Color(255, 255, 255), msg2 .. "\n")

            if #mountedConflicts > 0 then
                local displays = {}
                for _, addon in ipairs(mountedConflicts) do
                    displays[#displays + 1] = addon.display
                end
                MsgC(Color(255, 176, 93), "[GCAL] Conflicting mounted Workshop addons: " .. table.concat(displays, ", ") .. "\n")
            end

            if ConflictPopupEnabled() then
                ShowConflictPopup(hasLegacyFile, mountedConflicts)
            else
                MsgC(Color(151, 163, 177), "[GCAL] Conflict popup is disabled. Run gcal_conflict_popup 1 to show it again on startup.\n")
            end
        end
    end)
end

if SERVER then
    util.AddNetworkString("GCAL_Play")
    util.AddNetworkString("GCAL_Stop")
    
    -- Backward compatibility networking
    util.AddNetworkString("VManip_SimplePlay")
    util.AddNetworkString("VManip_StopHold")

    include("gcal/gcal_lerp.lua")
    include("gcal/gcal_core.lua")
    include("gcal/gcal_compat.lua")
    include("gcal/gcal_base_anims.lua")
    
    print("GCAL (Server) Initialized! :3")

    concommand.Add("gcal_menu_open", function(ply)
        if IsValid(ply) then
            ply:ConCommand("gcal_menu_open")
        else
            print("GCAL menu is clientside. Run gcal_menu_open from a player console.")
        end
    end)
end
