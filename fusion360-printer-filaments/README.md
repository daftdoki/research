# 3D-Printer Filament Appearances in Fusion 360

## Goal

Bring real 3D-printer filaments — especially the Bambu Lab catalogue — plus
generic PLA / PETG in gloss / matte / silk etc. into Fusion 360's
**Appearance** (render look) and **Material** (physics) browsers so CAD
models look and analyse like the parts they will actually produce.
([original prompt](#original-prompt))

## Answer

There are three practical paths, and the best setup **stacks** them:

1. **For engineering (strength / mass / FEA)** — install
   [`alecGraves/Fusion360PrinterMaterials`](https://github.com/alecGraves/Fusion360PrinterMaterials).
   One `.adsklib`, nine materials (PLA variants, PETG, ABS, ASA, PC,
   PolyMax PC, PA12-CF).  Load via `Utilities → Manage Materials → folder
   icon → Open Existing Library`.
2. **For Bambu-specific *looks*** — either download
   [morganmbk's "F360 Materials Library for BL Filament"](https://makerworld.com/en/models/108960-f360-materials-library-for-bl-filament)
   (free, MakerWorld account), or run the Python script in this repo to
   generate 94 Bambu appearances from the bundled `bambu_colors.json`.  A
   paid alternative is the Etsy "Bambulab Filament Color Fusion 360
   Generator Add-in".
3. **For generic filaments** (your own "PETG gloss green", "PLA matte
   olive", "PLA silk bronze", …) — duplicate Fusion's built-in
   **Plastic – Glossy / Matte / Translucent** appearances in `Favorites`,
   edit colour + roughness per the cheat-sheet below, then drag from
   Favorites into a custom library you create once with
   `Manage Materials → + New Library`.

A Fusion-360 quirk to know up front: the API can create an appearance in
the active design but **cannot save it back to a library file** – you
always need one manual right-click → `Add to → <library>` after scripted
generation.  Writing a `.adsklib` from scratch isn't supported by public
tools either, so any fully-automated solution has to ship a pre-built
`.adsklib` (option 2 above).

For additional and more detailed information see the
[research notes](notes.md).

## Methodology

Investigated four things:

1. **How Fusion 360 stores appearances and materials.**  Both browsers read
   `.adsklib` files (a zip of XML + textures shared across Autodesk
   products).  Fusion has per-user `My Appearances` / `My Materials` hidden
   libraries plus any number of named user libraries.
2. **What community libraries already exist.**  Searched GitHub, the Bambu
   Lab forum, MakerWorld, Printables and Etsy.
3. **What APIs Fusion exposes for automation.**  Read the
   `Appearances.addByCopy` reference and Autodesk community threads – API
   can add in-design, not library-side.
4. **What roughness / metallic / bump values actually look right for each
   filament family** in Fusion's PBR renderer.

Then I compiled a HEX table for 94 Bambu filaments from
[`dadequate/bambu-lab-filament-colors`](https://github.com/dadequate/bambu-lab-filament-colors)
(itself sourced from Bambu's published hex-code PDFs) and wrote a Fusion
**Script** that uses that data plus finish-specific roughness numbers to
auto-create every appearance in the active design.

## Results

### Community resources located

| Resource | Scope | Type | Cost |
| --- | --- | --- | --- |
| [alecGraves/Fusion360PrinterMaterials](https://github.com/alecGraves/Fusion360PrinterMaterials) | 9 engineering materials | `.adsklib` | Free |
| [morganmbk – F360 Materials Library for BL Filament](https://makerworld.com/en/models/108960-f360-materials-library-for-bl-filament) | Bambu Lab visual library | `.adsklib` | Free (MakerWorld account) |
| [dadequate/bambu-lab-filament-colors](https://github.com/dadequate/bambu-lab-filament-colors) | 94 Bambu colours – raw HEX data | `colors.json`, macOS `.clr` | Free |
| [Etsy – Bambulab Filament Color F360 Add-in](https://www.etsy.com/listing/4338423818/bambulab-filament-color-fusion-360) | 68 Bambu appearances, Python add-in | Python script | Paid |
| [Shoda – Filament Samples Fusion 360 Customizable](https://www.printables.com/model/358184-filament-samples-fusion360-customizable) | Texture maps for layer lines | STL + images | Free |

### Finish cheat-sheet (what to set in a duplicated appearance)

| Finish | Base template | Roughness | Metallic | Extra |
| --- | --- | ---: | ---: | --- |
| PLA Basic (gloss) | Plastic – Glossy | 0.45 | 0.00 | — |
| PLA Matte | Plastic – Matte | 0.92 | 0.00 | Bump 0.02 mm noise |
| PLA Silk / pearl | Plastic – Glossy | 0.25 | 0.35 | Metallic channel fakes the sheen |
| PLA Translucent | Plastic – Translucent Matte | 0.35 | 0.00 | Increase transmission |
| PETG Basic | Plastic – Glossy | 0.30 | 0.00 | Glossier than PLA Basic |
| ABS | Plastic – Glossy | 0.50 | 0.00 | — |
| TPU 90A | Plastic – Matte | 0.60 | 0.00 | Rubber template also works |
| PLA-CF / PETG-CF | Plastic – Matte | 0.80 | 0.00 | Bump 0.03 mm, CF noise map if you have one |
| PLA Wood | Plastic – Matte | 0.85 | 0.00 | Wood-grain image map in albedo + bump |

### Recommended minimum set for a "generic filament" library

Build these 12 appearances once and keep them in a custom `.adsklib`:

PLA Gloss Neutral, PLA Matte Neutral, PLA Silk Neutral, PLA Translucent,
PETG Gloss Neutral, PETG Matte Neutral, ABS Gloss Neutral, TPU Matte
Neutral, PLA-CF Neutral, PETG-CF Neutral, PLA Wood Neutral, PLA
Transparent.  For any specific job, duplicate the matching base and edit
the colour – 10 seconds instead of rebuilding the physical properties each
time.

## Recommended setup (my answer for "what do I actually do?")

1. Download `FusionPrintingMaterials.adsklib` and load it as a **material**
   library – this gives you density/modulus/etc. for FEA and mass.
2. Download `morganmbk`'s Bambu `.adsklib` from MakerWorld and load it as
   an **appearance** library – instant Bambu visual catalogue.
3. Run `BambuFilamentAppearances.py` only if (a) MakerWorld isn't an
   option for you, or (b) you want to extend/tweak the colour list
   yourself.  Edit `bambu_colors.json` freely, it's just data.
4. Create one **My Filaments** custom library (`Manage Materials → +`) and
   drag the generic 12 entries from the cheat-sheet above into it once.
   From then on "make a new colour" is always duplicate-and-retint.

## Analysis / caveats

- Fusion's appearance model is PBR-ish but not full PBR — there is no
  dedicated anisotropy channel, so silk can only be approximated via
  metallic + low roughness.  It looks right in still renders but the
  "direction-dependent sparkle" of real silk is lost under rotation.
- Translucency is expensive to render and converges slowly in Fusion's
  ray-traced mode; preferring `Plastic – Translucent Matte` over the
  generic "Glass" template keeps render times sane.
- The 94-colour Bambu list is a snapshot — Bambu ships new colours
  regularly.  `bambu_colors.json` is structured so you can paste new
  entries in and re-run the script without touching any code.
- The `.adsklib` format is a proprietary zip/XML.  No supported tool today
  *writes* one from scripts, which is why any "install these 94
  appearances" tool either ships a pre-built `.adsklib` or falls back to
  generating in-design + a one-time manual library drag.

## Files

- `README.md` – this report.
- `notes.md` – raw research notes and links.
- `bambu_colors.json` – 94 Bambu Lab filaments with HEX codes plus
  per-finish roughness / metallic / bump recommendations.  Derived from
  Bambu's own hex-code tables via `dadequate/bambu-lab-filament-colors`.
- `BambuFilamentAppearances.py` – Fusion 360 script (My Scripts).  Reads
  `bambu_colors.json` and creates one in-design appearance per filament.
  Instructions in the file header.

## Original Prompt

> I am learning 3d modeling with Fusion 360. I want to be able to have common 3d printer filaments in the appearance and materials library. Ideally, I'd like at least the Bambu filaments to be available. Additionally a way to just represent generic filament types like PLA, PETG in regular, gloss, matte, silk, etc would also be nice. But representing real filaments and their visual properties would be the best. How would I go about this?
