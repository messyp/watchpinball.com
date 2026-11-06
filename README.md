# watchpinball.com

The website for Watch Pinball: Wrist Arcade, an Apple Watch game by Attic Studio. Plain HTML hosted on GitHub Pages. `index.html` is the whole site, with its CSS and script inline and no build step.

## Release state

`<body data-release="pre">` is the state before version 1.1: four tables, with Clockwork marked coming soon. Change it to `data-release="live"` once 1.1 is on the App Store, and check the copy against the live listing first.

Before sharing the site publicly, remove `<meta name="robots" content="noindex">`.

## Assets

- `assets/tables`: full table art from the game's headless harness (`SKINPNG=dir MINUTES=0 ./pinsim all 1`), saved as JPEG.
- `assets/clips`: gameplay loops from `tools/clips.swift`, played by the game's bot.
- `assets/film`: the wrist film, the wide render of the 1.1 edit (`tools/promo-cut` in the game repo), made with `tools/transcode.swift`. It has no captions.
- `assets/download-on-the-app-store.svg`: Apple's official badge, unmodified. Use one per page.
- `assets/apple-watch-ultra-4.png`: Apple's official product bezel, used as supplied. Don't crop, tilt, shadow or overlay it.
- `assets/logos`: each table's own logo, rendered large and transparent by `tools/logos.swift`.
- `assets/fonts`: Big Shoulders Display and Hanken Grotesk, under the SIL Open Font License 1.1.

If a table's art changes shape, re-trace its outline with `tools/arches.py`.
