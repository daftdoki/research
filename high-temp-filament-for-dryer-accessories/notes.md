# Research Notes: Higher-temp filaments for 3D-printed filament dryer accessories

## Problem framing

- User owns a **Bambu Lab H2D** printer (note: user typed "Bambi Lab H2D").
- Wants to print *accessories that sit inside a filament dryer* while drying PETG.
- Needs a material **more heat-resistant than PLA or PETG**, safe to **print indoors**, and **not ASA or PVC**.
- Want to assess **ease of printing** and **thermal fitness** for the use case.

## Key constraint: what temperature does a filament dryer actually hit?

For drying PETG, most consumer filament dryers (Sunlu S2/S4, Creality Space Pi, Eibos Cyclopes, Polymaker PolyDryer, etc.) run between **55 °C and 65 °C** for 4–8 hours (verified: Siraya Tech / Bambu Lab wiki / Sunlu spec sheet). Sunlu's newer E2 and Bambu's AMS HT push higher (up to 85 °C) for nylons, but PETG itself is firmly in the 55–65 °C band.

Design rule of thumb: you want the material's **glass-transition temperature (Tg)** — or better its **Heat Deflection Temperature (HDT)** — comfortably above the dryer's set point, with enough margin for (a) radiant heat from the dryer's heater element and (b) constant long-duration exposure (creep matters, not just peak).

Practical minimum target: parts that can handle a **sustained 70 °C** without sagging/creeping under light load. Ideally ≥90 °C HDT for margin.

## Quick thermal reference (approximate, varies by brand)

| Material | Tg (°C) | HDT (°C, 0.45 MPa) | Notes |
|---|---|---|---|
| PLA | ~60 | ~55 | Creeps in dryer; *sometimes* OK if annealed/crystallized |
| PLA-HT / heat-treated PLA | ~60 → ~95 after anneal | up to ~95 after anneal | Needs anneal cycle, warps |
| PETG | ~80 | ~70 | Marginal – right at dryer temp, prone to creep |
| PETG-CF / PETG-HF | ~80 | ~75–85 | CF/fiber raises stiffness & HDT modestly |
| PCTG | ~85 | ~72–78 | Slightly better than PETG, very printable |
| ABS | ~105 | ~90–98 | Fumes — not indoor-safe without good ventilation |
| ASA | ~100 | ~95–100 | **User-excluded** |
| PC (Polycarbonate) | ~145 | ~115–135 | Very high temp; draws moisture fast; higher print temps |
| PC-blends (PC/ABS, PC/PBT, PC-FR) | ~110–135 | ~100–120 | Easier than pure PC |
| PA (Nylon) unfilled | ~50–70 | ~60–90 | Tg low when wet; absorbs moisture – ironic for a dryer accessory |
| PAHT-CF / PA-CF | — | ~120–180 | Very strong & heat-resistant; needs dry filament, hardened nozzle |
| PPA-CF | — | ~150–200 | "Engineering grade"; requires higher temps |
| PPS / PPS-CF | Tg ~90, Tm ~280 | ~100–220 | Chemically inert, expensive, high-temp hotend |
| PEEK / PEI | very high | >170 | Overkill, needs >400 °C hotend |

Sources of HDT values: Prusa Materials Guide, Polymaker datasheets, Bambu Lab material pages, 3DJake material comparison, CNC Kitchen testing.

## Indoor-safety (VOC / UFP) considerations

- **Indoor-safe (low emissions):** PLA, PETG, PCTG, PA (dry), PC (moderate), PPS.
- **Not recommended indoors:** ABS, ASA, HIPS — release styrene and high UFP levels; need enclosure + filtered exhaust.
- H2D is enclosed and has an activated-carbon + G3 filter, so higher-temp materials are more tolerable, but indoor-safe engineering materials are still the smart pick.

## Bambu Lab H2D hotend & chamber capabilities

*Verified via Bambu Lab H2D tech specs page (April 2026):*
- Dual-extruder, fully enclosed chamber, **active chamber heating up to 65 °C**.
- Hotend max **350 °C** (supports PPA and PPS-CF, which print at 300–320 °C).
- Heatbed up to **120 °C**.
- Ships with hardened steel 0.4 mm nozzle by default; 0.6/0.8 hardened nozzles available — *required* for CF/GF-filled filaments.
- Activated-carbon air filter included — relevant for higher-emission materials.
- Bambu supports PLA, PETG, PETG-CF, PCTG, ABS, ASA, PA, PAHT-CF/PA-CF, PC, PC-FR, PPS-CF, PET-CF, PPA-CF.

So the printer is not the bottleneck for any of the realistic candidates.

## Candidate shortlist for the task

Filtering the table by: HDT ≥ ~80 °C, indoor-safe (low VOCs), not ASA/PVC, printable on H2D without specialty hotend.

### 1. PETG-CF (carbon-fiber-reinforced PETG)
- HDT bumps from ~70 °C to ~80–85 °C thanks to CF reinforcement reducing creep.
- Prints almost like PETG (240–260 °C, 70–80 °C bed), indoor-safe.
- Needs hardened nozzle (H2D supports).
- **Verdict:** Small margin over dryer temp; fine if dryer is ≤60 °C and load is low. Easy win.

### 2. PCTG
- Amorphous copolyester, stronger + slightly higher Tg than PETG (~85 °C vs ~80 °C).
- Prints at ~245–265 °C, 75–85 °C bed. Near-zero warp, no enclosure needed, no styrene.
- **Verdict:** Minor upgrade, great ease of printing. Use if dryer ≤65 °C.

### 3. Polycarbonate (PC) and PC blends (PC-FR, PC/PBT, PC-Max)
- HDT ~115 °C (pure PC), ~100–110 °C (blends).
- Prints at 260–290 °C, bed 100–110 °C, enclosure strongly recommended (H2D has one).
- Absorbs moisture aggressively → must keep spool dry.
- Not as fumey as ABS; still prefer ventilation, but OK in an enclosed printer with carbon filter.
- **Verdict:** Excellent thermal fitness with huge margin. Moderate print difficulty.

### 4. PA (Nylon) — PAHT-CF / PA-CF
- HDT ~120–180 °C depending on crystallinity and fiber loading.
- Prints at 290–310 °C, bed 90–100 °C, **must** be printed dry (pre-dry 8h+ at 80 °C).
- Hardened nozzle required.
- **Caveat specific to this use case:** unfilled nylon is hygroscopic → a nylon bracket inside a dryer actually *wants* to be dry, which is fine (dryer keeps it dry), but it will rob moisture from parts being dried and may warp with humidity swings. CF-filled nylons are more dimensionally stable.
- **Verdict:** Overkill thermally, best mechanical properties, but highest ease-of-printing cost and some moisture quirks.

### 5. PPS-CF
- HDT 100–220 °C, chemically inert, flame-retardant.
- Needs higher hotend temps (≥320 °C); H2D can technically do it but it's near the edge.
- Expensive ($100+/kg). Overkill for a dryer accessory.

### 6. PLA-HT (annealed "high-temp" PLA)
- Print like normal PLA then bake at 80–110 °C to crystallize → HDT climbs from ~55 °C to ~90 °C.
- Parts shrink ~3–5% during anneal and can warp — design accordingly (Polymaker has a guide).
- Indoor-safe.
- **Verdict:** Easy-print option if you're willing to anneal; fine for a gentle 50–60 °C dryer but marginal at 70 °C.

## Why not ABS?

User didn't explicitly exclude ABS, but ABS in the same context as ASA is effectively disqualified for an "indoor-safe" request. ABS releases styrene vapor and high levels of ultra-fine particles (UFPs). Without a sealed enclosure venting outside (H2D has filtration but still vents into the room), ABS is not ideal indoors. PC or nylon cover ABS's niche without the styrene.

## Practical recommendation ranking

Best trade-off between thermal margin, ease of printing, and indoor safety for this specific use case (dryer accessories, 55–70 °C, inside):

1. **PETG-CF or PCTG** — cheapest, easiest, indoor-safe, just enough margin.
2. **PC or PC blend (PC-FR)** — big thermal margin, still printable on H2D, the "do it once, forget it" choice.
3. **PAHT-CF** — if the accessory is load-bearing or needs stiffness; thermally the best but fussiest to print.

I'd personally start with **PETG-CF** (Bambu or Polymaker) since the H2D prints it almost as easily as PETG, and only move up to PC if parts show creep after a long dry cycle.

## Things I checked / ruled out during research

- PEEK/PEI/PPSU: needs >400 °C hotend, not possible on H2D.
- TPU: low HDT, not applicable.
- HIPS: styrene emissions, same issue as ABS.
- PVA / BVOH: water-soluble support materials, irrelevant.
- PLA alone: creeps near dryer temp, not reliable even if it survives a single cycle.

## Open questions / uncertainties

- Exact HDT figures vary 10–20 °C by brand and test method (0.45 vs 1.8 MPa load). I used 0.45 MPa values as most accessory use is low-load.
- User's specific dryer temperature isn't stated; assumed 55–70 °C based on common PETG-drying profiles.
- Bambu AMS HT (heated AMS) reaches 85 °C, which would push the recommendation firmly into PC / nylon territory — worth confirming with user.
