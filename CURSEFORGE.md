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
- Items that don't stack and the whole drop of items that stack each get their own amount: 5 linen worth 30c each counts as 1s 50c.
- Each quality picks its price: the **vendor price**, a **priority order** of TSM, Auctionator and vendor price, or the **highest** of them.

Out of the box, grey and white items need to be worth 1s, and green and better are always picked up.

### Gathering and appearances
- **Gathering is never filtered:** herbs, ore, fishing and skinning are picked up whole, and so are chests and lockboxes.
- **Appearances you haven't collected** are always picked up, even on grey gear.

### Your own lists
**Always pick up** and **Never pick up** lists win over every other rule. Start typing an item's name and pick it from your bags, or Shift-click or drag it in.

### Profiles
Each character uses a whole filter of its own, or shares one with your other characters.

### More choices
- Quest items, currencies and items no one has a price for each get their own rule.
- The most valuable items go into your bags first, so full bags leave the cheap stuff behind.
- Leave the loot window open after looting if you'd rather pick through what's left.
- An optional chat line lists what was left behind.
- **Hold Shift** while looting to take everything.

### Good to know
- PickUp Filter does the auto looting itself, so the game's own Auto Loot has to be off. It offers to turn it off for you.
- Works with **TradeSkillMaster** and **Auctionator**. Without them, vendor prices are used.
- **/puf** opens the options. **/puf check [item]** says whether an item would be picked up, and why.
- Made for **WoW Forever**.

**Feedback and bug reports are welcome** in the comments.
```
---

**Source / Issues links:** `https://github.com/Archydude/PickUpFilter` and `https://github.com/Archydude/PickUpFilter/issues`

## B. Upload File form

**File:** `dist\PickUpFilter-1.1.0.zip`

**Display name**
```
PickUp Filter 1.1.0
```

**Release type:** `Release`

**Game versions:** Forever `1.60.1`.

**Changelog** (paste only the newest part; paste older parts too if they never went up)
```markdown
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
