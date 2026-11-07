-- BiSTools / Tools / Processing.lua - BiS> PROCESSING (6 Nov 2026). The plan: dev/PROCESSING.md.
--
-- Arn: "a processing [mode] ... lists all our stuff for our profession ... clicking it disenchants" - and the look:
-- "when we open a profession that we are in a $1 billion jet fighter, yet our interface is so simple and very
-- functional and very smart and very efficient heads-up display". So the window is a COCKPIT PAGE: a skill TAPE down
-- the left (an airliner's speed tape: your skill boxed in the middle, a red/black barber pole above it - what you
-- cannot do yet - a bug per skill your items need, gold brackets where the game said a rod is needed), the items as
-- FMC rows on the right, one computed line, and a SCRATCHPAD at the foot for the game's own words.
-- BiSTheme's palette carries the cockpit's meanings: teal = ready, purple accent = computed/target, gold = caution,
-- red = limit.
--
-- ENCHANTING FIRST (Chainheal is the enchanter; mining waits for a miner to test on).
--
-- NEVER THE WRONG ITEM (Arn: "two items of the same name ... one of them can have an enchant ... it might accidentally
-- delete my gear"): a row is ONE item by its GUID (the item's own unique id). The row's button is SECURE (Disenchant is
-- a spell cast on an item: type "spell", target-bag / target-slot); its PreClick asks what sits in that slot NOW and a
-- different GUID cancels the click (its type cleared) - and the row is NOT re-aimed inside that click, or the click
-- would land on whatever slid into the slot. Soulbound = SHIFT-click. Alt-click is never used (Gargul rolls on it).
-- ONE warning per mixed name, none for ten identical crafts (Arn: "we don't want to keep saying it 10 times").
-- Right-click a row = ignore that one item (by GUID).
--
-- A ROD (Arn: "higher levels requires a rod"): Forever's rule is not written down anywhere we could find, so the
-- game's own refusal teaches it - "Requires <rod>" after one of our clicks is said on the scratchpad and remembered
-- against that item level (db.blocked); a disenchant that goes through at that level forgets it.
--
-- LEAN: the window paints only while open; a bag change while closed is one walk of the bags (the tools box's
-- "anything ready?"), and only for a character that knows Disenchant. Nothing ticks.
local _, NS = ...
local R = NS.Registry
local P = {}
NS.Proc = P

P.SPELL, P.LINE = 13262, 333                    -- Disenchant; Enchanting's skill line
P.W, P.H = 358, 250                             -- 1.43:1
P.SCALE, P.GLOW = 1.2, 0.35                     -- 20% bigger (Arn: "cant read"); the hover wash, clearly seen
P.ROW, P.ROWS = 20, 7                         -- 7: room for the haul strip under them
P.TAPE_W, P.TAPE_H = 50, 160
P.PX = 1.0                                      -- tape pixels per skill point
P.ICON = "Interface\\Icons\\INV_Enchant_Disenchant"
P.RED = { 0.85, 0.15, 0.15 }
-- the game's own quality colours (Arn, 6 Nov: "green items green name text epic epic name color")
P.QUALITY = { [2] = { 0x1e / 255, 1, 0 }, [3] = { 0, 0x70 / 255, 0xdd / 255 }, [4] = { 0xa3 / 255, 0x35 / 255, 0xee / 255 } }
P.BAGS = 4
-- the skill an item level needs to disenchant: the classic table (uncommon), UNVERIFIED on Forever - the game's
-- refusal corrects it on the scratchpad
P.GATES = { { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 }, { 50, 150 }, { 55, 175 }, { 60, 200 },
            { 65, 225 } }

local function plain(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if not r[1] then return nil end
  return unpack(r, 2, table.maxn(r))
end
local function now() return (GetTime and GetTime()) or 0 end
local function fighting() return InCombatLockdown and InCombatLockdown() and true or false end
local function K() return NS.Farm end
local function rgb(name) return NS.T.rgb(name) end

function P.Need(ilvl)
  if type(ilvl) ~= "number" then return nil end
  for _, g in ipairs(P.GATES) do if ilvl <= g[1] then return g[2] end end
  return 225 + math.ceil((ilvl - 65) / 5) * 25
end

function P.Knows()
  if IsPlayerSpell and ask(IsPlayerSpell, P.SPELL) then return true end
  return IsSpellKnown and ask(IsSpellKnown, P.SPELL) and true or false
end

--- My enchanting skill, or nil.
function P.Skill()
  if GetProfessions and GetProfessionInfo then
    for _, i in ipairs({ ask(GetProfessions) }) do
      if type(i) == "number" then
        local _, _, rank, _, _, _, line = ask(GetProfessionInfo, i)
        if plain(line) == P.LINE then return plain(rank) end
      end
    end
  end
  return nil                                           -- (GetSkillLineInfo is gone on Forever - the fence, 6 Nov)
end

function P.SpellName()
  local n = C_Spell and C_Spell.GetSpellName and plain(ask(C_Spell.GetSpellName, P.SPELL))
  return type(n) == "string" and n ~= "" and n or "Disenchant"
end

function P.GUID(bag, slot)
  if not (C_Item and C_Item.GetItemGUID and ItemLocation and ItemLocation.CreateFromBagAndSlot) then return nil end
  local loc = ask(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
  if not loc then return nil end
  if C_Item.DoesItemExist and not ask(C_Item.DoesItemExist, loc) then return nil end
  return plain(ask(C_Item.GetItemGUID, loc))
end

local function ilvlOf(link)
  local n = C_Item and C_Item.GetDetailedItemLevelInfo and plain(ask(C_Item.GetDetailedItemLevelInfo, link))
  if type(n) == "number" then return n end
  local _, _, _, lv = ask((C_Item and C_Item.GetItemInfo) or GetItemInfo, link)
  return plain(lv)
end

function P.Enchanted(link)
  local e = type(link) == "string" and link:match("item:%-?%d+:(%-?%d*)")
  return e ~= nil and e ~= "" and e ~= "0"
end

--- The rod the game asked for at this item level, if any (the lowest blocked level at or under it).
function P.BlockedAt(db, ilvl)
  local best, msg
  for lv, m in pairs((db and db.blocked) or {}) do
    if type(ilvl) == "number" and ilvl >= lv and (not best or lv < best) then best, msg = lv, m end
  end
  return msg
end

--- Everything in the bags to disenchant: one entry per item, ready ones first, a mixed name warned once.
function P.Items(db)
  db = db or P.db or {}
  local out, ignored = {}, 0
  if not P.Knows() or not (NS.DE and NS.DE.Kind) then P.ignoredN = 0 return out, 0 end
  local C = C_Container
  local skill = P.Skill()
  for bag = 0, P.BAGS do
    for slot = 1, (plain(ask(C and C.GetContainerNumSlots, bag)) or 0) do
      local kind = NS.DE.Kind(bag, slot)
      if kind then
        local guid = P.GUID(bag, slot)
        local isIgnored = guid ~= nil and db.ignore and db.ignore[guid] ~= nil
        if isIgnored and not db.showIgnored then
          ignored = ignored + 1
        else
          local info = ask(C.GetContainerItemInfo, bag, slot) or {}
          local link = plain(info.hyperlink) or plain(ask(C.GetContainerItemLink, bag, slot))
          local lv = link and ilvlOf(link)
          local need = P.Need(lv)
          out[#out + 1] = {
            bag = bag, slot = slot, guid = guid, link = link, kind = kind, ilvl = lv, need = need,
            id = plain(info.itemID), icon = plain(info.iconFileID), quality = plain(info.quality),
            name = (link and link:match("%[(.-)%]")) or ("item " .. tostring(plain(info.itemID))),
            enchanted = P.Enchanted(link), ignored = isIgnored,
            above = type(skill) == "number" and type(need) == "number" and need > skill or false,
            blocked = P.BlockedAt(db, lv),
          }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    local ra, rb = not (a.above or a.blocked), not (b.above or b.blocked)
    if ra ~= rb then return ra end
    if a.name ~= b.name then return a.name < b.name end
    if a.enchanted ~= b.enchanted then return not a.enchanted end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
  end)
  -- ONE warning per mixed name (an enchanted or soulbound one among plain ones), on the first of them
  local groups = {}
  for _, e in ipairs(out) do
    if not e.ignored then groups[e.name] = groups[e.name] or {} table.insert(groups[e.name], e) end
  end
  for _, g in pairs(groups) do
    local mixed = false
    for i = 2, #g do
      if g[i].enchanted ~= g[1].enchanted or g[i].kind ~= g[1].kind then mixed = true end
    end
    if mixed then g[1].warn = true end
  end
  P.ignoredN = ignored
  return out, ignored
end

--- How many are ready right now (the tools box asks this) - counted on a bag change, never per paint of the box.
function P.Recount()
  local n = 0
  if R:Enabled("processing") and P.Knows() then
    for _, e in ipairs(P.Items(P.db)) do if not (e.above or e.blocked or e.ignored) then n = n + 1 end end
  end
  local was = P.count
  P.count = n
  if (was or 0) > 0 ~= (n > 0) and NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  return n
end
P.count = 0

-- ------------------------------------------------------------------ the page

local function fs(parent, size, color)
  local s = K().fs(parent, "", size or 9, color or "ink")
  s:SetJustifyH("LEFT")
  return s
end

local function textButton(parent, label, w, onclick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 14)
  K().tex(b, "BACKGROUND", "field", 0.9)
  b.edge = K().border(b, "edge", 1)
  b.label = K().fs(b, label, 9, "ink2")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", onclick)
  return b
end

--- Where a skill value sits on the tape (0 = the tape's middle). The tape centres on my skill, as an airliner's
--- speed tape - but never runs below 0 (Arn, 6 Nov, skill 7: half the tape was empty): while the skill is low the
--- box sits low and the whole height shows what is ahead.
function P.TapeCentre()
  local half = (P.TAPE_H / 2 - 4) / P.PX
  return math.max(P.Skill() or 0, half)
end
function P.TapeY(v)
  return (v - P.TapeCentre()) * P.PX
end

local function tapeTex(t, layer)
  local x = t:CreateTexture(nil, layer or "ARTWORK")
  return x
end

--- The tape: my skill boxed in the middle; the barber pole from it upward; a bug per need; a bracket per rod step.
function P.PaintTape(list)
  local t = P.frame and P.frame.tape
  if not t then return end
  local skill = P.Skill() or 0
  local half = P.TAPE_H / 2 - 4
  local function y(v) return math.max(-half, math.min(half, P.TapeY(v))) end
  t.box:SetText(tostring(skill))
  local at = P.TapeY(skill)                                     -- where my skill sits (low on the tape while it is low)
  t.boxFrame:ClearAllPoints()
  t.boxFrame:SetPoint("LEFT", t, "LEFT", 0, at)
  -- the scale: a tick and a number every 25
  local i = 0
  local centre = P.TapeCentre()
  local base = math.floor((centre - half / P.PX) / 25) * 25
  for v = base, centre + half / P.PX, 25 do
    if v >= 0 and math.abs(P.TapeY(v)) <= half - 6 then
      i = i + 1
      local m = t.marks[i] or { tick = tapeTex(t), label = fs(t, 8, "muted") }
      t.marks[i] = m
      m.tick:SetColorTexture(rgb("ink2"))
      m.tick:SetSize(6, 1)
      m.tick:ClearAllPoints() m.tick:SetPoint("RIGHT", t, "RIGHT", -8, P.TapeY(v))
      m.label:SetText(tostring(v))
      m.label:ClearAllPoints() m.label:SetPoint("RIGHT", m.tick, "LEFT", -2, 0)
      m.tick:Show() m.label:Show()
    end
  end
  for j = i + 1, #t.marks do t.marks[j].tick:Hide() t.marks[j].label:Hide() end
  -- the barber pole: red and black, from my skill to the top - what is out of reach
  local segs = math.max(0, math.floor((half - at) / 6))
  for j = 1, segs do
    local s = t.pole.segs[j] or tapeTex(t.pole)
    t.pole.segs[j] = s
    s:SetSize(4, 6)
    s:ClearAllPoints() s:SetPoint("BOTTOMRIGHT", t, "RIGHT", -2, at + (j - 1) * 6)
    if j % 2 == 1 then s:SetColorTexture(P.RED[1], P.RED[2], P.RED[3], 1) else s:SetColorTexture(0, 0, 0, 1) end
    s:Show()
  end
  for j = segs + 1, #t.pole.segs do t.pole.segs[j]:Hide() end
  t.pole.from = skill
  t.pole:Show()
  -- bugs: one per skill an item needs - teal when in reach, purple when above
  t.bugs = {}
  local seen, n = {}, 0
  for _, e in ipairs(list or {}) do
    if type(e.need) == "number" and not seen[e.need] and not e.ignored then
      seen[e.need] = true
      n = n + 1
      local b = t.bugPool[n] or tapeTex(t, "OVERLAY")
      t.bugPool[n] = b
      b:SetSize(8, 3)
      local r, g, bl = rgb(e.need <= skill and "good" or "accent")
      b:SetColorTexture(r, g, bl, 1)
      b:ClearAllPoints() b:SetPoint("LEFT", t, "RIGHT", -1, y(e.need))
      b:Show()
      t.bugs[#t.bugs + 1] = b
    end
  end
  for j = n + 1, #t.bugPool do t.bugPool[j]:Hide() end
  -- brackets: where the game asked for a rod
  t.brackets = {}
  local k = 0
  for lv in pairs((P.db and P.db.blocked) or {}) do
    k = k + 1
    local br = t.bracketPool[k] or { h = tapeTex(t, "OVERLAY"), v = tapeTex(t, "OVERLAY") }
    t.bracketPool[k] = br
    local r, g, bl = rgb("gold")
    br.h:SetColorTexture(r, g, bl, 1) br.v:SetColorTexture(r, g, bl, 1)
    br.h:SetSize(8, 2) br.v:SetSize(2, 10)
    local yy = y(P.Need(lv) or 0)
    br.h:ClearAllPoints() br.h:SetPoint("RIGHT", t, "RIGHT", -2, yy)
    br.v:ClearAllPoints() br.v:SetPoint("BOTTOMLEFT", br.h, "BOTTOMLEFT", 0, 0)
    br.h:Show() br.v:Show()
    t.brackets[#t.brackets + 1] = br
  end
  for j = k + 1, #t.bracketPool do t.bracketPool[j].h:Hide() t.bracketPool[j].v:Hide() end
end

--- Aim one row's secure button at its item - out of combat only.
local function arm(r, e)
  local a = r.act
  local name = P.SpellName()
  local free = e and e.kind == "free" and not e.above
  local bound = e and e.kind == "bound" and not e.above
  a:SetAttribute("target-bag", e and e.bag or nil)
  a:SetAttribute("target-slot", e and e.slot or nil)
  a:SetAttribute("type1", free and "spell" or nil)
  a:SetAttribute("spell1", free and name or nil)
  -- shift-click disenchants anything in reach; a plain click only what is not soulbound (Arn, 6 Nov)
  a:SetAttribute("shift-type1", (free or bound) and "spell" or nil)
  a:SetAttribute("shift-spell1", (free or bound) and name or nil)
  a.entry = e
end

function P.Say(text)
  P.said = text
  if P.frame then P.frame.say:SetText(text or "") end
end

function P.Paint()
  local f = P.frame
  if not (f and f:IsShown()) then return end
  if fighting() then P.dirty = true return end
  P.dirty = nil
  local list, ignored = P.Items(P.db)
  P.list = list
  local ready, above, blocked = 0, 0, 0
  for _, e in ipairs(list) do
    if e.above then above = above + 1 elseif e.blocked then blocked = blocked + 1 elseif not e.ignored then ready = ready + 1 end
  end
  P.offset = math.max(0, math.min(P.offset or 0, math.max(0, #list - P.ROWS)))
  for i, r in ipairs(f.rows) do
    local e = list[(P.offset or 0) + i]
    r.entry = e
    arm(r, e)
    if e then
      r.icon:SetTexture(e.icon or 134400)
      r.name:SetText(e.name)
      -- the name in its quality's colour, faded when it cannot be clicked now; soulbound is the tag's and the edge's
      local qc = P.QUALITY[e.quality or 0]
      local dim = (e.ignored or e.above or e.blocked) and 0.5 or 1
      if qc then r.name:SetTextColor(qc[1], qc[2], qc[3], dim) else r.name:SetTextColor(rgb("ink")) end
      local a = r.act
      local red = e.kind == "bound"
      for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        if red then a.edge[side]:SetColorTexture(P.RED[1], P.RED[2], P.RED[3], 1) end
      end
      if not red then a.edge:set("accent", 1) end
      a.edgeColor = red and "red" or "accent"
      local tags = {}
      if e.ignored then tags[#tags + 1] = "IGNORED" end
      if e.enchanted then tags[#tags + 1] = "ENCHANTED" end
      if e.kind == "bound" then tags[#tags + 1] = "SOULBOUND - SHIFT" end
      if e.warn then tags[#tags + 1] = "SAME NAME - CHECK" end
      if e.above then tags[#tags + 1] = "SKILL " .. tostring(e.need) end
      if e.blocked then tags[#tags + 1] = tostring((e.blocked:match("[Rr]equires (.+)") or e.blocked)):upper() end
      r.tag:SetText(table.concat(tags, "  "))
      if e.kind == "bound" and not (e.warn or e.blocked) then
        r.tag:SetTextColor(P.RED[1], P.RED[2], P.RED[3], 1)
      else
        r.tag:SetTextColor(rgb((e.warn or e.blocked) and "gold" or (e.above and "accent" or "muted")))
      end
      r.act.icon:SetDesaturated(e.above or e.ignored or false)
      r:Show()
    else
      r:Hide()
    end
  end
  f.summary:SetText(("%d READY  -  %d ABOVE SKILL%s"):format(ready, above, blocked > 0 and ("  -  " .. blocked .. " NEED A ROD") or ""))
  f.ignored:SetText(ignored > 0 and (ignored .. " IGNORED (SHOW)") or (P.db and P.db.showIgnored and "HIDE IGNORED" or ""))
  -- short enough to sit beside the title: "0.19.1  9e52109+ 1106-1841" (the branch is in the full stamp)
  local sha = NS.BUILD and NS.BUILD:match("@(%S+)")
  local when = NS.BUILD and NS.BUILD:match("(%S+)$")
  f.build:SetText(sha and (tostring(NS.VERSION) .. "  " .. sha .. " " .. (when or "")) or tostring(NS.VERSION))
  P.PaintTape(list)
  P.RefreshTip()
end

--- The mouse on a row while the list moved under it (Arn, 6 Nov: "it moves the next item one spot but it still has
--- old tooltip"): its tooltip again, for what the row holds now - or none, when the row is empty.
function P.RefreshTip()
  local f = P.frame
  local owner = f and GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner()
  if not owner then return end
  for _, r in ipairs(f.rows) do
    if owner == r or owner == r.act then
      if r.entry and r:IsShown() then r:GetScript("OnEnter")(r) else GameTooltip:Hide() end
      return
    end
  end
end

function P.Build()
  if P.frame then return P.frame end
  local k = K()
  local f = CreateFrame("Frame", "BiSToolsProcessing", UIParent)
  f:SetSize(P.W, P.H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetScale(P.SCALE)                                           -- Arn: "lets make 20% bigger its so small cant read"
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsProcessing") end   -- Escape closes it (out of combat:
                                                                -- a fight puts it away first)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  k.tex(f, "BACKGROUND", "frame", 0.97)
  k.border(f, "edge", 1)
  f.title = fs(f, 10, "accent")
  f.title:SetPoint("TOPLEFT", 8, -7)
  f.title:SetText("BiS> PROCESSING   ENCHANTING")
  f.close = textButton(f, "x", 16, function() P.Toggle(false) end)
  -- the fingerprint: the version, and on a deployed test build its stamp - faint, beside the x
  f.build = fs(f, 7, "dim")
  f.build:SetJustifyH("RIGHT")
  f.build:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.build:SetAlpha(0.6)
  f.close:SetPoint("TOPRIGHT", -4, -4)
  -- the tape
  local t = CreateFrame("Frame", nil, f)
  t:SetSize(P.TAPE_W, P.TAPE_H)
  t:SetPoint("TOPLEFT", 8, -26)
  k.tex(t, "BACKGROUND", "sunken", 1)
  t.marks, t.bugPool, t.bracketPool = {}, {}, {}
  t.pole = CreateFrame("Frame", nil, t)
  t.pole:SetAllPoints()
  t.pole.segs = {}
  t.boxFrame = CreateFrame("Frame", nil, t)
  t.boxFrame:SetSize(P.TAPE_W - 4, 16)
  t.boxFrame:SetPoint("LEFT", t, "LEFT", 0, 0)
  k.tex(t.boxFrame, "BACKGROUND", "bg", 1)
  k.border(t.boxFrame, "ink", 1)
  t.box = k.fs(t.boxFrame, "", 11, "ink")
  t.box:SetPoint("CENTER")
  f.tape = t
  -- the rows
  f.rows = {}
  local x = 8 + P.TAPE_W + 8
  local w = P.W - x - 8
  for i = 1, P.ROWS do
    local r = CreateFrame("Button", nil, f)
    r:SetSize(w, P.ROW)
    r:SetPoint("TOPLEFT", x, -26 - (i - 1) * P.ROW)
    -- THE ROW POPS UNDER THE MOUSE (Arn, 6 Nov, the third time asked): a clear wash and a bar on the left
    r.lit = k.tex(r, "BACKGROUND", "accent", 0)
    r.bar = r:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(3)
    do local rr, g, b = K().color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
    r.bar:SetAlpha(0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(P.ROW - 4, P.ROW - 4)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = fs(r, 9, "ink")
    r.name:SetPoint("LEFT", P.ROW + 2, 3)
    r.name:SetWidth(w - P.ROW - 28)
    r.tag = fs(r, 7, "muted")
    r.tag:SetPoint("LEFT", P.ROW + 2, -6)
    r.tag:SetWidth(w - P.ROW - 28)
    r:RegisterForClicks("RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if button ~= "RightButton" or not self.entry or fighting() then return end
      P.Ignore(self.entry)
    end)
    r:SetScript("OnEnter", function(self)
      self.lit:SetAlpha(P.GLOW) self.bar:SetAlpha(1)
      local e = self.entry
      if e and GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetBagItem then GameTooltip:SetBagItem(e.bag, e.slot) end
        GameTooltip:AddLine("right-click: " .. (e.ignored and "stop ignoring" or "ignore this one item"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function(self) self.lit:SetAlpha(0) self.bar:SetAlpha(0) if GameTooltip then GameTooltip:Hide() end end)
    -- the button that disenchants: secure, aimed at one bag slot
    local a = CreateFrame("Button", "BiSToolsProcessingAct" .. i, r, "SecureActionButtonTemplate")
    a:SetSize(P.ROW - 2, P.ROW - 2)
    a:SetPoint("RIGHT", -2, 0)
    a:RegisterForClicks("AnyUp", "AnyDown")              -- the client's template picks up or down by its own setting
    a.icon = a:CreateTexture(nil, "ARTWORK")
    a.icon:SetAllPoints()
    a.icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and plain(ask(C_Spell.GetSpellTexture, P.SPELL))) or P.ICON)
    a.edge = k.border(a, "accent", 1)
    a:SetScript("PreClick", function(self, button, down) P.PreClick(self, button, down) end)
    a:SetScript("OnEnter", function(self) if r:GetScript("OnEnter") then r:GetScript("OnEnter")(r) end end)
    a:SetScript("OnLeave", function() if r:GetScript("OnLeave") then r:GetScript("OnLeave")(r) end end)
    r.act = a
    f.rows[i] = r
  end
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    if fighting() then return end
    P.offset = (P.offset or 0) - delta * 3
    P.Paint()
  end)
  -- the computed line, the ignored count, the scratchpad
  f.summary = fs(f, 9, "accent")
  f.summary:SetPoint("TOPLEFT", x, -26 - P.ROWS * P.ROW - 6)
  f.ignoredBtn = CreateFrame("Button", nil, f)
  f.ignoredBtn:SetSize(110, 14)
  f.ignoredBtn:SetPoint("TOPRIGHT", -8, -26 - P.ROWS * P.ROW - 4)
  f.ignored = fs(f.ignoredBtn, 8, "muted")
  f.ignored:SetPoint("RIGHT")
  f.ignoredBtn:SetScript("OnClick", function()
    if fighting() or not P.db then return end
    P.db.showIgnored = not P.db.showIgnored or nil
    P.Paint()
  end)
  -- the haul: what disenchanting gave this session, icons with counts (hover: all time)
  local haul = CreateFrame("Frame", nil, f)
  haul:SetPoint("BOTTOMLEFT", 8, 30)
  haul:SetPoint("BOTTOMRIGHT", -8, 30)
  haul:SetHeight(18)
  haul.label = fs(haul, 8, "muted")
  haul.label:SetPoint("LEFT", 2, 0)
  haul.label:SetText("THIS SESSION")
  haul.slots = {}
  for i = 1, P.HAUL_MAX do
    local s = CreateFrame("Button", nil, haul)
    s:SetSize(16, 16)
    s:SetPoint("LEFT", 74 + (i - 1) * 38, 0)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints()
    s.count = fs(s, 9, "ink")
    s.count:SetPoint("LEFT", s, "RIGHT", 2, 0)
    s:SetScript("OnEnter", function(self)
      if not (GameTooltip and self.id) then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(P.haulName[self.id] or ("item " .. self.id))
      GameTooltip:AddLine(("this session %d   all time %d"):format(P.haul[self.id] or 0,
        (P.db and P.db.totals and P.db.totals[self.id]) or 0), 1, 1, 1)
      GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    s:Hide()
    haul.slots[i] = s
  end
  f.haul = haul
  local pad = CreateFrame("Frame", nil, f)
  pad:SetPoint("BOTTOMLEFT", 8, 8)
  pad:SetPoint("BOTTOMRIGHT", -8, 8)
  pad:SetHeight(18)
  k.tex(pad, "BACKGROUND", "sunken", 1)
  f.say = fs(pad, 9, "gold")
  f.say:SetPoint("LEFT", 6, 0)
  f.say:SetText(P.said or "")
  f:Hide()
  P.frame = f
  return f
end

--- The last word before the cast: is the item we aimed at still in that slot?
function P.PreClick(a, button)
  local e = a.entry
  if not e or fighting() then return end
  local guid = P.GUID(e.bag, e.slot)
  if guid ~= e.guid then
    a:SetAttribute("type1", nil)                      -- cancelled; NOT re-aimed in this click
    a:SetAttribute("shift-type1", nil)
    a.entry = nil
    P.dirty = true
    P.Say("ITEM MOVED - LIST REFRESHED, CLICK AGAIN")
    if C_Timer and C_Timer.After then C_Timer.After(0.2, function() P.Paint() end) end
    return
  end
  if e.above then return P.Say(("NEEDS ENCHANTING %d"):format(e.need or 0)) end
  if e.kind == "bound" and not (IsShiftKeyDown and IsShiftKeyDown()) then
    return P.Say("SOULBOUND - SHIFT-CLICK TO DISENCHANT")
  end
  P.clicked = { e = e, at = now() }
  P.Say("")
end

function P.Ignore(e)
  local db = P.db
  if not (db and e and e.guid) then return end
  db.ignore = db.ignore or {}
  if db.ignore[e.guid] then db.ignore[e.guid] = nil else db.ignore[e.guid] = e.name end
  P.Recount()
  P.Paint()
end

function P.IsOpen() return P.frame ~= nil and P.frame:IsShown() end

function P.Toggle(want)
  if fighting() then NS.Print("processing: after the fight") return false end
  local f = P.Build()
  if want == nil then want = not f:IsShown() end
  if want then
    if not f:IsShown() then P.haul, P.deAt = {}, nil end   -- a fresh open: a fresh session, no earlier disenchant
    f:Show() P.Paint() P.PaintHaul()
  else
    f:Hide()
  end
  return f:IsShown()
end

-- ------------------------------------------------------------------ the haul
-- Arn, 6 Nov: "a pop up or a ticker of all the stuff we got in this session of disenchanting resets when we open
-- window again maybe we keep track". This session = since the window opened (P.haul); all time = db.totals. Only
-- loot within P.LOOT_WINDOW seconds of OUR disenchant counts - a mob's drop or the mail never does.
P.HAUL_MAX, P.LOOT_WINDOW = 7, 6
P.haul, P.haulName = {}, {}

function P.Loot(msg)
  if type(msg) ~= "string" or not P.deAt or now() - P.deAt > P.LOOT_WINDOW then return false end
  if not msg:find("^You ") then return false end           -- mine, not a groupmate's ("You receive loot: ...")
  local id = tonumber(msg:match("|Hitem:(%d+)"))
  if not id then return false end
  local n = tonumber(msg:match("|r%s*x(%d+)")) or 1
  P.haul[id] = (P.haul[id] or 0) + n
  P.haulName[id] = msg:match("|h%[(.-)%]|h") or P.haulName[id]
  if P.db then
    P.db.totals = P.db.totals or {}
    P.db.totals[id] = (P.db.totals[id] or 0) + n
  end
  P.PaintHaul()
  return true
end

function P.PaintHaul()
  local f = P.frame
  if not (f and f.haul) then return end
  local ids = {}
  for id in pairs(P.haul) do ids[#ids + 1] = id end
  table.sort(ids, function(a, b) return (P.haul[a] or 0) > (P.haul[b] or 0) end)
  for i, s in ipairs(f.haul.slots) do
    local id = ids[i]
    s.id = id
    if id then
      s.icon:SetTexture((C_Item and C_Item.GetItemIconByID and plain(ask(C_Item.GetItemIconByID, id))) or 134400)
      s.count:SetText("x" .. P.haul[id])
      s:Show()
    else
      s:Hide()
    end
  end
  f.haul.label:SetText(#ids > 0 and "THIS SESSION" or "THIS SESSION: NOTHING YET")
end

-- ------------------------------------------------------------------ the doors

--- In the BiS> tools box, while something is ready.
function P.BoxButton()
  if P.box then return P.box end
  local k = K()
  local b = CreateFrame("Button", "BiSToolsProcessingBox", UIParent)
  b:SetSize(26, 26)
  k.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = k.border(b, "accent", 1)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2)
  b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture((C_Spell and C_Spell.GetSpellTexture and plain(ask(C_Spell.GetSpellTexture, P.SPELL))) or P.ICON)
  b:SetScript("OnClick", function() P.Toggle() end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("BiS> processing")
    GameTooltip:AddLine(("%d ready to disenchant"):format(P.count or 0), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  P.box = b
  return b
end

function P.ShowBox()
  -- in town only (Arn, 6 Nov: "so people arent questing with the button nagging them"): an inn or a city
  local town = IsResting and IsResting() and true or false
  return R:Enabled("processing") and town and not fighting() and (P.count or 0) > 0 and P.Knows() or false
end

--- On the profession window, beside its title.
function P.TradeSkillButton()
  local host = _G.ProfessionsFrame or _G.TradeSkillFrame
  if not host or P.tsButton then return P.tsButton end
  local b = textButton(host, "BiS> processing", 96, function() P.Toggle(true) end)
  b:SetPoint("TOPRIGHT", host, "TOPRIGHT", -60, -14)
  P.tsButton = b
  return b
end

-- ------------------------------------------------------------------ events

local ev = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "UNIT_SPELLCAST_SUCCEEDED", "UI_ERROR_MESSAGE", "PLAYER_REGEN_DISABLED",
                     "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "CHAT_MSG_LOOT", "PLAYER_UPDATE_RESTING" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if not R:Enabled("processing") then return end
  if event == "PLAYER_REGEN_DISABLED" then
    -- the last moment the client allows it: the page holds secure buttons
    if P.frame and P.frame:IsShown() then P.frame:Hide() P.reopen = true end
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    if P.reopen then P.reopen = nil P.frame:Show() P.dirty = true end
    if P.dirty then P.Recount() P.Paint() end
    return
  elseif event == "PLAYER_UPDATE_RESTING" then                -- into town or out of it: the box button follows
    if not fighting() and NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
    return
  elseif event == "TRADE_SKILL_SHOW" then
    P.TradeSkillButton()
    return
  elseif event == "UI_ERROR_MESSAGE" then
    -- a refusal just after one of our clicks: the game's words on the scratchpad; a rod, remembered
    local msg = type(a2) == "string" and a2 or (type(a1) == "string" and a1) or nil
    local c = P.clicked
    if not (msg and c and now() - c.at < 3) then return end
    P.Say(msg:upper())
    if msg:lower():find("rod", 1, true) and type(c.e.ilvl) == "number" and P.db then
      P.db.blocked = P.db.blocked or {}
      P.db.blocked[c.e.ilvl] = msg
    end
    P.clicked = nil
    P.Recount()
    P.Paint()
    return
  elseif event == "CHAT_MSG_LOOT" then
    P.Loot(plain(a1))
    return
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if a1 ~= "player" then return end
    if plain(a3) == P.SPELL then
      P.deAt = now()                                         -- its loot, arriving next, is the haul's
      -- it went through: any rod block at or under this item's level is answered
      local c = P.clicked
      if c and type(c.e.ilvl) == "number" and P.db and P.db.blocked then
        for lv in pairs(P.db.blocked) do if lv <= c.e.ilvl then P.db.blocked[lv] = nil end end
      end
      P.clicked = nil
    end
  end
  -- BAG_UPDATE_DELAYED, or a cast finished
  if fighting() then P.dirty = true return end
  P.Recount()
  P.Paint()
end)
P.events = ev

R:Register({
  name = "processing",
  desc = "your professions' work in one cockpit page: disenchant (enchanting first)",
  usage = "/bist processing [ignored clear | rods clear]",
  defaults = { ignore = {}, blocked = {}, totals = {} },
  OnInit = function(_, db) P.db = db end,
  OnLogin = function(_, db) P.db = db P.Recount() end,
  OnOpen = function(_, db, recenter)
    P.db = db
    if recenter then
      if P.frame and not fighting() then P.frame:ClearAllPoints() P.frame:SetPoint("CENTER") end
      return
    end
    P.Toggle(true)
  end,
  IsOpen = function() return P.IsOpen() end,
  OnClose = function() P.Toggle(false) end,
  OnDisable = function() if P.frame and not fighting() then P.frame:Hide() end P.count = 0 end,
  OnSlash = function(_, db, args)
    P.db = db
    args = tostring(args or "")
    if args == "ignored clear" then db.ignore = {} P.Recount() P.Paint() return NS.Print("processing: nothing ignored now") end
    if args == "rods clear" then db.blocked = {} P.Recount() P.Paint() return NS.Print("processing: the rod notes are forgotten") end
    P.Toggle()
  end,
})
