# Bambu Labs H2D Camera Access - Research Notes

## Question
Can the Bambu H2D built-in camera be accessed outside the Bambu apps (Bambu Studio / Handy)?
Options to investigate:
- RTSPS / ONVIF direct stream
- Home Assistant integrations
- Frigate / Blue Iris / Scrypted / go2rtc / security camera NVRs
- MQTT API / Python libraries

## Short answer

**Yes.** The H2D's built-in chamber/live view camera exposes an RTSPS (RTSP over
TLS) stream on the local network. It's the same basic mechanism used on the X1
Carbon. You flip **"LAN Only Liveview"** on the printer and then you can pull
the stream from any RTSP-compatible tool: VLC, ffmpeg, go2rtc, Frigate, Scrypted,
Blue Iris, OctoEverywhere/OctoApp, etc. Home Assistant integration works via
the `ha-bambulab` HACS integration, which creates a camera entity pointed at
the same RTSPS URL (and users typically route it through go2rtc/WebRTC Card
for lower latency).

### Stream details (the key facts)

- **URL:** `rtsps://bblp:<ACCESS_CODE>@<PRINTER_IP>:322/streaming/live/1`
- **Username:** always `bblp`
- **Password:** your printer's 8-char LAN Access Code
- **Port:** TCP 322
- **Protocol:** RTSPS (RTSP-over-TLS), not plain RTSP
- **Codec:** H.264 (older Bambu camera firmware used a non-standard variant, but
  X1/H2D series have been working fine in VLC/ffmpeg for a while now)
- **Firmware minimum:** 01.06.00.00+ (enables the local RTSPS stream feature at
  all; H2D ships with much newer firmware)
- **LAN-only:** there is no cloud/internet exposure of the raw stream. You'd
  need a VPN or a bridge (like OctoEverywhere, which runs locally and relays
  the stream upstream) to view it off-network.

### Caveats specific to H2D

1. **"LAN Only Liveview" toggle is REQUIRED.** On H2D/H2S (and P2S), this is a
   specific setting under the LAN Mode settings page on the printer touchscreen.
   You do NOT have to enable full LAN-only mode — the liveview toggle is
   independent. Cloud-mode Bambu Studio/Handy continues to work normally
   alongside it.
2. **Regional firmware gate.** Bambu has rolled the liveview feature out at
   different times by region. Early H2D firmware in some regions had the
   feature disabled pending software updates. As of firmware 01.03.xx and
   later it's broadly available.
3. **Toolhead camera is NOT on RTSPS.** The H2D has TWO cameras: the main
   chamber "live view" camera AND a separate toolhead (nozzle-mounted) 1080p
   camera used for calibration, nozzle offset, and code recognition. Only the
   chamber camera is exposed via the public RTSPS endpoint. The toolhead
   camera feed was still being added to Bambu Studio itself at the time of
   writing and is not reachable via a documented LAN API.
4. **Single camera live view confirmed.** Forum threads (community forum
   topic 165000, "Does H2D have only one live view camera?") confirm that for
   live viewing purposes only one camera is user-facing on RTSPS.

## Work log

### 2026-04-11 - initial searches

Searched for:
- "Bambu Lab H2D camera RTSP stream access Home Assistant 2026"
- "Bambu Lab printer camera LAN mode jpeg stream 990 port"
- Various follow-ups on ha-bambulab, go2rtc/Frigate, Scrypted.

Key findings:

- **ha-bambulab setup docs (docs.page/greghesp/ha-bambulab/setup):** Explicitly
  lists H2D / H2S support and tells users to enable "LAN Only Liveview" to
  expose the RTSPS stream locally. Independent of general LAN mode.
- **printerhive.com H2D guide:** Confirms enabling LAN Only Liveview is "the
  most critical step" for external access. Also mentions Developer Mode being
  on as a prerequisite in their workflow.
- **BambuBoard project's VIDEO_STREAMING_SETUP.md:** Clean reference for the
  URL format: `rtsps://bblp:<access_code>@<ip>:322/streaming/live/1`.
  Verified works with VLC and ffmpeg on X1/H2D.
- **Bambu Studio issue #1536 "RTSP Feed for printer cameras":** Community has
  been pushing for an officially documented endpoint for a while. Bambu's
  stance is the RTSPS feed IS the supported path; they just don't broadly
  document it.
- **go2rtc + Frigate:** Several users restream the Bambu RTSPS feed through
  go2rtc to get WebRTC / HLS / MJPEG / snapshot outputs and to feed Frigate
  for motion detection or recording. A known discussion (blakeblackshear/
  frigate #19832) reports "garbled in Frigate but fine in VLC" — the workaround
  is to have go2rtc re-encode with ffmpeg to a standard H.264 profile that
  Frigate's pipeline is happy with.
- **Scrypted:** Koush / Scrypted discussion #1687 and a blog post from
  tyler-wright.com "Stream Bambu Lab X1C Camera to Scrypted" show Scrypted
  can ingest the same RTSPS URL and re-expose it to HomeKit/Google/Alexa.
  Same approach works for H2D.
- **ha-bambulab Home Assistant integration:** First H2D support landed
  around v2.1.11 ("First attempt at H2D support"). Issue #1378 "Cover image
  and Camera not working for my H2D" was fixed in later 2.1.x releases.
  Issue #1627 documents the general workaround for P2S/H2D/H2S: route through
  go2rtc + WebRTC Card for reliability and sub-second latency; the built-in
  HA camera entity uses HLS which has 3-8s latency.
- **OctoEverywhere / OctoApp:** Officially support Bambu Lab printers
  including H2D. They run a local bridge that pulls the RTSPS feed and
  relays it securely to their cloud so you can view the camera remotely
  without exposing RTSPS to the internet. Notifications, AI Gadget failure
  detection, Quick View all work with the stream.
- **bambulabs_api Python library (BambuTools/bambulabs_api on PyPI):**
  Provides `printer.get_camera_image()` but as of the latest docs X1/H2D
  camera integration was still flagged as "not fully tested". The library
  is more oriented around MQTT status + FTP than the RTSPS video stream.
- **Bambu Lab security white paper:** Confirms that the local-network
  protocols are "SSDP, MQTTs, FTPs, and RTSPs" — all TLS-protected and
  authenticated. So the camera endpoint is part of the documented security
  model, just not heavily advertised to end users.

### Practical recipes gathered

**Quick test with VLC (what you should try first):**
```
vlc rtsps://bblp:ACCESSCODE@192.168.1.X:322/streaming/live/1
```
If that works, everything else will.

**Quick test with ffmpeg:**
```
ffmpeg -i "rtsps://bblp:ACCESSCODE@192.168.1.X:322/streaming/live/1" \
  -t 10 -c copy test.mp4
```

**go2rtc config snippet (what most HA users do):**
```yaml
streams:
  h2d_chamber:
    - ffmpeg:rtsps://bblp:ACCESSCODE@192.168.1.X:322/streaming/live/1#video=h264#hardware
```
Wrapping it with `ffmpeg:` + `#video=h264` forces re-encode, which fixes the
"garbled in Frigate" problem.

**Home Assistant configuration.yaml (generic_camera + go2rtc):**
```yaml
camera:
  - platform: generic
    name: H2D Camera
    stream_source: rtsps://bblp:ACCESSCODE@192.168.1.X:322/streaming/live/1
    verify_ssl: false
```
But you really want to use the `ha-bambulab` HACS integration — it
auto-creates the camera entity along with a mountain of other sensors
(nozzle temp, bed temp, print progress, HMS alerts, AMS slots, etc.)
and keeps the access code handling clean.

### Connectivity checklist (when it doesn't work)

1. Firmware >= 01.06.00.00 (H2D ships newer, not an issue in practice)
2. "LAN Only Liveview" enabled on printer (Settings > General / Network)
3. `nc -zv <printer_ip> 322` returns open
4. Access code is current (Bambu regenerates it in some cases)
5. No VLAN separating HA server from printer
6. ha-bambulab >= 2.1.11 if using that integration
7. If going through Frigate and video is garbled, route through go2rtc with
   ffmpeg re-encode.

## Tools / ecosystems that work with the H2D stream

| Tool | How it connects | Notes |
|------|-----------------|-------|
| VLC | Direct RTSPS URL | Simplest sanity check |
| ffmpeg | Direct RTSPS URL | For recording, conversion, re-encode |
| Home Assistant (ha-bambulab HACS) | RTSPS + HLS proxy | Official community integration |
| Home Assistant (generic camera) | RTSPS URL directly | Fallback if HACS integration doesn't fit |
| go2rtc | RTSPS → WebRTC/HLS/MJPEG | Best latency; used as a hub for other tools |
| Frigate | Via go2rtc | Works, use ffmpeg re-encode to avoid garble |
| Scrypted | RTSPS plugin | Re-exposes to HomeKit, Google, Alexa, Ring |
| Blue Iris / Synology Surveillance / Unifi Protect | Generic RTSPS camera | Works; treat it as a generic ONVIF-less RTSPS cam |
| OctoEverywhere | Local bridge reads RTSPS | Official Bambu support; gives you remote viewing + Gadget AI |
| OctoApp | Local bridge or OctoEverywhere | Mobile apps with multicam |
| bambulabs_api (Python) | MQTT + snapshot helpers | H2D support flagged as untested as of latest versions |

## What DOESN'T work / isn't available

- **ONVIF:** The camera does NOT speak ONVIF. It's a plain authenticated RTSPS
  stream, so any NVR that strictly requires ONVIF discovery won't find it. Add
  it as a "generic RTSP/RTSPS" camera instead.
- **HTTP MJPEG / JPEG snapshot endpoint:** There is no documented
  `http://printer/snapshot.jpg` endpoint. Snapshots have to come from decoding
  an RTSPS frame (which ha-bambulab, OctoEverywhere, and go2rtc all do for
  you). Bambu Studio itself has a separate cover-image / thumbnail mechanism
  that rides on MQTT + FTP and is not the camera feed.
- **Toolhead camera via RTSPS:** Not exposed. Only the chamber / live view
  camera is.
- **Plain (non-TLS) RTSP:** Earlier firmwares used an even more exotic
  Bambu-proprietary stream. Current firmware exposes RTSPS only; plain RTSP
  does not work.
- **Remote (non-LAN) access to the raw stream:** The RTSPS endpoint is LAN-only
  by design. If you want remote viewing you either: VPN into your LAN, use
  OctoEverywhere/OctoApp as a local bridge, or use the Bambu Handy app with
  cloud mode.

## References

- ha-bambulab setup docs (docs.page/greghesp/ha-bambulab/setup) — H2D/H2S camera setup
- BambuBoard/VIDEO_STREAMING_SETUP.md — URL format + VLC/ffmpeg examples
- Printerhive H2D camera activation guide
- Frigate + go2rtc docs on Bambu cameras
- Scrypted discussion #1687 — Bambu Lab 3D Printer Camera plugin
- tyler-wright.com — Stream Bambu Lab X1C Camera to Scrypted
- Bambu Studio issue #1536 — community request for documented RTSP feed
- Bambu Studio issue #2146 — URL format discussion
- Bambu Lab Wiki — Printer Network Ports page
- Bambu Lab Security White Paper — confirms RTSPs as part of local protocols
- OctoEverywhere Bambu Lab support page + blog
- forum.bambulab.com community forum threads on H2D camera feed and toolhead camera
