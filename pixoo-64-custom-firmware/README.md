# Writing custom firmware for the Divoom Pixoo 64

## Question / Goal

What does it take to write and install your own firmware on a Divoom Pixoo 64? The questions were what the chips are, whether the device is locked, how you get code onto it, how the LED panel is driven, and what already exists to build on. See the [Original Prompt](#original-prompt).

## Answer / Summary

**It's very doable, and as of late 2026 most of the hard work has already been published.**

- **The main chip is an ordinary ESP32, and it isn't locked.** The Wi-Fi mainboard carries an **ESP32-WROVER-IE** (ESP32-D0WD-V3) with 8 MB flash and 8 MB PSRAM. On the unit that was examined, **flash encryption and secure boot are both off** and UART download mode is allowed. That means you can read out the whole stock flash in plaintext and write unsigned images to it.
- **You need to open the case and solder or clip onto test pads.** The USB-C port only supplies power. Programming goes through back-side pads (`GND`/`TX`/`RX`/`IO0`) with a 3.3 V USB-UART adapter. Hold `IO0` low across a cold power-up, then use `esptool` (230400 baud was reliable; faster speeds corrupted packets). After the first flash, ESPHome can update over Wi-Fi (OTA).
- **The LEDs are driven by a second chip that you don't need to replace.** An **AT32F413CBT7** ARM MCU on the LED board handles the row scanning. The ESP32 just sends it whole frames over write-only SPI (CLK GPIO25, MOSI GPIO33, CS GPIO26) in a simple packet format: `0xAA len16LE cmd payload 0xBB`. Command `0x00` carries a 64×64×3 RGB frame, and `0x01` sets brightness. Custom firmware only replaces the ESP32 application. The panel MCU keeps its stock firmware.
- **ESPHome supports it upstream.** ESPHome has a built-in `pixoo` display and light platform (PR [esphome#16974](https://github.com/esphome/esphome/pull/16974), merged 2026-06-29). With it you can use the normal ESPHome drawing API or LVGL on the device. For a full replacement firmware, see [simplyRoba/pixoo-firmware](https://github.com/simplyRoba/pixoo-firmware) (AGPL-3.0, v2.1.0, Oct 2026). It is built on ESPHome and adds dashboards, Home Assistant integration, the microphone, the buzzer, buttons and DDP input. Its `docs/hardware.md` is the best public teardown and pinout.
- **Why do it:** the stock firmware has to reach Divoom's servers (`*.divoom-gz.com`) at boot. The local HTTP API is "community reverse-engineered, not officially documented or supported by Divoom" and can break when the firmware updates. Divoom said in 2021 that it would open-source the firmware, but I found no sign that it ever did.
- **Risks:** only one board revision has been documented (mainboard REV1.1, LED board REV1.0). The **Pixoo-64 II** hardware is unknown. Make your own full flash backup before writing anything, because nobody publishes a full stock image you can restore from.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

All of this came from reading public sources. No device was used.

1. Web searches turned up the ESPHome `pixoo` docs and the Home Assistant forum thread [Divoom Pixoo64 hacking](https://community.home-assistant.io/t/divoom-pixoo64-hacking/959184).
2. I used GitHub search (`gh api search/issues`, `search/code`, `search/repositories`) to find the ESPHome PR, the projects that use `platform: pixoo`, and firmware collections.
3. I read the ESPHome component source (`esphome/components/pixoo/pixoo.{h,cpp}`) and both community repos: `simplyRoba/pixoo-firmware` (docs/hardware.md, docs/manual.md, docs/firmware.md, the board profile YAML) and `amnemonic/Pixoo64`, which collects stock OTA images.
4. I wrote [`esp_image_header.py`](esp_image_header.py) to check the format of the stock `.bin` images, and ran `strings` on them to see which hosts they contact.
5. I tried to read the FCC internal photos (fccid.io returned 403) and the 2023 Reddit thread on isolated-network use (blocked). Neither is used as a source.

```bash
python3 -I esp_image_header.py pixoo64_V90122.bin pixoo64_V90224.bin
# pixoo64_V90122.bin 0xe9 segs 7 chip 0 appdesc 0xabcd5432 ... b'Pixoo64-wifi'
```

## Results

### Hardware (mainboard REV1.1 `20210318`, LED board REV1.0 `20210525`)

| Part | Detail | Source |
|---|---|---|
| Main SoC | ESP32-WROVER-IE, ESP32-D0WD-V3 rev 3, u.FL antenna | simplyRoba hardware.md §2.1 |
| Memory | 8 MB flash (JEDEC c8/4017, DIO), 8 MB PSRAM (only 4 MB mapped without himem) | §2.1–2.2 |
| Security eFuses | FLASH_CRYPT_CNT=0, no secure boot, UART download allowed, JTAG not disabled | §2.3 |
| USB-C | Power only, no USB-serial chip | §2.4 |
| Panel MCU | AT32F413CBT7 (ESPHome source says "GD32/AT32"), SWD pads `GND1/3V3/SWC/SWD` | §3.1, §3.5; ESPHome `pixoo.h` |
| LED drivers | 24× SM16380SC column drivers + 8× SM5166PF row switches; row-scanned matrix | §3.2–3.3 |
| Other | MEMS mic (I2S), buzzer, 2 buttons, microSD (SDMMC 4-bit) | §3.4, §11 |

### ESP32 pin map

| GPIO | Function |
|---|---|
| 25 / 33 / 26 | Panel SPI SCLK / MOSI / CS (mode 0, MSB-first; stock firmware runs it at 15 MHz, ESPHome defaults to 8 MHz) |
| 32 | UART RX from the panel, 115200 baud (panel firmware version reply) |
| 22 | Gate for the 5 V LED power rail. Ramp it on slowly (simplyRoba uses LEDC PWM over 120 ms), because switching it on abruptly can brown out the ESP32 |
| 18 / 19 / 5 / 21 | Mic I2S BCLK / WS / DIN / mic enable |
| 23 | Buzzer (LEDC PWM square wave) |
| 35 / 34 | Power / brightness buttons (input-only, active-low) |
| 14,15,2,4,12,13 | microSD SDMMC CLK, CMD, D0–D3 |

### Panel wire protocol (ESP32 → AT32 over SPI)

```
0xAA  <len LE16>  <cmd>  <payload[len]>  0xBB
```

| cmd | Meaning | Payload |
|---|---|---|
| `0x00` | Full frame, RGB888, row-major from the top-left | 12288 bytes |
| `0x01` | Brightness | 1 byte, 0–100 |
| `0x10` | Init / mode select (sent by the stock firmware; ESPHome skips it) | `0x00` |
| `0x21` | Padding/continuation up to the panel's 240-byte DMA chunk | filler |
| `0x22` | White balance / per-channel current | 3 bytes (ESPHome sends 75,75,75) |

A padded frame is 12533 bytes, which takes about 6.7 ms at 15 MHz. That puts the theoretical ceiling at about 150 fps. Animation is just a stream of `0x00` frames.

### Flashing procedure (per simplyRoba docs/manual.md)

1. Open the case. Wire a **3.3 V** USB-UART adapter to the `TX`/`RX`/`GND` pads (TX and RX crossed over). Leave the adapter's VCC disconnected and power the device from USB-C.
2. Bridge `IO0` to `GND`, power-cycle the device, then remove the bridge. The ESP32 is now in ROM download mode.
3. **Back up** the whole flash, for example with `esptool read-flash 0 0x800000 backup.bin` at 230400 baud, and save its SHA-256 checksum. The dump can contain your Wi-Fi credentials in plaintext.
4. Write the ESPHome factory image: `esptool --baud 230400 write-flash 0x0 firmware.factory.bin`. Power-cycle without the IO0 bridge.
5. From then on, update with `esphome run … --device pixoo64.local` (OTA). To restore the stock firmware, write your own backup back at `0x0`.

### Paths to custom firmware

| Approach | Effort | What you get |
|---|---|---|
| ESPHome + built-in `pixoo` platform (see [`pixoo64-minimal.yaml`](pixoo64-minimal.yaml)) | Low: YAML, lambdas, LVGL | Display, brightness, HA API, OTA. You wire the buttons, buzzer and mic yourself |
| Fork **simplyRoba/pixoo-firmware** | Medium (C++ inside ESPHome) | Finished dashboards, now-playing, weather, DDP on UDP 4048, notifications. AGPL-3.0 |
| Bare ESP-IDF / Arduino / Rust | Higher | Full control. Reimplement the SPI packet sender (about 50 lines), the LED-rail ramp, and Wi-Fi provisioning |
| Reflash the AT32 panel MCU over SWD | High, nobody has done it | In theory, your own scan timing or higher bit depth. No public panel firmware dump or protocol notes exist, and it's easy to lose the stock panel firmware |
| No firmware change: local HTTP API | None | Works, but it's unofficial, the cloud is needed at boot, and firmware updates can break it |

### Stock firmware observations

- The OTA images in `amnemonic/Pixoo64` (V90122, Jul 2022 → V90224, Jun 2026) are standard, unencrypted ESP-IDF app images. They have magic `0xE9`, 7 segments, the app-descriptor magic `0xABCD5432` and the project name `Pixoo64-wifi`. They are built with ESP-ADF and Bluedroid.
- The strings include `app.divoom-gz.com`, `appin.divoom-gz.com` and `api.divoom-gz.com`, plus many third-party APIs (Open-Meteo, Sonos, Spotify, Binance, NHL, Home Connect…). That fits the cloud dependency at boot that the HA thread reports.

## Analysis

- **Why it's easy:** Divoom put a commodity ESP32 module in the device, never burned the security eFuses, and pushed the hard real-time LED refresh onto a separate MCU. As a result, the "display driver" is a single SPI write of 12 KB per frame. Writing custom firmware is mostly ordinary ESP32 application work.
- **Why the panel MCU should stay stock:** it accepts frames at well over animation rates and does its own white balance. Replacing it would gain little and risks losing firmware that nobody has published. Its SWD pads exist, but nobody has documented reading out the AT32F413.
- **Caveats:**
  - Every hardware claim comes from one examined unit (REV1.1/REV1.0). Other revisions and the Pixoo-64 II are unknown. A Divoom update could, in principle, burn the security eFuses on devices that are still running stock firmware.
  - ESPHome and simplyRoba differ on SPI clock (8 vs 15 MHz) and init (`0x10` skipped vs sent). Both are reported to work.
  - The ESPHome docs example doesn't touch GPIO22, and I couldn't confirm whether the LED rail comes up without it.
  - [`pixoo64-minimal.yaml`](pixoo64-minimal.yaml) only combines documented pins. I didn't validate or test it on hardware.
- **Licensing:** simplyRoba is AGPL-3.0-or-later. ESPHome is GPL-3.0 / MIT, depending on the file. Taking either one as a base sets the license of what you build.

## Files

| File | Description |
|---|---|
| `README.md` | This report |
| `notes.md` | Working notes, including dead ends (Reddit and FCC blocked, the gh search syntax) |
| `esp_image_header.py` | Small parser that checks the ESP32 image magic and app-descriptor on stock `.bin` files |
| `pixoo64-minimal.yaml` | Starting ESPHome config for the Pixoo 64, built from documented pins (untested) |
| `_summary.md` | Index summary for the repo root README |

### Sources

- ESPHome Pixoo display docs: <https://esphome.io/components/display/pixoo/>
- ESPHome PR #16974: <https://github.com/esphome/esphome/pull/16974>; docs PR <https://github.com/esphome/esphome.io/pull/6792>
- ESPHome component source: <https://github.com/esphome/esphome/tree/dev/esphome/components/pixoo>
- simplyRoba/pixoo-firmware (hardware.md, manual.md, firmware.md): <https://github.com/simplyRoba/pixoo-firmware>
- amnemonic/Pixoo64 stock firmware collection: <https://github.com/amnemonic/Pixoo64>
- Home Assistant forum, "Divoom Pixoo64 hacking": <https://community.home-assistant.io/t/divoom-pixoo64-hacking/959184>
- Divoom, "Pixoo-64 API Beginner Guide" (Jul 2026): <https://divoom.com/blogs/app-guide/pixoo-64-api-beginner-guide>
- Hackster, "Divoom's Pixoo-64 … Could Be Open Sourced Soon" (2021): <https://www.hackster.io/news/divoom-s-pixoo-64-is-a-64x64-wi-fi-enabled-smart-pixel-art-frame-and-could-be-open-sourced-soon-8cb866fcb5fa>

## Original Prompt

> Research writing custom firmware for the Pixoo 64 display
