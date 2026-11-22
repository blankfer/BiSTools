-- BiSTools / Tools / Apps / Disenchant.lua - the tool in the phone (dev/APPS.md).
-- The gear in your bags that can be disenchanted, as the glow marks it (D.Kind): free gear, soulbound gear marked. Looking only: the
-- disenchanting is the processing app's (it knows each item by its own id, so it can never take the wrong one).
local _, NS = ...
local DP = NS.DeckPages
if not (DP and DP.App) then return end

DP.App.disenchant = function()
  local DE, P, D = NS.DE, NS.Proc, BiSTheme.Deck
  local COLOUR = { [2] = "Green", [3] = "Blue", [4] = "Epic" }

  local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return plain(v) end
  end
  --- Every piece: { text, kind, quality, icon, enchanted, bag, slot }, the bags in order - walked once a moment (a paint asks
  --- several times).
  local kept
  local function gear()
    local at = GetTime and GetTime() or 0
    if kept and kept.at == at then return kept end
    kept = { at = at }
    local K = C_Container or {}
    for bag = 0, DE.BAGS do
      for slot = 1, tonumber(ask(K.GetContainerNumSlots, bag)) or 0 do
        local kind = DE.Kind(bag, slot)
        if kind then
          local info = ask(K.GetContainerItemInfo, bag, slot)
          info = type(info) == "table" and info or {}
          local link = plain(info.hyperlink) or ask(K.GetContainerItemLink, bag, slot)
          link = type(link) == "string" and link or nil
          kept[#kept + 1] = { text = link and link:match("%[(.-)%]") or ("item " .. tostring(plain(info.itemID) or "?")), kind = kind,
            quality = plain(info.quality), icon = plain(info.iconFileID) or 134400, enchanted = link and P and P.Enchanted(link) or false, bag = bag, slot = slot }
        end
      end
    end
    return kept
  end
  local function rows(tab)
    local out = {}
    for _, e in ipairs(gear()) do
      local bound = e.kind == "bound"
      if tab == 1 or bound == (tab == 3) then
        out[#out + 1] = { pic = e.icon, text = e.text, right = bound and "BOUND" or e.enchanted and "ENCHANTED" or "", ink = bound and "warn" or "gold",
          tip = (COLOUR[e.quality] or "Gear") .. ", bag " .. (e.bag + 1) .. " slot " .. e.slot .. "." .. (bound and " Soulbound: you may still want it." or "")
            .. (e.enchanted and " Somebody enchanted it: look twice." or "") }
      end
    end
    return out
  end

  return {
    page = {
      tour = { { text = "The gear in your bags that can be disenchanted. BOUND is soulbound: be careful.",
        note = "Hold Alt over your bags: it glows there." } },
      tabs = function() return { "ALL", "FREE", "BOUND" } end,
      boxes = function()
        local all, bound, blue = gear(), 0, 0
        if #all == 0 then return {} end
        for _, e in ipairs(all) do
          if e.kind == "bound" then bound = bound + 1 end
          if (tonumber(e.quality) or 0) >= 3 then blue = blue + 1 end
        end
        return { { "GEAR", #all }, { "FREE", #all - bound, "good" },
          { "BOUND", bound, bound > 0 and "warn" or "dim" }, { "BLUE UP", blue, blue > 0 and "accent" or "dim" } }
      end,
      rows = rows,
      text = function(tab)
        if #gear() == 0 then return "Nothing to disenchant in your bags. Green, blue and epic weapons and armor show up here." end
        if #rows(tab) == 0 then return tab == 3 and "No soulbound gear among it." or "Only soulbound gear: look in BOUND." end
      end,
      say = function() return #gear() > 0 and "Hold Alt over your bags: it glows there" or nil end,
      keys = function()
        return { { word = "PROCESSING", peek = true, tip = "Where it is disenchanted, one item at a time", fn = function() D.Open("BiSTools:tool-processing") end } }
      end,
    },
  }
end
