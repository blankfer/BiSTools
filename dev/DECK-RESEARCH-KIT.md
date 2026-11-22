# The deck: what the research found (21 Nov 2026)

Three helpers, read only: every window we have, the engineering, the design. Tags as in _bisdev/docs/forever-lookup.md.
Mockup (its layout is DeckLayout.lua's, checked 320 ways): https://claude.ai/artifact/JcXqDFfGC7H4ciccgUHYLJ

## Engineering
- THE SPLIT (decides the rest): a plain SKIN draws everything; the macro / item / spell buttons stand on one SECURE OVERLAY
  root on UIParent, placed by numbers over the skin. Secure children protect the window they stand on, so the boss phone
  freezes at every pull; a plain skin may resize, flip, dim and hide in a fight. Overlay root: SecureHandlerStateTemplate +
  RegisterStateDriver "[combat]hide;show" (CONFIRMED live in BiS Healing). Buttons anchor only to the root, never to art.
  Probes 1-3 (bisdev plans/deckkit.lua) decide it; if the skin ever answers IsProtected() true, stop.
- A frame is protected if a secure frame is its descendant OR anchors to it, at any depth (CONFIRMED, 17-18 Nov). A protected
  frame may not be anchored to a texture anywhere in its chain (CONFIRMED, 12 Nov). SetAlpha is always allowed.
- PLAYER_REGEN_DISABLED comes before the lockdown (CONFIRMED): the last legal write. End drags there.
- No pooling, hiding or re-parenting of secure buttons in a fight; a fixed pool made out of one.
- Load order: the oldest copy may load first. Register data only at load; build the frame at the first Show after
  PLAYER_LOGIN by the newest copy; `frame.built` retires an older one; DECK_READY on the last line (a file that breaks halfway
  must not block the others). The kit has no saves: each addon lends a table, the newest stamp wins.
- Our own corner grip (cursor travel / effective scale): StartSizing cannot hold a shape and sticks to the mouse at a pull.
- Full screen: strata HIGH, under UIParent, never hide UIParent; a ready check is DIALOG and must come over it (BETA). Not on
  UISpecialFrames (it is emptied when a Blizzard panel opens, CONFIRMED).
- Profiles: IsInInstance kind, C_PvP.IsBattleground, IsResting, IsInRaid, level. Raid night = in a raid, or a raid group near a
  raid PASTED into BiS Guild (BiSGuildAPI.RaidNight; there is no weekly schedule). Into an instance at once, out after 10 s, as
  a ghost never, in a fight never, pinned never.
- Costs to hold: hidden 0 a second, minimized 1, a quiet home with six cards <= 60 calls.
- Risks: the overlay drifting from its row (a click does the wrong thing), secret names inside, blame and CPU billed to
  whichever addon's copy won, seven saves disagreeing, a full screen covering a ready check.

## What we have (short)
- 46 windows and pieces. ON THE DECK: Bosses, Farm, Summon, Combo, Party, Processing, Rivals, Rides, Guild logins, Nebbinator's
  scout, Gamba, FM. LANDSCAPE: Recap, Codex, Alts, Sounds, Journal, Guild terminal, Nebbinator, Guides audit. STAYS ON SCREEN:
  the healing grid and deck, BiS> now in a fight, combo float and tape, the Windfury lamp, farm arrow, marks, the overlay map.
- No profile feature exists anywhere; no BiSGuidesAPI; BiS Tools has no change events (cards would poll).
- Missing for cards: FarmNow, QuestRows, LastDeath, ProcessingReady, ComboRank, SummonList (Tools); MissingBuffs, BuffNeeded
  (Healing); OnThisDay, Summary(year) (Memories); Online, Glance, WhoLoggedIn (Guild - "dues" do not exist); NextPost
  (Nebbinator); Games with launch (Shell); everything (Guides).
- Hardest to move: the healing deck (link it, do not absorb it), secure rows, the boss phone's fight behaviour, Processing's
  GUID check, the box's docking, Combo's saved sizes, the 16:9 art, 3D models, the guild terminal, literal colours.

## Design
- 9:16 at 520 wide is 924 high and does not fit a 768-unit screen; the tallest portrait at scale 1 is 432 x 768.
- Full-height 1.43:1 is 1098 x 768. On 3440x1440 (1835 units wide) the side left over is 368: it holds a 368 x 654 portrait. On
  16:9 (1365) only 134 is left: the dock and the clock.
- Wide to tall keeps the DETAIL and hides the list; tall to wide brings the list back with the same row chosen. Scroll,
  choice and step survive every flip.
- A card answers "what now", "how long" or "what is missing"; three at most in portrait, the rest as chips; it keeps its place
  10 s and never moves while hovered; a new one joins at the bottom until the mouse leaves; gone at its end.
- Words: 13 units at effective scale 1 is the floor (18 px at 1080p). Rows 32, the one button 44, 24 between a button and its
  opposite - the deck's units times its scale.
- Colours: purple = clickable only, gold = the one thing now, teal = good. Rose "warn" and teal look the same to many
  colour-blind eyes: an error is red with a square. Borders at 3a3260 are decoration, never a state.
- Motion: 80 hover, 200 card, 300 flip, only what changed, nothing loops, none in a fight.
- Raid night, a glance each: before - in / missing / role gaps; ready check - who is not, no flask; between pulls - best %,
  first deaths, rez, break clock; loot - item, claims, trade clock; after - attendance, what dropped, next night.
