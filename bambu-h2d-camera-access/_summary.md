The Bambu Lab H2D's built-in chamber camera can be accessed externally via a LAN-only RTSPS (RTSP-over-TLS) stream, allowing integration with various third-party applications such as Home Assistant (via the [ha-bambulab integration](https://github.com/greghesp/ha-bambulab)), VLC, OctoEverywhere, Blue Iris, and others. To enable this, "LAN Only Liveview" must be toggled on in the printer's settings, and the stream is accessed at `rtsps://bblp:<ACCESS_CODE>@<PRINTER_IP>:322/streaming/live/1` using your printer's LAN Access Code. The toolhead calibration camera remains inaccessible outside Bambu's ecosystem, and no ONVIF or HTTP snapshot endpoints are provided. Sub-second latency for Home Assistant is achievable with tools like [go2rtc](https://github.com/AlexxIT/go2rtc).

**Key Findings:**
- Chamber camera stream is available via secure LAN-only RTSPS, compatible with many tools but not cloud-direct.
- Only the chamber camera is exposed; nozzle (toolhead) camera is not externally accessible.
- Adding to Home Assistant is easiest with the ha-bambulab integration, with go2rtc/WebRTC Card recommended for lowest latency.
