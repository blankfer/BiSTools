## Unreleased

- **The death recap shows faces.** Instead of a wall of text, it opens on up to three 3D models: whoever killed you in the middle, the two biggest assists either side. Under each: what they hit you with (the killer: the killing blow itself, "Fireball 312 +40") and how much they did in all, with their share. A player who killed you and is still nearby shows as themselves, gear and all; one who's already gone shows their class icon. Their nicknames are in the card's tooltip. The rest - who hit you, physical or magic, your health, the last ten hits - is one click away behind **details** at the bottom.

## 0.17.0

- **The farm's find sound is off by default.** The whisper ping for "a fresh copy of your mob turned up" kept going off in busy cities. It is now off for everyone once, unless you had picked "always". Want it back: `/bist farm sound first` (or the farm's options).
- **The farm's spawn arrow is off by default too.** The big floating arrow to the next spawn now shows only once you ask for it: `/bist farm arrow on`. Anyone who had switched it on keeps it.
- **The ride card says how sure it is.** Its last line used to say how long ago the ride was timed ("634:12 ago"). Now it says how likely the countdown still is to be right, within 10 seconds: "timed by Chain Healz - BiSGamba - 67% sure", green, gold or red. A fresh timing is 100%; every lap the zeppelin runs since lowers it, faster on routes the clock only learned from rides than on the ones it has measured. Six hours on it says 0%: a server restart resets every zeppelin, and the game can't tell us one happened.
- **RIDE-TRAK: shift-click the ride card.** Each ride gets a little line map right under its announcer, inside the card: here on the left, where it goes on the right, and the zeppelin or boat a gold block moving along it - docked here, on its way, docked over there, coming back - with how long until the next thing happens. A ride nobody has timed yet shows SCANNING. While it is open the card stays up for every ride from here, not only the one waiting, and each keeps its announcer: once his ride has left he tells you when the next one is in. Shift-click again to close it (or `/bist rides trak`).
- **Your face on RIDE-TRAK.** Standing on a platform, your round portrait sits at the dock end of that ride's line; once you're aboard it rides along on the zeppelin or boat. Anywhere else it stays off rather than guess wrong.
- **The announcers' faces are zoomed out a little** - some goblins showed as thin slices. Try your own: `/bist rides zoom 0.6` (0.3 far, 1 close).
- **The Deeprun Tram on the ride card** (with the shared BiS lib's next version). On a tram platform the card says when the tram to Ironforge or Stormwind rolls, timed by your guild like the zeppelins - anyone with a BiS addon who rides it once sets it for everyone. RIDE-TRAK shows both trams on the line, and your face exactly where you are in the tunnel. With BiS Shell installed its own TRAM-TRAK takes the tram, and this card stays out of its way. How sure it is now comes from the shared lib, so every BiS addon says the same number.
- **The ride card has an X.** Close it and it stops popping up - it says how to bring it back: `/bist rides on`.

## 0.16.0

- **Hands-off invites, in the party tool's options** (all off until you turn them on):
  - **accept invites from the guild** - a guildmate's party invite is accepted for you;
  - **accept invites from friends** - character friends and Battle.net friends;
  - **invite on a whispered keyword** - whoever whispers you the word (`inv`, `invite` or `123`, or your own: `/bist party keyword <word>`) gets an invite. **keyword from**: known (your guild and friends) or anyone. You must lead, or be on your own; past five the party becomes a raid by itself.
  - Matched by who people really are, not by first name - Forever has surnames, and two players can share a first name.
- **Inviting more than a party holds makes the raid by itself.** The game counts invites still waiting for an answer, so on your own only four can go out, and a party can only become a raid once someone is in it. Now the first four go out, the rest wait, and when the first person joins the party turns into a raid and the rest are invited. Already in a party, it becomes a raid before the invite that would be the sixth. Invites sent one at a time (BiS Guild's raid-night pop-up) count too. If nobody joins within two minutes, the waiting ones are dropped with a line saying who - press Invite again.
- **You show up in FojjiCore's windows.** A party member running FojjiCore now sees your level and experience in its Experience window and your campfire in its Campfires window, instead of "No Addon" (the shared BiS lib, version 16 - quiet if you run FojjiCore's Dungeon Journal yourself, which says the same).

## 0.15.0

- **The ride card.** At a zeppelin tower or a boat dock - or in its capital: Orgrimmar, Thunder Bluff, Undercity - a little card pops up at the top left while a ride waits at the dock: "Zeppelin to Grom'gol - leaves in 0:58". It hides again when the ride leaves. The clock is your guild's: anyone with a BiS addon who rides one times it, and everyone in the guild gets it; the card's last line says who timed it. Options under **rides**: the card on or off, **all rides** (every ride from here, coming and going), who timed it, its place (drag it anywhere). `/bist rides` lists the rides from where you stand.
- **For other addons:** BiSToolsAPI version 3 adds `Rides(map)` and `RideCard()`.
- The shared BiS lib is version 15 (the ride clock).

## 0.14.0

- **Fixed: the Friends list blamed BiS Tools for a blocked action** ("tried to call the protected function SearchFriends()"). BiS Tools no longer adds its lines to menus opened from the Friends list. To add a friend as a pal or rival, right-click their name in chat or target them.
- **A friends picker in the party window.** The new **friends** button lists your friends who are online, and your Battle.net friends playing WoW on your side. Click one to put them on the party list, and click again to take them off.
- **Guild online, in rivals & pals.** The rivals & pals window has two tabs now: **rivals**, and **guild online** - everyone in your guild who is on. Right-click a guildmate to add them as a pal (or take them off), or to whisper them.
- **The recruit crest.** With BiS> Nebbinator 4.0, anyone your guild is recruiting wears a gold version of the guild crest under their nameplate, and a line in chat says who in the guild is talking to them - so you can put in a good word. Option: "recruits (gold crest)".
- **Social:** `/bist social why` lists the last five buffs that made you wave, not just the last one.
- **For other addons:** BiSToolsAPI version 2 adds `IsRival(name)` (BiS Memories uses it to keep a picture when a rival kills you).

## 0.13.2

- **Every tool in the BiS Tools list opens and closes the same way.** Click a tool to open its window, click it again to close it. Some used to close and some only opened. Shift-click still brings a window to the middle of the screen. **social** and **bg**, which have no window, open the options where their settings are.

## 0.13.1

- **BiS addons can talk to other players on Forever again.** The game wrongly says addon messages are restricted, and the shared BiS code believed it, so nothing this addon sends to other players went out. It does now - and your guild's BiS Guild map shows where you are (outside instances; `/biscomm share off` turns that off).
- **Names with surnames work.** The shared code now uses your whole "Name Surname": you no longer show up twice on your own guild map, and party members with surnames are recognised.

## 0.13.0

- **Disband takes a shift-click**, like Invite, so you can't leave the group by mistake. A plain click only says how. Both the button in the BiS> tools box and "disband" in the party window; `/bist party disband` is unchanged.
- **The party window's invite checks first.** It no longer sends straight away: the little progress bar runs, then the list shows who'd be invited, by class, with an x on each. Guildmates and friends who are offline sit apart at the bottom and aren't invited; anyone outside your guild and friends list (the game can't say if they're on) is listed under Unknown; Refresh moves anyone who has logged on since up into the list. Then Send.
- **Pick several ranks.** In the guild view a click ticks a rank instead of inviting it. Tick Officer and Raider, press invite, and both ranks' people come up on one list, an x on each.
- **One list, added to.** With the invite list open, inviting your party list or ticked ranks adds them to it - nobody twice, one Send - and the top says what came in ("added <Officer>: 2 new").
- **The party window shows classes.** Names are in their class colour (from your group, guild or friends list), grey when offline, and whoever is with you now has a faint green bar.
- **No more "clear" button in the party window** - one click emptied the whole list. Take names off with the x beside each; `/bist party clear` or the button in the options still empties it on purpose.
- **When you last grouped.** Each name on the list shows how long since you were last in a group together ("3d", "5h"), and hovering it shows the day and the zone. BiS Tools keeps this itself, from today on, while the party tool is on.

## 0.12.0

- **BiSToolsAPI - other addons can use your party list's invites.** BiS Guild's raider terminal hands its raid lists to the confirm list (by class, an x per person, the inviting box, refusals in red). Nothing in it can change your settings; with the party tool off it simply says so.
- **Refresh you can see.** The confirm list sweeps back in line by line, the button reads "Refresh...", and the top says what changed for a few seconds ("2 new, 1 joined you", or "no change"). It also works now on a list that came from your party list or from another addon - whoever joined you moves down to "already with you".
- **Every button lights up under the mouse** - Send, Refresh, Close, Cancel, and the party window's buttons - so you can tell it's clickable.
- **`/bist pal <name> <surname>`** adds a pal without targeting them; type it again to take them off.
- **Shift-click** the tools-box Invite to open the party window and look the list over first. The row under the mouse lights up; the window's toggle reads party / guild.
- The addon list shows **BiS>Tools**, like its category.

## 0.11.0

- **A party list (new tool, off until you switch it on: `/bist on party`).** Your usual group, in its own window: click "party" in the tools list or type `/bist party`.
  - **Fill it** with "save" (whoever you're grouped with now), by typing a name, or with **Add to party list** on any friendly player's right-click - in the world, in chat, or in your Friends list (a Battle.net friend adds the character they're playing).
  - **Invite** asks everyone on it who isn't with you yet; **disband** clears your group (or leaves it, if you're not the leader). Invites go to the whole name, surname and all - that's how WoW Forever finds a player.
  - **guild** lists your guild's ranks: click one and it reads the roster, then shows everyone online with that rank, **by class, with an x** to leave out who isn't raiding tonight. **Send** invites them - and the list stays open: it rebuilds as people log on or join, so the next wave is one more Send. **Refresh**, **Close**.
  - **The inviting box**: a little loading window talks you through the invites and shows the game's real answers - received, declined, already in a group, can't find. Drag it where you like; switch the show off in the options if you'd rather not.
  - **In the BiS> tools box**: green Invite (shift-click - it opens the list to look over first; never shown in battlegrounds) and red Disband.
- **One BiS section on right-click menus.** Every BiS line - pal, rival, party list, "Track in farm" - now sits together under a "BiS" title, the way the game groups its own.
- **The overlay map shows where you are**, Diablo style: the zone and subzone in capitals in its corner.
- **Newly explored places fill in at once** on the overlay map - no more closing and opening it.

## 0.10.1

- **The overlay map fades out at its edges** instead of ending in a hard box, so it melts into the game. Your arrow and the dots stay sharp. (A new file: restart the game once after updating, a /reload won't pick it up.)
- **Capital cities lose their empty parchment.** A city map is one painted picture, so each of the six capitals now has its own measured frame - the empty paper and most of the crest go, the city and its name stay.
- **No more torn paper edge** around any map, and the map's name banner at the top is never cut off.
- **A faint line marks the map's tab** while it's hidden, so you can always find where to grab it.
- **"No map for this place"** (inside dungeons) sits in the map's corner under the tab, not over your character.

## 0.10.0

- **Your guild on the map.** Guildmates running any BiS addon show on the overlay map as small amber dots with their first names, on the zone you're looking at (your group keeps its class-coloured dots, and nobody is drawn twice). "Show guild" in the map tab's right-click menu hides them.
- **Sharing your spot is on by default, and one switch rules every BiS addon**: "share my spot" in the map options, or `/biscomm share off` / `on`. It's sent only while you move - every 15 seconds in a small guild, 30 with more than 20 online, once a minute past 50 - and never from inside an instance.

## 0.9.0

- **An overlay map, Diablo style.** Give it a key (Key Bindings > AddOns > BiS Tools > Overlay map - Alt+M works well) or type `/bist map`, and a faint map of your zone sits over the game. Clicks go straight through it, so you keep playing and fighting.
  - **It sits top-left** and hangs from a small tab that only shows when your mouse is over it - drag the tab to put the map anywhere; `/bist map reset` puts it back.
  - **Right-click the tab** for a quick menu: Show group, Lock map, Show all of the map, Grey, Opacity and Size with - and +, and All settings.
  - **Your arrow** in gold, turning as you turn. **Show group**: your party and raid as dots in class colours, with their first names.
  - **What it shows**: all of the zone (the explored parts painted over, as on the world map), or only what you've explored - the rest stays see-through and fills in as you go. A city is always shown whole.
  - Defaults: all, grey, 30% of the screen, 50% solid. A dotted trail of where you walked is there too, off by default.
- **Pals from the Friends list.** Right-click a friend and "BiS: add pal" is there - a Battle.net friend is added by their character's name, not their BattleTag. Same faction is a pal, the other faction a rival; when nothing says friend or foe (a name in chat), you get both lines and pick.
- BiS Tools has an icon in the addon list (a wrench).
- The shared BiS channel no longer hooks the summon popup on Forever, where hooking Blizzard's code can break it until a restart.

## 0.8.0

- **The death recap, remade** (the BiS shape, 1.43:1): the three cards, then **who hit you** - a bar per attacker with their damage and share - and **what kind** (physical or magic, and which school), your health across the hits, all ten hits in two columns, and the total. The rivals list is no longer tucked under it.
- **Rivals & pals have their own window**: rivals on the left (gold, the guild's, silver), your pals and the surnames you crown on the right. `/bist rivals`, the rivals & pals row in the tools list, or "rivals >" on the recap opens it; `/bist rivals list` still prints them in chat.
- **Your own side's MVPs**: in a battleground, your team's best healer and best killer wear a **>MVP<** tag - the same white box, the word in gold - read off the same scoreboard as theirs.
- **Marks above the nameplate, if you like them there**: "mark spot" under bg - on (on the body, under the nameplate) or above (on top of the nameplate, over the name). "mark height" nudges from either.
- **The minimap button sits on the minimap's edge, whatever its size.** It was placed for the default map, so on a bigger one (a minimap addon, or a scaled-up map) it landed inside; it now measures the map, and moves again when an addon resizes it after login.
- **The saber button in the tools box: left-click targets, right-click marks.** A left-click now only targets one of their marked players (nearest first); a right-click reads the scoreboard and marks them.
- **A pal nearby, a small note**: when one of your pals comes into view, out of combat, a green "<3 *Name* is nearby" in chat - once every ten minutes each, no sound. "pal nearby note" in the options switches it off.
- **Rivals & pals get the same preview**: hover the crosshair, sound, pal note, guild rivals or guildmates settings and your two characters wear a rival's crosshair (in the style you pick) with a surname crown, and a pal's heart with the guild crest.
- **See the marks on yourself before a battleground.** Hover "mark look", "mark size" or "mark height" in the options and a panel rolls out beside the window: two 3D models of your own character, a nameplate over each, wearing the healer mark and the killer mark - redrawn as you click through.
- **A sixth battleground mark: the tag.** A white box with **>Healer<** over their top healers and **>Killer<** over their top killer - white arrows, a red word, nothing behind it. "mark look" in the options, under bg.
- **Rivals & pals are their own tool.** A row of their own in the tools list, their own settings section in the options (sound, crosshair, guild rivals, guildmates, the target button) and their own commands: `/bist rivals`, `/bist rival`, `/bist pal`, `/bist pals`, `/bist surname`. Switching the death recap off no longer turns them off; switching rivals & pals off takes every crosshair, heart, crown and crest down but keeps your lists. Clicking a killer on the recap still makes them a rival, and the old `/bist recap rival` commands still work. Your rivals and pals are where they always were - nothing to set up again.

## 0.7.0

- **Battlegrounds: their healers and their top killer, marked** (new tool `bg`, on by default, battlegrounds only). The enemy's **top three healers** wear **white crossed sabers** on them, and their player with the **most killing blows** wears **red** ones - glowing and pulsing, right on the body under the nameplate. Forever hides the scoreboard's numbers mid-match, but it still sorts by them: BiS Tools reads the order, every 10 seconds while your scoreboard is closed (never while you're looking at it). Nothing in the first 90 seconds, while everyone is still at 0.
  - **A saber button** in the BiS> tools box (battlegrounds only): one click **targets** one of the marked players - those near you first - and reads the board right then. Also a **"BiS> mark"** button under the scoreboard window, and `/bist bg mark`.
  - **It remembers** their healers and killers across battlegrounds - a known healer is marked the moment they show up in your next one. `/bist bg why`, `/bist bg forget <name>`, `/bist bg clear`.
  - **Five looks** - X, saber, arrow, diamond, corners - with **size** and **height** settings under "bg".
- **Rivals are enemies; pals are friends.** A friendly player can no longer be made a rival or wear a rival's crosshair. Instead, right-click a friendly player for **"BiS: add pal"**: a little **green heart** over them, out of combat. A rival named "Terry Lin" no longer marks a "Terry Daviss" - whole names and player IDs are checked.
- **A whole surname at once**: `/bist surname Foreverpvp` - everyone named "*something* Foreverpvp" gets a small **gold crown**: enemies any time (one call-out a minute for the whole surname, not one per player), friends out of combat. The same again turns it off.
- **Battleground rivals are for that match**: a rival you add inside a battleground is let go when you leave - unless they kill you 10 times in that match, then they're kept for good.
- **Guildmates wear a small guild crest** instead of the plain +.
- **Shorter commands**: `/bist rival`, `/bist rivals`, `/bist pal`, `/bist pals`, `/bist surname`.
- **Thank-you emotes now catch a re-cast buff** (someone refreshing a Blessing of Kings you already had), and `/bist social why` keeps its real answer instead of "nothing new on you".
- **Options windows**: every setting says what it does in a help strip at the bottom when you hover it; windows are the BiS shape (1.43:1) with settings in even columns, and two BiS windows no longer open on top of each other.

## 0.6.0

- **Adding a rival in a battleground: a "+" button** appears in the BiS> tools box in battlegrounds and arenas - target an enemy player and click it ("-" takes them off again). `/bist recap rival` does the same from a macro. Inside battlegrounds and dungeons the game's right-click menu breaks if an addon adds a line to it, so BiS Tools no longer adds one there; out in the world "BiS: add rival" is still on the menu, now on target and focus menus too (players only). A rival saved as just "Grape" is still found as "Grape Sprite". `/bist recap why` says which menu opened last and what the rival line decided.
- **Threat marks - BETA, off by default** (new tool; turn it on with `/bist on threat`, then `/bist threat` opens its window): what each mob's threat is doing, on its nameplate.
  - **Tank:** purple on you, grey on another tank, red and flashing on a non-tank, orange as a groupmate closes in on a mob you hold. Yellow out of combat if you want it (off by default).
  - **DPS and healers:** nothing until your threat on a mob reaches 60% of a pull, then it fades in yellow -> orange -> red; it flashes only from 95%, and when it turns on you.
  - **Three looks:** a bar down the **left side** of the plate (default - readable when plates stack), a small **glow** down the sides and under it (open at the top, so the name stays clear), or your **crosshair**. Drawn beside the plate, so it works with any nameplate addon.
  - **The window:** pick the look, tank or dps (or auto), switch each situation on or off, pick each colour from a palette, set where it starts showing and where it starts flashing, preview it on a fake plate, reset the colours.
  - Ideas from the guild. A crowd-controlled mob cannot be shown: the game hides a mob's debuffs in combat.

- **Farm a mob from its right-click menu**: right-click a mob's portrait and pick **BiS: track in farm** - no typing its name, no killing one first. On the mob you are already farming it says **BiS: stop farming**. Only on mobs you can attack, never on players.

## 0.5.1

- **Which button is which, at a glance**: in the BiS> tools box the farm's skull has a **purple** edge (mobs) and the rival button a **red** edge with **crossed swords** (players) - the same colours as their crosshairs.

- **The BiS> tools box's bar looks like every other BiS> bar**: the family prompt (purple BiS>, the word, the blinking _) at BiS Healing's size and height.

## 0.5.0

- **Death recap.** When you die, a BiS window opens: the **killer** in the middle and the two biggest **assists** either side, each with their damage and share, the killing blow and its overkill; your **health** falling across the last hits, gold on crits; the **hits**, newest first; and "306 damage in 6.0 seconds". Mobs are grouped by who they really are - Forever gives a mob a new nickname on every hit. It closes when you are back in your body; `/bist recap` opens your last death again; "open when you die" in the options. Costs nothing until you die. Killed by players: their names in **class colour**, each card says what they mostly hit you with ("Arcane Shot 281"), and when more damage landed than you had health, it says you healed through some of it. **Click a player's card to make them a rival** (click again to undo) - the PvP tracker will watch for them; a rival who kills you again is counted. `/bist recap rivals` lists them, `/bist recap forget <name>` drops one.
- **Rivals drawer and tracker.** The **+** on the recap opens every rival: **gold** = hunting, **silver** = remembered and quiet; click to switch, shift-click to forget, with how often they killed you and where you last saw them. When a **gold** rival comes into sight - their nameplate, your target, your mouse - you get a raid-warning "Rival nearby: name", a sound (switch in the options) and the zone, at most once a minute each. Costs nothing while nobody is gold. A gold rival in nameplate range also gets **red rails down both sides of their body** (half the nameplate's width, centred) under the nameplate, a tick in at the middle of each, pulsing - pinned to the nameplate, so the game carries them as they move; gone with the nameplate, or when you send them to silver.
- **Rival target button.** A small button (right-drag to move) appears while you have gold rivals: one click targets one that is in range, the most recently seen first - `/target` for each, the way you would type it. `/bist recap key F6` binds it to a key; "rival target button" in the options hides it. A rival who turns gold mid-fight is added when the fight ends.
- **Crosshair styles.** "crosshair" in the options (or `/bist recap style <name>`): **rails** (the default), **L** (corner brackets), **aim** (a scope sight), **box** (an outline). A rival already on screen is redrawn at once, so you can compare.
- **Social: a thank-you for buffs.** A friendly player buffs you, out of combat: a random friendly emote at them (thank, hug, kiss, cheer, bow, salute). 2-5 minutes between emotes, never the same person twice in ten, groupmates left alone unless you ask. **Off until you switch it on**: `/bist social on`. `/bist social why` says who it saw and why.
- **Crosshair "none"**, and a "needs nameplates on" line in the options with a button that turns enemy nameplates on.
- **"stop showing this"** at the bottom of the recap: it stops opening when you die (and offers "show when I die" to bring it back); `/bist recap` still opens your last death.
- **The Tools list and Options window are 20% bigger.**
- **Fixed: the minimap icon going dark after a click** under EllesmereUI's minimap collector (its black backing was lifted over the icon); and the icon now sits where every other addon's does, above the button's backing.
- **Eight crosshairs.** Besides rails, L, aim and box: **scope** (posts, thin lines, range ticks, a dot), **drop** (a chevron over a little ladder), **chevron** and **tee**. "crosshair" in the options is a stepper now - each step redraws a rival on screen.
- **Purple crosshairs on mobs.** The mob you farm, and the mobs RestedXP's guide has on its Active Targets, wear the crosshair too - in purple (players are red). Only clean copies (alive, not tapped by someone else). Farming something else, or the guide moving on, takes the old ones down. "crosshair on the mob" in the farm options.
- **The BiS> tools box.** The farm's target button (with the skull) and the rival target button live together in one small box, each shown only when it has something to do. With BiS Healing's "BiS> now" up, the box docks beside it and moves with it - to its right, or below it when the right would cover the healing grid. Its header works like BiS> now's: **drag** it anywhere (it stays where you drop it), **shift-click** to send it round BiS> now (auto, right, below, left, top).
- **Guild rivals.** "BiS: add guild rival" on the right-click menu puts a player on the whole guild's list (everyone running BiS Tools learns it). A guild rival in sight wears an **amber** crosshair - yours stay red - and your addon tells the guild where you saw them, once a minute at most; the drawer shows them in amber with "seen 1m ago, Tarren Mill (Tyrone)". Click a guild row to make them yours, shift-click to take them off the guild's list. "guild rivals (amber)" in the options turns it off.
- **Guildmates in passing.** Alone (not in a party, raid, battleground or arena), a guildmate's nameplate gets a small teal **+** - no sound, no text. It goes the moment you group. "guildmates (+, alone)" in the options. Needs friendly nameplates on.
- **"BiS: add rival" on the right-click menu** of an enemy (or any player, a name in chat, a party or raid member): adds them as a gold rival with their class; "BiS: remove rival" when they already are one. Never in the guild roster menus. `/bist recap raw` prints exactly what the game recorded.

- Res claims (RezComm minor 4) are never sent into the chat lockdown, and a claim the game asks to retry is sent once more.

- Shared messaging library updated (LibBiSComm minor 10): after a boss, when the game lifts its chat lockdown, BiS addons say hello again so group lists stay current; it respects a realm that blocks addon messages, picks the raid channel only when the game confirms you are in a raid, and ignores anyone flooding it.

## 0.4.0

- **Lighter while you farm.** The Spawns window no longer keeps rebuilding itself after you close
  the farm window; the arrow turns 20 times a second but works out its spot 4 times a second;
  sweeping the mouse across a pack starts one scan, not one per mob.

- **Your farm spots on the minimap and the world map**, each wearing its own raid mark - bright
  when it is up, dim while it waits to respawn; hover for the mob, the kills and the time left.
  `/bist farm pins off` hides them. Drawn with HereBeDragons, the library Questie uses (BSD; see
  `Libs/THIRD-PARTY.txt`).
- **A big floating arrow, RestedXP-style,** to the spot most likely up next: what is up
  first, then what is due soonest by its learned respawn time, then the one killed longest ago.
  Its mark (or #number) and timer under it, then the distance. Drag it anywhere; it shows only
  while you farm a mob. `/bist farm arrow off` hides it.
- **RestedXP's Active Targets in the farm window**: whatever your guide step wants killed shows
  under your own kills, tagged RXP; click one to farm it. It follows the guide as it moves on.
  `/bist farm guide off` hides them. Needs RestedXP installed; without it nothing changes.
- **Nothing runs out of the windows**: the Spawns window's empty lines were too long for it. The
  test suite now measures every line of text against its window.
- **Every spot is on the map now**, not only the eight that have a raid mark: the rest are gold dots.
- **Clicking the farmed mob again clears its pins and the Spawns window**; clicking it back brings
  them back. What the spots learned is kept - the window's `r` button is what forgets a mob.
- **The farm key hands out the next mark**: skull, then cross, square and down, remembering which
  mob has which; a kill frees its mark.
- **The command is `/bist` now**, to match the family (`/bish` BiS Healing, `/bisg` BiS Guild).
  `/bt` and `/bistools` still work, so old macros keep going.

- **Runs clean on WoW Forever.** The farm tool used to hear kills through the combat log, and on
  Forever even asking for it is blocked - every login showed "BiSTools tried to call the
  protected function". On Forever it now counts kills from the game's own kill event instead.
  TBC is unchanged.
- **On WoW Forever the farm key does the marking.** Forever does not let an addon place a raid
  mark on its own (it showed as "BiSTools tried to call the protected function SetRaidTarget").
  The scanner still finds the next clean copy and tells you; your farm key then targets it and
  marks it with the game's own /tm - the spot's mark where you stand at one, the skull otherwise.
  TBC still marks automatically.
- **The summon tool is off on WoW Forever** - there are no summoning stones there. No window, no
  nag, no `/bt summon`. On TBC it is unchanged.
- All BiS addons sit under one **BiS>Addons** heading in the addon list.
- The shared comm layer sends at the pace the client allows (one message a second) and waits out
  chat lockdown, so a burst of summon traffic no longer goes missing.
- The release zip holds only files the project tracks - nothing stray can ship.

## 0.3.4

- LibBiSComm minor 6: summon API moved to C_SummonInfo on 2.5.6 — the phantom-summon filter works again.
- Summon accept hook on C_SummonInfo.

## 0.3.3

- Shared console minor 4: the blinking cursor in the `BiS>` header is its own text now, so
  the words beside it no longer shift a hair every half second.

## 0.3.2

- The farm window's header is the `BiS>` prompt now, like Summon and the Hub: `BiS> Farm_`
  cycling `farming <mob>` and `N spots`, "farming X" said in the header instead of chat. The
  skull logo and the old title are gone.
- Shared console minor 3: a slot that toggles on and off no longer gets a second (third,
  sixth) turn in the rotation. Summon's `N asking` and `summon incoming` were the ones bleeding.

## 0.3.1

- Fix: the Hub and the options window threw `attempt to call field 'Options'` for anyone
  without the BiSTheme addon installed. `Libs\BiSTheme\Options.lua` was embedded but never
  listed in the TOC, so it only ever loaded off Arn's own BiSTheme. It is in the TOC now, and
  the harness asserts the line is there.
- Options window: Escape closes it (shared kit minor 2, synced from BiSTheme).

## 0.3.0

- **Minimap button** (Arn: "the / commands are so convoluted between all the addons"). Left
  click: the **Hub** - every tool on one list; click a row to open its window (shift-click
  drags the window to the middle of the screen - "I have no idea where the farm window is
  at"), right-click a row to switch the tool on/off. Right click on the button: **Options** -
  on/off per tool, farm find-sound / spot radius / burst / prune, summon window mode / nag /
  summoner mode / interact key / at-stone yards / rows / linger, the minimap button itself, the BiS
  channel switch, and "reset window positions". Drag the button around the minimap rim.
  `/bt hub`, `/bt options`, `/bt minimap` are the slash fallbacks.

- Fix: "SUMMON from someone" raid warning when somebody ELSE got summoned. The client fires
  `CONFIRM_SUMMON` on bystanders too, with no summoner, area or clock; the nag took it as an
  offer and the lib announced a phantom OFFER to every summoner. LibBiSComm minor 5 asks the
  client whether a summon is really pending (`HasPendingSummon`) and both now stay quiet.

- Drift guard: `release.ps1` refuses to zip if an embedded lib differs from its canonical
  copy; the harness asserts the same bytes; `_bisdev\sync.ps1` pushes the canonical libs into
  every addon. A phantom OFFER from a peer still on an older lib is ignored on this side too.

## 0.2.0

- **LibBiSComm** embedded (`Libs/LibBiSComm-1.0`): the shared BiS raid channel. Just having
  BiSTools installed makes you answer "where are you" and "did the summon go through" to any
  BiS summoner, with nothing to configure. `/biscomm` shows status; `/biscomm off` is the only mute
  and is remembered across sessions.
- `summon` tool: SummonScan folded in. `/bt summon` pins the window, auto mode brings it up
  when you mouse over a summoning stone. Furthest first; click a name to target, right-click
  to skip, shift-drag to move. Raid members with any BiS addon are shown as fact (they say
  where they are and whether they accepted); everyone else is a guess with a `?`. A decline
  pops the name back to the top the second it happens.
- Summon nag: when someone summons YOU, a raid-warning line, the raid-warning sound and a
  voice line, every 20 s until you answer. Works even with the summon tool switched off;
  `/bt summon nag off` is its switch.
- **Request a summon**: the button at the bottom of the summon window (or `/bt summon me`)
  puts you on top of every BiS summoner's list marked `asks`, with a ping on their side.
  Click again to cancel; clears itself when an offer reaches you.
- Summoning stones are learned, not looked up: hover one (or a peer lands on one after
  accepting) and its position is saved and shared with the raid. "At the stone" is then a
  distance to the stone, wherever the summoner stands; the header shows `N at stone`.
- **Summoner mode** (`S` on the header, `/bt summon summoner`): you are the summoner tonight - window
  pinned, every request reaches you as a raid warning + sound + voice, wherever you are.
- Summon list order: whoever asked, then the other world (Azeroth/Outland, named in the row),
  then same world other zone (`far`), then same zone by yards, furthest first. People inside
  an instance, at the stone or next to you are hidden; `all` on the footer unrolls the whole
  raid with `inside` / `here`.
- Yards in the summon list only show while you stand at (or look at) a stone - then they are
  yards from the stone. Away from it a same-zone name shows nothing, another zone `far`.
  Raid members already inside an instance are listed last as `inside`.
- LibBiSComm minor 2: WHERE now carries the map id outdoors too, so a peer standing next to
  you no longer reads as `far`. Tools also falls back to what the client can see for peers
  still on minor 1.
- **Spam the key**: stand at the stone, mouse on the summon window, press Interact With
  Target: first press targets the top name, next press is the real interact - the stone. The
  top changes, the key targets the next one. `/bt summon key off` to disable.
- Positions stay fresh: stepping on or off a known stone pushes your position to the raid,
  and an open summon window re-asks when a name's position is older than 30 s.
- Two people at a stone: the summon window opens on every BiSTools client in the raid. Far
  from the stone it is compact - `N at the stone` and the request button; `all` unrolls the
  list. At the stone you get the full list.
- The summon window talks like a shell, in its header: the title is a `BiS> _` prompt with a
  blinking cursor that cycles what matters - `Summon`, `2 at stone` (green, you counted),
  `1 asking`, `requesting...`, `summon incoming` - and says events over it for a few seconds:
  `X asks`, `X accepted`, `X declined`, `request now`, `no summons`. Nothing of that goes to
  chat any more. The prompt is `BiSTheme.Console`, shared by every BiS window from here on
  (a copy ships in `Libs/BiSTheme/Console.lua`, so it works without BiSTheme installed).
- LibBiSComm minor 3: a client no longer listens to its own echo. The game hands every group
  addon message back to the sender; minor 2 took it and made you your own peer, so a summoner
  at the stone counted himself twice (`2 at stone` with one person there) and a requester saw
  his own `1 asking`. `N asking` now shows only to summoners (at a stone, or summoner mode).
- 25-man rehearsal (`_bisdev/comm/raid25.lua`, 41 checks; Tools harness gained a 25-man block):
  forming a raid is one HI per client; a zone line is one WHERE and never a HI; a roster tick
  that changes nobody costs nothing; only the man who joined says HI and only the people he is
  short of answer him (minor 2 had 8 people zoning into Karazhan turn into 30 HIs and every
  promote into 22); a throttled answer now waits instead of being dropped (a reload right
  after a join lost a third of the raid). Whole simulated night: ~140 messages, ~4 KB.
- **RezComm** embedded (`Libs/RezComm-1.0`, byte-identical to `_bisdev`): a BiSTools priest,
  paladin or shaman now puts rez claims on BiSInnervate's wire (`4|RCLAIM|name`, `RFREE`, `RDONE`
  on prefix `BiSInn`) the instant the cast starts, so an Innervate raid coordinates around them
  without them running Innervate. Announce-only, no rez code in Tools, stands down when Innervate
  is installed. Rebirth excluded on purpose.
- LibBiSComm minor 4: the lib's slash is `/biscomm` (`/bis` belongs to LoonBestInSlot).
- House standard: version read from the TOC (the lib announces the real one); the harness loads
  exactly what the TOC lists, in TOC order; no toggle can gate the comm lib (every one is
  flipped in the suite); `dev/theme.lua` runs the suite with a poisoned accent and caught two
  hardcoded purples in the farm titles - now `T.text("accent", ...)` like everything else.
- Pin button dropped: the window opens itself when summons are available; `/bt summon
  show|auto|hide` is the manual way. Logo dropped too - the prompt is the brand.
- Summon window header drags without shift now.
- `/bt summon peers` lists who the channel can see. `/bt summon testaccept` is a live probe
  for whether an addon may accept a summon without a click.

## 0.1.0

- `farm` (Target Farming): small Innervate-style window showing your last kill. Click it once and a 0.5s scanner
  marks every free copy nearby: the nameplate scanner deals star..cross (1-7) one per mob and
  respects marks already on them, skull is for whatever you mouse over (works from the air, never overwrites a mark);
  skips dead / in-combat / tapped. Click
  again to stop. Type any mob name in the box to farm that instead. `/bt farm key <KEY>` binds a key that
  targets the skulled mob. Voice line (FojjiCore pack or client TTS) on the first find, whisper
  ping after; `/bt farm sound first|always|off`. `/bt farm` toggles, `/bt farm clear`, `/bt farm add <name>`.
- `farm` lock: once you are farming a mob, kills of anything else do not swap the row; the
  farmed mob keeps counting. Click it again to unlock and the last-kill tracker resumes.
- `farm` spawn timers, two levels: a **zone** is where a cluster lives (radius = the option,
  default 20 yd, `/bt farm radius 5-60`) and owns one raid mark for good from the first kill
  there. Its **spots** (radius 35% of the zone) sit indented under it on the shelf; each gets a
  mark while you are in the zone - the zone's own first, then marks no zone owns - and gives
  it back when you leave. Skull is never used; it is the cursor's. A kill is matched by the
  mark the mob died wearing first, then by distance, then to the nearest zone with a spot that
  is up. Kills within 60 s of each other at one spot (`/bt farm burst 5-300`) are
  different mobs and get their own spots, as is a kill on a spot still counting down. Up to 16
  zones and 12 spots each; past 7 marks they show as numbers. A spot that sits up for 10 min
  with no kill folds into its neighbour (`/bt farm prune 60-3600|off`). A second kill at a spot teaches its respawn; 15 s before it is due the mark is called
  out. `t` on the header (or `/bt farm spots`) opens the shelf: arrow from where you stand,
  mark, countdown, yards; a zone's timer is its soonest spot; the zone you stand in is tinted. `r` resets this mob; `/bt farm
  spots clear` wipes every mob.
- Skeleton: tool registry, `/bt` dispatcher, per-tool saved settings, BiSTheme palette with fallback.
