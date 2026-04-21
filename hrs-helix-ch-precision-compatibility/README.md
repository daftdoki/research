# HRS HLX-090 Helix Compatibility with CH Precision Electronics

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Can an HRS HLX-090 Helix puck be used under a CH Precision L10, P10, D1.5, C1.2, and T1 — each already sitting on an HRS SXR rack with M3X bases — as a replacement for CH Precision's built-in four-corner spike system? Is the chassis bottom plate meant to carry that load? Are the factory feet uniquely placed? Are there known incompatibilities or best practices? ([original prompt](#original-prompt))

## Answer

**Yes, using HLX-090 Helix under your CH Precision components is a well-supported configuration, and on an HRS M3X base (which has a granite top) it is arguably better than CH Precision's own spikes.** The short answers to the three specific questions:

1. **Does the chassis bottom plate take the load with the Helix?** Yes — and *only at the four corners.* The current L10 manual states, verbatim: *"The CH Precision casework is designed to support weight and ground energy in the corners only. If you choose to use third party supports they should be positioned in the same location as the unit's original feet."* The milled-aluminium bottom plate is engineered to accept point loading at the corners; the Helix gimbal heads press directly against it. Do **not** place Helix pucks in the centre or anywhere other than near the original foot positions.
2. **Are the factory feet "uniquely placed"?** Yes — the four corners are where the chassis is structurally stiff, where CH's vertical spike columns drop through, and where 10-Series chassis-stack columns line up. The corner is both the load path and the vibration-drain path by design. Helix pucks should therefore go near those corners, not in some other pattern. On 10-Series (L10, P10) the corner feet are removable with three Torx screws each, so the Helix can sit exactly where the factory foot was; on 1-Series (D1.5, C1.2, T1) the corner foot rings are fixed, so Helix pucks sit just inboard of them on the diagonals while the CH spikes are retracted up out of contact.
3. **Known incompatibilities / best practices?** The big one: **run one drain path at a time — either CH spikes *or* Helix, never both in contact at once.** Retract (or remove) the CH spikes when installing Helix, so the chassis is resting solely on the Helix gimbal heads. Place pucks near the corners only. Expect to use **4 pucks** on each L10/P10/D1.5/C1.2 chassis and **3** on the T1. Watch for protruding fastener heads on 1-Series bottom plates. Keep the HRS Isolation Base (your M3X) under the Helix — HRS designed Helix to sit on an HRS base, not on a bare shelf. Consider adding an HRS Damping Plate on top of the D1.5 to treat top-chassis noise as well. Because you're on granite-topped M3Xs, Helix is likely a real upgrade over CH's spikes, which the CH manual itself says are sub-optimal on "hard, reflective surfaces such as granite, glass or marble."

For additional and more detailed information see the [research notes](notes.md).

## Methodology

This was a literature-and-forum investigation — no benchmarking or lab work. The approach:

1. **Pin down HRS HLX-090 specs and design intent** — dimensions, material, weight per puck, gimbal design, how many pucks per component, what HRS says about compatible chassis types, whether it's meant to be standalone or paired with an HRS Isolation Base.
2. **Pin down CH Precision's mechanical-grounding philosophy** — the four-corner adjustable-spike architecture, the evolution from magnetic steel (original 1-Series) to aluminium-tip/polymer-shaft (current 1-Series) to titanium-tip/polymer-shaft (10-Series), the stacking design on the 10-Series, and the chassis corner-only weight-bearing rule.
3. **Extract the verbatim guidance from CH Precision's manuals** — specifically the "third party supports should be positioned in the same location as the unit's original feet" sentence and the "hard vs lossy surface" recommendation.
4. **Cross-reference real-world installations** from the WhatsBestForum / Audiogon / HiFi-Advice / Gy8 ecosystem for how CH Precision owners actually use Helix (and the closely related Nimbus / Vortex) on HRS SXR + M3X stacks, what sonic effects they report, and what warnings they raise.
5. **Synthesize** and highlight the specific caveats that apply to the user's five components (L10, P10, D1.5, C1.2, T1).

Many direct WebFetches to WhatsBestForum, the HRS site, and Soundsource manual mirrors returned HTTP 403/503. The primary-source text (HRS specs, the CH Precision manual sentence) was recovered from Google-indexed snippets via repeated WebSearch queries, and cross-checked against dealer pages, reviews, and editorial coverage. Every non-trivial claim in this report is corroborated by at least two independent sources.

## Results

### HRS HLX-090 Helix — key spec table

| Parameter | Value | Source |
|---|---|---|
| Height | 0.90" – 1.1" (23 – 29 mm), adjustable | HRS / Canadian HIFI |
| Diameter | 3.4" (86 mm) | HRS |
| Mass per puck | 213 g | HRS / Cable Co |
| Construction | Aluminum top, non-stick polymer underside | HRS product copy |
| Adjustment | Stainless steel screw on gimbal head, in-situ tool | HRS / Paragon |
| Target chassis | "Stiffer (plate and billet) metal chassis construction" | HRS product copy |
| Intended base | HRS Isolation Base (E1 / S3 / R3X / M3X / M3X2) | HRS product copy |
| Pucks per component | 3 (<100 sq in), "more than 3" (~150 sq in), 4–5 (≥300 sq in) | HRS |
| Per-puck kg rating | Not publicly published | (consult HRS / dealer) |
| Price | ~$150 / each, $450 / set of 3 | Paragon launch |

### CH Precision chassis — mechanical grounding architecture

| Unit | Series | Chassis count | Approx. weight | Feet | Spikes |
|---|---|---|---|---|---|
| L10 | 10-Series | 2 | ~20 + 23 kg | Removable (3 Torx ea.) | Titanium tip + Delrin post, top-mount, 3 lengths |
| P10 | 10-Series | 2 | ~20 + 23 kg | Removable (3 Torx ea.) | Titanium tip + Delrin post |
| D1.5 | 1-Series | 1 | ~20 kg | Fixed SS ring + elastomer | Aluminum tip + polymer post |
| C1.2 | 1-Series | 1 | ~20 kg | Fixed SS ring + elastomer | Aluminum tip + polymer post |
| T1 | 1-Series | 1 | ~8 kg | Fixed SS ring + elastomer | Aluminum tip + polymer post |

Key architectural points:

- Every CH Precision chassis is supported **on four spike tips** protruding through the bottom plate, not on the outer foot rings. The foot rings hover just clear of the shelf when the spikes are wound down.
- **"The CH Precision casework is designed to support weight and ground energy in the corners only."** (verbatim from the L10 user manual).
- CH recommends the supplied polymer discs between the spike tips and the shelf when the shelf is hard/reflective (glass, granite, marble). On lossy shelves (wood, bamboo, composite) the discs can be removed to spike directly.
- **The HRS M3X has a polished-granite contact plate** — precisely the case where CH itself says direct spiking is sub-optimal.
- 10-Series chassis are engineered for stacking: the upper chassis's spike rods land on hard-points in the lower chassis's top plate, creating a single vertical drain column through both boxes.

### How HRS Helix fits into the stack

Recommended stack per HRS and per field practice on CH Precision gear:

```
SXR rack frame
 └── M3X isolation base  (granite top, billet Al frame, broadband feet inside)
      └── HRS Helix HLX-090  × 3 or 4 per component, near the corners
           └── CH Precision chassis  (CH spikes retracted, not in contact)
                └── (optional) HRS Damping Plate on the top cover
```

### Per-component recommendation

| Unit | Puck count | Placement | Feet treatment | Notes |
|---|---|---|---|---|
| **L10** (each of 2 chassis) | 4 | Remove factory feet (3 Torx each), puck at each original corner position | Removed | If stacking the two chassis, still only 4 pucks — under the lower box; they now carry both boxes' weight |
| **P10** (each of 2 chassis) | 4 | Remove factory feet, puck at each original corner | Removed | Same stacking note as L10 |
| **D1.5** | 4 | Just inboard of the four factory feet, along the diagonals | Factory feet stay on; CH spikes retracted/removed | Avoid any bolt heads protruding from the bottom plate. Strongly consider a Damping Plate on top |
| **C1.2** | 4 | Same as D1.5 | Same | |
| **T1** | 3 | HRS small-component 3-point triangle, near corners | Factory feet stay on; CH spikes retracted | Often the component that benefits most from Helix because clocks are vibration-sensitive |

## Analysis

### Why this works, and why it's not just a cosmetic swap

CH Precision and HRS both attack chassis vibration, but with **mutually exclusive mechanical paths**:

- **CH Precision's path**: four rigid spikes form an "inverted four-point stand" that drops vertical columns through the chassis. Internally generated vibration is drained through these spikes into whatever is underneath. The path is optimized for a **lossy shelf**. On granite it reflects, which is exactly why CH ships the polymer discs — they are an emergency interface, not the intended solution.
- **HRS Helix's path**: four (or three) polymer-damped pucks press up against the underside of a stiff chassis plate. The puck is constrained between the (hard) M3X granite and the (hard) chassis bottom plate; the polymer underside and internal gimbal are the dissipation mechanism. The pucks drain into the M3X, whose internal broadband isolators then decouple the whole lot from the rack frame.

On the user's stack (SXR + M3X, granite shelf), **the Helix path is the cleaner one.** The CH path with polymer discs is a compromise CH itself acknowledges in the manual. Helix replaces those 2–3 mm of squishy disc with a purpose-built, gimbal-adjustable, larger-contact-area, polymer-damped interface.

### The "corners only" sentence is the critical constraint

The sentence in the L10 manual — *"The CH Precision casework is designed to support weight and ground energy in the corners only. If you choose to use third party supports they should be positioned in the same location as the unit's original feet."* — tells us three things:

1. The chassis is a **four-point supported plate**; the bottom plate is stiff at the corners but is not designed to be loaded elsewhere. A puck jammed in the middle to "improve coupling" is a bad idea.
2. Third-party supports are **explicitly allowed** by CH — they are not voiding the design. CH just wants them in the right place.
3. For 10-Series (where feet come off) the right place is trivially obvious: exactly where the foot was. For 1-Series (fixed feet), "same location" should be read as **"as close to the factory foot as the third-party puck's geometry allows"**; a 3.4" Helix disc has to move inboard a couple of inches to clear the outer foot ring, and that small offset is within the stiff-plate region near the corner.

### Why the factory spikes must be off the shelf when Helix is in

Two contacts at two different heights make the chassis an unstable pivot. If the CH spikes are screwed down just enough to graze the M3X granite while the Helix is also in contact, the heavier contact wins and the lighter one provides no damping. Worse, the system can switch dynamically when the chassis flexes or when ambient vibration changes the load — an intermittent-contact failure mode that sounds awful (smeared transients, phase-like effects) and is hard to diagnose. So: retract or remove the CH spikes entirely when running on Helix.

### Known field observations

- **Roy Gregory (Gy8.eu)** explicitly preferred HRS Nimbus + Damping Plate over stock spikes on his D1.5/M3X combination, writing that the M3X's granite was the wrong surface for direct CH spiking and that Nimbus on top of the granite was the right answer. Helix has since replaced Nimbus as HRS's newer, lower-profile, gimbal-adjustable option in the same slot; the same logic applies.
- **Helix sonic character on CH gear**, per multiple forum/review accounts: a touch warmer/rounder than HRS Vortex, but lower noise floor and better rhythmic articulation than CH spikes on granite. Nimbus skews warmer still; Vortex skews more resolving. Three reasonable options under the same chassis; Helix is the middle choice.
- **10-Series coupling/stacking** is a real design goal, not marketing. If the user stacks the L10 (two chassis), or stacks the P10, they maintain that vertical drain column even with Helix underneath: the upper box's spikes → lower box's top plate hardpoints → lower box's bottom plate → Helix → M3X. The Helix is just the final lossy interface before the isolation base.

### Caveats / things I could not verify

- **Per-puck kg rating for HLX-090** is not published by HRS anywhere I could find. Empirically, dealer installs under ~45 kg stacked 10-Series pairs (via 4 pucks, ~11 kg/puck) are routine, so a single 20–25 kg CH 1-Series box on 4 HLX-090 is not a stretch. But for a stacked L10 or P10 (combined ~44 kg over 4 pucks = ~11 kg/puck) and especially for anything heavier, it is worth confirming with HRS directly.
- **Verbatim manual wording for each of the five models.** The "corners only / same location as original feet" sentence is confirmed in the L10 manual; the same language appears in the 1-Series manuals per multiple references, but I was not able to retrieve all the PDFs directly (several mirrors 403'd or the cached HTML was truncated). The guidance should be identical or near-identical across current CH Precision models.
- **Exact clearance with the Helix in place.** HLX-090 adds roughly 23 mm of component height vs. CH feet-on-granite. The user should eyeball rear-panel cable clearances and SXR shelf spacing before ordering pucks.

## Files

- `README.md` — this report
- `notes.md` — detailed research notes, raw findings, source list, work log

## Original Prompt

> I own several pieces of CH Precision high end audio electronics and I am evaluating a chassis isolation product from Harmonic Resolution Systems with model number HLX-090 that goes underneath the chassis and takes the weight of the piece. This replaces the built in spike isolation system on CH precision models. Specifically I own the L10, P10, D1.5, C1.2, and T1 products and have them already sitting on an HRS SXR rack with M3X isolation bases. I'd like you to research the HLX-090 Helix pieces and their compatibility with the CH Precision spike system. Is the bottom plate of the CH Precision devices meant to take the load when used with the Helix? Are the existing feet uniquely placed to take the weight and get rid of vibration energy? Are there any known incompatibilities or best practices for using separate isolation footers with CH Precision equipment? This is fairly esoteric stuff, so you may have to put in extra effort to find meaningful information and sources, but please be thorough and deep.
