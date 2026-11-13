# Changelog

## 1.5.1
- Fixed an error when opening the options during combat ("tried to call the protected function 'OpenSettingsPanel()'"). The options now open as soon as the fight ends.

## 1.5.0
- The Always pick up and Never pick up boxes now find any item in the game, not just what's in your bags, so you can list things you've never had. Matches from your bags come first, and the list of matches scrolls.
- Item lists have a window of their own: the options page shows how many items each list has, and **Open list** shows the whole list, however long. Find items in it by name or ID, move one to the other list with the arrow button, take one off with the X, or empty the list with **Remove all**.

## 1.4.0
- Items that stack are now judged by what a full stack would be worth, however many dropped: one cloth worth 30c that stacks to 20 counts as 6s. The default **Whole stack** amount is now 5s, and rules still on the old 1s default move to 5s.
- New TSM price: **Region sale average**, what an item actually sells for across your region.
- The "left behind" chat line and `/puf check` now say which price they used, like "TSM market value" or "vendor price".

## 1.3.0
- New option under Other rules: always pick up what **All The Things** says you need. Items it counts as missing from your collection, or needed for something you haven't collected yet, are picked up whatever their quality or price, following your All The Things settings. On from the start; it does nothing without All The Things.

## 1.2.0
- New option under Other rules: always pick up crafting reagents, like cloth, herbs, leather and ore, whatever their quality or price. Your Never pick up list still wins. Off from the start.

## 1.1.0
- Take everything when gathering: herbs, ore, fishing and skinning are picked up whole, and so are chests, lockboxes and other things you open. On from the start; turn it off under Other rules.
- Gear with an appearance you haven't collected yet is always picked up, whatever its quality or price. Also on from the start, under Other rules.

## 1.0.0
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
