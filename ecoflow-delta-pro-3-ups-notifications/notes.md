# Research Notes: EcoFlow Delta Pro 3 UPS Notifications

## Goal
Find ways to get power-status / battery-low notifications from an EcoFlow Delta
Pro 3 (DP3) to hosts (servers, PCs) so they can shut down automatically during
an outage. Local preferred over cloud. User has Home Assistant. User is also
curious about the CAN bus port on the DP3.

## What I know going in
- DP3 does NOT expose a USB-HID UPS interface (newer River 3 Plus does;
  Delta Pro Ultra reportedly does too).
- DP3 has WiFi + Bluetooth (BLE) + a CAN bus expansion port used for the Smart
  Extra Battery and Power Kit / SHP gear.
- Stock cloud path: device → MQTT over TLS to `mqtt-e.ecoflow.com` → EcoFlow app.

## Connectivity surfaces inventoried

### 1. EcoFlow cloud (MQTT over TLS)
- All "official" remote control flows through the cloud broker
  `mqtt-e.ecoflow.com` / `mqtt.ecoflow.com` (TCP 8883, TLS).
- Telemetry is Protobuf-encoded; auth uses per-account credentials.
- Internet outage = no telemetry. (Not strictly fatal if the user has a small
  UPS upstream protecting the WAN gear, since DP3 transfers to battery in ~30 ms.)

### 2. Official EcoFlow Developer API
- Public REST + MQTT API: <https://developer.ecoflow.com/us/document/introduction>
- Requires accessKey/secretKey. Polling + a real-time MQTT push channel.
- DP3 is supported as a target device.

### 3. Bluetooth Low Energy (local)
- "Use without Internet" mode lets the app talk to DP3 directly via BLE.
- Two reverse-engineering efforts:
  - `nielsole/ecoflow-bt-reverse-engineering` (Delta 2-focused, older).
  - `rabits/ef-ble-reverse` (V2 protocol; targets SHP2 and Delta Pro Ultra).
- Companion HA integration: `rabits/ha-ef-ble`.
- **DP3 is not yet a supported device class** in `ha-ef-ble`, but the BLE V2
  protocol is shared across newer EcoFlow gear, so DP3 support is mostly a
  matter of someone implementing the device profile.
- BLE is fully local, no WiFi/cloud needed.

### 4. WiFi "Direct Connect" / AP mode
- DP3 can be put into a local WiFi mode reachable at `192.168.4.1:8055`.
- Talks the same protobuf/MQTT-ish protocol as cloud, but the unit gives up
  and reverts after a timeout — not a persistent option for 24/7 monitoring.

### 5. Local MQTT bypass via DNS redirection
- People have rerouted `mqtt-e.ecoflow.com` to a local Mosquitto/EMQX with a
  self-signed cert. Device connects and subscribes but "sits silently"
  without the cloud-side handshake (tolwi#261). No turnkey solution today.

### 6. CAN bus (battery/expansion port)
- DP3 has a CAN bus port used for: Smart Extra Battery, EcoFlow Power Kit gear,
  Smart Home Panel 2, generator.
- Reverse-engineering work:
  - `bulldog5046/EcoFlow-CanBus-Reverse-Engineering` — documents the PowerStream
    and original Delta Pro CAN traffic. Type-3C messages carry BMS telemetry
    (cell voltages, SoC, temperature, balance). They figured out the heartbeat
    needed to convince a PowerStream that an "official" battery is attached.
  - Pinout (PowerStream battery port): pin1=Wake, pin2=CAN-H, pin5=CAN-L,
    pin6=GND. EcoFlow LFP battery: pin1/2 are CAN-H/L. DP3's specific pinout
    isn't published but is the same family.
  - No public DP3-specific decoder yet.
- Hardware to listen: any CAN transceiver — MCP2515-based USB-CAN sticks, an
  ESP32 with a TJA1051/MCP2562 transceiver, Raspberry Pi + MCP2515 HAT, etc.
- For our UPS use case, the value of CAN bus is: locally observe live BMS
  telemetry (SoC, charge/discharge current sign tells you whether mains is
  feeding the unit) without WiFi/BLE involvement. Cost: significant
  reverse-engineering work since DP3 specifically hasn't been decoded.

## Home Assistant integrations summary

| Integration | Device path | DP3 supported | Cloud-free? | Notes |
|---|---|---|---|---|
| `tolwi/hassio-ecoflow-cloud` | EcoFlow MQTT broker | partially (community PRs, not 100%) | No | Most popular cloud integration; lots of sensors. |
| `TarasKhust/ecoflow-api-mqtt` | Official Developer API + MQTT | Yes — 40+ sensors, 13 binary sensors, 9 switches, 13 controls | No | Hybrid REST + MQTT push. Cleanest "first-party" path. |
| `foxthefox/ioBroker.ecoflow-mqtt` (via iobroker→HA bridge) | EcoFlow MQTT broker | Yes (delta3 listed) | No | Decodes Protobuf so HA can consume it. |
| `rabits/ha-ef-ble` | Local BLE | Not yet (SHP2 + DPU only) | YES | The most cloud-independent path; awaiting DP3 device profile. |
| `vwt12eh8/hassio-ecoflow` | Local TCP (direct) | Older; broke after firmware updates | partially | Historical reference only. |

Relevant DP3 sensors in cloud integrations include: AC In Power (W), AC In Voltage,
Main Battery Level (%), Charging/Discharging state, "AC connected" binary sensor,
estimated remaining time. These are the building blocks for UPS logic.

## NUT (Network UPS Tools) side

- HA core has a NUT client integration (`network UPS tools`) that pulls UPS
  variables from a `upsd` server.
- HA also has the **Network UPS Tools community add-on** which can run a NUT
  server inside Home Assistant.
- NUT ships a `dummy-ups` driver. It is normally a test fixture, but it has a
  legitimate use as a "repeater": it reads variables from a file (or another
  UPS) and re-publishes them on the NUT protocol. That means we can fabricate
  a virtual UPS whose `ups.status`, `battery.charge`, `battery.runtime`,
  `input.voltage` etc. are populated from external data.
- The bridge: a small script (or an MQTT subscriber, or a HA shell_command
  triggered on sensor change) writes the current EcoFlow values into a
  `.dev` file that `dummy-ups` polls. Then `upsd` exports a normal NUT UPS,
  and any `upsmon` client on the network treats it as a first-class UPS.
- Hosts on Linux/macOS/Windows/NAS can use `upsmon` to perform graceful
  shutdown when `ups.status` becomes `OB LB` (on-battery + low-battery).
  This is the canonical, well-understood shutdown protocol.

This is the cleanest architecture because it cleanly separates concerns:
- "How do I read the DP3?" → any of the integration paths above.
- "How do I tell N heterogeneous hosts to shut down?" → standard NUT.

## Shutdown / notification mechanics in HA itself
If a user doesn't want to set up NUT, HA can directly:
- SSH into Linux hosts and run `shutdown -h now` via `shell_command:` or the
  `command_line` integration.
- WoL is built in for power-on after the outage ends.
- For Windows, HA has `iot_link`/`pyWoL`/`winexe` or run an MQTT subscriber
  on the Windows side that listens for a shutdown topic.
- For Proxmox/TrueNAS/Synology, those run real `upsmon` already, so NUT path
  is easier than per-host SSH.

## Smart-plug fallback for "is mains alive?" signal
A plug with energy monitoring (e.g., Shelly Plug S, Athom, Sonoff S31) on the
DP3's INPUT side gives a 100%-local "grid up / grid down" signal independent of
EcoFlow firmware. Combine with the DP3 SoC from any integration to build the
UPS logic without depending on EcoFlow's "AC connected" binary sensor.

## Things ruled out / longer-term

- **CAN bus as the primary path**: feasible but high effort. There is no public
  DP3 message map. Worth pursuing only if the user enjoys reverse engineering
  or wants the most cloud-independent telemetry imaginable. The CAN port is
  also primarily an "expansion battery" port; tapping it requires either a
  break-out adapter that doesn't break the Smart Extra Battery's normal
  function (if used), or just plugging into the unused port. The
  EcoFlow LFP Battery Polarity Adapter has been used as a CAN access aid in
  the community. There's a non-trivial safety note (community references a
  protocol message that can drive capacitor voltages into "self-destruct"
  territory) — listen-only is safe; do not send blindly.

- **Pure local MQTT bypass**: blocked on cloud-side handshake; not turnkey.

## Concrete recommendation outline (for README)

1. **Today, easy**: HACS install `TarasKhust/ecoflow-api-mqtt` (or
   `tolwi/hassio-ecoflow-cloud`). Add HA automations on Battery Level and
   AC-In Power. Use SSH `shell_command:` or NUT NOTIFY → MQTT to fan out.
   This depends on EcoFlow cloud — accept that and put the WAN gear on the
   DP3 too so the cloud stays reachable during outages.

2. **Better, mostly local**: Same as 1 but back the cloud sensor up with a
   local Shelly/Athom/Sonoff energy-monitor plug on the DP3 input. HA logic
   uses the plug as the source of truth for "is the grid up?" and the cloud
   for SoC. Now the only thing the cloud has to do is report SoC — and even
   if it drops, you can fall back to time-on-battery from the plug event.

3. **NUT bridge (best for many hosts)**: Add HA's NUT Server add-on with
   `dummy-ups` set as repeater. Have a small script (or HA automation +
   shell_command) write the current SoC, AC-status and runtime into the
   `dummy-ups` data file every few seconds. `upsmon` on every Linux/Windows
   host, TrueNAS, Proxmox, Synology, etc., connects and shuts down by
   standard `OB LB` rules.

4. **Fully local future**: Help the `rabits/ha-ef-ble` project add DP3
   support, or run the BLE library yourself once the device profile lands.
   Then nothing needs the EcoFlow cloud.

5. **CAN bus side quest**: A neat project for the long game, but currently no
   off-the-shelf code. Best entry point is `bulldog5046/EcoFlow-CanBus-
   Reverse-Engineering` — read-only sniffing on the DP3 expansion port,
   contribute the DP3 message map back.
