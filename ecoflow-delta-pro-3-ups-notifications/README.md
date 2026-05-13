# EcoFlow Delta Pro 3 as a Notifying UPS: Architectures for Auto-Shutdown

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

The EcoFlow Delta Pro 3 (DP3) acts as an excellent online-style UPS — it
transfers to battery in ~30 ms during a mains failure — but, unlike traditional
UPSes (and unlike newer EcoFlow units such as the River 3 Plus and Delta Pro
Ultra), it does **not** expose a USB-HID UPS interface. That means there is no
out-of-the-box way for a host plugged into the DP3 to know that mains has
failed and that the battery is dropping, and therefore no way for that host to
shut down cleanly before the DP3 runs out.

This report investigates **how to bridge that gap**, with a preference for
local control over EcoFlow cloud, and with an eye on the DP3's CAN bus port
and the user's Home Assistant deployment. See the [Original Prompt](#original-prompt).

## Answer / Summary

**Recommended architecture (most pragmatic, deploys today):**

1. Add a Home Assistant integration to read the DP3 — the most complete option
   today is **`TarasKhust/ecoflow-api-mqtt`** (official EcoFlow Developer API +
   MQTT push, 40+ DP3 sensors), with **`tolwi/hassio-ecoflow-cloud`** as an
   alternative. Both depend on the EcoFlow cloud.
2. Put an inexpensive local **energy-monitoring smart plug** (Shelly Plug S,
   Athom, Sonoff S31, etc.) on the wall outlet feeding the DP3. This gives a
   100% local, instant "is grid up?" signal that is independent of EcoFlow's
   cloud and firmware.
3. Run the **Home Assistant Network UPS Tools (NUT) add-on** with a `dummy-ups`
   "repeater" driver. A short HA automation writes the current AC-in status
   (from the smart plug), battery SoC and runtime estimate (from EcoFlow)
   into the `dummy-ups` data file. The NUT server then publishes a perfectly
   ordinary NUT UPS that any host on the network — Linux, Windows, TrueNAS,
   Synology, Proxmox — can monitor with stock `upsmon` and shut down on
   `OB LB` (on-battery, low-battery).
4. Optionally, for hosts you don't want to run `upsmon` on, fire SSH
   shell commands, MQTT messages, or HTTP webhooks from HA on the same
   triggers.

**Why this combo:** the cloud integration gives you accurate SoC and a rich
sensor set, the smart plug gives you a cloud-independent "mains lost" signal,
and the NUT bridge lets every host use the industry-standard UPS shutdown
protocol that already works everywhere.

**Going more local in the future:** the most promising path to a fully
cloud-free DP3 is the `rabits/ef-ble-reverse` / `rabits/ha-ef-ble` Bluetooth
project. It already speaks EcoFlow's BLE V2 protocol locally for the SHP2 and
Delta Pro Ultra; DP3 needs its device profile contributed. The same protocol
family is used, so it's tractable rather than green-field.

**On the CAN bus port:** technically interesting and *would* be the most
cloud-independent telemetry channel, but no public DP3 message map exists yet.
The `bulldog5046/EcoFlow-CanBus-Reverse-Engineering` project has decoded
PowerStream and original Delta Pro traffic (type-3C BMS messages with SoC,
voltage, temperature, balance) and is the right starting point. Treat this as
a longer-term DIY project, listen-only at first — community reports indicate a
specific protocol message can drive the unit's capacitor voltage into "boom"
territory if sent blindly.

For additional and more detailed information see the [research notes](notes.md).

## Methodology / Experiment

This was a desk research investigation, not a hands-on build. I surveyed:

- The DP3 user manual and EcoFlow's developer documentation to inventory
  connectivity surfaces.
- Active Home Assistant integrations for EcoFlow gear (HACS, GitHub) for
  capabilities, DP3 coverage and cloud dependence.
- Community reverse-engineering projects (BLE, CAN bus, local MQTT
  interception) for what is solved vs. still open today.
- Network UPS Tools' `dummy-ups` driver and HA's NUT integrations, looking
  for a way to surface DP3 state as a standard UPS that any host can
  consume.
- Community write-ups about turning EcoFlow River 3 Plus into a NUT-driven
  UPS (relevant to the DP3 because it shows what the standard path looks
  like when HID *is* available, and what we have to substitute for it).

## Results

### Connectivity surfaces inventoried on the DP3

| Surface | Local? | Status today | Notes |
|---|---|---|---|
| EcoFlow MQTT broker (cloud) | No | Production | Protobuf payloads, TLS, account creds. |
| Official EcoFlow Developer API | No | Production | Polling REST + MQTT push, supports DP3. |
| Bluetooth LE | Yes | Partially reverse-engineered for SHP2/DPU; DP3 device profile not yet contributed | Same V2 protocol family. |
| WiFi "Direct Connect" / AP (192.168.4.1:8055) | Yes | Works but the mode auto-disables after a timeout | Not suitable for 24/7 monitoring. |
| Local MQTT via DNS redirection of `mqtt-e.ecoflow.com` | Yes | Devices connect, subscribe — but stay silent without the cloud-side handshake. Not turnkey. | Tracked in `tolwi/hassio-ecoflow-cloud#261`. |
| CAN bus (expansion port) | Yes | DP3 not decoded publicly; PowerStream & DP1 are partially decoded by `bulldog5046/...` | Type-3C messages carry BMS telemetry. |
| USB-HID UPS | — | **Not present on DP3** (present on River 3 Plus, reportedly on DP Ultra) | This is why the user needs this report. |

### Existing Home Assistant integrations

| Integration | DP3 support | Cloud-free | Best for |
|---|---|---|---|
| `TarasKhust/ecoflow-api-mqtt` | Full, official API | No | Cleanest first-party path, rich sensors |
| `tolwi/hassio-ecoflow-cloud` | Partial / community | No | Largest community, lots of devices |
| `foxthefox/ioBroker.ecoflow-mqtt` (via iobroker-HA bridge) | Yes (delta3 listed) | No | If you already run iobroker |
| `rabits/ha-ef-ble` | Not yet — SHP2 + Delta Pro Ultra implemented | **Yes** | Future fully-local path |
| `vwt12eh8/hassio-ecoflow` | Older, broken by firmware updates | Partial | Historical reference only |

Relevant DP3 sensors from the cloud integrations include AC In Power (W), AC
In Voltage, Main Battery Level (%), Charging/Discharging state, an "AC
connected" binary sensor, and estimated remaining runtime — everything needed
to build UPS logic.

### NUT bridge feasibility

`dummy-ups` is a NUT driver that reads UPS variables from a flat data file (or
another `upsd`) and republishes them. That's the hinge: anything that can keep
the file up to date — a tiny Python script subscribed to MQTT, a HA
`shell_command` triggered on state changes, even a cron job — can synthesise a
fully functional NUT UPS out of the DP3's sensor stream.

A minimal data-file shape suitable for `upsmon` looks like:

```
ups.status: OL          # or "OB" when smart plug shows no power, "OB LB" when SoC < threshold
ups.model: EcoFlow Delta Pro 3
battery.charge: 73
battery.charge.low: 25
battery.runtime: 4200   # seconds, from EcoFlow's remaining-time sensor
input.voltage: 121
```

Hosts then run standard `upsmon` against this virtual UPS — there is nothing
EcoFlow-specific on the host side, which is the point.

### Trigger logic (what HA needs to decide)

A robust "is the DP3 actually on battery?" signal combines several inputs:

- Smart plug on the wall outlet feeding DP3: instantaneous, local truth that
  mains is gone.
- DP3 AC In Power dropping to 0 W (via cloud integration): confirms it.
- DP3 charging state transitioning to "discharging": confirms it.

Use whichever responds first; a 5–15 s debounce avoids brief glitches.

Battery thresholds typical for a UPS workflow:
- 30%: announce, send a soft warning push.
- 20%: issue `OB LB` (low-battery) — `upsmon` clients begin graceful shutdown.
- 10%: hard kill any stragglers, then power off DP3 AC outputs (DP3 itself
  has scheduled power-off in the EcoFlow app/API).

### CAN bus reality check

- The CAN port on DP3 is primarily the bus connecting the unit to its Smart
  Extra Battery and Power Kit / SHP2 gear. Public reverse-engineering work
  (`bulldog5046/EcoFlow-CanBus-Reverse-Engineering`) covers PowerStream and
  the original Delta Pro: pin1=Wake, pin2=CAN-H, pin5=CAN-L, pin6=GND on the
  PowerStream battery port; an LFP Battery Polarity Adapter is the
  community's preferred breakout. DP3 is the same family but the message map
  has not been published.
- For UPS purposes, the win on CAN is: SoC and AC-input current sign,
  observed locally, with no WiFi, no BLE, no cloud. The loss is: someone has
  to do the reverse engineering. Listen-only sniffing is safe; transmitting
  is not (the protocol includes a command that can drive capacitor voltages
  destructively).
- If you want to start: ESP32 + TJA1051 transceiver, or a USB-CAN dongle, in
  parallel between DP3 and the Smart Extra Battery, with candump logging.

## Analysis

The reason there isn't a clean answer "off the shelf" is that EcoFlow's
strategic position has been to push everything through their cloud. The most
"first-party" thing you can do is the official Developer API + MQTT, which the
HA community has wrapped nicely but which still requires reachability to
`mqtt.ecoflow.com`. That is fine *in practice* if you put your modem, router
and an HA host on the DP3 itself — the cloud round-trip survives the outage
exactly because the DP3 is keeping the WAN gear alive. Most home labs already
do this.

Going **truly local** (no cloud at all) is achievable in two ways today:

- **The cheap and reliable way:** offload "is mains alive?" to a smart plug
  with energy monitoring on the input side. You no longer need cloud for the
  *event*. You still want SoC and runtime, but a degraded mode where you
  assume worst-case runtime is acceptable for the few seconds of cloud
  unavailability that might occur during a transition.
- **The proper way:** the BLE V2 reverse-engineering project (`rabits/ef-ble-
  reverse` and its HA integration `rabits/ha-ef-ble`). Already works for the
  Smart Home Panel 2 and Delta Pro Ultra; DP3 is the next obvious addition.
  Contributing a DP3 device profile is the right long-term investment for a
  user who wants their home lab independent of EcoFlow's servers.

The **CAN bus angle is the most interesting from a hacker's perspective** —
it would give listen-only, instantaneous, fully-local SoC/AC telemetry with
no radio in the loop at all — but it is also the highest-effort path because
nobody has published a DP3 decoder yet. If the user has the appetite, an ESP32
with CAN and an SD logger sitting on the DP3 ↔ Smart Extra Battery cable will
collect the corpus needed to decode it.

The **NUT-bridge architecture** is the load-bearing idea in the recommendation
regardless of which sensor path is used, because it cleanly decouples "how do
I read EcoFlow?" from "how do I tell hosts to shut down?". Every machine on
the network can shut down with stock, well-debugged software (`upsmon`) that
already integrates with TrueNAS, Synology, Proxmox, systemd, Windows. You
swap out the upstream sensor source later (cloud → BLE → CAN) without
touching any host.

### Architecture diagram (text)

```
                 ┌────────────────────┐
   wall outlet ──┤ Shelly/Athom plug  │── DP3 INPUT
                 └─────────┬──────────┘
                           │ (local, instant "mains lost")
                           ▼
                 ┌────────────────────┐        cloud:           ┌──────────────┐
                 │  Home Assistant    │ ◀─MQTT/REST───────────▶│ EcoFlow API  │
                 │  (HA OS or Core)   │                         └──────────────┘
                 │                    │
                 │  • EcoFlow sensors │
                 │  • plug sensor     │
                 │  • automation:     │
                 │    write UPS state │
                 │    into dummy-ups  │
                 │    data file       │
                 └─────────┬──────────┘
                           │
                 ┌─────────▼──────────┐
                 │ NUT add-on (upsd)  │  ← dummy-ups driver, reads HA-written file
                 └─────────┬──────────┘
                           │ NUT protocol (TCP 3493)
       ┌───────────────────┼─────────────────────┐
       ▼                   ▼                     ▼
   upsmon on           upsmon on             upsmon on
   Linux server        TrueNAS/Synology      Proxmox/Windows
       │                   │                     │
       └─ shutdown -h now ─┴── safe-shutdown ────┘
```

## Files

- `README.md` — this report.
- `notes.md` — full working notes from the investigation.

## Original Prompt

> I have an EcoFlow delta pro 3 that I use as a UPS for home electronics and
> servers. One of the features that I wish it had was the ability to notify
> my hosts of its power status so that I could automatically shut them down
> when the battery is low during a power outage. Some of the newer EcoFlow
> power stations have a USB HID connection for this signaling but mine does
> not. Can you research ways that I could accomplish a similar functionality?
> Local functionality is preferred over relying on connectivity to cloud
> services. I also noticed that the delta pro 3 has a CAN bus port and wonder
> if that could somehow be utilized? I use home assistant as well if that
> helps but I'm open to all suggestions.
