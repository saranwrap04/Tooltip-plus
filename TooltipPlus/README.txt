TOOLTIP PLUS v1.10.2
Everything about an item, right in its tooltip. For World of Warcraft 3.3.5a.
By Saranwrap

Hover any item and Tooltip Plus tells you where it comes from, what it is used for and
how many your characters have, without leaving the game:
  - Where to get it: vendors, quest rewards, crafting, mob drops with the drop chance,
    chests and gathering nodes, containers, disenchanting, prospecting, milling, skinning,
    pickpocketing and fishing.
  - Professions: which professions use a material, the reagents and skill colours of a
    crafted item, and which of your characters know a recipe or can learn it.
  - Your characters: how many of the item each of your characters has, and where (bags,
    bank, equipped, mailbox, currencies), plus your guild banks.
  - Sell price, stack size, item ID and item level.
  - Tooltip look: position (game default, at the mouse, or a spot you choose), flat look,
    scale, font, colours, borders in class / reaction / item quality colour.
  - Units: class colours, guild rank, level, target, who in your group targets it,
    talents of players, NPC ID, and health and mana bars in the tooltip.
  - Item stats: ratings as % at your level, what primary stats give your class, and a stat
    summary with the change against the item you wear.
  - Links: spell, quest and achievement IDs, and the icon beside links clicked in chat.
  - One window (minimap button) with every recipe of every profession, and everything your
    characters own, both searchable.


INSTALL
  1. Close the game.
  2. Copy the "TooltipPlus" folder into <WoW folder>\Interface\AddOns\ and keep its name:
     the addon loads from it.
  3. Start the game.

  UPDATING
    Close the game and DELETE THE OLD "TooltipPlus" FOLDER COMPLETELY, then copy in the new
    one. Also delete any "Tooltip-Plus-main" folder from an older download, so only one copy
    is installed. Copying over the old folder can keep old files (images in particular),
    and the game only loads new files after a full restart, not after /reload.


IN THE TOOLTIP
  The information has its own block at the bottom of the tooltip, under "Tooltip Plus:".
  Vendor          who sells it, where, A / H (Alliance / Horde only), price in gold, badges,
                  honor or arena points, limited stock
  Quest           the quest that rewards it, its level and where it starts
  Crafted         the profession, skill colours [250 290 305 320] (orange / yellow / green /
                  grey), the reagents, and which of your characters know the recipe or can
                  learn it
  Drop            the mobs that drop it, the place and mode (Normal, Heroic, 10, 25, 10 HC,
                  25 HC) and the drop chance per kill. Bosses and rare mobs are coloured;
                  dungeon and raid trash is grouped under "[Ulduar [25]] - trash mobs"
  Object          chests, caches, herbs, ore veins... and the chance per opening
  Contained in    bags, boxes and caches that contain it
  Disenchanting, Prospecting, Milling   what it comes from, with the chance
  Skinning, Pickpocket, Fishing         mobs or fishing zones, with the chance
  Teaches         on a recipe: what it teaches, and which of your characters know it, can
                  learn it now, or later
  Used in         on a material: the professions that use it (number of recipes) and which
                  of your characters know a recipe that uses it
  Sells for       the vendor price
  ID / Count      the item ID, the stack size and how many all your characters have, then
                  one line per character: "Bags: 24" or "90 (Bags: 24, Bank: 66)"

  Lines look like:  Object: [Ulduar [25]] - Rare Cache of Winter      18%
  Tags after a source:
    (Hallow's End)  only during that world event
    (quest)         drops only while you are on the quest
    (hard mode)     drops only in hard mode
    A / H           Alliance / Horde only
  The main sources are listed first, followed by "... and N more". An empty line closes the
  block, so the lines of other addons stay apart.


THE WINDOW  (minimap button, or /tplus recipes)
  Tabs in the title bar: Recipes, Items and Settings.

  Recipes: every recipe of every profession.
  - Filter by profession, search a recipe or reagent name (or shift-click an item into the
    box), and show all recipes, the ones this character knows, can learn now, or later, the
    ones another character knows, or the ones none of your characters know.
  - Names are in this character's skill colour (red: skill too low, dark grey: not one of
    its professions). A tick marks the recipes it knows.
  - Right side: skill colours, how many it makes, the reagents with how many you have, where
    the recipe is learned (trainer, recipe item, quest or discovery) and which of your
    characters know it or can learn it.
  - Under the reagents: every raw material, with crafted reagents broken down (bars to ore,
    bolts to cloth, inks to pigments), as icons with how many you need and have.
  - Click a reagent or a material icon: the recipes that use it (or make it).
  - Hover a recipe or a reagent for its full tooltip. Shift-click links it in chat.
  - Shift + right-click a material (bags, bank, chat link or the window): the window opens
    with every recipe that uses it, the ones you know first. A crafted item opens its recipe.

  Items: everything your characters on this realm have, and your guild banks, in one list.
  - Search by name, filter by character or guild bank.
  - Hover an item: who has it and where. Shift-click: link. Ctrl-click: try on.
  - The gold of all your characters at the top right (hover it for each character).


YOUR CHARACTERS
  Log on each character once so it is remembered.
  - Bank, mailbox, guild bank: read when you open them (each guild bank tab when you look
    at it).
  - Recipes known: read when the character opens each of its profession windows.
  /tplus forget <name> removes a character you deleted. The minimap button tooltip shows
  the gold of every character.


SETTINGS  (/tplus, minimap right-click, or Escape > Interface > AddOns > Tooltip Plus)
  A side bar of categories on the left, the options on the right. Hover an option for
  what it does.

  Item info
  - General: show item sources, only while holding Shift (the tooltip says "Hold Shift"
    and fills in as soon as you press it), minimap button, the commands.
  - Item sources: compact (hide zones), "... and N more" lines, which sources to show.
  - Item details: item ID, stack size, sell price, count of all your characters, one line
    per character.
  - Professions: used in, recipes known / can learn, reagents, Shift + right-click to open
    recipes.

  Tooltip look  (/tplus look)  -  with a live preview of a player, an NPC or an item
  - Position: units and objects in the world, and frames and bars (unit frames, action
    bars, anything using the game's default spot), each at the game default, at the mouse
    or at your anchor point. At the mouse: which side, X / Y offset. "Move anchor point"
    shows a box to drag (right-click it when done); the tooltip grows away from the
    nearest screen corner. The preview shows where each kind of tooltip opens.
  - Appearance: flat look, scale, font, font size, background (with opacity) and border
    colours.
  - Units: player names in class colour, <AFK> / <DND>, guild with rank, coloured level,
    race and class (Elite / Rare / Boss), hide the faction and PvP lines, target of the
    unit, targeted by (your group), talents of players, NPC ID, border in class / reaction
    colour.
    Targeted by: how many of your party or raid target the unit, and who (up to 6 names).
    The game only tells it for your group, so it shows while you are in a party or raid.
    Talents: the main tree and the points, e.g. Holy (51/20/0), read when you hover a
    player within inspect range (about 28 yards) and remembered for 5 minutes.
  - Health bars: health bar, mana / rage / energy bar, numbers on the bars. Health of mobs
    outside your group is only known as a percentage on 3.3.5.
  - Items and links: border in item quality colour, item level of gear, spell / quest /
    achievement IDs, icon beside links clicked in chat.
  - Item stats:
    Ratings as %: each rating with what it gives at your level, e.g.
      +32 Critical Strike Rating (0.70% crit)
    What primary stats give: Strength -> attack power (and block value for warriors,
    paladins and shamans), Agility -> crit, armor (and attack power for rogues, hunters
    and shamans), Stamina -> health, Intellect -> mana and spell crit. Crit from agility
    and intellect is shown at level 80.
    Stat summary: under gear, one line per stat as your class uses it (health, mana, mana
    regen, attack or spell power, armor, crit, hit, haste, expertise, armor penetration,
    defense, dodge, parry, block, resilience), e.g.
      Spell Haste(%)        1.19 (-0.43)
    Change against what you wear: in brackets, what you gain (green) or lose (red) against
    the item in that slot; rings, trinkets and one-hand weapons: against both of yours
    (first / second). It uses the base stats of the items, without gems and enchants.
    Item level is not added when the tooltip already shows one.

  The Escape > Interface > AddOns page also has every command as a button.


COMMANDS
  /tplus                 settings (/tooltipplus works too)
  /tplus look            tooltip look settings
  /tplus recipes         recipes
  /tplus items           items of your characters
  /tplus gold            gold of your characters, in chat
  /tplus on | off        turn the item sources on / off
  /tplus <item ID>       print an item's sources in chat
  /tplus minimap         show / hide the minimap button
  /tplus chars           characters remembered on this realm
  /tplus forget <name>   forget a deleted character
  /tplus help            list the commands


ABOUT THE DATA
  Sources, prices and drop chances come from the AzerothCore world database (the core
  ChromieCraft runs on) and the 3.3.5a game files. A server can change some of its data,
  so treat the drop chances as a guide.
