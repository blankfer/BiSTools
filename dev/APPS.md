# APPS: every tool IN the phone (22 Nov 2026)

Arn, 22 Nov, looking at the deck live for the first time:
- "these apps i want them to open in the phone like apps, right now the apps are just options"
- "its only when i drag a window out that it becomes an app in the screen not in the phone, or if i drag a live tile it stays like a tile"
- "dont like how stuff is cutoff"

So: an icon opens the TOOL ITSELF in the phone - its list, its search, its buttons, its numbers. Never just its options (they are the last
tab, SETTINGS, added by the frame). Never an OPEN button to the old window, except where the old window holds something the deck can not
hold yet (a secure cast button, the see-through map): then one key "OLD WINDOW", `peek = true`.

## The file
`Tools/Apps/<Name>.lua`, loaded after `Tools/DeckPages.lua`:

    local _, NS = ...
    local DP, R = NS.DeckPages, NS.Registry
    if not (DP and DP.App) then return end
    DP.App.sounds = function(tool, db)      -- the registry key; db() = the tool's saved settings, NOW (call it each time)
      return {
        name = "Sounds",                    -- optional
        badge = function() return n end,    -- optional number on the icon
        card = { ... },                     -- optional live card
        page = { tabs, find, boxes, rows, text, hero, say, big, keys, tick, tour },
      }
    end

Everything is DATA (functions that answer tables and words), called at paint time (at most once a second, 0.15 s while typing). No frames,
no colours of your own, no events and no tickers in these files: the tool already has them. Reuse the tool's OWN functions (NS.Sounds.Shown,
NS.Party.Invite, ...): no second copy of its logic. If the tool keeps something local that the page needs, expose it on its table in the
tool's file with a minimal edit (and nothing else in that file).

page parts (every one is handed the tab number; only your own tabs reach you, SETTINGS is not yours):
- `tabs = fn -> { "ALL", "STARS" }` 1-3 short words in capitals (SETTINGS comes after them: 4 in all must fit 240 px, so <= 9 letters)
- `find = fn(tab) -> { hint = "search", get = fn -> words, set = fn(words), enter = fn(words) }` or nil: a search line
- `boxes = fn(tab) -> { { "LABEL", value, ink }, ... }` 1-4 number boxes. ink: "ink" "ink2" "dim" "good" "gold" "accent" (rose/danger exist too: look at what DeckPages.lua uses)
- `rows = fn(tab) -> { row, ... }`, row = { text, right = words, ink = colour of right, mark = one letter or pic = icon texture/file id, done = true (dim),
  act = button (a click on the row: it gets a chip at its right, `verb` = the word on it, else a secure button's word, else ">"; `act.chip = true` = the
  right words are the chip, a switch's ON / OFF), head = true (a small heading, no ground), side = button (a second key, 48 px, at the right - then no `right`), less = / more = buttons, tip = words on hover }.
  The list scrolls by itself (wheel / pad). Give the whole list; no paging of your own. A very long one (thousands): build it once and keep it until it changes.
- `text = fn(tab) -> words` (wraps), mostly for "nothing here yet: do this to fill it". nil when there is a list.
- `say = fn -> one short line` under the list. `hero = fn -> { art = "model", creature = npcId | display = displayId, big, small }` (the picture on top).
- `big = fn(tab) -> button` the one main thing to do, `keys = fn(tab) -> { button, ... }` up to 4 smaller ones.
- `tick = true` when its words change by the second.
- `tour = { { text, note }, { text } }` shown once, the first time: what this app does, in plain words (two steps at most).
button = { word = "PLAY", fn = function() ... end, peek = true (looking only: does not make a live card), tip }.
  A row without act / side / less / more is INFORMATION: no ground, no chip (Arn, 22 Nov: "this is clickable or this is just information"). Numbers
  that belong together are BOXES (up to eight, two lines), not rows.
  A SECURE button = { word, spell = [, bag, slot] | item = | macro = , ok = fn (the last word before the click: false = nothing happens), after = fn (once, after it) }: live
  out of a fight (DeckOverlay). Never do anything protected in a fn
  (CastSpell, UseItem, TargetUnit, JoinX in a fight...). In a fight nothing on the deck can be clicked at all.
card = { when = "use" (only after you did something in the app) | leave out (comes by itself when prio answers), alive = fn -> bool (for "use"),
  prio = fn -> number | nil (nil = no card now; 3 = quiet, 5-6 = useful now, 8-9 = act now), tick = true,
  lines = fn -> { "TITLE", "", "the words", "right", inkOfRight, hot = bool, list = { { left, right }, ... up to 3 } },
  buttons = fn -> up to 3 buttons }. Only where a live card makes sense.

Confirm anything that hurts (disband, kick, clear a list): first press changes the word ("SURE?") for 5 s, the second does it. GetTime().

## Rules of the house
Plain words, no flight words. Forever client: in a dungeon a living creature's name / GUID is SECRET - never compare or concatenate a value from
the client without the file's own `plain()` / `issecretvalue` guard. Player names are whole ("Name Surname"). No realm APIs. Nothing per frame.
ASCII only in Lua. Lines under ~160 letters. No new saved-variable keys unless the app truly needs one.

## The test
`dev/apps/<name>.lua`, run by dev/tests.lua at its end: `return function(H) ... end`, H = { NS, R, ok, S (slash: S("on sounds")), fireAll, W, Dk (BiSTheme.Deck), Page = fn(key) -> def,
Paint = fn(key, tab) -> paints the app at 220x300, 260x462, 600x420 and answers nothing (throws = red) }. Test: the rows say what the tool knows, a press does what the tool's own window does, empty states, a
secret value does not throw, and every press leaves no error. Restore every global you replace. Run: `cd BiSTools && lua.exe dev/tests.lua`
(ends in "ALL OK"), then `bash ../_bisdev/check.sh BiSTools` ("all green").
