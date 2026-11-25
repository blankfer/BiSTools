-- BiSTools / Tools / TotemCard.lua - the totem card: BiS>totems' top two rows, small, on your screen (23 Nov 2026).
--
-- Arn, 23 Nov: "make that one pop out like a card, click drops, shift hover pop out" - "on top of my bars thats how small the card
-- should be two rows and draggable" - "a very small line when solo, of the dps of the current set up updating after each fight with
-- all the smarts of the big tool, but light weight" - "it can just get the info from the phone".
--
-- NOTHING OF ITS OWN: the rows are the phone's (C.Phone.icons, Tools/Apps/Combo.lua) - the imbue and four totems on top, the Calls +
-- Bring + Recall under them - and the line is the phone's number (C.Phone.number). A click CASTS: the imbue or the totem on the row
-- (its `cast`), a Call (saving the row into it first, the phone's own `ok`), Bring, Recall. Shift over an icon of the top row = the
-- others of its kind pop out over it (the phone's `fly`); a click there drops that one and puts it on the row. (Letting go of Shift
-- cannot cast: the game casts only on a click or a key.)
--
-- THE TAB (Arn, same day, picking C: "just add a small dps number make it like a little tab and that where they can drag the bar put
-- it on the left side"): the row's dps from the phone's number, small, on a tab at the card's left - and the tab is what drags it.
-- Its tooltip: what the row is, the last fight against it and the place, the phone's own words.
-- THE DECK TAB (Arn: "where should we add send to bis healing deck ... a shift click somewhere or on the right side" - Shift is the
-- pop-out, so the right side): the same tab on the right, the phone's "Update healing deck" - a click sends the row's four totems
-- and its Call to BiS Healing's deck; ON when the deck has them. Only with BiS Healing there (C.DeckCan).
--
-- SECURE BUTTONS: everything is aimed, shown and moved OUT OF A FIGHT only; in one the card stays as it was and its buttons
-- still cast what they hold.
-- IN A FIGHT TOO (Arn: "how is blizz able to pop them out during a fight" - "yes build it"): the game's own totem bar way. Every
-- pop-out is BUILT AND AIMED before the pull - one column per icon of the top row, hidden - and small SECURE SNIPPETS (run by the
-- game itself, legal in a fight) show one: Shift over an icon (its OnEnter, wrapped), or Shift pressed with the mouse already on it
-- (a state driver on [mod:shift]). The mouse off both = closed (OnLeave, wrapped). A pick casts, and the snippet re-aims the row's
-- icon at it, so the next click drops the new one; the picture follows, and the phone hears of it after the fight. Out of a fight
-- the snippets stand aside (they ask [combat]) and the plain code below does it, as before. The pop-out closes at PLAYER_REGEN_DISABLED (the lockdown has not started yet), a drag ends
-- there too. Painted on events only - a fight saved, a row changed, the bars, the weapon, the group - never on a timer; the pop-out
-- watches the mouse with an OnUpdate only while it is open. Off until switched on (`/bist combo bar`, or the phone's SETTINGS).
local _, NS = ...
local T, R = NS.T, NS.Registry
local C = NS.Combo
if not C then return end

local TC = { SIZE = 28, GAP = 2, TAB = 30, WAIT = 0.3, GRACE = 0.25, OFF = 0.3, MARGIN = 6 }
NS.TotemCard = TC

local function db() return C.db or R:DBFor(R:Get("combo")) end
--- Is the mouse over this frame? Its own IsMouseOver (every frame has it), the old global only as a fallback - (Arn, 23 Nov: "holding
--- shift does not pop out": with the global missing the pop-out shut itself the frame it opened).
function TC.Over(fr)
  if not fr then return false end
  local m = TC.MARGIN                                       -- (a little round it: the gaps between icons count as on it)
  if fr.IsMouseOver then local fine, yes = pcall(fr.IsMouseOver, fr, m, -m, -m, m) if fine then return yes and true or false end end
  if MouseIsOver then local fine, yes = pcall(MouseIsOver, fr, m, -m, -m, m) if fine then return yes and true or false end end
  return true                                               -- (cannot tell: left open; the next leave or a pull closes it)
end
local function note(why) TC.why = why end
local function fighting() return InCombatLockdown and InCombatLockdown() and true or false end

--- Shown? Switched on, the combo tool on, a shaman, and the phone has its row.
function TC.Wanted()
  local d = db()
  return d and d.bar == true and R:Enabled("combo") and NS.Totems and NS.Totems.Shaman() and C.Phone ~= nil or false
end

--- What a button casts: { type, spell } from an icon of the phone, or nil.
function TC.Cast(b)
  if type(b) ~= "table" then return nil end
  if b.cast then return b.cast end
  local a = b.act
  if type(a) == "table" and type(a.spell) == "string" then return a.spell end
  return nil
end

-- ------------------------------------------------------------------ ranks
--[[ THE WHEEL PICKS A RANK (Arn, 23 Nov: "maybe when we are selecting a totem we can scroll wheel up to select a rank?" - "yes build
  the wheel ranks on the card"). The game's totem bar offers only the newest rank of each totem (the probe, 23 Nov: Searing Rank 4,
  Healing Stream Rank 4...), so the Calls stay newest. But a card button can cast ANY rank you know, by its spell id. Your ranks are
  read from your own spellbook (C_SpellBook, cached till SPELLS_CHANGED); the wheel over an icon steps its rank (out of a fight),
  db.barRank[name] = the rank number (nil = the newest), an "R2" on the icon says it is not the newest. ]]
local function plainV(v) if v ~= nil and issecretvalue and issecretvalue(v) then return nil end return v end
local function askV(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  return ok and plainV(a) or nil
end
--- Every rank of a spell you know, by its plain name: { { id, rank }, ... }, lowest rank first. The spellbook is read ONCE for
--- every name (then cached till your spells change) - a read per name was a spellbook a totem.
function TC.Ranks(name)
  if type(name) ~= "string" then return {} end
  if not TC.rankCache then
    local all, B = {}, C_SpellBook
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if B and B.GetNumSpellBookSkillLines and B.GetSpellBookSkillLineInfo and B.GetSpellBookItemInfo then
      for line = 1, askV(B.GetNumSpellBookSkillLines) or 0 do
        local li = askV(B.GetSpellBookSkillLineInfo, line)
        local from, n = type(li) == "table" and plainV(li.itemIndexOffset) or 0, type(li) == "table" and plainV(li.numSpellBookItems) or 0
        for i = from + 1, from + (n or 0) do
          local it = askV(B.GetSpellBookItemInfo, i, bank)
          local id = type(it) == "table" and plainV(it.spellID) or nil
          local nm = id and askV(C_Spell and C_Spell.GetSpellName, id)
          if type(nm) == "string" then
            local sub = askV(C_Spell and C_Spell.GetSpellSubtext, id)
            all[nm] = all[nm] or {}
            table.insert(all[nm], { id = id, rank = type(sub) == "string" and tonumber(sub:match("(%d+)")) or nil })
          end
        end
      end
    end
    for _, list in pairs(all) do
      table.sort(list, function(a, b) if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) < (b.rank or 0) end return a.id < b.id end)
    end
    TC.rankCache = all
  end
  return TC.rankCache[name] or {}
end
--- The rank the card casts for that name: its spell id, its place in your ranks, how many you have (nil = cast by name).
function TC.RankOf(name)
  local list = TC.Ranks(name)
  if #list == 0 then return nil end
  local want = (db().barRank or {})[name]
  for i, r in ipairs(list) do if want and r.rank == want then return r.id, i, #list end end
  return list[#list].id, #list, #list
end
--- The wheel over an icon: a rank up (delta > 0) or down. Out of a fight only.
function TC.Wheel(b, delta)
  local it = b and b.item
  local name = it and TC.Cast(it)
  if not name then return end
  if fighting() then return note("ranks: not in a fight") end
  local list = TC.Ranks(name)
  if #list < 2 then return note("one rank of " .. name .. " in your spellbook") end
  local _, at = TC.RankOf(name)
  at = math.max(1, math.min(#list, (at or #list) + (delta > 0 and 1 or -1)))
  local d = db()
  d.barRank = d.barRank or {}
  d.barRank[name] = at < #list and list[at].rank or nil
  note(("%s: rank %s of %d"):format(name, tostring(list[at].rank or at), #list))
  TC.dress(b, it, b:GetWidth())
  TC.Soon()                                         -- (every button of that totem takes the rank, not only this one)
  if b:GetScript("OnEnter") and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end
end

-- ------------------------------------------------------------------ the frame
local function tex(parent, layer, name)
  local t = parent:CreateTexture(nil, layer)
  if name then t:SetColorTexture(T.rgb(name)) end
  return t
end

local function button(parent, name)
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.edge = tex(b, "BACKGROUND", "line")
  b.edge:SetAllPoints(b)
  b.pic = tex(b, "ARTWORK")
  b.pic:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.pic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.word = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.word:SetPoint("CENTER")
  b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.rank:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  if b.EnableMouseWheel then b:EnableMouseWheel(true) end                -- (made out of a fight: the wheel picks a rank)
  b:SetScript("OnMouseWheel", function(self, delta) TC.Wheel(self, delta) end)
  b:SetScript("PreClick", function(self)
    local it = self.item
    if fighting() or not it then return end
    local a = it.act
    if type(a) == "table" and type(a.ok) == "function" and not it.cast then
      local fine, yes = pcall(a.ok)
      if not (fine and yes) then self:SetAttribute("*type1", nil) end     -- (refused: nothing is cast this click)
    end
  end)
  b:SetScript("PostClick", function(self, _, down)
    local it = self.item
    if down or not it then return end
    if fighting() then                                      -- (a pick in a fight: its picture on the row now, the phone later)
      if self.inFly and self.src then
        pcall(self.src.pic.SetTexture, self.src.pic, it.pic)
        TC.queue = TC.queue or {}
        TC.queue[#TC.queue + 1] = it
        note("picked in a fight: " .. tostring(it.word))
      end
      return
    end
    local a = it.act
    if self.inFly and type(a) == "table" and type(a.fn) == "function" then pcall(a.fn) end   -- (a pick: onto the row)
    if type(a) == "table" and type(a.after) == "function" then pcall(a.after) end
    if self.inFly then TC.CloseFly() end
    TC.Soon()
  end)
  b:SetScript("OnEnter", function(self)
    if self.item and self.item.tip and GameTooltip then
      -- to the SIDE (Arn, 23 Nov: "put the tooltip to the side i cant see what im clicking" - on top it covered the pop-out)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(TC.Tip(self))
      if self.top and self.item.fly then GameTooltip:AddLine(T.text("dim", "Shift: the others of its kind")) end
      local name = TC.Cast(self.item)
      local _, at, of = TC.RankOf(name)
      if of and of > 1 then
        local r = TC.Ranks(name)[at]
        GameTooltip:AddLine(T.text(at < of and "gold" or "dim", ("Rank %s of %d - the wheel: another rank"):format(tostring(r.rank or at), of)))
      end
      GameTooltip:Show()
    end
    if self.top then TC.hover = self if IsShiftKeyDown and IsShiftKeyDown() then TC.OpenFly(self) end end
  end)
  b:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    if TC.hover == self then TC.hover = nil end
  end)
  return b
end

--- What a button says on the card: the phone's words, with what a click does HERE (the phone's "choose another" / "onto the row"
--- are the phone's clicks; on the card a click drops it).
function TC.Tip(b)
  local it = b.item or {}
  local t = tostring(it.tip or it.word or "")
  t = t:gsub("%. Click: choose another$", ""):gsub("%. Click: choose one$", ""):gsub("%. Click: onto the row$", "")
  if b.inFly then return t .. (TC.Cast(it) and ". Click: drops it, onto the row" or "") end
  if b.top then return t .. (TC.Cast(it) and ". Click: drops it" or "") end
  return t
end

--- One icon of the phone onto a button: its picture, its glow, what it casts. Out of a fight only.
local function dress(b, it, size)
  b.item = it
  b:SetSize(size, size)
  if it.pic then b.pic:SetTexture(it.pic) b.pic:Show() b.word:SetText("") else b.pic:Hide() b.word:SetText(tostring(it.word or "-"):sub(1, 4)) end
  b.pic:SetAlpha(it.done and 0.45 or 1)
  b.edge:SetColorTexture(T.rgb(it.lit and "gold" or (not it.soft and it.glow) or "line"))
  local spell = TC.Cast(it)
  local id, at, of = TC.RankOf(spell)                         -- (the rank the wheel picked; none read = by its name)
  local r = id and TC.Ranks(spell)[at]
  b.rank:SetText(id and at < of and T.text("gold", "R" .. tostring(r and r.rank or at)) or "")
  -- ("*type1": any modifier too - Shift is held over the pop-out, and a Shift-click on a plain "type1" casts nothing)
  b:SetAttribute("*type1", spell and "spell" or nil)
  b:SetAttribute("*spell1", spell and (id or spell) or nil)
  b:Show()
end
TC.dress = dress

function TC.Build()
  if TC.frame then return TC.frame end
  local f = CreateFrame("Frame", "BiSToolsTotemCard", UIParent)
  f:SetSize(100, 60)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f.bg = tex(f, "BACKGROUND", "bg")
  f.bg:SetAllPoints(f)
  f.bg:SetAlpha(0.75)
  -- the tab: the dps number at the left, and the handle (a click on an icon casts)
  local g = CreateFrame("Frame", nil, f)
  g:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  g:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  g:SetWidth(TC.TAB)
  g.bg = tex(g, "BACKGROUND", "line")
  g.bg:SetAllPoints(g)
  g.num = g:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  g.num:SetPoint("CENTER", g, "CENTER", 0, 4)
  g.dps = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  g.dps:SetPoint("TOP", g.num, "BOTTOM", 0, -1)
  g.dps:SetText(T.text("dim", "dps"))
  g:EnableMouse(true)
  g:RegisterForDrag("LeftButton")
  g:SetScript("OnDragStart", function() if not fighting() then f:StartMoving() f.moving = true end end)
  g:SetScript("OnDragStop", function() TC.EndDrag() end)
  g:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("BiS>totems")
    for _, l in ipairs(TC.TabLines(TC.num)) do GameTooltip:AddLine(l) end
    GameTooltip:AddLine(T.text("dim", "Drag here to move it. Shift over a totem: the others pop out."))
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.tab = g
  local k = CreateFrame("Button", nil, f)
  k:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  k:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  k:SetWidth(TC.TAB)
  k.bg = tex(k, "BACKGROUND", "line")
  k.bg:SetAllPoints(k)
  k.word = k:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  k.word:SetPoint("CENTER", k, "CENTER", 0, 5)
  k.state = k:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  k.state:SetPoint("TOP", k.word, "BOTTOM", 0, -2)
  k.word:SetText(T.text("dim", "deck"))
  k:RegisterForClicks("LeftButtonUp")
  k:SetScript("OnClick", function()
    local it = TC.deck
    if it and it.act and type(it.act.fn) == "function" then pcall(it.act.fn) end
    TC.Soon()
  end)
  k:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Healing deck")
    GameTooltip:AddLine(T.text("ink2", TC.deck and TC.deck.tip or ""))
    GameTooltip:AddLine(T.text("dim", TC.deck and TC.deck.verb == "IS ON IT" and "It has them." or "Click: send them."))
    GameTooltip:Show()
  end)
  k:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.deck = k
  f.top, f.low, f.cols = {}, {}, {}
  -- the watcher: out of a fight, the open column's mouse check (shown only while one is open; a fight's is the snippets')
  TC.watch = TC.watch or CreateFrame("Frame")
  TC.watch:Hide()
  TC.watch:SetScript("OnUpdate", function()
    if fighting() then return end
    local from = TC.flyFrom
    local col = from and f.cols[from.slot]
    local now = GetTime and GetTime() or 0
    if TC.flyAt and now - TC.flyAt < TC.GRACE then return end
    -- (Arn, 23 Nov: "as soon as i move off the first totem the pop out totems go away": one frame in the gap between the icon and
    -- the column closed it. Now a margin round both, and the mouse must stay off a moment.)
    if TC.Over(col) or TC.Over(from) then TC.offAt = nil return end
    TC.offAt = TC.offAt or now
    if now - TC.offAt >= TC.OFF then TC.CloseFly("the mouse left it") end
  end)
  TC.Secure(f)
  f:SetScript("OnHide", function() TC.EndDrag() end)
  TC.frame = f
  TC.Place()
  return f
end

function TC.Place()
  local f, p = TC.frame, db() and db().barPos
  if not f or fighting() then return end
  f:ClearAllPoints()
  if type(p) == "table" and p[1] then f:SetPoint(p[1], UIParent, p[3] or p[1], p[4] or 0, p[5] or 0)
  else f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150) end      -- (over the bars, till you drag it)
end

--- A drag ends: saved where it is. Also at a pull and when the card hides (a frame hidden mid-drag stays glued to the mouse).
function TC.EndDrag()
  local f = TC.frame
  if not (f and f.moving) then return end
  f.moving = nil
  NS.LetGo(f)
  local a, _, b, x, y = f:GetPoint()
  db().barPos = { a, nil, b, x, y }
end

-- ------------------------------------------------------------------ the pop-out
local FIGHT = [[
  local fight = (PlayerInCombat and PlayerInCombat()) or (SecureCmdOptionParse and SecureCmdOptionParse("[combat] y; n") == "y")
]]
local SHIFT = [[
  local shift = (IsShiftKeyDown and IsShiftKeyDown()) or (SecureCmdOptionParse and SecureCmdOptionParse("[mod:shift] y; n") == "y")
]]
--- Shift over a top icon, in a fight: its column.
TC.SNIP_ENTER = FIGHT .. SHIFT .. [[
  if not (fight and shift) then return end
  local c = self:GetFrameRef("fly")
  if c then c:Show() end
]]
--- The mouse off a top icon or a pop-out icon, in a fight: the column closes when the mouse is on neither.
TC.SNIP_LEAVE = FIGHT .. [[
  if not fight then return end
  local c, s = self:GetFrameRef("fly"), self:GetFrameRef("src")
  if c and c:IsShown() and not c:IsUnderMouse(true) and not (s and s:IsUnderMouse(true)) then c:Hide() end
]]
--- A pick (before its cast): the row's icon now drops this one. Its message has the column close after the cast - on the mouse
--- coming UP only (Arn, 23 Nov: "it does not update the first row it still shows the old totem": the game casts on the DOWN, and a
--- column closed then never heard the up - the up is where the plain code puts the pick on the row).
TC.SNIP_PICK = [[
  local s, spell = self:GetFrameRef("src"), self:GetAttribute("*spell1")
  if s and spell then s:SetAttribute("*type1", "spell") s:SetAttribute("*spell1", spell) end
  if down then return end
  return nil, "picked"
]]
TC.SNIP_PICKED = [[
  local c = self:GetFrameRef("fly")
  if c then c:Hide() end
]]
--- Shift pressed with the mouse already on a top icon, in a fight (a state driver on [mod:shift], on the header).
TC.SNIP_SHIFT = FIGHT .. [[
  if newstate ~= "down" or not fight then return end
  for i = 1, 8 do
    local b, c = self:GetFrameRef("top" .. i), self:GetFrameRef("fly" .. i)
    if b and c and b:IsVisible() and b:IsUnderMouse(true) then c:Show() end
  end
]]

--- The secure header, once, out of a fight. No header, no wrapping = the pop-out only out of a fight (TC.secure says why).
function TC.Secure()
  if TC.header or fighting() then return end
  local okH, h = pcall(CreateFrame, "Frame", "BiSToolsTotemCardHeader", UIParent, "SecureHandlerStateTemplate")
  -- (the globals, not the template's methods: the fence's Forever baseline has SecureHandlerWrapScript / SecureHandlerSetFrameRef,
  -- and no SetFrameRef method)
  if not (okH and h) then TC.secure = "no secure header on this client" return end
  if not (SecureHandlerWrapScript and SecureHandlerSetFrameRef) then TC.secure = "no secure snippets on this client" return end
  TC.header = h
  h:SetAttribute("_onstate-shift", TC.SNIP_SHIFT)
  if RegisterStateDriver then pcall(RegisterStateDriver, h, "shift", "[mod:shift] down; up") end
  TC.secure = "ready"
end
local function wrap(b, script, pre, post)
  if not TC.header then return end
  local fine = pcall(SecureHandlerWrapScript, b, script, TC.header, pre, post)
  if not fine then TC.secure = "the game refused to wrap " .. script end
end
local function ref(b, label, to)
  if TC.header and b and SecureHandlerSetFrameRef and to then pcall(SecureHandlerSetFrameRef, b, label, to) end
end

--- Column `i` over top icon `from`, built and aimed now (out of a fight): the phone's list for that icon.
function TC.Column(f, i, from, size)
  local col = f.cols[i]
  if not col then
    local okC, c = pcall(CreateFrame, "Frame", "BiSToolsTotemCardCol" .. i, f, "SecureHandlerBaseTemplate")
    col = okC and c or CreateFrame("Frame", "BiSToolsTotemCardCol" .. i, f)
    col.bg = tex(col, "BACKGROUND", "line2")
    col.bg:SetAllPoints(col)
    col:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    col.b = {}
    f.cols[i] = col
  end
  local list, gap = from.item and from.item.fly or {}, TC.GAP
  for j, it in ipairs(list) do
    local b = col.b[j]
    if not b then
      b = button(col, "BiSToolsTotemCardFly" .. i .. "_" .. j)
      b.inFly = true
      wrap(b, "OnLeave", TC.SNIP_LEAVE)
      wrap(b, "OnClick", TC.SNIP_PICK, TC.SNIP_PICKED)
      col.b[j] = b
    end
    dress(b, it, size)
    b.src = from
    ref(b, "src", from)
    ref(b, "fly", col)
    b:SetFrameLevel((col:GetFrameLevel() or 1) + 1)
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", col, "BOTTOM", 0, gap + (j - 1) * (size + gap))      -- (the first nearest its icon, the game's way)
  end
  for j = #list + 1, #col.b do col.b[j]:Hide() end
  col:ClearAllPoints()
  col:SetPoint("BOTTOM", from, "TOP", 0, 0)                  -- (touching its icon: no gap to cross)
  col:SetSize(size + 2 * gap, math.max(1, #list * (size + gap) + gap))
  ref(from, "fly", col)
  ref(from, "src", from)
  ref(TC.header, "top" .. i, from)
  ref(TC.header, "fly" .. i, col)
  if TC.flyFrom ~= from then col:Hide() end
  return col
end

--- Shift over an icon of the top row, out of a fight: its column (built at the paint).
function TC.OpenFly(from)
  local f = TC.frame
  if fighting() then return end                              -- (in a fight the snippets do it)
  if not f then return note("no card") end
  local col = from and from.slot and f.cols[from.slot]
  if not col or #(from.item and from.item.fly or {}) == 0 then return note("nothing else of its kind to pick") end
  for k, c in pairs(f.cols) do if k ~= from.slot then c:Hide() end end
  TC.flyFrom = from
  TC.flyAt = GetTime and GetTime() or 0
  TC.offAt = nil
  col:Show()
  TC.watch:Show()
  note(("opened: %d to pick"):format(#from.item.fly))
end

function TC.CloseFly(why)
  local f = TC.frame
  TC.flyFrom = nil
  if TC.watch then TC.watch:Hide() end
  if not f or fighting() then return end
  local was = false
  for _, c in pairs(f.cols) do if c:IsShown() then was = true c:Hide() end end
  if was and why then note("closed: " .. why) end
end

--- After a fight: the picks made in it go onto the phone's row (what the snippets already aimed).
function TC.Settle()
  local q = TC.queue
  TC.queue = nil
  for _, it in ipairs(q or {}) do
    local a = it.act
    if type(a) == "table" then
      if type(a.fn) == "function" then pcall(a.fn) elseif type(a.ok) == "function" then pcall(a.ok) end
    end
  end
end

-- ------------------------------------------------------------------ the paint
--- The tab's number: the phone's big number ("NEW" = never fought with this row: a dash), in its colour.
function TC.Tab(n)
  if type(n) ~= "table" then return T.text("dim", "-") end
  return T.text(n.ink or "good", n.big == "NEW" and "-" or tostring(n.big or "-"))
end
--- Its tooltip: what the row is, the last fight against it, the place.
function TC.TabLines(n)
  local out = {}
  if type(n) ~= "table" then return out end
  if n.small then out[#out + 1] = T.text("ink2", n.small) end
  if n.big == "NEW" then out[#out + 1] = T.text("dim", "never fought with this set-up: go and fight") end
  if n.right and n.right ~= "" then out[#out + 1] = n.right end
  if n.under and n.big ~= "NEW" then out[#out + 1] = T.text("dim", n.under) end
  return out
end

function TC.Paint()
  TC.pending = nil
  if fighting() then TC.late = true return end
  local f = TC.frame
  if not TC.Wanted() then if f then TC.CloseFly() f:Hide() end return end
  local fine, rows = pcall(C.Phone.icons)
  if not fine or type(rows) ~= "table" or type(rows[1]) ~= "table" then if f then f:Hide() end return end
  f = TC.Build()
  local d = db()
  local size, gap = tonumber(d.barSize) or TC.SIZE, TC.GAP
  local okN, n = pcall(C.Phone.number)
  TC.num = okN and n or nil
  f.tab.num:SetText(TC.Tab(TC.num))
  local okD, dk = false, nil
  if C.DeckCan and C.DeckCan() and C.Phone.deck then okD, dk = pcall(C.Phone.deck) end
  TC.deck = okD and type(dk) == "table" and dk or nil
  if TC.deck then
    local on = TC.deck.verb == "IS ON IT"
    f.deck.state:SetText(T.text(on and "good" or "gold", on and "ON" or "SEND"))
    f.deck:Show()
  else f.deck:Hide() end
  local top = gap
  local x0, wide = TC.TAB + gap, 0
  for r, list in ipairs({ rows[1], rows[2] or {} }) do
    local pool = r == 1 and f.top or f.low
    for i, it in ipairs(list) do
      local b = pool[i]
      if not b then
        b = button(f, "BiSToolsTotemCard" .. (r == 1 and "Top" or "Low") .. i)
        b.top, b.slot = r == 1 or nil, r == 1 and i or nil
        if r == 1 then wrap(b, "OnEnter", TC.SNIP_ENTER) wrap(b, "OnLeave", TC.SNIP_LEAVE) end
        pool[i] = b
      end
      dress(b, it, size)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + (i - 1) * (size + gap), -(top + (r - 1) * (size + gap)))
      if r == 1 then TC.Column(f, i, b, size) end
    end
    for i = #list + 1, #pool do pool[i]:Hide() end
    wide = math.max(wide, #list)
  end
  f:SetSize(x0 + wide * (size + gap) + (TC.deck and TC.TAB or 0), top + 2 * (size + gap))
  for i = #rows[1] + 1, #f.top do if f.cols[i] then f.cols[i]:Hide() end end
  if TC.flyFrom and TC.flyFrom:IsShown() and TC.flyFrom.item and TC.flyFrom.item.fly then TC.OpenFly(TC.flyFrom) else TC.CloseFly() end
  f:Show()
  return true
end

--- Painted a moment later, once for a burst (a press, a fight saved, the bars changing).
function TC.Soon()
  if TC.pending then return end
  if not (TC.Wanted() or (TC.frame and TC.frame:IsShown())) then return end
  TC.pending = true
  if C_Timer and C_Timer.After then C_Timer.After(TC.WAIT, TC.Paint) else TC.Paint() end
end
C.CardSoon = TC.Soon

-- ------------------------------------------------------------------ events
local ev = CreateFrame("Frame")
TC.events = ev
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_SLOT_CHANGED", "UNIT_INVENTORY_CHANGED",
  "GROUP_ROSTER_UPDATE", "MODIFIER_STATE_CHANGED", "SPELLS_CHANGED" }) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, e, a1, a2)
  if e == "SPELLS_CHANGED" then TC.rankCache = nil end        -- (a new rank: read again when next asked; then painted)
  if e == "PLAYER_REGEN_DISABLED" then                       -- (before the lockdown: the last moment to put things away)
    TC.EndDrag()
    TC.CloseFly()
    return
  end
  if e == "MODIFIER_STATE_CHANGED" then                       -- (Shift pressed with the mouse already on an icon)
    if (a1 == "LSHIFT" or a1 == "RSHIFT") and a2 == 1 then
      if TC.hover then TC.OpenFly(TC.hover) else note("Shift pressed, but the mouse was on no totem of the card") end
    end
    return
  end
  if e == "UNIT_INVENTORY_CHANGED" and a1 ~= "player" then return end
  if e == "PLAYER_REGEN_ENABLED" then
    TC.Settle()                                              -- (picks made in the fight, onto the phone's row)
    if TC.frame then TC.CloseFly() end
    if not TC.late then return end                           -- (a fight saved paints it, 1.5 s later)
  end
  TC.late = nil
  TC.Soon()
end)

--- `/bist combo bar [on|off|size N|reset]`.
function TC.Slash(rest)
  local d = db()
  local w, v = tostring(rest or ""):match("^(%S*)%s*(.-)$")
  if w == "on" or w == "off" then d.bar = w == "on"
  elseif w == "size" and tonumber(v) then d.barSize = math.max(18, math.min(48, math.floor(tonumber(v))))
  elseif w == "reset" then d.barPos = nil TC.Place()
  elseif w == "why" then
    NS.Print("totem card: %s; pop-out: %s; mouse on: %s; in a fight: %s", TC.Wanted() and "shown" or "not shown", tostring(TC.why or "never tried"),
      TC.hover and tostring(TC.hover.item and TC.hover.item.word) or "nothing", tostring(TC.secure or "not built yet"))
    return
  elseif w == "" then d.bar = not (d.bar == true) end
  TC.Paint()
  NS.Print("totem card %s%s - drag it by the dps tab at its left; Shift over a totem: the others pop out", T.text(d.bar and "good" or "warn", d.bar and "on" or "off"),
    (TC.Wanted() or not d.bar) and "" or T.text("dim", " (it shows for a shaman, with the combo tool on)"))
end
