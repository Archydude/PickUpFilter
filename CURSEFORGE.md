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
Auto loot that leaves the junk behind. Pick up only what's worth having, by item quality and vendor, TSM or Auctionator price, with your own always and never lists.
```

**Main category:** `Bags & Inventory`
**Additional categories:** `Auction & Economy`

**License:** `MIT License`

**Logo / avatar:** `PickUpFilter\images\logo-v2.png`

**Description** (paste everything between the lines)

---
```markdown
## Auto loot, without the junk

WoW Forever drops a lot of junk. PickUp Filter loots for you and takes only what's worth having. The rest stays on the corpse, so your bags stay clean.

### Rules by quality
One row for each item quality, from grey to Legendary:
- **Always pick up**, **never pick up**, or pick up when it's **worth at least** an amount you set, like `1s` or `2g 50s`.
- Stackables count as a full stack: one linen at 30c, in stacks of 20, is worth 6s.
- Each quality picks its price: the **vendor price**, a **priority order** of TSM, Auctionator and vendor price, or the **highest** of them.

Out of the box, grey and white items need to be worth 1s, or 5s for a full stack, and green and better are always picked up.

### Always picked up
- **Gathering is never filtered:** herbs, ore, fish, skins, chests and lockboxes come in whole.
- **Appearances you haven't collected**, even on grey gear.
- **Crafting reagents** too, if you like.
- **What All The Things says you need**, when you have it: anything missing from your collection or needed to get something.

### Your own lists
**Always pick up** and **Never pick up** lists win over every other rule. Add items by typing part of their name.

### Profiles
Each character uses a whole filter of its own, or shares one with your other characters.

### More choices
- Quest items, currencies and unpriced items get their own rules.
- The most valuable items go into your bags first, so full bags leave the cheap stuff behind.
- Leave the loot window open after looting if you'd rather pick through what's left.
- An optional chat line lists what was left behind.
- **Hold Shift** while looting to take everything.

### Good to know
- PickUp Filter does the auto looting itself, so the game's own Auto Loot has to be off. It offers to turn it off for you.
- Works with **TradeSkillMaster**, **Auctionator** and **All The Things**. Without them, vendor prices are used.
- **/puf** opens the options. **/puf check [item]** says whether an item would be picked up, and why.
- Made for **WoW Forever**.

**Feedback and bug reports are welcome** in the comments.
```
---

**Source / Issues links:** `https://github.com/Archydude/PickUpFilter` and `https://github.com/Archydude/PickUpFilter/issues`

## B. Upload File form

**File:** `dist\PickUpFilter-1.4.0.zip`

**Display name**
```
PickUp Filter 1.4.0
```

**Release type:** `Release`

**Game versions:** Forever `1.60.1`.

**Changelog** (paste only the newest part; paste older parts too if they never went up)
```markdown
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
