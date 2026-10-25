# xigear

A Windower 4 addon for [xi-gear.com](https://xi-gear.com), the FFXI gear planner. It saves a character's gear, storage slips, merits, job points and master levels to one file, which you import on xi-gear's Characters page. "Find best set" and the WS calculator then use what you actually have.

**It never connects to the internet.** It only writes a file to your own computer. It's one short file, [`xigear/xigear.lua`](xigear/xigear.lua), so you can check that yourself.

## What's in the file

Only this, for the character you're logged in as:

- Character name, server and race
- Every item in your inventory, wardrobes and Mog House bags (safe, storage, locker, satchel, sack, case), with each item's augments and rank
- The items stored on your storage slips
- Your merits
- Job points spent on each job, and master levels

## Install

1. On this page, click the green **Code** button, then **Download ZIP**.
2. Open the zip. Inside `xigear-main` there's a folder called `xigear`. Drag that folder into `Windower4/addons/`, so you have `Windower4/addons/xigear/xigear.lua`.
3. In game: `//lua load xigear`

To update later, download again and replace the `xigear` folder.

Add `lua load xigear` to `Windower4/scripts/init.txt` to load it every time.

## Use

1. In game, type `//xigear`. It writes `xigear_<name>_<date>_<time>.json` to `Windower4/addons/xigear/data/`.
2. On xi-gear.com, open **Characters**, click **Import** on that character, and pick the file.

Do it again whenever your gear changes. Each character has its own file.

**Master levels** come from information the game sends when you log in or zone. If you load the addon partway through a session and it says they weren't loaded, zone once and save again.

## Credits

The bag list and the way augments and ranks are read come from [invdump](https://github.com/Masin-M/invdump) by Masin-M (BSD license, notice kept in `xigear/xigear.lua` and in [LICENSE](LICENSE)). Storage slips are read with Windower's own `slips` library.
