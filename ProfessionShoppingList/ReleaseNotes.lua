local _, ns = ...

-- Newest first. Add an entry here with every change.
ns.RELEASE_NOTES = {
    {
        version = "v0.25 - Beta", date = "2026-10-13",
        added = {
            "Leveling guide: 'Check for updates' button. Compares the guides with your game version and with the real recipes in your profession windows, and lists any recipe whose reagents changed.",
            "The addon now remembers each recipe's reagents when you open a profession window (used by the guide check).",
        },
    },
    {
        version = "v0.24 - Beta", date = "2026-10-13",
        added = {
            "Leveling guide: 'Your professions' shows a skill bar for each of your professions (current / max skill), read from your character. Click a bar to open that profession's guide.",
        },
    },
    {
        version = "v0.23 - Beta", date = "2026-10-12",
        added = {
            "Vertical scrollbars on the right of every scrolling area (materials list and grid, shopping list, notes, release notes, leveling guide). They only appear when there is more to scroll.",
        },
        changed = {
            "Settings: special thanks now go to Seeme | Pilanatesta.",
        },
    },
    {
        version = "v0.22 - Beta", date = "2026-10-12",
        changed = {
            "Leveling guide window now resizes to fit each guide: the grey box grows with the steps and materials, and the bottom part (guide note, source, buttons) keeps a fixed layout.",
        },
        fixed = {
            "Long guide notes (e.g. Cooking) overlapped the estimated cost.",
        },
    },
    {
        version = "v0.21 - Beta", date = "2026-10-12",
        changed = {
            "Settings: credits sit right under the opacity slider (no more empty space) and the window fits its content.",
            "Settings: more space between the credit lines; special thanks now reads 'Special thanks to Zneko | Kney for their feedback'.",
        },
    },
    {
        version = "v0.20 - Beta", date = "2026-10-12",
        added = {
            "Credits at the bottom of the Settings window: author and special thanks.",
        },
    },
    {
        version = "v0.19 - Beta", date = "2026-10-12",
        added = {
            "Leveling guides for Alchemy (1-290), Blacksmithing (1-225), Cooking (1-300), Enchanting (1-300), Engineering (1-300), First Aid (1-300) and Tailoring (1-225). Source: wow-professions.com.",
            "Guides with two ways to level (Alchemy, Enchanting, First Aid, Leatherworking) pick the cheaper route automatically once prices are scanned.",
            "Tailoring plans craft all the bolts the later steps need from cloth, matching the guide's cloth totals.",
        },
        changed = {
            "Profession grid shows each guide's skill range (e.g. '1 to 225') in yellow instead of 'Available'.",
            "Herbalism, Mining, Skinning and Fishing stay 'Coming soon'.",
        },
    },
    {
        version = "v0.18 - Beta", date = "2026-10-12",
        added = {
            "Notes: a faded hint while the notes are empty. Christmas lists welcome.",
        },
    },
    {
        version = "v0.17 - Beta", date = "2026-10-12",
        added = {
            "Leveling guide opens on a grid of all professions. Leatherworking is available; the others are placeholders marked 'Coming soon'.",
            "'< Back' button in a guide returns to the profession grid.",
        },
        changed = {
            "Leveling guide tab uses a generic book icon instead of the profession's icon.",
            "The leveling guide no longer follows the profession picked in the main window - you choose it in the grid.",
        },
        fixed = {
            "The three buttons in the 'add additional items' popup are now centred.",
        },
    },
    {
        version = "v0.16 - Beta", date = "2026-10-12",
        added = {
            "Leveling guide: pressing 'Add to list' when your shopping list already has items asks first - 'Add more', 'Clear current shopping list' (replaces it with the guide's materials) or 'Cancel'.",
        },
    },
    {
        version = "v0.15 - Beta", date = "2026-10-12",
        changed = {
            "Leveling guide: steps and materials are laid out in columns - craft count and quantity in one column, price in another.",
            "Leveling guide: vendor items are tagged 'vendor' after their name, like in the materials list.",
            "Leveling guide tab shows the selected profession's icon.",
        },
        fixed = {
            "Leveling guide tab icon was blank in WoW Forever.",
        },
    },
    {
        version = "v0.14 - Beta", date = "2026-10-12",
        added = {
            "Leveling guide: 'Share list' button. Type a player's name and the steps + materials are whispered to them.",
            "Leveling guide: clicking 'wow-professions.com' opens a box with the link, plus 'Copy URL' and 'Close'.",
        },
        changed = {
            "Side tabs reordered: Leveling guide, Notes, Settings.",
            "Release notes tab moved to the bottom of the window's right edge.",
            "Leveling guide icon changed to a map.",
            "Leveling guide: the route is chosen automatically (the cheapest once everything is priced), so the 'Route' picker is gone.",
            "Leveling guide: 'Estimated cost' is pinned to the bottom of the dark box.",
        },
        removed = {
            "Leveling guide: URL text field (replaced by the clickable site name).",
            "Leveling guide: 'Replace list' button.",
        },
    },
    {
        version = "v0.13 - Beta", date = "2026-10-12",
        added = {
            "Leveling guide tab (scroll icon, or /psl guide). Pick a skill range (e.g. 1-75) and a route, see the steps, the materials to buy and the estimated cost.",
            "'Add to list' and 'Replace list' put the plan's materials straight into your shopping list.",
            "Items made by earlier steps in the chosen range are subtracted automatically (e.g. Cured Light Hide made at 30-55 is used later).",
            "Leatherworking route 1-225 for WoW Forever, with or without Heavy Hide. Source: wow-professions.com.",
        },
    },
    {
        version = "v0.12 - Beta", date = "2026-10-12",
        changed = {
            "Minimize button is now the same size and style as the X close button.",
            "Settings, Notes and Release notes moved from the title bar to tabs on the right edge of the window (same icons, spellbook-style tabs). A tab stays highlighted while its window is open.",
            "Side windows open just past the tabs so they don't cover them.",
        },
    },
    {
        version = "v0.11 - Beta", date = "2026-10-12",
        added = {
            "'Clear' button in the Notes window, with the confirmation 'Clear the Notes text?' (Yes / No).",
        },
    },
    {
        version = "v0.10 - Beta", date = "2026-10-12",
        changed = {
            "'Subtract what I already own' is aligned on the same line as 'Last scan'.",
            "Total, You have and After buying now sit in their own dark box, with a separator line above it like the one between materials and the shopping list.",
        },
    },
    {
        version = "v0.9 - Beta", date = "2026-10-12",
        changed = {
            "'Last scan' now sits under the Scan list and Clear list buttons, still inside the shopping list box.",
            "Total, You have and After buying are properly centred in the space under the shopping list.",
        },
    },
    {
        version = "v0.8 - Beta", date = "2026-10-12",
        changed = {
            "Shopping list column headers (Have, Qty, Each, Total) are now inside the dark box.",
            "'Shopping List' subtitle sits above the box with some space, and reads: Shopping List (type a quantity, alt-click to search the Auction House).",
            "Empty shopping list now says: Click materials from the list above, or drag items from your bag to here.",
            "'Last scan' moved inside the shopping list box, bottom right, on one line.",
            "Item count moved into the box's header row.",
            "Total, You have and After buying are centred between the shopping list and the bottom of the window.",
        },
        fixed = {
            "Collapsed window showed stretched, broken border art. It is now a clean rectangle.",
        },
    },
    {
        version = "v0.7 - Beta", date = "2026-10-12",
        changed = {
            "'Scan list' moved into the shopping list area, to the left of 'Clear list'.",
            "'Subtract what I already own' moved into the shopping list area, at the bottom.",
            "Settings, Notes and Release notes always open beside the window: on the right, or on the left when the window is near the right edge of the screen.",
            "Several open side windows stack under each other instead of overlapping.",
        },
    },
    {
        version = "v0.6 - Beta", date = "2026-10-12",
        added = {
            "'Clear list' button at the bottom-right of the shopping list, with a confirmation.",
            "Vendor items always use the vendor price (learned the first time you open that vendor).",
            "Coin icon next to vendor prices once the item has been scanned on the AH. Green: AH is cheaper. Red: AH costs more. Hover for the exact difference.",
        },
        changed = {
            "Materials list is only for picking materials: no prices or owned counts shown there.",
            "Vendor prices show in blue in the 'Each' column.",
        },
        removed = {
            "'Clear' button in the footer (replaced by 'Clear list').",
            "Prices on the right side of the materials list.",
        },
    },
    {
        version = "v0.5 - Beta", date = "2026-10-12",
        added = {
            "Release notes button in the title bar (and /psl release).",
            "Author line at the bottom of the window.",
            "Settings: toggle to allow resizing the window (beta).",
            "5-second cooldown on Scan list, with the countdown shown on the button.",
            "Live 'last scan' timer that counts seconds, then minutes, hours and days.",
            "\"You have\" line under the total.",
        },
        changed = {
            "Total shows as 00g 00s 00c with the amount in white (red if you can't afford it).",
            "\"You have\" and \"After buying\" are larger and easier to read.",
            "More space between the text and the window edges.",
        },
        fixed = {
            "Title, settings, notes and collapse buttons were hidden behind the window border.",
            "Resize grip could be hidden behind the window border.",
            "'Last scan' showed 'just now' instead of the time since the scan.",
        },
    },
    {
        version = "v0.4 - Beta", date = "2026-10-12",
        added = {
            "Window uses the modern Blizzard frame style (same as the auction house).",
            "Window attaches to the right side of the auction house when it opens.",
            "Side collapse: shrink the window into a thin tab facing the auction house.",
            "Materials source filter: All, Vendor, Drop / gathered, Crafted.",
            "Learns vendor items (and their price) from vendor windows, and crafted items from profession windows.",
            "Separator line between materials and the shopping list.",
            "Resizable window from the bottom-right corner.",
            "Grid view for materials: large icons with the name underneath, with an icon size slider.",
            "Settings: 'Attach to the auction house' toggle.",
        },
    },
    {
        version = "v0.3 - Beta", date = "2026-10-12",
        changed = {
            "Renamed to Marisco's Profession Shopping List.",
            "Version shown next to the window title and in the minimap tooltip.",
        },
    },
    {
        version = "v0.2", date = "2026-10-12",
        added = {
            "Minimap button (left-click open, right-click settings, drag to move).",
            "Collapse button to shrink the window to its title bar.",
            "Notes window for free text, saved automatically.",
            "Settings window: open with the auction house, background opacity, minimap button.",
            "Red X on each shopping list line to remove it.",
            "Quantity box on each line to type how many you want.",
            "'Have' column and '(have N)' in the materials list showing what you own.",
            "Total turns red when it's more than the gold you carry.",
            "'After buying' line showing the gold you'd have left.",
            "Date of the last Scan list.",
            "Scan list prices the whole list in one request (modern auction house).",
        },
        changed = {
            "'Open with the auction house' moved to the settings window.",
        },
        removed = {
            "Clicking shopping list rows no longer changes quantities (use the quantity box).",
            "Support for the classic-style auction house (WoW Forever uses the modern one).",
        },
    },
    {
        version = "v0.1", date = "2026-10-12",
        added = {
            "Profession picker with dropdown and < > cycling.",
            "Materials listed alphabetically per profession, with a search box.",
            "Click materials to add them to a saved shopping list.",
            "Movable window that remembers its position.",
            "Prices update automatically from your auction house searches.",
            "Scan list button and a running total of the cost.",
            "Learns new materials from your open profession window.",
            "Drag items from your bags onto the window to add them.",
            "'Subtract what I already own' option.",
            "Slash commands: /psl, /psl add, /psl scan, /psl clear, /psl reset, /psl learn.",
        },
    },
}
