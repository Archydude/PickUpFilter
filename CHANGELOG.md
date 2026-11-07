# Changelog

## 1.0.0
- First release: auto loot that leaves the junk behind. Loot as usual and only what passes your rules goes into your bags. The rest stays on the corpse and the loot window closes.
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
