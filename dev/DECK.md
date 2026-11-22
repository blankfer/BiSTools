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

## The look in one sentence, and pulling cards out (Arn, 22 Nov)
His rule for every screen: a Ryan Gosling phone, half iPhone, half Tesla. In our words (no brand or person names in anything
public): night dusk in purple and pink on black, one dark glass, ONE big thin number per card and the rest small, a pill at the
top that says the one thing now, things glide home, calm, nothing flashes. Still BiSTheme colours only.
"BiS rides if someone wants to drag that out of the phone and pin [it to] their screen even when they close tools ... when they
close it it goes back to the tools": any card. Sketch https://claude.ai/artifact/9bL2M1PZCBUepmLmjQZRZ6 (three picks owed: shape,
look, what a fight does). Build rules: its own small plain frame on UIParent (nothing secure, never a child of the deck, so the
deck may close); place and size per character and per card in the store; alive with the deck closed (a beat only while a pin is
shown); a slot in the deck with BRING IT BACK, never shown twice; a button does what the drag does (pad, keyboard); a drag ends
at the pull; a card with nothing to say hides and comes back to its place. Rides first: it takes over from the old rides card
(one or the other, never both).

## Themes (Arn, 22 Nov: "make Ryan gosling mode a mode you have to turn on theme , I like the clean style that you did first , we like dark mode other people can change the theme")
Dark = the clean deck, the default, and what every layout is judged in. Night drive (the Gosling look: pink accent, a dusk and roofs behind the head of
home, never behind a list), Light, High contrast are picked in the switches (THEME), `/bist deck theme <name>`, or the welcome. A theme is the same
colour names in other colours (D.THEMES); it never touches T.hex, so no other BiS window changes. dev/deck.lua measures every theme: ink 7:1, the rest 4.5:1.
PULL-OUT cards therefore start in the clean style; the big thin number, the pill and the glide stay part of the plan for all themes.

## Peek, use, live card, pulled out (Arn, 22 Nov) - BUILT
"they open farm app they click around in it it'll show up as a live card if it makes sense if they just looks at it and exit they just
took a peek, but if they like the live card cause they can click stuff on it and drag it out and pin it to their screen , they don't end up
likening it they close it and goes back to the phone, if they want to see more it opens the app on the phone". And before it: "does
everything have an app or do some only have a live card ... we need to make all the tools into apps and smarty size them for live cards".
- PEEK = opened, tabs, scrolling, a button marked `peek`: nothing left behind. USE = a button that does something: `D.Used`, and the card is
  there if `card.alive` says there is something to show. x on the card = done with it; `alive` false or 12 h = it goes by itself. Per
  character. `card.when`: "use" (Farm) or "news" (Rides, Bosses: by itself); the Apps page's LIVE CARDS tab: AFTER USE / BY ITSELF / NEVER.
- OUT or a drag = BiSTheme/DeckPins.lua: its own plain frame, the card's plain buttons, OPEN (or a click on it) = the app on the deck, x or
  dropped on the deck = back into it. The deck may be closed. A fight: clicks go through (switch: gone). Rides out = the old rides card
  stays away.
- EVERY TOOL IS AN APP: DP.Tools makes a page of each tool's own options (switch, choice, - / +, button, OPEN its window); a tool that is
  off is in the Apps page with TURN ON. Full pages so far: Bosses, Run, Rides, Farm.
- NEXT: cards size themselves S / M / L (proposal https://claude.ai/artifact/NJCTxoummvEmEmjgHExQE7), then Combo and Windfury as full
  apps with live cards.

## The signs at the top (Arn, 22 Nov, with his phone's status bar: "the signal strength does something WiFi guild communication battery")
BiSTheme/DeckStatus.lua: SIGNAL = the worse of home / world ping (4 bars to 80 ms, 3 to 150, 2 to 300); WIFI = people with a BiS addon heard
in group and guild (LibBiSComm peers + vers; stroke = off, unlit = paused by a chat lockdown); BATTERY = AUTO (rested XP while leveling, worst
gear at the top, gear under 20 always) or rested / gear / bags; teal = filling; THE BED = resting. One click = the Status page (words, numbers,
who was heard, what the battery shows). Switch "Signal, WiFi, battery". Lines are tinted textures (bislint line-paint).

## Data
BiS>Guides = a separate, NOT public library (Arn, 21 Nov) behind a BiSGuidesAPI (to build): dungeon quests, chains, givers,
levels, what each needs (kill / loot / use / click) and the item. The deck works without it: own quest log, BQ.OWN (our own
runs), LibQuestieDB at run time. Guides' RestedXP-made data is never shipped in BiS Tools (public).

## Order
1. Tonight's PRs merged. 2. The kit + its test (a sweep of every size, height and switch; nothing touches). 3. Bosses as the
first page, then its steps. 4. Home, cards, dock. 5. The other pages, one at a time, the old window behind a switch. 6. Guides
API, quest items (sketch https://claude.ai/artifact/3wUWgpd76pYafqEDXZp3TE, picks owed), PREP.
