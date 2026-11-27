# PickUp Filter: CurseForge upload sheet

What to type into each CurseForge field, ready to copy and paste. The steps for a first upload and for releasing an update are in [UPLOADING.md](../UPLOADING.md).

Update this sheet with every release: the zip, the display name and the changelog, and rewrite the description so it covers everything in the new version.

## A. Project form

**Project name**
```
PickUp Filter
```

**Summary**
```
Auto loot that leaves the junk behind. Pick up only what's worth having, by item quality and vendor, TSM, Auctionator or Craftonomics price, with your own always and never lists.
```

**Main category:** `Bags & Inventory`
**Additional categories:** `Auction & Economy`

**License:** `MIT License`

**Logo / avatar:** `PickUpFilter\images\logo-v2.png`

**Description** (paste everything between the lines)

---
```markdown
## Auto loot, without the junk

Mobs drop a lot of junk. PickUp Filter loots for you and takes only what's worth having. The rest stays on the corpse, so your bags stay clean.

### Rules by quality
One row per item quality, from grey to Legendary:
- **Always pick up**, **never pick up**, or pick up when **worth at least** an amount you set (`1s`, `2g 50s`).
- Judge stackables as a **Full stack** (30c linen in stacks of 20 counts as 6s) or **Per item**.
- Price by **vendor**, a **priority order** of TSM, Auctionator, Craftonomics and vendor, or the **highest**.

Defaults: grey and white items need 1s (5s for a full stack); green and better are always picked up.

### Always picked up
- **Gathering is never filtered:** herbs, ore, fish, skins, lockboxes, and beasts (when Skinning) come in whole.
- **Uncollected appearances**, even on grey gear.
- **Crafting reagents:** take all, or only the ones your checked professions craft with.
- **What All The Things says you need**, if you use it.

### Your own lists
**Always pick up** and **Never pick up** lists override every rule. Search any item in the game by name, even ones you've never had, or view each list in its own window.

### Profiles
Each character uses its own filter, or shares one across characters.

### More choices
- Separate rules for quest items, currencies and unpriced items.
- Picks up the most valuable items first, so full bags leave the cheap stuff behind.
- Leave the loot window open afterwards if you want to take something yourself.
- Optional chat line listing what stayed behind.
- **Hold Shift** while looting to take everything.

### Good to know
- The game's Auto Loot has to be off; PickUp Filter offers to turn it off.
- Works with **TradeSkillMaster**, **Auctionator**, **Craftonomics** and **All The Things** (else vendor prices).
- **/puf** opens options; **/puf check [item]** explains why an item is kept or left.
- Made for **WoW Forever** and **Retail**.

This addon was made with AI.

**Feedback, suggestions, and bug reports are welcome** in the comments or by sending me a message on Discord.
```
---

**Source / Issues links:** `https://github.com/Archydude/PickUpFilter` and `https://github.com/Archydude/PickUpFilter/issues`

## B. Upload File form

**File:** `dist\PickUpFilter-1.7.3.zip`

**Display name**
```
PickUp Filter 1.7.3
```

**Release type:** `Release`

**Game versions:** Retail `12.1.5`, Forever `1.60.1`.

**Changelog** (paste only the newest part; paste older parts too if they never went up)
```markdown
1.7.3
- **Quest items: Always pick up** now also picks up regular items needed to finish an active quest objective (like Okra for Westfall Stew), sums the required amount when multiple active quests need the same item, and stops once you have enough.

1.7.2
- Fixed: **Always pick up appearances you haven't collected** no longer picks up gear whose appearance your account already collected from another item when your current character can't equip that weapon or armor type.

1.7.1
- World chests are now filtered normally instead of being picked up whole under **Take everything when gathering** (lockboxes and other items you open are still taken whole).
- With **Take everything when gathering** on and **Skinning** learned, Beast corpses are now looted whole so you can skin them right away (other mobs in an AoE loot stay filtered).

1.7.0
- **Full stack or Per item:** choose whether stackable items under **Check value** are judged by what a full stack is worth (using **Whole stack**) or by what each individual item is worth (using **Single item**).
- **Crafting reagents by profession:** **Crafting reagents** under **Other rules** can now follow the quality rules, always pick up all crafting reagents, or always pick up only the ones your character's professions craft with — with checkboxes to leave individual professions out (such as Cooking).
- **Retail support:** PickUp Filter now also supports World of Warcraft Retail alongside WoW Forever.

1.6.1
- Fixed: AoE looting a mob alongside a chest or gathering node no longer bypasses your filter for the whole pull, and Pick Pocket loot is filtered normally.
- Fixed: you can click with an item on your cursor to drop it into the Always pick up or Never pick up boxes, and a character's profile resolves reliably at login.
- Fixed: removed the unused count argument from `/puf check`.

1.6.0
- **Craftonomics prices:** PickUp Filter can now price loot with **Craftonomics** (including Craftonomics' own auction house scans), in your priority order or highest-price mode.
- Fixed: only real gathering actions (herbalism, mining, skinning, fishing, opening, pick pocket and disenchanting) count as gathering loot, so casting an attack while looting a mob no longer bypasses your filter.
- Fixed: Uncommon and better items set to **Always pick up** are now looted most valuable first when bags are nearly full.
- Fixed: items whose details haven't loaded yet wait briefly before falling back to your unpriced-item rule, and editing your item lists no longer causes redundant redraws.

1.5.2
- Fixed: characters were saved under their first name only, so characters with the same first name on a realm shared one profile choice and one on/off setting. Each character now has its own, starting from what it shared before.
- Fixed: when the game didn't give the realm's name at login, a character could run on the Default profile for that session. It now keeps its own profile and on/off setting.

1.5.1
- Fixed an error when opening the options during combat ("tried to call the protected function 'OpenSettingsPanel()'"). The options now open as soon as the fight ends.

1.5.0
- The Always pick up and Never pick up boxes now find any item in the game, not just what's in your bags, so you can list things you've never had. Matches from your bags come first, and the list of matches scrolls.
- Item lists have a window of their own: the options page shows how many items each list has, and **Open list** shows the whole list, however long. Find items in it by name or ID, move one to the other list with the arrow button, take one off with the X, or empty the list with **Remove all**.

1.4.0
- Items that stack are now judged by what a full stack would be worth, however many dropped: one cloth worth 30c that stacks to 20 counts as 6s. The default **Whole stack** amount is now 5s, and rules still on the old 1s default move to 5s.
- New TSM price: **Region sale average**, what an item actually sells for across your region.
- The "left behind" chat line and `/puf check` now say which price they used, like "TSM market value" or "vendor price".

1.3.0
- New option under Other rules: always pick up what **All The Things** says you need. Items it counts as missing from your collection, or needed for something you haven't collected yet, are picked up whatever their quality or price, following your All The Things settings. On from the start; it does nothing without All The Things.

1.2.0
- New option under Other rules: always pick up crafting reagents, like cloth, herbs, leather and ore, whatever their quality or price. Your Never pick up list still wins. Off from the start.

1.1.0
- Take everything when gathering: herbs, ore, fishing and skinning are picked up whole, and so are chests, lockboxes and other things you open. On from the start; turn it off under Other rules.
- Gear with an appearance you haven't collected yet is always picked up, whatever its quality or price. Also on from the start, under Other rules.

1.0.0
- First release: auto loot that leaves the junk behind. Loot as usual and only what passes your rules goes into your bags. The rest stays on the corpse and the loot window closes, or stays open if you'd rather take something yourself.
- A rules table with one row per item quality: always pick up, never pick up, or pick up when the item is worth at least an amount. Items that don't stack and the whole drop of items that stack each get their own amount.
- Each quality picks its price: vendor price, a priority order of TSM, Auctionator and vendor price, or the highest of the three.
- The default filter picks up grey items the vendor pays at least 1s for, white items worth at least 1s, and everything Uncommon and better. **Reset to default filter** brings it back.
- Always pick up and Never pick up lists. Type part of an item's name to pick it from your bags, or type an item ID, Shift-click an item or drag one from your bags. The lists win over every other rule.
- Profiles: each character uses a whole filter of its own or shares one with your other characters. Make, copy, rename and delete them on the options page, or switch with `/puf profile`.
- Choose what happens to quest items, currencies and items no one has a price for.
- The most valuable items are picked up first, so full bags leave the cheap stuff behind. When something you wanted doesn't fit, the loot window stays open.
- Hold Shift while looting to take everything.
- `/puf check` with an item link says whether it would be picked up, and why.
- An optional chat line lists what was left behind and what it was worth.
```
