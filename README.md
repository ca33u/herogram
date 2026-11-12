English · [Русский](README.ru.md)

# Herogram

A **World of Warcraft: Forever** addon (Interface 16001) by **addicted** ([addicted.sh](https://addicted.sh)), MIT license.

Share your hero. Herogram makes a card of your character for social media: your hero as a live 3D model in a glow of your colour, name, level, race and class, guild, professions with their ranks, talents, time played, quests done and your proudest item, in a dark card with a gold frame.

## Formats

| Format | Shape | Exported at | For |
|---|---|---|---|
| Stories | 9:16 | 1080×1920 | Instagram, Telegram and VK stories, Reels, TikTok |
| Post | 4:5 | 1080×1350 | Instagram and Threads feed |
| Square | 1:1 | 1080×1080 | anywhere |
| Wide | 16:9 | 1920×1080 | X / Twitter, Discord |

## Making a card

1. Type **/herogram** or click the minimap button.
2. Pick the format and the colour (your class, your faction, gold, arcane, fel or frost).
3. Pose your hero: drag to turn, mouse wheel to zoom, right-drag to move. Pick a pose (ready, battle roar, salute, dance…) and press **Freeze** to stop it at the right moment.
4. Add a headline if you like ("Finally Artisan!") and choose what to show, down to which professions appear (each with its rank).
5. Press **Take the picture**. For a split second the card fills a black screen and the game saves a screenshot.
6. Open **Crop.html** from the addon folder (`World of Warcraft/_forever_/Interface/AddOns/Herogram/Crop.html`) in your browser and drop the screenshot on it. The page finds the card, cuts it out at the exact size of its format, and lets you save, copy or share it. It works offline: nothing is uploaded.

The **Best item** is your best equipped item by default. To show another one, drag it from your bags or the character sheet onto the Best item slot in the panel (or onto the item row on the card), or Shift-click it in your bags while the panel is open. Right-click the slot or press **Auto** to go back. The item stays where it was.

When you reach a new level or a new profession rank (75, 150, 225, 300), Herogram offers to make a card with a ready headline.

## Commands

- `/herogram` open or close the card
- `/herogram toasts` offer a card on level up and new profession ranks (on by default)
- `/herogram minimap` show or hide the minimap button
- `/herogram reset` put the hero back as it was
- `/herogram debug` show what the game reports about professions and talents, in a box you can copy

## Limits

- Addons cannot post, upload or copy pictures: the picture is a normal game screenshot, and the crop page does the rest.
- The picture is as sharp as your screen: on a 1080p screen a Stories card is about 1040 pixels tall and is scaled up to 1920.
- Screenshots are saved as PNG while the picture is taken (your own setting comes back right after).

## License

MIT, by [addicted](https://addicted.sh).
