# BiS Tools as a deck (plan, 21 Nov 2026)

Arn, 21 Nov: "our next big project is making bis tools a deck, this time we are going 9:16 i have an ultra wide screen so i
have room for width but my cousin does not he says taller better"; "the bis prob is exactly the test and prgroess i need
for biss boss quest pre quest steps auto advnaced skip go back etc"; "and from the start rezisable and toggles"; picks off
https://claude.ai/artifact/L3zXKVYauTFQjAWwtkLTgr: "yes d inside a they all look good live cards are nice too".

## What he picked
- A HOME SCREEN (A): app icons with counts, the dock (the old tools box's buttons that have work).
- LIVE CARDS (B) on top of the home screen: the things that need you now, each with its buttons. More than fit: scroll.
- STEP BY STEP (D) inside Bosses: PREP -> OUTSIDE -> INSIDE -> AFTER as one list of steps. One step's card with its one
  button, moves on by itself, back / skip / next, a progress bar, the list. The probe deck's flow (_bisdev Deck.lua).
- SWITCHES AND SIZE from day one: every app, every part, presets ALL / LEAN / BOSSES, per character; SIZE (scale) and
  HEIGHT (more rows) sliders and the corner grip. Secure parts change after the fight.
- Not answered one by one, taken from "they all look good": processing and recap become tall pages, the codex book stays
  big; start at the probe deck's size; old windows stay behind a switch for one release.

## Where everything goes
- PAGES: Bosses (Quests, Prep), Farm, Combo, Party, Summon, Rides, Rivals + griefers, Recap, Processing, Alts, Sounds, Codex.
- DOCK: target, farm key, rival target, XP food, bag and tent.
- STAYS ON SCREEN (read in a fight): combo text and tape, Windfury lamp + ASK, farm arrow, rival and healer marks, map.
- SWITCH ONLY: disenchant glow, emote, recap popping up.

## The kit (BiSTheme, synced copy)
One frame `T.Deck`. An addon registers pages as DATA: { key, name, icon, badge(), cards(), boxes(), tabs, rows(), big, keys,
steps() }. The kit owns: drawing and flow (every height from the ones above), secure rows and buttons (macro / item; written
out of a fight only, Dirty after), the fight dim (alpha, mouse off, models hidden by hand), hover pop, drag + saved place,
pages, the clock, the faint code line, switches, size. A page never makes a frame.
STEPS: { text, note, phase, button = { word, macro | item | fn }, done = fn, watch = events }. Done is read from the game:
quest accepted / turned in (QUEST_LOG_UPDATE, IsQuestFlaggedCompleted), an objective's `finished`, an item in the bags,
ENCOUNTER_END; never a creature's name (secret inside, solved.md 21 Nov).

## One look (Arn, 21 Nov: "our ui strays sometimes need a way to unify it", "bis healing black background wokrs becuause we can hide boxes")
The deck stands on the healing deck's BLACK: a part switched off leaves no hole. Every colour is BiSTheme's, owned by the kit - a
page hands in words and numbers and never a colour. `_bisdev/colours.lua` (check.sh) counts hand-picked colours per addon and only
lets the number go down.

## For everyone (Arn, 22 Nov: "design in mind going forward, let's make it easy for people with accessibility and gamepad support")
- EASY TO HIT: nothing to click under 24 wide and 22 high before the deck's 1.25 (the sweep fails otherwise); one press, never
  a hold, never a double click; a button and its opposite stand apart.
- EASY TO READ: no words under 11 units (the faint code aside), SIZE scales all of it, "Stronger words" turns grey into white.
- NEVER BY COLOUR ALONE: gold has a "!", done has a tick, a switch says ON / OFF, the chosen row has a bar.
- EASY TO HEAR: "Read aloud" (off until asked for) speaks what the mouse or the pad is on; never in a fight.
- QUIET: nothing flashes or loops; a fight makes it almost vanish.
- THE PAD: D-pad = nearest piece, A = press, B = back then out, LB / RB = tabs or steps (BiSTheme Pad.lua). The deck stands open
  all evening, so it holds the pad only while asked (`/bist deck pad`) and gives it back at B and at every pull. A secure button
  cannot be pressed by the pad's :Click() - the overlay must bind PAD1 to it out of a fight (UNPROVEN).
- Nothing lives only on hover: what a tooltip says, focus says too.

## One deck for every addon (Arn, 21 Nov: "this makes api our apps way easier", "unifed ui", "we can put a bis memoris live cardd")
The deck is not BiS Tools' alone. The kit is embedded in every addon (a synced BiSTheme copy, newest minor wins, as Settings
does for the BiS> options page), and whichever addon loads first makes the ONE frame. Registering a page or a card IS the
API: `T.Deck.Register{ owner = "BiSMemories", key = "memories", card = fn, page = {...} }`. An addon missing = its icon and
card are not there; an addon alone still has a deck with its own page. No addon reads another's tables: it hands in words,
numbers, and buttons it made itself.
- BiS Memories: a live card (tonight's shots, the last moment) with OPEN; a page later. No picture: an addon cannot show a
  file from the Screenshots folder.
- BiS Healing: out of a fight only (buffs missing before a pull, the cue card, EXPORT); its deck stays its own window.
- BiS Guild: dues, raid nights, who is on. Nebbinator: last scout. BiS Gamba: table open. BiS Shell: games as icons.
- BiS>Guides: never a page (not public) - it answers questions.
One set of switches: a card or page switched off asks nothing of its owner. A page's errors are the kit's to catch (pcall, the
card says so) - one addon's bug never takes the deck down.

## The first day, and our own tools (Arn, 22 Nov: "build the infrastructure for the onboarding stuff / Put my tools in there but grayed out")
BiSTheme/DeckApps.lua, data only; Deck.lua grew `state`, `about`, `turnOn`, `open`, `dev`, `hidden`, `page.tour`.
- Icons: what is on is lit, what is off says OFF, what is not installed says GET, our own tools come last and say DEV (or their
  count). Never gray alone. OFF / GET open a page that says what it is (TURN ON, or the name to search for). A switch hides
  what you do not have; LEAN and BARE have it off.
- The catalogue = the seven public addons, opened by their own door (API Open, else the slash word). An addon that hands in
  its own "app" wins. Guides and BiSProbe are never in it.
- Our tools hand THEMSELVES in with `dev = true` at PLAYER_LOGIN (BiSProbe: Probe deck, Reload, Errors when BugSack is there),
  so who does not have them never sees them. One click does the work.
- Apps page: every icon SHOWN / HIDDEN by a click; WELCOME plays everything again.
- The welcome: the step card, once, at the first Show; it goes on when it sees the drag, the size, the flip; a card keeps its
  place until done or NO THANKS. `/bist deck welcome` = again. A page's `tour` = its own words, once.

## Data
BiS>Guides = a separate, NOT public library (Arn, 21 Nov) behind a BiSGuidesAPI (to build): dungeon quests, chains, givers,
levels, what each needs (kill / loot / use / click) and the item. The deck works without it: own quest log, BQ.OWN (our own
runs), LibQuestieDB at run time. Guides' RestedXP-made data is never shipped in BiS Tools (public).

## Order
1. Tonight's PRs merged. 2. The kit + its test (a sweep of every size, height and switch; nothing touches). 3. Bosses as the
first page, then its steps. 4. Home, cards, dock. 5. The other pages, one at a time, the old window behind a switch. 6. Guides
API, quest items (sketch https://claude.ai/artifact/3wUWgpd76pYafqEDXZp3TE, picks owed), PREP.
