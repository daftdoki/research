Leveraging the EcoFlow Delta Pro 3 as a notifying UPS requires bridging its lack of a standard USB-HID interface by integrating local sensors and network automation. The proposed architecture combines a Home Assistant MQTT integration for battery and status telemetry (via [TarasKhust/ecoflow-api-mqtt](https://github.com/TarasKhust/ecoflow-api-mqtt)), a local energy-monitoring smart plug for instant, cloud-independent mains status, and the Home Assistant NUT add-on as a protocol bridge. This setup lets any host communicate and shut down cleanly via industry-standard NUT tools, with optional automations for additional triggers. Future improvements include using the [rabits/ef-ble-reverse](https://github.com/rabits/ef-ble-reverse) Bluetooth project for fully local telemetry and exploring DP3’s CAN bus, though CAN reverse engineering is still an ongoing effort.

**Key Findings:**
- Combining a smart plug and Home Assistant provides real-time, local "power-loss detected" signals.
- EcoFlow API cloud integrations offer rich battery telemetry but depend on internet connectivity.
- The NUT protocol bridge enables hosts to use familiar shutdown tools with custom UPS data.
- Developing fully local solutions via Bluetooth and CAN bus remains feasible but requires further device protocol discovery.
