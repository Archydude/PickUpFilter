# PickUp Filter

Auto loot that leaves the junk behind. Loot as usual: PickUp Filter picks up what's worth having and leaves the rest on the corpse, then closes the loot window (or leaves it open, if you'd rather). You decide what counts as worth having, by item quality and price, with your own lists of items to always or never pick up.

Made for WoW Forever.

## Getting started

PickUp Filter does the auto looting itself, so the game's own **Auto Loot** has to be off: with it on, the game takes everything first. The first time you log in with it on, PickUp Filter asks whether to turn it off. The options page shows a button for it too.

Then just loot. **Hold Shift while looting to take everything**, junk included (that's the game's own Auto Loot key, so it follows your key bindings).

Works with **TradeSkillMaster** and **Auctionator** for auction prices. Without them, the vendor price is used.

## Profiles

A profile is a whole filter: the rules table, prices, other rules and both item lists. Each character uses one profile, and characters can share one, so a change to a shared profile reaches every character on it. New characters start on **Default**.

At the top of the options page:
- **This character uses** picks this character's profile.
- **New** makes a profile with the default filter, **Copy** makes a copy of the current one, and both switch this character to it.
- **Rename** renames the profile for every character using it.
- **Delete** deletes it after asking. Characters using it switch to Default (or to another profile when Default is the one being deleted). Your last profile can't be deleted.

Below them, the page lists the other characters using the same profile.

Whether the filter is on, and the minimap button, aren't part of a profile: on/off is set for each character, and the minimap button for your whole account.

## Rules by quality

The options page (`/puf`) has a table with a row for each item quality: Poor, Common, Uncommon, Rare, Epic, and Legendary and up. Each row has:

| Column | Choices |
|---|---|
| Action | **Check value**, **Always pick up** or **Never pick up** |
| Price | **Vendor price**, **Priority order** or **Highest price** (for Check value) |
| Single item | What an item that doesn't stack has to be worth to be picked up |
| Whole stack | What the whole drop of an item that stacks has to be worth: 5 of an item worth 30c each are worth 1s 50c |

Amounts are typed like `1g 20s 5c`, `50s` or `25c`. Clear a box to put it back to the default filter's amount.

The default filter:

| Quality | Action | Price | Single item | Whole stack |
|---|---|---|---|---|
| Poor (grey) | Check value | Vendor price | 1s | 1s |
| Common (white) | Check value | Priority order | 1s | 1s |
| Uncommon and better | Always pick up | | | |

**Reset to default filter** puts the table back to this. Your item lists and other rules stay as they are.

## Prices

- **Vendor price:** what a vendor pays.
- **Priority order:** the first source with a price for the item, in the order you set. The default is TSM, then Auctionator, then vendor price. Set a place to Nothing to skip it.
- **Highest price:** the highest of TSM, Auctionator and vendor price.
- **TSM price:** market value (default), lowest auction right now, historical price, or region market average.

TSM and Auctionator count only while they're loaded. The options page says which ones are.

## Other rules

| Rule | Choices | Default |
|---|---|---|
| Quest items | Always pick up, or follow the quality rules | Always pick up |
| Currencies | Always pick up, or leave behind | Always pick up |
| Items with no price | Pick up, or leave behind (for Check value) | Pick up |
| Most valuable first | On or off | On |
| Loot window afterwards | Close it, so the rest stays on the corpse, or leave it open so you can still take something yourself | Close it |
| Say what was left behind | On or off: a chat line after looting lists what stayed behind and its value | Off |

Money is always picked up.

With **Most valuable first**, the most valuable items go into your bags first, so when they fill up, what's left behind is the cheap stuff. When something you wanted doesn't fit, the loot window stays open so you can make room and take it.

## Item lists

**Always pick up** and **Never pick up** lists win over every other rule, quest items included. To add an item, start typing its name: items in your bags that match show up under the box, so click one, or pick it with Up and Down and press Enter. You can also type an item ID or Shift-click an item into the box and press Enter, or drag an item from your bags onto the box. Each row shows the item and its ID, with a button to take it off. An item can only be on one list.

## Commands

- `/puf` opens the options (also Esc > Options > AddOns > PickUp Filter). `/pickupfilter` works too.
- `/puf on` and `/puf off` turn the filter on and off. When it's off, everything is picked up.
- `/puf always <item>`, `/puf never <item>`, `/puf remove <item>`: add an item to a list or take it off. Use an item ID or a Shift-clicked link.
- `/puf list` shows both lists.
- `/puf check [count] <item>` says whether the item would be picked up, and why: `/puf check 20 [Linen Cloth]`.
- `/puf profile` shows your profiles and which one this character uses. `/puf profile <name>` switches to another one.
- `/puf minimap` shows or hides the minimap button.

The minimap button's tooltip shows whether the filter is on and which profile this character uses. The button opens the options on click and turns the filter on or off on right-click. Minimap button collectors pick it up, and it's in the addon menu on the minimap too.

## License

MIT, see [LICENSE](LICENSE).
