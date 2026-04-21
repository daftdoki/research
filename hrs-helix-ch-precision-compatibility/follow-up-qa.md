# Follow-up Questions & Answers

Supplementary material to the main [investigation](README.md) on HRS HLX-090 Helix compatibility with CH Precision electronics. These questions arose after the initial research and may be useful to other owners considering the same setup.

---

## Q1. Does the point about hard granite surfaces being incompatible with the CH spikes mean that using the CH Precision factory feet with the spikes retracted would be a better solution than engaging the spikes on granite?

No — retracting the spikes and letting the chassis rest on the factory feet is not a real alternative, for a few reasons.

**The stock feet are surface-protection rings, not a tuned isolation interface.** Each CH Precision foot is a small stainless-steel ring with a thin elastomer gasket. Stereophile and Roy Gregory (Gy8) both describe them specifically that way — their job is to keep the chassis from marking a shelf when the spikes aren't yet wound down. They were not engineered as the load-bearing, vibration-draining interface. That is the spikes' job, by CH's own design. "Spikes retracted, feet bearing" is essentially an unboxing / transport configuration, not an intended operating mode.

**CH's own hard-surface recipe is still "spikes," just with polymer discs.** The manual's instruction for granite / glass / marble is to insert the supplied polymer (Delrin-type) discs between the spike tips and the shelf — not to retract the spikes and park on the feet. That "spikes + discs on granite" combination is the compromise CH itself acknowledges. It works, but it is the case where the HRS Helix — which is a much larger contact patch, gimbal-adjustable, with a purpose-designed damped polymer underside — is doing a better-engineered version of the same job.

**You also lose the precise levelling the spike system gives you.** With spikes you can bring each of four corners to equal load and get sub-millimetre levelling. Resting on the foot rings, the chassis level is whatever the granite's level is, and you lose CH's "equal resistance on all four spikes" loading discipline.

**Geometry-wise the stock feet are a pretty poor lossy interface.** A stainless ring ~1 inch across with a thin elastomer gasket puts a small, hard-bounded contact patch of rubber between two hard surfaces (aluminium chassis / granite). That's some damping, but very little travel, very little surface area, and no tuning. A Helix puck is 3.4" of purpose-damped polymer with an adjustable gimbal head pressing up against the chassis bottom — it is doing the same job an order of magnitude more deliberately.

**What you *could* do that would beat "stock feet, spikes retracted":** put the CH polymer discs (or nothing) on the granite, retract the spikes, and rest on the feet — and at that point you have "CH feet on granite with elastomer damping." It's benign, won't hurt the gear, and will sound perfectly acceptable. But you have essentially re-invented a worse Helix. On a granite-topped M3X, the Helix (or Nimbus / Vortex) is the right answer. On a lossy shelf (Panzerholz, bamboo, a constrained-layer composite), the CH spikes on direct contact would be the right answer, and neither the stock feet nor the Helix would be necessary.

**Bottom line:** retracting the spikes and riding on the feet is neither what CH intends nor what HRS intends. It's a hybrid off-label configuration that gives up the best properties of both systems. On your granite M3X stack, you are really choosing between **CH spikes + polymer discs** (CH's acknowledged compromise) and **HRS Helix on the granite** (HRS's purpose-built solution). The Helix is the stronger choice on that particular shelf.

---

## Q2. Why is Delrin used between the spikes and a granite surface when it isn't particularly associative and is a hard material itself? What does it add to just spiking directly?

The short answer is that "hardness" in the colloquial sense isn't what matters at a vibration-coupling interface. Three other things do: **acoustic-impedance mismatch, internal (viscoelastic) damping, and local conformity.**

**Delrin is hard relative to rubber, but it is an order of magnitude softer than aluminium or granite, and about two orders of magnitude lossier.** Young's modulus of Delrin (acetal) is ~3 GPa. Aluminium is ~70 GPa, granite ~50–70 GPa, hardened steel ~200 GPa. More importantly, Delrin's material loss factor (tan δ) is ~0.02–0.05, versus ~10⁻⁴ for metals and stone. At the audio frequencies CH cares about, Delrin dissipates roughly 100× – 1000× more energy per stress cycle than either the spike or the granite does by themselves.

### What Delrin actually does at the interface

1. **It breaks a matched impedance boundary into two lossy ones.** A spike tip sitting on granite is a metal-on-stone interface where the acoustic impedances are similar and the mismatch is small — a lot of energy bounces back up the spike, and energy inside the granite bounces around and bleeds back through the same point contact. Dropping a Delrin disc in the middle gives you metal/Delrin and Delrin/granite, each with a large impedance mismatch. Each boundary reflects a chunk of any wave trying to cross it, and the Delrin layer itself damps whatever does get across (in both directions). You have turned a leaky one-stage coupling into a two-stage coupling with a lossy layer between.

2. **It kills the point-contact ring.** A hardened tip on polished granite makes Hertzian contact on an area that's a few microns across, with nothing to damp it. That contact is a high-Q resonator — it has its own "pitch" and re-radiates. Delrin locally cold-conforms to the spike tip (it creeps very slowly under load), so the effective contact patch balloons to square millimetres of viscoelastic material. The contact is no longer a small elastic point; it is a larger, heavily damped interface.

3. **It provides damping without compliance.** This is the subtle bit. The natural instinct is "if damping is what I want, use something soft and sticky like sorbothane or rubber." But under a stiff chassis on a rigid spike, a soft layer would compress and rock — the chassis would micro-pivot on four squishy points and the component would lose the structural rigidity of its four-corner support. Delrin is deliberately stiff enough that it does not creep meaningfully under static load or allow the chassis to rock, but lossy enough that transient vibration energy is converted to heat as it passes through. It sits in a narrow design sweet spot: high enough modulus to keep the chassis still, high enough damping to matter, and dimensionally stable so it does not cold-flow or degrade.

### Why this matters specifically for granite

Granite is dense, stiff, and almost perfectly elastic. It accepts energy and rings back. The HRS M3X granite slab isn't really a "drain" in the lossy sense — it is a mass that stores and returns energy (and the M3X's real isolation happens below the granite, in the broadband feet inside the billet frame). So the spike/granite interface is where you want the loss to happen, because below that interface the granite will return whatever it receives. Delrin is a targeted lossy impedance transformer sitting exactly where the compromise is worst.

### Summary

Compared to spiking directly onto granite, Delrin gives you:

- a bigger effective contact patch
- two impedance discontinuities instead of one
- actual internal damping at the interface
- no metal-on-stone point-contact resonance
- no scratching of the shelf

Compared to a squishy rubber interface, Delrin gives you:

- no rock
- no creep
- no sag
- stable levelling
- still most of the damping benefit

### Why HRS Helix works better still

This is also why HRS Helix improves on the CH-Precision-supplied polymer disc. Helix is a larger-diameter engineered version of the same idea — a polymer underside against granite, a gimbal-adjusted metal top conforming to the chassis — where the polymer is chosen for even higher loss factor than Delrin and the contact patch is ~9 cm² per puck rather than a sub-cm² disc. Same physics, more of it.
