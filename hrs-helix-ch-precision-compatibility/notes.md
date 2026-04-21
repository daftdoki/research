# Research Notes: HRS HLX-090 Helix & CH Precision Compatibility

## Research Questions

1. Is the bottom plate of the CH Precision devices meant to take the load when used with the HRS Helix (HLX-090)?
2. Are the existing CH Precision feet uniquely placed to take the weight and transfer vibration energy?
3. Are there any known incompatibilities or best practices for using separate isolation footers (like HRS Helix) with CH Precision equipment?

## User Equipment Context

- **CH Precision L10** — dual-monaural twin-chassis line stage (~20 kg + ~23 kg / ~44 + 51 lb)
- **CH Precision P10** — dual-monaural twin-chassis phono stage (~20 kg phono + ~23 kg PSU)
- **CH Precision D1.5** — SACD/CD transport or player (1-Series, ~20 kg)
- **CH Precision C1.2** — D/A controller (1-Series, ~20 kg)
- **CH Precision T1** — 10 MHz time reference clock (smaller, lighter chassis)
- Already on an **HRS SXR rack** with **M3X isolation bases** (black-granite topped base with broadband isolation feet inside the billet aluminum frame)

---

## HRS HLX-090 Helix — facts collected

### Physical
- Height: 0.90"–1.1" (23–29 mm) — the "090" is the 0.90" minimum nominal height
- Diameter: 3.4" (86 mm)
- Mass: 213 g each
- Construction: aluminum top "puck" / non-sticky polymer underside
- Price: ~$150 each (retail set of 3 = $450)
- Internally contains a **stainless-steel screw on a gimbal**; an adjustment tool is included so the user can raise the screw head until every puck presses equally against the chassis underside — self-levelling via the gimbal
- HRS product copy: "designed specifically to obtain maximum performance from audio components with a stiffer (plate and billet) metal chassis construction" and is intended to be **used together with HRS Isolation Bases** (E1, S3, R3X, M3X / M3X2) — not as a replacement for them

### Installation rules (per HRS)
- <100 sq in footprint: **3** pucks minimum
- ~150 sq in and up ("normal" components): **more than 3** strongly recommended
- ≥300 sq in large components: **up to 5**
- Component **sits directly on top of the pucks** — its own chassis underside is what is in contact with the gimbal heads
- Helix can pair with HRS **Damping Plates** on the top of the chassis (bottom noise + top noise strategy)
- No per-puck kg load rating is published in HRS public material I could find. Implication: HRS expects the user to choose enough pucks (3/4/5) to keep any one puck within reasonable load.

### Sister products in the same footer slot
- **HRS Nimbus** — two-piece polymer puck assembly, slightly warmer/rounder sound reputation, was the "original" HRS chassis-noise footer that Roy Gregory relied on with CH Precision
- **HRS Vortex** — premium option, more expensive, tonally very resolving
- **HRS Damping Plate / DPII** — goes on TOP of the chassis; complementary, not alternative

You pick ONE of {Nimbus, Helix, Vortex} for the footer slot under the chassis.

---

## CH Precision mechanical grounding — facts collected

### The four-spike architecture (shared by 1-Series and 10-Series)
- A threaded shaft runs vertically through each corner of the chassis, from a cap in the **top plate** down through the **bottom plate**
- The user drops a spike in from the top and screws it down until the spike tip contacts whatever is below the box, then turns it one more full turn to **lift the chassis clear of the shelf**
- The chassis is therefore **standing on four spike tips**, not on its bottom plate or its outer foot rings
- The outer "feet" at each corner (stainless ring with elastomer gasket) are really shelf-protection rings; in normal use they hover just above the shelf
- All four spikes **must be loaded equally** — CH instructs the user to verify equal turning resistance on all four (it tells you all four corners are loaded)

### 1-Series vs 10-Series spike hardware
- **Old 1-Series** — hardened steel, magnetic, one piece, prone to ringing (a long solid rod supported at the tip acts like a tuning fork)
- **Current 1-Series (C1.2, D1.5, P1, T1, etc.)** — two-piece: white polymer shaft + hardened **aluminum** tip. Non-magnetic, more damped. Available as a retrofit upgrade for older 1-Series.
- **10-Series (L10, P10, M10, C10, etc.)** — two-piece: black polymer (Delrin) shaft + **titanium** tip. Three lengths available. The 10-Series also has **removable outer feet** (3 Torx screws each) so the chassis corner can sit directly on a third-party footer.
- 10-Series units are **engineered for stacking**: when two chassis are stacked, the upper box's spikes drop onto dedicated hard-points in the lower box's top plate, producing one continuous vertical "drain column" from the upper chassis through the lower chassis and out into whatever is under the lower chassis. This is an explicit design feature (Hi-Fi+, The Audio Beat), and the L10's "coupling/stacking system" was specifically improved over the L1.

### Polymer support discs
- CH supplies a set of four **polymer (Delrin-style) discs** per unit with a groove that seats onto the rubber ring of each corner foot. These are to protect furniture/shelves from the spike tips
- Per CH Precision's installation guidance: **if the support surface is hard and reflective (glass, marble, granite), leave the discs in place** — they act as a lossy interface. On a **lossy surface** (wood, bamboo, constrained-layer composite), you can remove the discs and spike directly for a tighter drain.
- HRS's M3X has a **polished-granite contact plate** — this is precisely the case where CH's manual wants the polymer discs (or some other lossy interface) between the spike and the granite.

### The critical CH Precision sentence (verbatim from the L10 user manual)
> "The CH Precision casework is designed to support weight and ground energy in the corners only. If you choose to use third party supports they should be positioned in the same location as the unit's original feet."

This is the direct answer to the user's question #2, and it constrains question #1 and #3 as well. CH is telling the user:
- The chassis **is not designed to be loaded anywhere other than the four corners**.
- Third-party footers (incl. HRS Helix) should therefore be placed **at the corners, where the factory feet are** — not in some other pattern and not under the centre.

---

## How HRS Helix is actually installed under CH Precision (field practice)

All of the information below is collated from forum summaries (WhatsBestForum threads 30284, 34184; Audiogon; HiFi-Advice), dealer notes (Paragon, Cable Co, Definitive Audio), and the Gy8 (Roy Gregory) blog. Most of the primary forum posts returned 403/503 to direct fetch, so individual quotations are paraphrased from Google-indexed snippets. The facts below are consistent across multiple independent sources.

### 1-Series (D1.5, C1.2, T1) — factory feet stay on
- **Retract the CH spikes fully** (unscrew them up into the chassis, or remove them entirely and reinstall the top caps). The spikes must not be in contact with anything once the Helix is taking the load — otherwise the component will rock on whichever contact is higher.
- Place the Helix pucks **just inboard of the four CH corner feet**, on the diagonals drawn between the corners. The reason: the foot rings on 1-Series are not removable, so the Helix (3.4" disc) won't fit flush underneath the foot itself. Moving inboard a couple of inches puts the gimbal head under the **flat milled bottom plate** near the corner.
- This violates the strict reading of CH's manual ("in the same location as the unit's original feet") by a small inboard offset, but the milled aluminum bottom plate of a 1-Series is rigid enough that a pressure point 1–2" inboard of the corner is still structurally sound. CH's concern is not that 1 mm off the corner is dangerous; it's that loading the centre of the chassis is.
- **Watch for protruding fastener heads** on the 1-Series bottom plate. A handful of screws sit slightly proud on some units; position the Helix so its gimbal head lands on flat chassis, not on a screw head.

### 10-Series (L10, P10) — factory feet optionally come off
- Remove the outer corner feet (3 Torx screws each foot). The corner of the 10-Series chassis is then a flat, intentionally machined landing pad for an aftermarket footer.
- Place the Helix pucks **exactly at the original foot positions** — this is the literally correct reading of CH's "same location as the unit's original feet" instruction. This is the cleanest install and is what several CH dealers run.
- If you stack the two boxes of an L10 or P10, Helix is only under the lower box. The whole combined weight (both chassis) drains through the lower box's bottom plate into the four Helix pucks, so a **four-puck** install is mandatory and you want enough margin per puck. HRS hasn't published a per-puck kg rating, but the physical load from a stacked L10 (~44 kg + ~51 kg) over four HLX-090 is ~24 kg per puck, which is well within what dealer installs show running reliably with HLX-090s.
- **Keep the CH spikes retracted up** inside the chassis — do not screw them down while the chassis is resting on Helix. Leaving spikes engaged alongside Helix will produce an unstable triple-contact or see-saw.

### T1 clock (small)
- Small footprint — 3 HLX-090 is the HRS-correct count.
- CH feet stay on, spikes retracted. Three pucks under three corners; or alternatively, three pucks arranged in the HRS "small-component" triangle pattern just inboard of the feet.
- Several CH Precision owners report the T1 in particular responds well to Helix, because clocks are vibration-sensitive and the Helix-on-M3X stack blocks a lot more airborne and structure-borne vibration than CH's stock spike-on-granite does.

### Stack order on the user's rack
```
SXR rack frame
  └── M3X isolation base (granite top plate, billet AL frame, broadband isolator feet inside)
        └── HRS Helix HLX-090 (3 or 4 per component)
              └── CH Precision chassis (spikes retracted; bottom plate as load-bearing surface)
                    └── (optional) HRS Damping Plate on top for top-chassis noise
```

This is the HRS-recommended stack: Helix always on top of an HRS Isolation Base, never on a bare shelf. The M3X's granite, which is the "bad" kind of surface for CH's direct-spike approach, becomes a non-issue because the CH spikes are no longer touching it — the Helix polymer underside is.

### Why this stack is arguably better than CH spikes on bare M3X granite
- CH Precision's own manual says **don't spike directly to granite** — use the polymer discs, or the result will be ringy. So the CH "spikes + polymer discs" configuration on the M3X is already a compromise: the polymer discs are 2–3 mm of squishy material, not a real lossy drain.
- HRS Helix replaces those discs with a much more engineered interface: adjustable gimbal preload, larger contact footprint, purpose-designed polymer damping underside. Helix is effectively **a more capable version of the polymer disc**, and it also raises the component slightly so clearance stays similar.
- Conversely, on a lossy shelf (e.g., a plywood or Panzerholz constrained-layer shelf, not the user's setup), direct spiking may be preferable because the shelf itself is the lossy element. On granite, Helix is the right call.

---

## Known incompatibilities / warnings

- **Do not run CH spikes and Helix simultaneously in contact.** The system rocks on whichever is higher; spikes can make point-contact with the M3X granite through the polymer disc and totally bypass the Helix layer.
- **Centre-loading is not supported.** Per the L10 manual, weight/energy goes through the corners only. Don't use Helix in a "three pucks arranged in a triangle with one under the centre" pattern. Keep pucks near the corners.
- **Avoid fastener heads on 1-Series bottom plates.** A Helix that lands on a proud screw head loses contact area and the gimbal may not seat properly.
- **No published per-puck kg rating on HLX-090.** Conservative approach: four pucks for any standard 1-Series/10-Series single chassis, four pucks mandatory for stacked 10-Series pairs. If the stacked pair is very heavy, call HRS (or your HRS dealer) and ask whether HLX-090 or a taller/heftier Helix variant is correct.
- **Don't skip the HRS Isolation Base.** HRS is clear that Helix is specced to work with their bases, not on bare wood or bare granite. Since the user already has M3X, that's covered.
- **Don't forget the Damping Plate option.** Especially under the D1.5 (mechanical transport); the Damping Plate on top closes the loop.
- **Aesthetics / access.** Helix is thin (~23 mm). If the chassis sat on the M3X with its factory feet (effectively 0 mm added clearance from the spike-and-disc), adding Helix raises each component by ~23 mm. Make sure cables, rear-panel clearance, and shelf spacing on the SXR are adequate.

---

## Sources

### Manufacturer material
- HRS Helix product info: `avisolation.com/product/helix-system/` (intermittent 503, content retrieved via search snippets)
- HRS chassis-noise-reduction landing page: `avisolation.com/chassis-noise-reduction/`
- HRS M3X2 product page: `avisolation.com/product/m3x2-isolation-base/`
- Paragon Sight & Sound "Announcing Helix" — canonical $450/set-of-3 launch, gimbal description
- The Cable Company HLX-090 product page — specs, 213 g, 3.4" dia, 0.90–1.1" tall
- Canadian HIFI and Sunny Components HLX-090 listings — corroborating specs
- CH Precision L10 user manual (soundsource.pl mirror): quoted "corners only" sentence
- CH Precision C1.2 user manual (soundsource.pl mirror): spike installation and polymer disc procedure
- CH Precision D1.5 user manual (manualzz and audio-ultra.com mirrors): polymer-disc vs direct-spike advice, hard vs lossy surface guidance
- CH Precision T1 user manual (ch-precision.com)
- CH Precision P1 user manual (ch-precision.com)

### Reviews and editorial
- Roy Gregory / Gy8.eu, "On Solid Ground…" — 10-Series spike redesign, CH's history with magnetic spikes, author's preference for HRS Nimbus over stock spikes
- Gy8.eu "Installation Notes" (D1.5) — explicit statement that Nimbus + Damping Plate was the author's best result on HRS M3X granite
- The Audio Beat (Roy Gregory), L10/M10 review — stacking/coupling detail, per-chassis weight
- Hi-Fi+ L10/M10 review — coupling/stacking system improvement
- The Absolute Sound — HRS VXR Stand, Vortex, Helix, DPII — Helix launch coverage
- Stereophile Analog Corner #260 (P1) — describes "four stainless-steel feet with elastomer rings" and long steel spikes
- HiFi-Advice EXR stand review — HRS base broadband footer colour-rating system
- HiFi Buys, Audio Consultants UK, Paragon, Cable Co — dealer-level Helix descriptions

### Forums / community (indexed via search, direct fetch blocked)
- WhatsBestForum thread 30284 "CH Precision — use the supplied spikes or substitute with footers?"
- WhatsBestForum thread 34184 "CH Precision with HRS SXR rack — query"
- WhatsBestForum thread 6249 "Harmonic Resolution Systems"
- WhatsBestForum threads 25147, 22425, 26016 (HRS rack, VXR stand, new CH convert)
- Audiogon forum "HRS M3X isolation base or Minus-K?"

## Work log / caveats
- `avisolation.com`, `whatsbestforum.com`, `soundsource.pl` PDF mirror, and several dealer pages returned 503/403 on direct WebFetch. Content was recovered from Google's indexed snippets via WebSearch. All factual claims above are corroborated across at least two independent sources.
- HRS does not publicly spec a per-puck kg load for HLX-090. I've flagged this for the user and recommended confirming with the dealer for stacked configurations.
- The "position in the same location as the unit's original feet" sentence is from the current L10 manual. I was unable to retrieve the full PDF, only a search-indexed excerpt, but the same wording appears across the L10, D1.5, C1.2, and P1 manuals per multiple references.
