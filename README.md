<p align="center">
<img width="390" height="332" alt="tooltip_plus_logo" src="https://github.com/user-attachments/assets/26aea1cb-98ef-40a7-89a9-18551717389c" />
</p>
# Tooltip Plus

**Everything about an item, right in its tooltip.** For World of Warcraft 3.3.5a (Wrath of the Lich King).

Version 1.7.1 · by Saranwrap

Hover any item and Tooltip Plus tells you where it comes from, what it is used for and how many your characters have, without leaving the game.

- **Where to get it**: vendors, quest rewards, crafting, mob drops with the drop chance, chests and gathering nodes, containers, disenchanting, prospecting, milling, skinning, pickpocketing and fishing.
- **Professions**: which professions use a material, the reagents and skill colours of a crafted item, and which of your characters know a recipe or can learn it.
- **Your characters**: how many of the item each of your characters has, and where (bags, bank, equipped, mailbox, currencies), plus your guild banks.
- **Sell price, stack size and item ID.**
- **One window** (minimap button) with every recipe of every profession, and everything your characters own, both searchable.

---

## Installation

1. Close the game.
2. Click **Code → Download ZIP** and extract it into `<WoW folder>\Interface\AddOns\`.
3. Keep the folder name `Tooltip-Plus-main`: the addon loads from it.
4. Start the game. After an update, restart the game completely: new files are not loaded by `/reload`.

---

## In the tooltip

The information has its own block at the bottom of the tooltip, under the heading **Tooltip Plus:**

| Line | What it shows |
| --- | --- |
| **Vendor** | Who sells it, where, Alliance / Horde only (A / H), the price in gold, badges, honor or arena points, limited stock |
| **Quest** | The quest that rewards it, its level and where it starts |
| **Crafted** | The profession, skill colours `[250 290 305 320]` (orange / yellow / green / grey), the reagents, and which of your characters know the recipe or can learn it |
| **Drop** | The mobs that drop it, the place and mode (Normal, Heroic, 10, 25, 10 HC, 25 HC) and the drop chance per kill. Bosses and rare mobs are coloured; dungeon and raid trash is grouped under `[Ulduar [25]] - trash mobs` |
| **Object** | Chests, caches, herbs, ore veins… and the chance per opening |
| **Contained in** | Bags, boxes and caches that contain it |
| **Disenchanting, Prospecting, Milling** | What it comes from, with the chance |
| **Skinning, Pickpocket, Fishing** | Mobs or fishing zones, with the chance |
| **Teaches** | On a recipe: what it teaches, and which of your characters know it, can learn it now, or later |
| **Used in** | On a material: the professions that use it (number of recipes) and which of your characters know a recipe that uses it |
| **Sells for** | The vendor price |
| **ID / Count** | The item ID, the stack size, and how many all your characters have, then one line per character: `Bags: 24` or `90 (Bags: 24, Bank: 66)` |

Lines look like `Object: [Ulduar [25]] - Rare Cache of Winter   18%`: the place and mode first, then the source.

Tags after a source:

- **(Hallow's End)**, **(Brewfest)**… only during that world event
- **(quest)**: drops only while you are on the quest
- **(hard mode)**: drops only in hard mode
- **A / H**: Alliance / Horde only

When an item has many sources, the main ones are listed first, followed by "… and N more". An empty line closes the block, so the lines of other addons stay apart.

---

## The window

Open it with the minimap button or `/tplus recipes`. Tabs in the title bar: **Recipes**, **Items** and **Settings**.

### Recipes

Every recipe of every profession.

- Filter by profession, search a recipe or reagent name (or shift-click an item into the search box), and show all recipes, the ones this character knows, can learn now, or later, the ones another character knows, or the ones none of your characters know.
- Recipe names are in this character's skill colour (red: skill too low, dark grey: not one of its professions). A tick marks the recipes it knows.
- The right side shows the skill colours, how many it makes, the reagents with how many you have, where the recipe is learned (trainer, with the profession, or the recipe item and where to get it) and which of your characters know it or can learn it.
- Hover a recipe or a reagent for its full tooltip. Shift-click links it in chat.

**Shift + right-click a material** in your bags, your bank, a chat link or the window: the window opens with every recipe that uses it, the ones you know first. A crafted item opens its recipe.

### Items

Everything your characters on this realm have, and your guild banks, in one list.

- Search by name and filter by character or guild bank.
- Hover an item to see who has it and where. Shift-click links it, Ctrl-click tries it on.
- The gold of all your characters is shown at the top right (hover it for each character).

---

## Your characters

Log on each character once so it is remembered. Some things are read when you open them:

- **Bank, mailbox, guild bank**: when you open them (each guild bank tab when you look at it).
- **Recipes known**: when the character opens each of its profession windows.

`/tplus forget <name>` removes a character you deleted. The minimap button tooltip shows the gold of every character.

---

## Settings

Open them with `/tplus`, a right-click on the minimap button, or **Escape → Interface → AddOns → Tooltip Plus**.

- Show item sources, only while holding Shift, compact (hide zones), "… and N more" lines
- Item ID, stack size, sell price
- Count of all your characters, one line per character
- Used in, recipes known / can learn, reagents of crafted items, Shift + right-click to open recipes
- Minimap button
- Which sources to show

The **Escape → Interface → AddOns** page also has every command as a button: open the window, look up an item, and forget a character.

---

## Commands

| Command | |
| --- | --- |
| `/tplus` | Settings (`/tooltipplus` works too) |
| `/tplus recipes` | Recipes |
| `/tplus items` | Items of your characters |
| `/tplus gold` | Gold of your characters, in chat |
| `/tplus on` / `off` | Turn the item sources on or off |
| `/tplus <item ID>` | Print an item's sources in chat |
| `/tplus minimap` | Show or hide the minimap button |
| `/tplus chars` | Characters remembered on this realm |
| `/tplus forget <name>` | Forget a deleted character |
| `/tplus help` | List the commands |

---

## About the data

Sources, prices and drop chances come from the AzerothCore world database (the core ChromieCraft runs on) and the 3.3.5a game files. A server can change some of its data, so treat the drop chances as a guide.
