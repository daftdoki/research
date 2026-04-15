"""
BambuFilamentAppearances.py

Fusion 360 script that creates a full set of Bambu Lab filament appearances
(PLA Basic, PLA Matte, PLA Silk, PLA Translucent, PLA Tough+, PLA-CF, PETG
Basic, PETG-CF, ABS, TPU 90A, PLA Silk Multi-Color, PLA Wood) directly in the
active design.

Usage in Fusion 360
-------------------
1. `Utilities → Scripts and Add-Ins → Scripts → + (My Scripts)`.
2. Create a new Python script; open the folder, and drop this file AND
   `bambu_colors.json` in beside it (or edit `COLORS_JSON_PATH` below).
3. Run the script from the dialog.  Each colour/finish combination is copied
   from an appropriate Fusion stock appearance and re-tinted, producing one
   in-design appearance per filament.
4. Open `Modify → Appearance`, scroll to `In This Design`, right-click the new
   appearances you want to keep, and choose `Add to → <your library>.adsklib`
   (create a custom library first via `Manage Materials → + New Library`).

Why is the right-click step needed?
-----------------------------------
Fusion 360's public API (see `Appearances.addByCopy`) lets you add
appearances to the *design* but NOT write them back to a library file.  A
one-off manual drag from "In This Design" into your user library is the
currently supported workflow.

Base appearances used
---------------------
The script copies from Fusion's stock "Fusion 360 Appearance Library" so
there is no dependency on extra material packs.  If a base appearance name
has changed in a newer Fusion build, edit `BASE_APPEARANCES` below.

Author: research report companion – use/modify freely.
"""

import adsk.core
import adsk.fusion
import json
import os
import traceback

COLORS_JSON_PATH = os.path.join(os.path.dirname(__file__), "bambu_colors.json")

# Base appearances to duplicate for each finish.  These names are taken from
# the stock "Fusion 360 Appearance Library" (English locale).  If Fusion
# cannot find a name, it falls back to "Plastic - Matte (White)".
BASE_APPEARANCES = {
    "PLA Basic":              "Plastic - Glossy (White)",
    "PLA Matte":              "Plastic - Matte (White)",
    "PLA Silk":               "Plastic - Glossy (White)",        # we lower roughness below
    "PLA Translucent":        "Plastic - Translucent Matte (White)",
    "PLA Tough+":             "Plastic - Glossy (White)",
    "PLA-CF":                 "Plastic - Matte (White)",
    "PETG Basic":             "Plastic - Glossy (White)",
    "PETG-CF":                "Plastic - Matte (White)",
    "ABS":                    "Plastic - Glossy (White)",
    "TPU 90A":                "Plastic - Matte (White)",
    "PLA Silk Multi-Color":   "Plastic - Glossy (White)",
    "PLA Wood":               "Plastic - Matte (White)",
}
FALLBACK_BASE = "Plastic - Matte (White)"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def find_library_appearance(app, name):
    """Find an appearance by name in the Fusion 360 Appearance Library."""
    lib = app.materialLibraries.itemByName("Fusion 360 Appearance Library")
    if not lib:
        # Some locales use a different display name.
        for i in range(app.materialLibraries.count):
            candidate = app.materialLibraries.item(i)
            if "Appearance" in candidate.name:
                lib = candidate
                break
    if not lib:
        raise RuntimeError("Fusion 360 Appearance Library not found")
    return lib.appearances.itemByName(name)


def set_color_property(appearance, rgb):
    """Set the 'Color' property (ColorProperty) of an appearance to an RGB tuple."""
    props = appearance.appearanceProperties
    for i in range(props.count):
        p = props.item(i)
        if p.name == "Color" and p.objectType == adsk.core.ColorProperty.classType():
            color = adsk.core.Color.create(rgb[0], rgb[1], rgb[2], 0)
            adsk.core.ColorProperty.cast(p).value = color
            return True
    return False


def set_float_property(appearance, prop_name, value):
    props = appearance.appearanceProperties
    for i in range(props.count):
        p = props.item(i)
        if p.name == prop_name and p.objectType == adsk.core.FloatProperty.classType():
            adsk.core.FloatProperty.cast(p).value = value
            return True
    return False


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface
        design = adsk.fusion.Design.cast(app.activeProduct)
        if not design:
            ui.messageBox("Open a Fusion 360 design first.")
            return

        with open(COLORS_JSON_PATH, "r") as f:
            data = json.load(f)
        finishes = data["finishes"]
        colors = data["colors"]

        appearances = design.appearances
        created = 0
        skipped = 0

        # Cache base appearances copied into the design once.
        base_in_design = {}
        for finish, base_name in BASE_APPEARANCES.items():
            try:
                base = find_library_appearance(app, base_name)
            except Exception:
                base = None
            if not base:
                base = find_library_appearance(app, FALLBACK_BASE)
            # Copy into design with a temporary unique name.
            tmp_name = f"__bambu_base__{finish}"
            existing = appearances.itemByName(tmp_name)
            base_in_design[finish] = existing or appearances.addByCopy(base, tmp_name)

        for entry in colors:
            name = entry["name"]
            finish = name.split(" — ")[0]  # "PLA Basic", "PLA Matte", ...
            hex_color = entry["hex"]
            if finish not in base_in_design:
                skipped += 1
                continue
            if appearances.itemByName(name):
                skipped += 1
                continue

            appearance = appearances.addByCopy(base_in_design[finish], name)
            set_color_property(appearance, hex_to_rgb(hex_color))

            cfg = finishes.get(finish, {})
            if "roughness" in cfg:
                # Fusion's plastic roughness property is usually "surface_roughness".
                set_float_property(appearance, "surface_roughness", cfg["roughness"])
            created += 1

        # Clean up the temporary base copies.
        for finish, a in base_in_design.items():
            try:
                a.deleteMe()
            except Exception:
                pass

        ui.messageBox(
            f"Bambu filament appearances added.\n\n"
            f"Created: {created}\nSkipped (already existed): {skipped}\n\n"
            f"Now open Modify → Appearance → 'In This Design', right-click an\n"
            f"appearance and choose 'Add to → <your custom library>.adsklib'\n"
            f"to persist them across projects."
        )
    except Exception:
        if ui:
            ui.messageBox("Failed:\n{}".format(traceback.format_exc()))
