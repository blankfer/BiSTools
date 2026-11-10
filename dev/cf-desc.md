# BiS Tools — CurseForge page text (1.1.0)

Paste everything below the line into the project description
(CurseForge → BiS Tools, project 1686340 → Edit → Description), in the Markdown editor.

First public text 12 Oct 2026 (0.5.0); rewritten 14 Oct for 0.7.0 - battlegrounds, pals, surname
crowns. In the house voice (`_bisdev/docs/voice.md`): the opener and "Why it works" talk; tables
and lists stay flat.

**Deliberately NOT on the page: summon** (Forever has no summoning stones, the tool does not load
there). The threat beta and the pup finder were retired on 9 Nov. The page is for Forever.

Changed for 1.1.0 (9 Nov): two new sections before "Farm" - **BiS> bosses** (the boss finder) and
**BiS> Codex** (the book, and after dark full screen) - their commands in the table, and the opener's
bold line names them. Pictures for the gallery: `C:\Users\arnol\Pictures\BiS-CF\2026-11-09\tools-*.jpg`.

Changed in the text before (8 Nov, 1.0.0 - Forever 1.0): "Settings" rewritten - a new install starts with
every tool off (existing players keep theirs), the options dashboard (Esc > Options > AddOns > BiS> > BiS> Tools),
and the minimap button (right-click again closes the options). Rivals: the ping and the guildmate crest start off on
a new install, each with its own tick - the "you hear it" and crest lines say so.

---

# BiS Tools

**Your XP buffs in one stop, your disenchanting in one window, every boss in a dungeon marked, a picture book of every creature, what killed you, who to watch for, who heals them, and what to farm. For WoW Forever.**

You're dead, and you never saw it coming. BiS Tools opens the game's own record of the hits that killed you: who landed the last one, who helped, with what, and how fast. Click a player on that screen and they're your rival. The next time they walk into view, you'll know.

## XP buffs, while you level

Stop to eat, and BiS Tools has the whole stop ready. When an XP buff needs you, its button comes into the BiS> tools box, glowing, and one click does it:

- **Camp Tent first.** Your rested XP under 5% of a level, the tent off cooldown and its hour-long debuff off you: put it down (a campfire nearby).
- **Then the Cozy Sleeping Bag.** Well-Rested gone, short of its 3 stacks, or under 10 minutes left.
- **Then your XP food.** Well Fed gone or under 2 minutes left. Any cooked food that gives the experience bonus will do, with nothing to set up; the one you last ate goes first. Vendor food is never picked.
- **One stop for both.** Eat on the bag and you get both buffs at once. So when it's time to eat and Well-Rested would run low before your next meal, the bag comes too, and the other way round.
- **Out of combat only, nothing at level 60.** No timer ticking: it looks when your buffs, bags or rested XP change. `/bist xp` says where everything stands.

## Disenchanting, like a cockpit

`/bist proc` (or the button in the BiS> tools box, in town, or on your profession window) opens one page with every piece of gear you can disenchant. Built like a flight display: simple, high contrast, everything on it has a job.

- **A skill tape** down the left: your enchanting skill boxed, a red-and-black pole above it for what you can't reach yet, a mark for each skill your items need, a gold bracket where the game asked for a rod.
- **One row per item**, its name in its quality's colour, a Disenchant button on the right. A plain click for gear that isn't soulbound; soulbound takes Shift-click.
- **Never the wrong item.** Each row is one exact item. Just before the click it checks the item is still in that slot; if your bags moved, nothing is destroyed and the list refreshes. Enchanted gear says ENCHANTED, and two items of one name where one differs get a SAME NAME warning. Right-click hides an item you carry on purpose. Alt-click is never touched, so roll-out addons keep it.
- **What you got:** this session's dust and essences in a strip, and **the hoard** (ALL TIME): everything you've ever disenchanted piled up in a little cave with you on top. Empty, you sit on the floor; at the top you flex on your mountain.
- **The glow:** hold Alt over your bags (any bag addon) and gear you can disenchant glows purple, soulbound gear red.

## Death recap

When you die, a small window opens on the faces of whoever did it.

- **The killer in the middle, the two biggest helpers either side, in 3D.** A player still nearby shows as themselves, gear and all. Under each: what they hit you with (the killer: the killing blow, "Fireball 312 +40"), their damage and their share.
- **Details, one click away:** your health falling across those seconds (gold where a hit was a crit), physical or magic, and the last ten hits newest first, with a total: "306 damage in 6.0 seconds".
- **Players in their class colour.** Mobs are grouped by who they really are. Forever gives a mob a new nickname on every hit; the recap knows it was one Molten Elemental, not three.
- **It closes when you're back in your body.** `/bist recap` opens your last death again.

## Rivals

Click a player on your recap, or right-click an enemy player and pick **BiS: add rival**. They're gold now: hunted.

- **They walk into view, you know it.** A warning in the middle of your screen, and where you are. Once a minute at most. Tick "sound when a rival is near" and a ping comes with it.
- **A crosshair on their body**, pinned under their nameplate, pulsing. Eight shapes to pick from, or none. It needs enemy nameplates on; the options have a button for that.
- **One button targets them**, even across the map. It sits in the BiS> tools box and takes a key if you want one.
- **Enemies only.** A friend can't be a rival, and a "Terry Lin" on your list never marks a "Terry Daviss": whole names and player IDs are checked.
- **In a battleground**, the right-click menu can't carry the line, so a red **+** in the tools box adds your target. A rival you add there is for that match only. Kill you ten times and they're kept for good.

## Pals

Right-click a friendly player and pick **BiS: add pal**. A small green heart sits over them, out of combat, so you find your people in a crowd. `/bist pal` on your target does the same in a battleground.

## A whole surname

Forever lets a guild share a surname. `/bist surname Foreverpvp` puts a small **gold crown** over everyone wearing it: enemies any time, friends out of combat. One call-out a minute for the whole surname, not one per player. The same again turns it off.

## Battlegrounds: their healers, and their killer

Forever hides the scoreboard's numbers from addons mid-match. It still sorts by them. BiS Tools reads the order, and their **top three healers** wear **white crossed sabers**, their **top killer red ones**, glowing on the body.

- **One click targets one of them**, the nearest first, from a saber button in the tools box. A **BiS> mark** button under the scoreboard reads it on demand.
- **It remembers.** A healer from last match is marked the moment they show up in the next one.
- **It never touches your scoreboard while you're reading it**, and stays quiet the first 90 seconds, while everyone is still at zero.
- **Five looks** (X, saber, arrow, diamond, corners), with size and height in the options.

## Guild rivals

Right-click a player and pick **BiS: add guild rival**, and every guildmate running BiS Tools learns them. A guild rival wears an **amber** crosshair, so you know the call came from someone else. When anyone sees one, the guild's lists say where, and who saw them. No sound.

## Guildmates in passing

Tick "guildmates" in the options and, out in the world on your own, a guildmate gets a small teal **guild crest** under their nameplate. Nothing else: no sound, no text. Join a party, a raid or a battleground and it's gone.

## A thank-you for buffs

A stranger buffs you on the road and you're mid-pull, or just didn't notice. Switch on `/bist social on` and BiS Tools does it for you: a random friendly emote at them, a thank or a hug or a bow. Two to five minutes between emotes, never the same person twice in ten, never in a fight, and your group left alone. It's off until you turn it on.

## BiS> bosses: every boss in the place, marked

Walk into a dungeon or raid and its boss list comes up, in the game's own order, each with the raid mark it will get: skull first, then cross, square, moon.

- **Click a boss** to target it and mark it. Shift-click pings it for your party too. If the boss isn't nearby, nothing changes and you keep your target.
- **MARK ALL** marks every boss it can find. **FIND** goes one at a time, the ones in sight first: targeted, marked and pinged. `/bist bosses key F7` puts FIND on a key.
- **A cockpit to watch it on:** a needle that climbs as bosses go down, a strip with one light per boss (green down, gold in sight, purple marked), and the boss in 3D over a synthwave sunset.
- **It stays put.** A boss is ticked off when its fight ends and the mark passes to the next. In a fight the window fades almost away and clicks go straight through it. Escape leaves it alone (you press Escape all run); die, release or hearth out and it's back when you walk in.
- **Every dungeon and raid on Forever:** 43 places, 335 bosses, from the game's own data. Fights of several, like The Seven, are listed and ticked off but never targeted.

## BiS> Codex: a picture book of every creature

`/bist codex` opens a two-page book inside a cockpit panel. Contents by volume (Dungeons, Raids), each dungeon's plate of its creatures in 3D, and a page for every creature: its model (turn it, make it stand, attack, cast or fall), a data plate (level, type, rank, where it lives, how often you've met it), its abilities in the game's own words, and what you've seen it drop. An A to Z index and a search cover the lot.

- **Every boss is in it**, every dungeon on Forever and the Molten Core.
- **It learns as you play.** Every creature you target joins the book with its level, the spells you see it cast and the loot you take from it, dungeon creatures included.
- **Everything comes from your game.** BiS Tools ships only the creatures' numbers; the names, words and models are your client's own.

**After dark.** Press FULL (or `/bist codex full`) and you're behind the wheel at night: the creature stands in your headlights on a wet road, its name in pink over the city like an opening title. Drag it to turn it. The rear-view mirror is the page you read before, the sun visor holds what it drops like tickets (shift-click to link one), the gauges count levels and meetings, the radio's tuning band is the A to Z, and the road atlas on the seat is the dungeon's route. Turn the key to close. It fits any screen and steps aside the moment a fight starts.

## Farm

Type a mob's name, kill one, or right-click it and pick **BiS: track in farm**.

- **The skull, on a fresh copy.** One key press targets a live one nobody else has tagged and marks it.
- **A purple crosshair on every live copy** in view, so you can see the next one coming.
- **Spawn timers.** Where you killed it, and when it's back. On the minimap, on the world map, and as a big arrow pointing at the next one up.
- **RestedXP's targets.** If you run RestedXP, the mobs your guide step wants show in the farm window and wear the purple crosshair too.

## Zeppelins, boats and the tram

At a zeppelin tower, a boat dock or a Deeprun Tram platform, a small card pops up while your ride waits: the zeppelin master or dockhand in 3D, calling **"All aboard for Grom'gol - we lift off in 0:58!"**. It hides again when the ride leaves.

- **Your guild's clock.** Anyone with any BiS addon who rides once times that route for the whole guild. The card's last line says who timed it and how sure the countdown still is: **100% sure** just after a ride, lower with every lap since, 0% after six hours (a server restart resets every ride).
- **RIDE-TRAK.** Shift-click the card and each ride gets a little line map under its announcer: here on the left, where it goes on the right, the ride a gold block moving between them - and your own face on it once you're aboard. The tram shows both of its cars.
- **Close it for good** with the X; `/bist rides on` brings it back.

## Sound explorer

Every sound the game has a name for, in one list you can search. Type a word (`bell`, `click`, `chime`) or an id, click a row, hear it.

- **Hold your own sound up against the game's.** Play any .ogg from your AddOns folder, then click through the game's until you find the one that sounds like it.
- **Any id**, even the ones the list doesn't name.
- **Star the good ones** with a shift-click; `/bist sounds favs` lists them with their ids.
- **On the sound-effects channel**, so muting effects mutes it. Nothing runs until you open it.

## The BiS> tools box

The farm's skull, the rival target button, the XP buff buttons, and in battlegrounds the red **+** and the saber button sit together in one small box. Each shows only when it has something to do. With BiS Healing's "BiS> now" on screen, the box docks beside it.

## Settings

**A quiet start.** A new install starts with every tool off: no sounds, no windows opening by themselves, nothing on your screen until you ask for it. Switch on the ones you want. The tools you switch on start quiet too: the farm window waits for a click instead of opening at every login, and the rival ping and the guildmate crest each have their own tick. Already using BiS Tools? Nothing changes for you: every tool and setting stays as you had it.

**One dashboard for every tool.** Esc > Options > AddOns > **BiS>** > **BiS> Tools**: every tool down the left with its lamp, the one you pick big on the right, with an ON/OFF switch, what it does in full words, a button to its window and all its settings. Point at anything and the strip along the bottom says what it does.

**The minimap button:** left-click for the tools, right-click for the options window (right-click again closes it), drag to move it. Or type:

| command | does |
|---|---|
| `/bist` | the list of tools |
| `/bist recap` | your last death |
| `/bist rival` · `/bist rivals` | add your target as a rival · list them |
| `/bist pal` · `/bist pals` | add your target as a pal · list them |
| `/bist surname <word>` | crown everyone with that surname (again: off) |
| `/bist recap forget <name>` | drop a rival |
| `/bist recap key F6` | a key that targets a gold rival - `off` to drop it |
| `/bist recap style scope` | the crosshair: rails, L, aim, box, scope, drop, chevron, tee, none |
| `/bist bg mark` · `why` · `clear` | battlegrounds: read the board now · what it saw · forget everyone |
| `/bist social on` · `off` · `group` · `why` | the thank-you emote for buffs |
| `/bist bosses` · `/bist bosses key F7` | the boss finder · FIND on a key |
| `/bist codex` · `/bist codex full` · `/bist codex <name>` | the Codex · after dark · look one up |
| `/bist farm` | the farm window |
| `/bist farm key F5` | the skull key |
| `/bist sounds` · `/bist sounds favs` | the sound explorer · your starred sounds |
| `/bist xp` · `/bist xp tent off` · `/bist xp bag off` | where your XP buffs stand · drop a button |
| `/bist proc` · `/bist off de` | the disenchanting page · the Alt glow off |
| `/bist on <tool>` · `/bist off <tool>` | switch a tool on or off |

## Why it works the way it does

Forever closed the combat log to addons. So this one never asks for it. The death recap is the game's own record, the one Blizzard keeps for its recap screen, read to the last number in a dungeon, mid-fight, before a line of the window was written.

The battleground marks work the same way. The numbers are hidden. The order isn't. So it reads the order.

The rest watches nameplates. When one appears, a name is read and compared. With nobody to watch for, a city full of players costs nothing.

When the game won't say, it says so. It does not guess.
