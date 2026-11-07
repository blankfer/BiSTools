-- BiSTools / Core / Init.lua
-- First file to load. Owns the namespace, the palette, and the saved DB.
local ADDON, NS = ...
_G.BiSTools = NS

-- version from the TOC, never a literal that drifts (house law); the literal is the
-- fallback only and the harness holds it equal to ## Version
local VERSION_FALLBACK = "0.19.1"   -- == ## Version in the TOC; the harness scans for this
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or VERSION_FALLBACK

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

-- Saved variables. Each tool keeps its own sub-table: NS.DB().tools[name].
local DEFAULTS = { tools = {}, enabled = {} }
function NS.DB()
  return BiSToolsDB
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
    BiSToolsDB = BiSToolsDB or {}
    for k, v in pairs(DEFAULTS) do
      if BiSToolsDB[k] == nil then BiSToolsDB[k] = type(v) == "table" and {} or v end
    end
    NS.Comm.Boot()
    NS.Registry:InitAll()
  elseif event == "PLAYER_LOGIN" then
    NS.Registry:Fire("OnLogin")
  elseif event == "PLAYER_LOGOUT" then
    NS.Comm.Save()
  end
end)
