# Research notes — Fusion 360 printer filament appearances/materials

## Goal

User wants Bambu Lab (and more generally PLA / PETG in gloss / matte / silk
etc.) filaments available inside Fusion 360's **Appearance** and **Material**
browsers, so CAD models render like the actual prints they will produce.

## Two separate libraries in Fusion 360

Fusion 360 (and all Autodesk apps) keep two browsers that people often
confuse:

| Library | What it drives | Examples |
| --- | --- | --- |
| **Materials** | Physics — density, E modulus, thermal/electrical, *also* the default appearance shown on a body | "ABS Plastic", "Aluminum 6061" |
| **Appearances** | Visual only — base colour, roughness, metallic, bump/transparency, used by Render workspace | "Plastic – Glossy (White)" |

Both are stored in `.adsklib` files (a zip of XML + texture images – not
SQLite, even though some forum posts claim so).  The same `.adsklib` file
can be loaded by Fusion, Inventor, Revit, 3ds Max, AutoCAD.  Files in
`My Appearances` and `My Materials` are auto-created and can't themselves be
shared – you need to make a **custom library** to share or version-control.

## Existing community libraries I found

1. **`alecGraves/Fusion360PrinterMaterials`** (GitHub, 149★).
   Ships one `FusionPrintingMaterials.adsklib` with nine engineering-focused
   entries: PLA, PolyLite PLA, PolyTerra PLA, PETG, ABS, ASA, PC, PolyMax PC,
   PolyMide PA12-CF.  This is a **material** library (density, Young's
   modulus, etc.); the visual appearance is generic.  Install: `Utilities →
   Manage Materials → folder icon → Open Existing Library`.
2. **`morganmbk` – "F360 Materials Library for BL Filament"** on MakerWorld
   (model 108960).  A Bambu-branded library.  Could not inspect contents –
   MakerWorld page was behind login / 403, but forum chatter says it
   provides an `.adsklib` covering Bambu PLA Basic and Matte colour lines.
3. **Etsy listing "Bambulab Filament Color Fusion 360 Generator Add-in"**
   (paid, \~\$5–10).  Python add-in that creates 68 in-design appearances
   (PLA Basic/Matte/Silk) from Bambu's hex code tables.
4. **`dadequate/bambu-lab-filament-colors`** (GitHub).  Not Fusion-specific –
   it publishes a `colors.json` listing 94 Bambu filaments across PLA
   Basic / Matte / Tough+ / Translucent / Wood / Silk Multi-Color, PLA-CF,
   PETG-CF, ABS, TPU 90A.  The JSON is the practical data source for
   building your own Fusion library.

## Fusion 360 API reality check

- `design.appearances.addByCopy(existingAppearance, newName)` works from any
  library into the active design.
- **The API cannot write back to a library file.**  Autodesk support and the
  `Appearances.addByCopy` reference both say this explicitly.
- So any automation ends at "appearance exists inside this design".  Saving
  to a user `.adsklib` requires one manual step: right-click the appearance
  in the "In This Design" section and choose `Add to → <library>`.
- There is no documented public format for writing `.adsklib` from scratch.
  The format is Autodesk's ProteinSDK/ADSK XML material schema.  Some
  third-party authoring tools (Twinmotion, Revit) write it, but not the
  Fusion API.

## Consequence for the workflow

You can't write a fully automated "install these 94 colours as a library"
tool unless you reverse-engineer `.adsklib`.  Realistic options ordered by
effort:

| Option | What you get | Effort |
| --- | --- | --- |
| Install `Fusion360PrinterMaterials.adsklib` | Good physics, generic looks | 1 min |
| Install morganmbk's Bambu adsklib (MakerWorld) | Bambu visual library ready to go | 2 min + MakerWorld account |
| Buy Etsy add-in | One-click to populate in-design | \$ + import step |
| Run the script in this repo + colors.json | 94 free Bambu appearances, fine-tuneable | \~5 min + one right-click drag per finish to persist |
| Hand-build in `Favorites` using Fusion's built-in "Plastic – Matte/Glossy/Translucent" templates | Fully custom generic filaments (PLA matte, PETG gloss, etc.) | ongoing |

## Generic filament appearance cheat-sheet

Starting points that look right in Fusion's renderer:

| Finish | Base template in Fusion | Roughness | Metallic | Notes |
| --- | --- | --- | --- | --- |
| PLA Basic (gloss) | Plastic – Glossy | 0.40 – 0.50 | 0 | "Basic" Bambu PLA has modest sheen – don't push below ~0.3 |
| PLA Matte | Plastic – Matte | 0.90 – 0.95 | 0 | Add a small bump (0.02 mm) noise for micro-texture |
| PLA Silk / pearl | Plastic – Glossy | 0.20 – 0.30 | 0.25 – 0.45 | Metallic channel fakes the pearlescent sparkle convincingly |
| PLA Translucent | Plastic – Translucent Matte | 0.35 | 0 | Increase transmission / reduce opacity |
| PETG Basic | Plastic – Glossy | 0.25 – 0.35 | 0 | Glossier than PLA Basic |
| ABS | Plastic – Glossy | 0.45 – 0.55 | 0 | |
| TPU | Plastic – Matte / Rubber | 0.60 | 0 | |
| PLA-CF / PETG-CF | Plastic – Matte | 0.80 | 0 | Ideally overlay a subtle carbon-fibre noise image as bump |
| PLA Wood | Plastic – Matte | 0.85 | 0 | Use a wood-grain texture for both albedo and bump for realism |

For extra realism you can map a small, tiling greyscale image of **layer
lines** (0.2 mm stripes) into the bump slot – Shoda's "Filament Samples –
Fusion 360 Customizable" model on Printables includes texture maps meant
for exactly this.

## API notes gathered

- Colour property on appearance is `Color` (type `ColorProperty`).  Set via
  `adsk.core.Color.create(r, g, b, 0)`.
- Roughness property is named `surface_roughness` (FloatProperty) on the
  stock plastics; other schemas exist (`generic_glossiness` for "Generic").
- `Appearance.appearanceProperties` iterates all editable channels.
- The stock appearance library is called **"Fusion 360 Appearance Library"**
  in English locale (not "Fusion Appearance Library" and not "Autodesk
  Appearance Library").

## Things I tried

- Wanted to inspect a stock `.adsklib` in the repo sandbox.  Skipped – it's
  only installed inside Fusion installations, and licensing discourages
  redistribution.
- Couldn't fetch MakerWorld or Autodesk support articles from the sandbox
  (403 / 503).  Pulled equivalent info from forum search snippets and other
  mirrors.
- Initially considered writing `.adsklib` directly; abandoned because the
  schema isn't public and the "add appearance in design + right-click into
  library" workflow is the officially supported path.

## File artefacts

- `bambu_colors.json` – 94 Bambu filament HEX codes grouped by line, plus
  recommended roughness / metallic / bump values per finish.  Derived from
  Bambu Lab's own hex-code PDFs via `dadequate/bambu-lab-filament-colors`
  on GitHub.
- `BambuFilamentAppearances.py` – Fusion 360 **Script** (not an add-in).
  Loads `bambu_colors.json` and populates the active design with one
  appearance per filament + colour.
