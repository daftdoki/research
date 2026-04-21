# Higher-Temp Filaments for 3D-Printed Filament-Dryer Accessories (Bambu Lab H2D)

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What 3D-printing filament — more heat-resistant than PLA or PETG, safe to print indoors, not ASA and not PVC — should I use on my Bambu Lab H2D to print accessories that live *inside a filament dryer while it's drying PETG*? ([original prompt](#original-prompt))

## Answer

**Start with PETG-CF (or PCTG). Step up to Polycarbonate (PC / PC-FR) if you want big thermal margin. Reach for PAHT-CF only if you also need the mechanical stiffness.**

PETG dryers run at **55–65 °C**. You want a material whose heat-deflection temperature (HDT) sits comfortably above that under sustained load. The three realistic, indoor-safe, H2D-printable candidates rank like this:

| Rank | Filament | HDT ≈ | Ease of printing | Indoor-safe? | Notes |
|---|---|---|---|---|---|
| 1 | **PETG-CF** | ~80–85 °C | Easy (≈ PETG) | ✅ | Smallest leap from PETG; small but real HDT uplift from CF reinforcement. Needs hardened nozzle. |
| 1 | **PCTG** | ~76–85 °C | Very easy | ✅ | A slightly tougher, slightly higher-Tg PETG. Minimal downsides. |
| 2 | **Polycarbonate / PC-FR / PC-CF** | ~115–135 °C | Moderate | ✅ (mild) | Huge thermal margin; absorbs moisture fast, higher print temps. |
| 3 | **PAHT-CF (carbon-fibre nylon)** | ~120–180 °C | Hard (must be dry, hardened nozzle, enclosure) | ✅ | Overkill thermally; best mechanics; fussiest workflow. |

My practical recommendation: **PETG-CF** is the best single answer — it's nearly as easy as PETG on the H2D, is indoor-safe, and carries enough HDT margin for any consumer PETG dryer. If the accessory is load-bearing (a hanging bracket, a hinge, a hook with weight on it), jump to **PC-FR**. Only use **PAHT-CF** if you also want strength/stiffness, since the print workflow is considerably more demanding.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Confirmed the printer's envelope on Bambu Lab's [H2D tech-specs](https://bambulab.com/en/h2d/tech-specs) page: max nozzle 350 °C, bed 120 °C, active chamber heating to 65 °C, integrated carbon filter.
2. Confirmed the typical operating temperature of consumer PETG-drying cycles (**55–65 °C**, 4–8 h) via the [Bambu Lab filament-drying wiki](https://wiki.bambulab.com/en/filament-acc/filament/dry-filament), [Sunlu S2 review](https://www.gambody.com/blog/new-sunlu-filament-dryer-review-filadryer-s2-2023-edition/), and [Siraya Tech's PETG-drying guide](https://siraya.tech/blogs/news/how-to-dry-petg).
3. Collected Tg / HDT figures for every plausible candidate from manufacturer datasheets and third-party comparisons (Polymaker, Bambu Lab, Prusa, 3DXTech, Snapmaker, Wevolver).
4. Filtered candidates on four criteria:
   - HDT comfortably above 65 °C (≥ ~75 °C minimum; ≥ 90 °C preferred).
   - Low VOC / ultra-fine-particle emissions (indoor-safe).
   - Not ASA, not PVC (user-excluded).
   - Printable on the H2D without specialty hardware beyond the factory hardened nozzle.
5. Ranked survivors on ease of printing and thermal margin.

No physical testing — this is a comparative literature review. Manufacturer-reported HDT values are known to vary 10–20 °C by test load (0.45 MPa vs 1.8 MPa); the 0.45 MPa figures are reported here because dryer accessories are light-load.

## Results

### Thermal margin vs. a 65 °C PETG dryer

| Material | Tg (°C) | HDT @ 0.45 MPa (°C) | Margin over 65 °C | Indoor-safe | Excluded? |
|---|---|---|---|---|---|
| PLA (untreated) | ~60 | ~55 | **–10** ❌ | ✅ | baseline (too low) |
| PLA (annealed / "HT") | — | ~90 after anneal | +25 | ✅ | Warps during anneal |
| PETG | ~80 | ~70 | +5 (marginal) | ✅ | baseline (too low) |
| **PETG-CF** | ~80 | ~80–85 | **+15–20** | ✅ | — |
| **PCTG** | ~85 | ~76–85 | **+10–20** | ✅ | — |
| ABS | ~105 | ~90–98 | +25–35 | ⚠️ styrene/UFPs | de facto (indoor safety) |
| ASA | ~100 | ~95–100 | +30–35 | ⚠️ | explicitly excluded |
| **PC / PC-FR** | ~145 | ~115–135 | **+50–70** | ✅ (mild) | — |
| PC-CF | — | ~135 | +70 | ✅ | — |
| **PAHT-CF (nylon+CF)** | — | ~120–180 | **+55–115** | ✅ | — |
| PPS-CF | Tg ~90 | ~100–220 | +35–155 | ✅ | Expensive, overkill |
| PEEK / PEI | 143+ | >170 | +105+ | ✅ | H2D 350 °C hotend; PEEK wants 400+ |

### Ease-of-printing ranking (on H2D)

| Rank | Material | Profile | Hardware needed | Notes |
|---|---|---|---|---|
| 1 | PETG | 235–250 °C / bed 70–80 °C | stock nozzle | baseline |
| 2 | PCTG | 245–265 °C / 75–85 °C | stock nozzle | drop-in PETG replacement |
| 3 | PETG-CF | 240–260 °C / 70–80 °C | **hardened** 0.4/0.6 nozzle | stringy if wet; dry before use |
| 4 | PC / PC-FR | 260–290 °C / 100–110 °C | stock nozzle OK | Chamber heat helps; dry spool |
| 5 | PC-CF | 270–290 °C / 100–110 °C | hardened nozzle | same, less warp than pure PC |
| 6 | PAHT-CF | 290–310 °C / 90–100 °C | hardened nozzle | **must** pre-dry 8+ h at 80 °C |
| 7 | PPS-CF / PPA-CF | 310–340 °C / 110–120 °C | hardened nozzle, specific hotend | near H2D limits; expensive |

## Analysis

**Why PETG-CF first.** Your dryer tops out at ~65 °C, and PETG is already borderline at that temperature — which is presumably why you asked. Adding chopped carbon fibre to PETG doesn't meaningfully change the Tg of the resin itself, but it *does* raise the HDT by 10–15 °C because the fibres resist creep under load. You get enough margin to stop worrying, without changing the print workflow: same nozzle temp band as PETG, no enclosure tricks, no styrene. PCTG is interchangeable here — prints even cleaner, slightly higher Tg, a hair lower HDT.

**Why PC as the step-up.** Polycarbonate leaves zero ambiguity: HDT ~115 °C means your accessory isn't going to notice the dryer at all, even if you run it at Bambu AMS-HT temperatures (85 °C) in the future. The cost is print difficulty: 260–290 °C nozzle, >100 °C bed, enclosure required (you have one), aggressive moisture absorption (keep the spool dry). PC-FR adds flame retardancy — sensible for an accessory that lives next to a heater element. PC is *relatively* indoor-safe compared to ABS/ASA: VOC emissions are much lower than styrenics, and the H2D's carbon filter handles what's left. Open a window; you'll be fine.

**Why PAHT-CF is the third option, not the first.** Nylon variants have the best heat resistance per dollar of any of these, and carbon-fibre loading makes them dimensionally stable. But nylon is famously hygroscopic, the print workflow is demanding (dry filament, dry printing chamber, hardened nozzle, calibrated retractions), and it's overkill for the thermal load you described. Use it if you *also* want a part that can take mechanical stress.

**What I excluded and why.**
- **ABS / HIPS** — styrenic emissions; you asked for indoor-safe, and while ABS is defensible inside the H2D's filtered enclosure, "safer than ASA" is a low bar. PC covers the same thermal niche without the styrene smell.
- **PEEK / PEI / PPSU** — needs a >400 °C hotend; the H2D tops out at 350 °C.
- **PPS-CF** — technically printable on H2D at 310–340 °C, but it's a $100+/kg engineering thermoplastic. Massive overkill for a dryer bracket.
- **TPU** — low HDT, irrelevant.
- **PLA (annealed) / PLA-HT** — achievable, but the anneal step distorts geometry and the HDT uplift evaporates if the part sees any load. Fine for a hook or label holder inside a 55 °C dryer; risky at 65 °C+.

**Watch-outs specific to a filament-dryer accessory.**
- Accessories near the heating element see radiant heat on top of air temperature; design in some clearance margin.
- Long-duration (multi-day) exposure at Tg–10 °C will still creep under sustained load in PLA and untreated PETG. The CF-reinforced or higher-Tg materials above solve this.
- A hygroscopic material inside a dryer is self-defeating only if the dryer isn't actually drying — the dryer will keep a nylon bracket dry during use, but the bracket will absorb moisture between cycles. CF-filled grades mitigate this.

## Files

- `README.md` — this report
- `notes.md` — full research notes, work log, and ruled-out options

## Original Prompt

> 3D printing filaments. I am looking for a higher temp resistant filament than PLA or PETG that I can use to print accessories that will be subject to the inside of a filament dryer when drying PETG. I want an alternative that is safe to print indoors and is not ASA or PVC. Research options and make sure to assess their ease of printing as well as their thermal fitness for this use case. I have a Bambi Lab H2D printer.
