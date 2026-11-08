# BiSTools/dev/codexdata.py - writes Tools/CodexData.lua (BiS> Codex's shipped index) out of BiS Shell's ADVENT cast.
#
#     python dev/codexdata.py            (from the addon root; BiSShell must sit beside BiSTools)
#
# Arn, 8 Nov 2026: "nothing scraped from websites to keep it lean ... Index already". So the Codex ships IDS ONLY plus
# our own short words: which creatures (npc id + model id) stand in which dungeon, grouped into volumes. Every NAME
# comes live from the game (the tooltip trick, CODEX-RESEARCH.md probe 1), every spell text from the client's own
# spell data. The cast is the 120 ADVENT foes in BiSShell/Games/AdventCast.lua; the dungeons' titles, places and
# levels come from the ADVENT world files beside it; boss or not from each room's `foe = { boss = true`.
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.join(HERE, '..', '..', 'BiSShell', 'Games')
OUT = os.path.join(HERE, '..', 'Tools', 'CodexData.lua')
WORLD = ['AdventWorld.lua', 'AdventDungeons.lua', 'AdventCrawls.lua', 'AdventForever.lua']

# THE MOLTEN CORE has no W.Dungeon block (its rooms are hand-built in AdventWorld.lua): Volume II, Raids.
RAIDS = {'mc': {'title': 'THE MOLTEN CORE', 'name': 'the Molten Core', 'where': 'Blackrock Mountain', 'level': 60}}

# OUR OWN SHORT WORDS, one line a dungeon (the page's opening paragraph). Forever's own dungeons get no lore we cannot
# stand behind - only where they are.
ABOUT = {
    'rfc': "A cavern of fire under Orgrimmar. Troggs dig up from below, the Searing Blade cult meets in its halls, "
           "and a demon waits in the deepest pit.",
    'thanes': "The Alliance's first dungeon on Forever, under Dun Morogh. Its plates show ADVENT's cast for it, "
              "until the hall's own are met.",
    'dm': "Under Moonbrook in Westfall, the Defias Brotherhood builds a warship in an old goblin mine.",
    'wc': "Caves under the Barrens where the druid Naralex dreams, and his disciples have turned to serpents.",
    'sfk': "Archmage Arugal's keep in Silverpine Forest, overrun by the worgen he called.",
    'bfd': "A flooded temple on the Ashenvale coast, held by naga and the Twilight's Hammer.",
    'brd': "The Dark Iron dwarves' city in the heart of Blackrock Mountain, ruled by Emperor Thaurissan.",
    'gnomer': "The gnomes' lost city under Dun Morogh, poisoned and overrun, with Mekgineer Thermaplugg at its core.",
    'rfk': "The quilboar's warren of thorns in the southern Barrens.",
    'sm': "The Scarlet Crusade's monastery in Tirisfal Glades: a graveyard, a library, an armory and a cathedral.",
    'rfd': "The quilboar's burial mounds, taken by the Scourge and the lich Amnennar.",
    'ulda': "A titan vault in the Badlands, dug open by the Dark Iron dwarves and guarded by stone.",
    'zf': "The Sandfury trolls' walled city in the Tanaris desert.",
    'mara': "The centaur's holy caverns in Desolace, where Princess Theradras poisons the land.",
    'st': "The sunken temple of Atal'Hakkar in the Swamp of Sorrows, where trolls call on Hakkar.",
    'lbrs': "The orc and ogre halls of the lower spire, high in Blackrock Mountain.",
    'ubrs': "The upper spire: Rend Blackhand's hall and General Drakkisath's black dragonflight.",
    'dire': "The ruined highborne city of Eldre'Thalas in Feralas, its north wing held by the Gordok ogres.",
    'strat': "The fallen city in the Eastern Plaguelands, split between the Scarlet Crusade and Baron Rivendare.",
    'scholo': "The Barovs' crypt-school on Caer Darrow, where Darkmaster Gandling teaches necromancy.",
    'mc': "The fire lord Ragnaros's realm at the root of Blackrock Mountain, kept by his lieutenants.",
}
FOREVER_ABOUT = "One of WoW Forever's own dungeons, in %s."

# ABILITIES WE SHIP: only where the spell id is CONFIRMED to be that creature's. A creature without a row here shows
# what the Codex has SEEN it cast (learned live), or says it has not seen any. Sources:
#   live  = asked of the Forever client 8 Nov 2026 (CODEX-RESEARCH.md probe 6: 11970 "Fire Nova" + its text)
#   name  = the client's own spell name says whose it is (SpellName, Forever 1.60.1.70862, read 8 Nov 2026)
#   arn   = in Arn's brief for the Codex, 8 Nov 2026 (Taragaman's Uppercut beside his Fire Nova)
SPELLS = {
    11520: ([11970, 18072], 'live (11970 Fire Nova) + arn (18072 Uppercut)'),   # Taragaman the Hungerer
    11502: ([20566], 'name: 20566 "Wrath of Ragnaros"'),                         # Ragnaros
    12118: ([19703], 'name: 19703 "Lucifron\'s Curse"'),                         # Lucifron
    12259: ([19716], 'name: 19716 "Gehennas\' Curse"'),                          # Gehennas
    12264: ([19713, 23138], 'name: 19713 "Shazzrah\'s Curse", 23138 "Gate of Shazzrah"'),   # Shazzrah
}

CAST_LINE = re.compile(r'^\s*\["(\w+)"\]\s*=\s*\{\s*npc\s*=\s*(\d+)(?:\s*,\s*display\s*=\s*(\d+))?.*?\}\s*,\s*--\s*(\w+)')
GROUP_LINE = re.compile(r'^\s*--\s*(\w+)\b')   # "-- rfc", "-- drowned (not open ...)"; other words are notes
_UNUSED = (r'')   # "-- rfc", "-- drowned (not open ...)"; other words are notes


def read(name):
    with open(os.path.join(SHELL, name), encoding='utf-8') as fh:
        return fh.read()


def credits():
    """AdventCast.lua's CREDITS block, word for word (Arn asked for these)."""
    src = read('AdventCast.lua')
    m = re.search(r'\n(\s*CREDITS \(Arn asked for these\):.*?)\n\]\]', src, re.S)
    if not m:
        sys.exit('codexdata: no CREDITS block in AdventCast.lua')
    return m.group(1)


def dungeons():
    """id -> {title, name, where, level, boss = {room index or 'boss'/'trash': bool}} from the world files."""
    out, order = {}, []
    for f in WORLD:
        cur, room = None, 0
        for line in read(f).splitlines():
            m = re.search(r'\bid = "(\w+)",.*?title = "([^"]+)", name = "([^"]+)"', line)
            if m:
                cur = {'title': m.group(2), 'name': m.group(3), 'boss': {}, 'small': 'side =' in line}
                out[m.group(1)] = cur
                order.append(m.group(1))
                room = 0
            if cur is None:
                continue
            w = re.search(r'where = "([^"]+)"', line)
            if w and 'where' not in cur:
                cur['where'] = w.group(1)
            lv = re.search(r'\blevel = (\d+)', line)
            if lv and 'level' not in cur:
                cur['level'] = int(lv.group(1))
            if re.match(r'^    \{ name = "', line):
                room += 1
            if 'foe = { boss = true' in line and room:
                cur['boss'][room] = True
    for d in out.values():
        if 'where' not in d or 'level' not in d:
            sys.exit('codexdata: a dungeon without where/level: %r' % d)
    return out, order


def cast(known):
    """[(group, room key, npc, display or None, source)] in AdventCast.lua's order."""
    rows, group = [], None
    src = read('AdventCast.lua')
    body = src[src.index('foes = {'):src.index('music = {')]
    for line in body.splitlines():
        g = GROUP_LINE.match(line)
        if g:
            if g.group(1) in known:
                group = g.group(1)
            continue
        m = CAST_LINE.match(line)
        if m:
            rows.append((group, m.group(1), int(m.group(2)), m.group(3) and int(m.group(3)), m.group(4)))
    return rows


def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    world, order = dungeons()
    world.update({k: dict(v, boss={}, small=False) for k, v in RAIDS.items()})
    rows = cast(world)
    if len(rows) != 120:
        sys.exit('codexdata: expected the 120 ADVENT foes, read %d' % len(rows))
    lists, creatures = {}, {}
    for group, key, npc, display, srcmark in rows:
        if group not in world:
            sys.exit('codexdata: foe %s in an unknown dungeon %r' % (key, group))
        d = world[group]
        if group in RAIDS:
            boss = True
        elif d['small']:
            boss = key.endswith('_boss')
        else:
            n = int(key.rsplit('_', 1)[1])
            boss = bool(d['boss'].get(n))
        if npc in creatures:
            print('codexdata: npc %d is in %s and %s - kept the first' % (npc, creatures[npc]['d'], group))
            continue
        creatures[npc] = {'d': group, 'display': display, 'boss': boss, 'src': srcmark}
        lists.setdefault(group, []).append(npc)
    vol1 = [k for k in order if k in lists]
    vol1.sort(key=lambda k: (world[k]['level'], order.index(k)))
    vol2 = [k for k in RAIDS if k in lists]

    out = []
    out.append('-- BiSTools / Tools / CodexData.lua - BiS> Codex\'s shipped index. GENERATED by dev/codexdata.py from')
    out.append('-- BiSShell/Games/AdventCast.lua (the 120 ADVENT foes) and the ADVENT world files - edit those, then run')
    out.append('-- `python dev/codexdata.py`. Never edit this file by hand.')
    out.append('--')
    out.append('-- IDS ONLY, and our own short words (Arn, 8 Nov 2026: "nothing scraped from websites to keep it lean"). Every')
    out.append('-- creature\'s NAME comes live from the game (C_TooltipInfo.GetHyperlink, second ask - CODEX-RESEARCH.md),')
    out.append('-- every spell\'s name and text from the client\'s own spell data. Every id here is UNVERIFIED on Forever until it')
    out.append('-- draws (or names itself) in game.')
    out.append('--   volumes[i]   = { id, numeral, title, list = { dungeon ids } }')
    out.append('--   dungeons[id] = { title, name, where, level, about (our words), list = { npc ids, in room order } }')
    out.append('--   creatures[npc] = { d = dungeon id, display = model id (nil: ask by npc), boss = true, spells = { ids } }')
    out.append('--')
    out.append('-- The same credits as BiSShell/Games/AdventCast.lua, word for word:')
    out.append('--[[')
    out.append(credits())
    out.append('  The Codex\'s spell ids: see each line\'s comment (live = asked of the Forever client, name = the client\'s')
    out.append('  own spell name says whose it is, arn = Arn\'s brief), 8 Nov 2026.')
    out.append(']]')
    out.append('local _, NS = ...')
    out.append('NS.CodexData = {')
    out.append('  volumes = {')
    out.append('    { id = "dungeons", numeral = "I", title = "DUNGEONS", list = { %s } },' % ', '.join(lua_str(k) for k in vol1))
    out.append('    { id = "raids", numeral = "II", title = "RAIDS", list = { %s } },' % ', '.join(lua_str(k) for k in vol2))
    out.append('  },')
    out.append('  dungeons = {')
    for k in vol1 + vol2:
        d = world[k]
        about = ABOUT.get(k) or (FOREVER_ABOUT % d['where'])
        out.append('    %s = { title = %s, name = %s, where = %s, level = %d,' % (
            k, lua_str(d['title']), lua_str(d['name'][:1].upper() + d['name'][1:]), lua_str(d['where']), d['level']))
        out.append('      about = %s,' % lua_str(about))
        out.append('      list = { %s } },' % ', '.join(str(n) for n in lists[k]))
    out.append('  },')
    out.append('  creatures = {')
    for k in vol1 + vol2:
        out.append('    -- %s' % k)
        for npc in lists[k]:
            c = creatures[npc]
            parts = ['d = %s' % lua_str(k)]
            if c['display']:
                parts.append('display = %d' % c['display'])
            if c['boss']:
                parts.append('boss = true')
            note = c['src']
            if npc in SPELLS:
                ids, why = SPELLS[npc]
                parts.append('spells = { %s }' % ', '.join(str(i) for i in ids))
                note += '; spells: ' + why
            out.append('    [%d] = { %s }, -- %s' % (npc, ', '.join(parts), note))
    out.append('  },')
    out.append('}')
    with open(OUT, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('\n'.join(out) + '\n')
    print('codexdata: %d creatures, %d dungeons (+%d raids) -> %s' % (len(creatures), len(vol1), len(vol2),
                                                                    os.path.normpath(OUT)))


if __name__ == '__main__':
    main()
