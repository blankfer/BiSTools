-- BiSTools / Core / Init.lua
-- First file to load. Owns the namespace, the palette, and the saved DB.
local ADDON, NS = ...
_G.BiSTools = NS

-- version from the TOC, never a literal that drifts (house law); the literal is the
-- fallback only and the harness holds it equal to ## Version
local VERSION_FALLBACK = "1.1.0"   -- == ## Version in the TOC; the harness scans for this
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or VERSION_FALLBACK
-- THE BUILD STAMP (Arn, 6 Nov 2026: "a finger print thing only you can see so you know what version i am on"):
-- _bisdev/deploy.sh writes "## X-BiS-Build: <branch>@<commit> <MMDD-HHMM>" into the COPY it puts in the game; a
-- released zip has none, so this is nil there. Windows show it faint beside the version.
NS.BUILD = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "X-BiS-Build"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "X-BiS-Build")) or nil
if NS.BUILD == "" then NS.BUILD = nil end
--- What a window prints, faint, so a screenshot says which copy it is: "0.20.2  d5b473d 1106-2221" on a test build
--- (Arn, 6 Nov: "print the version number somewhere so you can see on the screenshots"), the version alone on a release.
function NS.Stamp()
  local sha = NS.BUILD and NS.BUILD:match("@(%S+)")
  local when = NS.BUILD and NS.BUILD:match("(%S+)$")
  return sha and (tostring(NS.VERSION) .. "  " .. sha .. " " .. (when or "")) or tostring(NS.VERSION)
end

-- Palette: prefer BiSTheme (loads before us? no - alphabetical, BiSTheme > BiSTools,
-- so resolve lazily on first use), fall back to the inline BiS palette.
local FALLBACK = {
  bg = "121020", surface = "1a1730", sunken = "221d3c", line = "2a2446",
  line2 = "3a3260", ink = "ece8f6", ink2 = "c6bedd", muted = "968ead",
  accent = "b980ff", accentSoft = "2c2148", good = "4fd0cf", warn = "f08cb0",
  gold = "e5c04a", slate = "8fb4d6", dim = "8e86a6",
}
local function hx(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local T = {}
function T.rgb(name)
  local BT = _G.BiSTheme
  if BT and BT.rgb then return BT.rgb(name) end
  return hx(FALLBACK[name] or FALLBACK.ink)
end
function T.rgba(name, a)
  local r, g, b = T.rgb(name)
  return r, g, b, a or 1
end
function T.text(name, s)
  local BT = _G.BiSTheme
  if BT and BT.text then return BT.text(name, s) end
  return "|cff" .. (FALLBACK[name] or FALLBACK.ink) .. tostring(s) .. "|r"
end
NS.T = T

NS.PREFIX = T.text("accent", "BiS") .. " Tools"
function NS.Print(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(NS.PREFIX .. ": " .. msg)
end

--- OUR OWN RAID-WARNING LINE (7 Nov 2026, Arn's BugGrabber, 19x: "RaidWarning.lua:233 attempt to perform arithmetic
--- on a secret number (tainted by BiSTools)"). RaidNotice_AddMessage put our text into Blizzard's RaidWarningFrame,
--- and from then on its own fade ran as OUR code. So BiS Tools draws its call-outs (a rival nearby, a summon) in a
--- MessageFrame of its own, laid ON the raid warning's spot with the same big, fading look. Blizzard's frame is only
--- anchored to, never written into. rgb: { r, g, b } (default: the raid warning's orange).
NS.ALERT = { size = 26, visible = 5, fade = 2, y = -260 }
function NS.Alert(text, rgb)
  if text == nil then return false end
  local f = NS.alertFrame
  if not f then
    f = CreateFrame("MessageFrame", "BiSToolsAlert", UIParent)
    f:SetSize(512, 70)
    local rw = rawget(_G, "RaidWarningFrame")
    if not pcall(f.SetPoint, f, "TOP", rw or UIParent, "TOP", 0, rw and 0 or NS.ALERT.y) then
      f:SetPoint("TOP", UIParent, "TOP", 0, NS.ALERT.y)
    end
    if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
    f:SetFont(STANDARD_TEXT_FONT, NS.ALERT.size, "THICKOUTLINE")
    if f.SetJustifyH then f:SetJustifyH("CENTER") end
    f:SetInsertMode("TOP")
    f:SetFading(true)
    f:SetTimeVisible(NS.ALERT.visible)
    f:SetFadeDuration(NS.ALERT.fade)
    NS.alertFrame = f
  end
  local c = type(rgb) == "table" and rgb or (ChatTypeInfo and ChatTypeInfo.RAID_WARNING) or nil
  local r, g, b = 1, 0.5, 0
  if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
    r, g, b = c.r, c.g, c.b
  end
  f:AddMessage(text, r, g, b)
  return true
end

-- Saved variables. Each tool keeps its own sub-table: NS.DB().tools[name].
local DEFAULTS = { tools = {}, enabled = {} }
function NS.DB()
  return BiSToolsDB
end

--- The saved table as the client hands it back at ADDON_LOADED -> the table to use. NOTHING handed back (nil) is a
--- NEW install: Forever 1.0 starts it with every tool off (Registry R:Forever10). Anything handed back is an
--- existing save: frozen as it was, once. Caveat: Forever was measured once handing back no SavedVariables for an
--- existing user; BiS Tools keeps no per-character mirror, so that load comes up quiet - the safe side.
function NS.OpenDB(saved)
  local isNew = type(saved) ~= "table"
  local db = isNew and {} or saved
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then db[k] = type(v) == "table" and {} or v end
  end
  if not db.forever10 and NS.Registry then NS.Registry:Forever10(db, isNew) end
  return db
end

-- The shared BiS channel (Libs/LibBiSComm-1.0, embedded from _bisdev). It is
-- NOT a tool: no Registry entry, no on/off in /bist. Every tool may be switched
-- off and this client still answers the raid, or "one addon gets you half way"
-- dies quietly. The lib has no SavedVariables, so the off switch (/biscomm off)
-- is remembered here and restored on the next login.
NS.Comm = {}
function NS.Comm.Lib() return _G.LibBiSComm end
function NS.Comm.Boot()
  local lib = _G.LibBiSComm
  if not lib then return end
  lib:RegisterAddon(ADDON, NS.VERSION)
  if BiSToolsDB.comm == false then lib:SetEnabled(false) end
  if BiSToolsDB.commShare == false and lib.SetSharing then lib:SetSharing(false) end   -- /biscomm share off (minor 12)
  lib:Boot()
end
function NS.Comm.Save()
  local lib = _G.LibBiSComm
  if lib and BiSToolsDB then BiSToolsDB.comm = lib:Enabled() and true or false end
  if lib and BiSToolsDB and lib.Sharing then BiSToolsDB.commShare = lib:Sharing() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    BiSToolsDB = NS.OpenDB(rawget(_G, "BiSToolsDB"))   -- nil here = a new install (looked at BEFORE any default)
    NS.Comm.Boot()
    NS.Registry:InitAll()
  elseif event == "PLAYER_LOGIN" then
    NS.Registry:Fire("OnLogin")
  elseif event == "PLAYER_LOGOUT" then
    NS.Comm.Save()
  end
end)
