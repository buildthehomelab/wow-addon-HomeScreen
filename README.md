# Home Screen

<img src="icon.png" alt="" width="64" align="right">

A World of Warcraft 3.3.5a addon for the home screen of
[mod-playerhousing](https://github.com/buildthehomelab/wow-mod-playerhousing): after logging in you
land in the world at your plot instead of on character select, and pick a character from there.

On the server's viewer character it hides the UI and lists your characters, and the top ones (favourites first)
stand in the yard as figures.
On any other character it does nothing, apart from saying how long Play took.

## What it adds

- **Your characters:** a window listing them, a dozen to a page. Pick one and click **Play**.
- **Figures:** click a character standing in the yard, or their pet, to pick them. Hover for a name.
- **Character select:** a button that takes you there, to create or delete a character.
- **Camera:** start or stop a slow turn, and save the view you like. It comes back next time.
- **Show UI:** brings the normal UI back. From there, `/homescreen` brings the window back.

## Requirements

- A server running mod-playerhousing's home screen, on a core that has it, and a character select screen
  that takes part. See its
  [docs/HOME_SCREEN.md](https://github.com/buildthehomelab/wow-mod-playerhousing/blob/main/docs/HOME_SCREEN.md).
- The server's `AddonChannel` option on, which is the default.

## Install

Copy the `HomeScreen` folder into `Interface\AddOns`.

## Testing

`lua tests/test_homescreen.lua` from this folder runs mock tests of the logic.

## Troubleshooting

- **No window on the home screen:** check the addon is enabled for that character in the AddOns list.
  If it's missing or off, character select won't take you to the home screen at all.
- **Stuck somewhere odd:** hold Shift while the character list loads to stay on character select.

## Credits

Written for mod-playerhousing, by dudemcbro, which this talks to.

## License

MIT.
