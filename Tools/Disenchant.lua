-- BiSTools / Tools / Disenchant.lua - THE DISENCHANT GLOW (6 Nov 2026).
--
-- Arn: "when i hold alt and my mouse is in my bags itll glow items that can be dienchanted purple items that are soul
-- bound red so im more careful about disenchating gear" - BiS JC prospected ore from the bags the same way, but
-- disenchanting destroys gear, so the point is the WARNING: soulbound gear, the gear you may still want, is red.
--
-- ANY BAGS (Arn: "i use ellemere ui but not everyone uses elleseme"). No bag addon is asked. Blizzard's bags,
-- EllesmereUI's and Baganator's are all built of the client's item buttons (ContainerFrameItemButtonTemplate): a
-- button's ID is its slot, its parent's ID its bag. So: the frame under the mouse, up to its window, and the window
-- walked for such buttons - plus Blizzard's own open bags (ContainerFrameN), each a window of its own.
--
-- LEAN: nothing runs until Alt goes down (MODIFIER_STATE_CHANGED) or a bag slot's tooltip opens with Alt held. Away
-- from the bags that is one walk up from the mouse. Over them, one item question per slot. Let go: the glow goes.
-- Paint only: no click, nothing secure, nothing in the bag addon's own code touched.
local _, NS = ...
local R = NS.Registry
local D = {}
NS.DE = D

D.PURPLE = { 0.73, 0.50, 1.00 }        -- can be disenchanted
D.RED    = { 1.00, 0.20, 0.20 }        -- can be disenchanted, and soulbound: careful
D.CLASS  = { [2] = true, [4] = true }  -- Weapon, Armor
D.SKIP   = { [""] = true, INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_NON_EQUIP_IGNORE = true,
             INVTYPE_AMMO = true }      -- not worn, a shirt, a tabard, ammo: nothing to get
D.BAGS   = 4                            -- the backpack (0) and four bags
D.DEPTH  = 8                            -- how deep a bag window is walked
D.BLIZZ  = 13                           -- ContainerFrame1..13
D.PX     = 2

local function plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

--- Every answer of a call, or nothing when it threw.
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2, table.maxn(r))
end

--- "bound" (red), "free" (purple), or nil: not gear worth disenchanting.
function D.Kind(bag, slot)
  local info = ask(C_Container and C_Container.GetContainerItemInfo, bag, slot)
  if type(info) ~= "table" then return nil end
  local q, id = plain(info.quality), plain(info.itemID)
  if type(q) ~= "number" or q < 2 or q > 4 or type(id) ~= "number" then return nil end
  local _, _, _, loc, _, class = ask((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant, id)
  if not D.CLASS[plain(class) or 0] or D.SKIP[plain(loc) or ""] then return nil end
  local bound = plain(info.isBound)
  if bound == nil and C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
    local where = ask(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
    bound = where and plain(ask(C_Item.IsBound, where))
  end
  return bound and "bound" or "free"
end

--- A bag slot's button: its ID the slot, its parent's (or its own GetBagID) the bag. Else nil.
function D.Slot(b)
  if type(b) ~= "table" or type(b.GetID) ~= "function" then return nil end
  local kind = b.GetObjectType and ask(b.GetObjectType, b)
  if kind ~= "Button" and kind ~= "ItemButton" and kind ~= "CheckButton" then return nil end
  local slot = plain(ask(b.GetID, b))
  local bag = b.GetBagID and plain(ask(b.GetBagID, b)) or nil
  if bag == nil then
    local p = b.GetParent and b:GetParent()
    bag = p and p.GetID and plain(ask(p.GetID, p)) or nil
  end
  if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 or bag < 0 or bag > D.BAGS then return nil end
  return bag, slot
end

local function collect(f, out, seen, depth)
  if depth > D.DEPTH or type(f) ~= "table" or seen[f] then return end
  seen[f] = true
  if f.IsVisible and not f:IsVisible() then return end
  local bag, slot = D.Slot(f)
  if bag then out[#out + 1] = { b = f, bag = bag, slot = slot } return end
  if not f.GetChildren then return end
  for _, c in ipairs({ f:GetChildren() }) do collect(c, out, seen, depth + 1) end
end

--- The window under the mouse: up from the frame there until the next step is the screen itself.
function D.Window()
  local foci = GetMouseFoci and ask(GetMouseFoci)
  local f = type(foci) == "table" and foci[1] or (GetMouseFocus and ask(GetMouseFocus)) or nil
  for _ = 1, 30 do
    if type(f) ~= "table" or not f.GetParent then return f end
    local p = f:GetParent()
    if p == nil or p == UIParent then return f end
    f = p
  end
  return f
end

--- The bag slots to paint: the window under the mouse, if it holds any - then Blizzard's other open bags too.
function D.Slots()
  local out, seen = {}, {}
  collect(D.Window(), out, seen, 0)
  if #out == 0 then return out end                              -- the mouse is not in the bags
  for i = 1, D.BLIZZ do collect(_G["ContainerFrame" .. i], out, seen, 0) end
  return out
end

local function paint(b, colour)
  local g = b.bisDE
  if not g then
    g = {}
    g.wash = b:CreateTexture(nil, "OVERLAY", nil, 6)
    g.wash:SetAllPoints()
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do g[side] = b:CreateTexture(nil, "OVERLAY", nil, 7) end
    g.top:SetPoint("TOPLEFT") g.top:SetPoint("TOPRIGHT") g.top:SetHeight(D.PX)
    g.bottom:SetPoint("BOTTOMLEFT") g.bottom:SetPoint("BOTTOMRIGHT") g.bottom:SetHeight(D.PX)
    g.left:SetPoint("TOPLEFT") g.left:SetPoint("BOTTOMLEFT") g.left:SetWidth(D.PX)
    g.right:SetPoint("TOPRIGHT") g.right:SetPoint("BOTTOMRIGHT") g.right:SetWidth(D.PX)
    b.bisDE = g
  end
  local r, gr, bl = colour[1], colour[2], colour[3]
  g.wash:SetColorTexture(r, gr, bl, 0.30)
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do g[side]:SetColorTexture(r, gr, bl, 1) g[side]:Show() end
  g.wash:Show()
  g.on = true
end

local function unpaint(b)
  local g = b and b.bisDE
  if not g then return end
  g.wash:Hide()
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do g[side]:Hide() end
  g.on = false
end

D.lit = {}
function D.Clear()
  for _, b in ipairs(D.lit) do unpaint(b) end
  D.lit = {}
  D.on = false
end

--- Paint every bag slot in the window under the mouse (and Blizzard's open bags). Alt only, tool on only.
function D.Show()
  D.Clear()
  if not (R:Enabled("disenchant") and IsAltKeyDown and IsAltKeyDown()) then return 0 end
  local slots = D.Slots()
  for _, s in ipairs(slots) do
    local kind = D.Kind(s.bag, s.slot)
    if kind then
      paint(s.b, kind == "bound" and D.RED or D.PURPLE)
      D.lit[#D.lit + 1] = s.b
    end
  end
  D.on = #slots > 0
  return #D.lit
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "MODIFIER_STATE_CHANGED")
pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event)
  if event == "MODIFIER_STATE_CHANGED" then
    if IsAltKeyDown and IsAltKeyDown() then D.Show() elseif D.on or #D.lit > 0 then D.Clear() end
  elseif event == "BAG_UPDATE_DELAYED" and D.on then
    D.Show()                                                    -- a bag addon reuses its buttons: paint again
  end
end)
D.events = ev

-- Alt already down when the mouse reaches a bag slot: the slot's tooltip is that moment, whichever bag addon drew it
-- (SetBagItem is the real GameTooltip's own - EllesmereUI and Baganator call it on Forever - but hooking a name that is
-- not there throws at load, so it is asked first)
if GameTooltip and hooksecurefunc and type(GameTooltip.SetBagItem) == "function" then
  hooksecurefunc(GameTooltip, "SetBagItem", function()
    if not D.on and IsAltKeyDown and IsAltKeyDown() then D.Show() end
  end)
end

R:Register({
  name = "disenchant",
  desc = "hold Alt over your bags: gear you can disenchant glows purple, soulbound gear red",
  usage = "/bist on|off disenchant",
  defaults = {},
  OnDisable = function() D.Clear() end,
})
