# PhayarSar prayer covers

34 original, individually composed square SVG illustrations covering every
prayer currently returned by `PrayerCatalog` through `Prayers/manifest.json`.
The catalog currently lists 34 prayers, despite the older count in `AGENTS.md`.

Open **index.html** for an offline gallery with Burmese titles and individual
downloads. **preview.png** is the full contact sheet; **preview.svg** is its
scalable counterpart. All individual originals are in **svg/**.

## Art direction

Restrained retro print / geometric pop illustration: warm paper, terracotta,
ochre, deep teal, sage and dark ink. Large silhouettes, diagonal fields and
hard-edged colour separations echo vintage travel posters and record sleeves.
A narrow paper border ties the collection together. Each prayer has a distinct
composition rather than a palette-swapped generic icon.

The artwork uses symbolic plants, jewels, water, architecture and animals drawn
from the bundled prayer descriptions and verses. These are artistic associations,
not canonical emblems. No sacred text, portraits, logos, borrowed illustrations,
distressed raster textures, gradients or external assets are included. Titles
stay in the app UI so Burmese text can keep its proper font, size and spacing.

## Vector files

- Every original is `800 × 800` with `viewBox="0 0 800 800"` (1:1).
- Shapes remain editable paths, circles, polygons and rectangles.
- No embedded bitmap images, filters, external references or font dependencies.
- SVG `<title>` and `<desc>` identify each illustration accessibly.
- All colours are explicit flat fills; the SVGs scale to any export resolution.
- `catalog.json` maps exact, unmodified `Prayer.id` values to SVG paths. IDs
  intentionally differ from prayer filenames in several cases.

Each SVG is also installed as its own image set in
`Sources/PrayersKit/Resources/PrayerCovers.xcassets`, processed by SwiftPM.
The image sets preserve vector data and use original colours. Each prayer entry
in `Sources/PrayersKit/Prayers/manifest.json` pairs its `file` with its `cover`
asset name. `PrayerCatalog.coverAssetName(for:)` resolves this mapping using the
prayer's actual ID; `PrayerCoverImage(prayerID:)` loads from the package bundle.
The home list and detail carousel (including reflections and the iOS 16 static
cover) display these individual assets.

## Regeneration

From the repository root:

```sh
python3 PhayarSarLibrary/Artwork/Tools/generate_prayer_covers.py --render
```

Python uses only its standard library. `--render` additionally needs
`rsvg-convert` (librsvg), renders every cover at 64 and 800 pixels to check SVG
compatibility, and creates the contact-sheet PNG. Omit the flag to regenerate
the SVGs, mapping and HTML without a raster renderer.

Regeneration updates the individual package image sets as well as the review
artifacts. The manifest owns each asset's name; there is no second runtime map.
The palette and individual compositions live in the generator. Edit those
definitions before regenerating; direct edits to generated SVGs are overwritten.
The adjacent `PhayarSar-Prayer-Covers.zip` is a portable copy of this directory.
