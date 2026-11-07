# BiS> processing - the plan (6 Nov 2026)

Arn, 6 Nov: "a processing more it's lists all our stuff for our profession ... click a button in the BiS toolbox or
... a button to the profession overview window ... Enchanting and miner ... clicking it disenchants, all the ore
with a smelt icon opens the smelt window and starts smelting ... if there is tin and copper it makes bronze ...
refreshes after every cast finish or when we get new items from mail." Named: **Processing module**.

## What it is

A BiS Tools tool, `processing` (`Tools/Processing.lua`), and one window, **BiS> processing** (1.43:1). One row per
thing in the bags a profession of yours can turn into something else: icon, name, count, and on the right a button
wearing the profession's icon. Hover a row = the item's tooltip.

Opened from:
- a button in the **BiS> tools box** - shown only while there is something to process;
- a button on the **profession window** (TradeSkillFrame), beside its title.

Refreshed after every cast (UNIT_SPELLCAST_SUCCEEDED, player) and every bag change (BAG_UPDATE_DELAYED - mail
taken lands here too). Nothing runs while the window is closed except the tools-box button's one question
"is there anything?", asked on bag change only.

## Enchanting - disenchant

- Rows: gear you can disenchant (the glow's rule, `NS.DE.Kind`: weapon/armor, green to epic, no shirt/tabard).
  Purple = free, red = soulbound.
- The button is SECURE (Disenchant is a spell cast on an item): type `spell`, Disenchant, `target-bag`/`target-slot`.
  Red rows: **Shift**-click (the glow's rule: one key more where care is the point).
- **Alt-click is never used** - Gargul's roll-out stays safe (Arn: "might mess with people rolling out gear").

### Never the wrong item (Arn: "two items of the same name ... one of them can have an enchant")

- Every row is ONE item by its **GUID** (`C_Item.GetItemGUID(ItemLocation)` - the item's own unique id, the
  "unique number" BiS JC used). The button's PreClick asks again what sits at that bag/slot; a different GUID =
  the click is cancelled (its `type` cleared) and the window repaints. A bag sort between paint and click can
  never disenchant the neighbour.
- **Enchanted** items (an enchant id in the link) wear an "enchanted" tag - that is the "my gear" case.
- **Same name, mixed** (one enchanted / soulbound / different suffix, one not): ONE warning line on the group, not
  per item. Ten identical fresh crafts from levelling the profession: no warning at all (Arn: "we don't want to keep
  saying it 10 times if they know they're gonna disenchant 10").
- **Ignore** (Arn: "we don't want to always pop up their purple gear that they carry as extra gear"):
  right-click a row (or the item in the bags, with the glow up?) = "ignore this item" - by GUID, so the one copy
  you carry is hidden and the ten crafts of the same name still show. A footer "N ignored - show" brings them back.

## Mining - smelt

- RestedXP's way, measured in its Forever guides (`/run local t=C_TradeSkillUI;t.OpenTradeSkill(129);
  t.CraftRecipe(3275,n)`): from a click, `C_TradeSkillUI.OpenTradeSkill(186)` (Mining) then
  `C_TradeSkillUI.CraftRecipe(recipe, C_TradeSkillUI.GetCraftableCount(recipe))`. No secure button needed.
- Rows: each ore you can smelt (Copper 2657, Tin 3304, Silver 2658, Iron 3307, Gold 3308, Mithril 10097,
  Truesilver 10098, Thorium 16153, Dark Iron 14891 - recipe = the smelt spell; checked against the client's own
  recipe list, `GetAllRecipeIDs`, never assumed known).
- **Alloys, in order** (Arn: "copper ore [smelt] tin ore [smelt] once those two materials are in, bronze
  [smelt]"): Bronze 2659 (Copper Bar + Tin Bar), Steel 3569 (Iron Bar + Coal). The alloy's row shows only once its
  bars are in the bags; the ores above it come first.
- **A forge** (Arn: "if they click the button and nothing happens, we have to let them know"): the client's own
  refusal (UI_ERROR_MESSAGE "Requires Forge" / anvil) is caught and said in the window's prompt: "stand next to a
  forge". Never silent.

## Later (not now)

Other professions that turn bag items into something (if Forever has them). Auto-open with the profession window
(Arn has not asked). Leatherworking hides? Skinning? Ask first.

## Live checks needed (probes before trusting)

1. Disenchant through a secure `spell` button with target-bag/target-slot on Forever (BiS JC proved it for
   Prospecting on TBC only).
2. `CraftRecipe` from our button's OnClick on Forever (RestedXP's macros say yes - from a macro, not an addon
   frame).
3. Mining's skill line id on Forever (186 classic) and whether the smelt recipe ids are the spell ids.
4. The exact "Requires Forge" error text, to catch it.

Testers: who has Enchanting, who has Mining - Arn to say.
