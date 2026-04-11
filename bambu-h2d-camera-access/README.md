# Bambu Lab H2D Camera: External Access Options

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Is the Bambu Lab H2D's built-in camera accessible outside Bambu's own apps
(Bambu Studio / Bambu Handy)? Can it be viewed in Home Assistant, generic
security-camera software, or other external programs? ([original prompt](#original-prompt))

## Answer / Summary

**Yes — the H2D's chamber "live view" camera is exposed as a local RTSPS
(RTSP-over-TLS) stream that any RTSP-compatible tool can consume, including
Home Assistant, VLC, ffmpeg, go2rtc, Frigate, Scrypted, Blue Iris, and
OctoEverywhere/OctoApp.**

Three things to know:

1. **Flip one toggle on the printer.** You must enable "LAN Only Liveview" in
   the H2D's LAN Mode settings. You do **not** need to put the printer into
   full LAN-only mode — the liveview toggle is independent, and cloud-mode
   Bambu Studio/Handy keep working. This is the same gate Bambu added on the
   X1 / P2S / H2S / H2D generation.
2. **The stream URL is:**
   ```
   rtsps://bblp:<ACCESS_CODE>@<PRINTER_IP>:322/streaming/live/1
   ```
   Username is always `bblp`. Password is your printer's 8-character LAN
   Access Code. Port is TCP/322. Protocol is RTSPS (TLS-wrapped RTSP), not
   plain RTSP.
3. **Two cameras, one feed.** The H2D has both a chamber "live view" camera
   and a toolhead (nozzle) camera. **Only the chamber camera is exposed on
   RTSPS.** The toolhead camera is internal to the printer's own calibration
   and Bambu Studio UI and has no documented external endpoint.

For Home Assistant specifically, the easiest path is the HACS community
integration **[`ha-bambulab`](https://github.com/greghesp/ha-bambulab)** (≥ v2.1.11 added H2D
support). Most people pair it with **go2rtc + WebRTC Card** to get sub-second
latency instead of the built-in 3–8 second HLS delay.

For additional and more detailed information see the [research notes](notes.md).

## Methodology / Investigation

This was a literature-only investigation (no printer in hand). The work was:

1. Confirm the H2D exposes the same RTSPS-based mechanism as the rest of the
   current Bambu lineup, and pin down the exact URL/port/auth.
2. Check whether the `ha-bambulab` Home Assistant integration supports H2D
   specifically, and what the current state of camera support is.
3. Enumerate third-party software that's known to ingest the Bambu stream
   (Frigate, Scrypted, Blue Iris, OctoEverywhere, etc.) and note any
   H2D-specific quirks.
4. Identify what is **not** accessible (toolhead camera, HTTP JPEG snapshot,
   ONVIF, remote cloud stream).

Sources searched: Bambu Lab Wiki & forum, `greghesp/ha-bambulab` GitHub issues
and docs, `bambulab/BambuStudio` GitHub issues, Frigate/go2rtc discussions,
Scrypted discussions, OctoEverywhere blog and docs, BambuTools/bambulabs_api
Python library, BambuBoard project's streaming setup doc, and the Bambu Lab
Security White Paper.

## Results

### Connection details (the one thing you actually need)

| Field | Value |
|---|---|
| Protocol | RTSPS (RTSP over TLS) |
| Port | TCP **322** |
| Username | `bblp` (literal, not your Bambu account name) |
| Password | Printer's LAN Access Code (Settings → Network) |
| Path | `/streaming/live/1` |
| URL | `rtsps://bblp:<ACCESS_CODE>@<PRINTER_IP>:322/streaming/live/1` |
| Video codec | H.264 |
| Firmware required | ≥ 01.06.00.00 (H2D already ships newer) |
| Setting that enables it | "LAN Only Liveview" — on the printer touchscreen, under LAN Mode settings. Does not require full LAN-only mode to be enabled. |

### Quick verification commands

```bash
# Reachability
nc -zv 192.168.1.X 322

# VLC
vlc 'rtsps://bblp:YOURCODE@192.168.1.X:322/streaming/live/1'

# ffmpeg: 10-second test recording
ffmpeg -i 'rtsps://bblp:YOURCODE@192.168.1.X:322/streaming/live/1' \
  -t 10 -c copy test.mp4
```

### Software compatibility

| Software | Works? | How | Notes |
|---|---|---|---|
| VLC | Yes | RTSPS URL directly | Simplest sanity check |
| ffmpeg | Yes | RTSPS URL directly | For recording / re-encode |
| **Home Assistant (`ha-bambulab` HACS)** | **Yes** | Camera entity auto-configured | H2D support since v2.1.11; earliest releases had bugs, now resolved |
| Home Assistant (generic camera) | Yes | `platform: generic` + RTSPS URL | Fallback; no printer sensors |
| **go2rtc** | **Yes** | Ingest RTSPS, publish as WebRTC/HLS/MJPEG | Best latency; hub for everything else |
| **Frigate** | Yes | Via go2rtc with ffmpeg re-encode | Stream sometimes "garbles" if passed raw; re-encode to H.264 baseline fixes it |
| **Scrypted** | Yes | Generic RTSP camera plugin | Re-exposes to HomeKit / Google / Alexa |
| Blue Iris | Yes | Generic RTSP/RTSPS camera | No ONVIF discovery — add manually |
| Synology Surveillance Station | Yes | User-defined RTSP camera | Same caveat — no ONVIF |
| Unifi Protect | Limited | Only if you front it with go2rtc/MediaMTX | Protect prefers its own cameras |
| **OctoEverywhere** | **Yes** | Official Bambu Lab support, local bridge | Enables remote viewing + AI "Gadget" failure detection |
| OctoApp (mobile) | Yes | Via OctoEverywhere or local bridge | Multi-cam supported |
| `bambulabs_api` (Python) | Partial | `printer.get_camera_image()` | H2D flagged as untested in recent versions |

### What is *not* accessible

- **ONVIF discovery** — the Bambu camera does not advertise ONVIF. Add it to
  NVRs as a "generic RTSP" camera manually.
- **HTTP MJPEG / JPEG snapshot endpoint** — there is no
  `http://printer/snapshot.jpg`. Snapshots must be pulled by decoding an
  RTSPS frame, which `ha-bambulab`, `go2rtc`, and OctoEverywhere all do
  transparently.
- **Toolhead camera** — the H2D's nozzle-mounted calibration camera is not
  exposed on RTSPS. It is used internally for motion/nozzle calibration and
  only recently started surfacing inside Bambu Studio itself.
- **Plain RTSP** — only TLS-wrapped RTSPS works.
- **Internet-reachable raw stream** — the RTSPS endpoint is LAN-only by
  design. For remote viewing, either VPN into your LAN, use OctoEverywhere as
  a local bridge, or stick with the Bambu Handy app in cloud mode.

## Analysis

The practical recommendation depends on what you're after:

- **"I just want it in Home Assistant."** Install the `ha-bambulab` HACS
  integration. It gives you a pre-wired camera entity plus a huge set of
  printer sensors (temperatures, progress, HMS, AMS slots). If live-view
  latency feels sluggish, add go2rtc + the WebRTC Card — this is the single
  most common tweak documented in the integration's issue tracker.
- **"I want to add it to my existing NVR (Blue Iris, Synology, etc.)."** Treat
  it as a generic RTSPS camera (not ONVIF). Paste the URL, use username `bblp`
  and your LAN Access Code. Done. Be aware some NVRs assume plain RTSP on
  port 554 by default — you have to override both to RTSPS/322.
- **"I want motion detection / recording via Frigate."** Run it through go2rtc
  first and tell go2rtc to re-encode with ffmpeg (`#video=h264#hardware`).
  That bypasses the "looks fine in VLC, garbled in Frigate" issue that's been
  reported with the Bambu stream.
- **"I want to share it with HomeKit / Google / Alexa."** Scrypted is the
  path of least resistance — point a generic RTSP plugin at the Bambu URL.
- **"I want to view it remotely without opening ports."** Use OctoEverywhere.
  It officially supports Bambu (including H2D), runs as a local bridge that
  pulls the RTSPS feed, and relays it to your phone securely. You also get
  their AI "Gadget" failure-detection layer as a side benefit.

The main H2D-specific gotcha is the "LAN Only Liveview" toggle. Bambu layered
this option onto the H2D / H2S / P2S generation after cloud-mode users
complained that enabling LAN mode broke their existing Handy workflows. As a
result, if you just follow older X1-era guides that tell you to "turn on LAN
mode", you'll end up in a confusing state. The correct instruction on H2D is:
**leave LAN mode however you like, but specifically flip "LAN Only Liveview" on.**

## Files

- `README.md` — this report
- `notes.md` — work log and deeper reference notes

## Original Prompt

> I have a Bambu Labs H2D 3D printer. It has a camera that can be used to view the inside of the printer from the Bambu apps. Is this camera accessible in other ways? Can I view it in any kind of other external program or security camera software? Homeassistant?
