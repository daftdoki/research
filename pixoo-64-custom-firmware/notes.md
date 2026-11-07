# Pixoo 64 custom firmware — Notes

## Goal
Figure out what it takes to write custom firmware for the Divoom Pixoo 64 (MCU, flashing path, prior art, alternatives).

## Work log

- Searched for a teardown and existing custom firmware. The first hits were the ESPHome `pixoo` display page and a Home Assistant forum thread called "Divoom Pixoo64 hacking" (Dec 2025).
- HA thread (read via the Discourse JSON, 4 posts): it reports a boot-time cloud dependency ("needs to reach the vendor's website before it'll work") and an ESP32 seen in the FCC internal photos. It has no flashing info.
- The Reddit thread (r/homeassistant 183mbrk) and fccid.io both refused automated fetches (Reddit blocked, fccid.io 403). Dead end, so I don't use either one as a source.
- ESPHome docs (stable 2026.10.2, next 2026.11.0b2): the `pixoo` display and light platforms, 64x64 only. SPI CLK=GPIO25, MOSI=GPIO33, CS=GPIO26. Nothing on how to flash.
- Found the PR with `gh api search/issues` (it needs `is:pull-request` in the query, otherwise HTTP 422): esphome/esphome#16974 by jesserockz, merged 2026-06-29. Docs PR esphome.io#6792. Neither one mentions flashing.
- Downloaded the component source from raw.githubusercontent (dev branch). pixoo.h documents the LED-board packet protocol `0xAA lenLE16 cmd data 0xBB`, the cmds 0x00 DATA / 0x01 LIGHT / 0x21 UNUSED pad / 0x22 SET_RGB_IOUT, and the 240-byte DMA chunk. The LED board is described as a "GD32/AT32 MCU".
- `gh api search/code '"platform: pixoo"'` and `search/repositories` turned up:
  - simplyRoba/pixoo-firmware: an AGPL ESPHome-based replacement, v1.0.0 2026-10-08, v2.1.0 2026-10-23. Its docs/hardware.md is a full teardown: ESP32-WROVER-IE (D0WD-V3), 8MB flash + 8MB PSRAM, panel MCU AT32F413CBT7, 24x SM16380SC + 8x SM5166PF. Flash encryption and secure boot are OFF and UART download is allowed. Back-side pads GND/TX/RX/IO0/IO2. The USB-C port is power only. The panel link runs at 15 MHz SPI, plus a 115200 UART back-channel on GPIO32. GPIO22 gates the LED power rail, the mic is on I2S with an enable on GPIO21, the buzzer is on GPIO23, and the buttons are on GPIO35/34. The SD card uses SDMMC 4-bit.
  - amnemonic/Pixoo64: a collection of stock OTA .bin files, V90122 (Jul 2022) through V90224 (Jun 2026).
- Wrote esp_image_header.py to check the stock images. Magic 0xE9, 7 segments, app-desc magic 0xABCD5432, project name "Pixoo64-wifi". So these are plain unencrypted ESP-IDF app images. My first guess at the app-desc field offsets was off (the version field read "1"); I ignored that because the magic number and project name are enough. Strings show an ESP-ADF + bluedroid build ("/home/albert/work/esp/divoom_esp/esp_light/...") and the hosts app.divoom-gz.com, appin.divoom-gz.com and api.divoom-gz.com. They also contain 3rd-party APIs (open-meteo, Sonos, Spotify, Binance, NHL...).
- Divoom API beginner guide (Jul 2026): the local HTTP API is "community reverse-engineered, not officially documented or supported by Divoom"; "firmware updates can change or temporarily block API access". The guide also says Pixoo-64 II protocol behaviour may differ. I found no hardware info on the II.
- Hackster (2021): Divoom said it was "considering its open source capability" for Q4 2021. I found no evidence that this ever happened.
- Mismatch to keep in mind: ESPHome's pixoo defaults to 8 MHz and sends only 0x22 at setup. The stock firmware (per simplyRoba's captures) sends 0x10 init and then 0x22, at 15 MHz. Both are reported to work.
- Not done: no hardware in hand, so nothing was verified on a device. pixoo64-minimal.yaml is assembled from documented pins and has not been tested.
