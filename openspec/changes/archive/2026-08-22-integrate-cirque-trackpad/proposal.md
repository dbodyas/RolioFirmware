## Why

The right half of the Rolio46 split keyboard previously supported a secondary display (Vista508 or nice!view). Integrating a Cirque TM040040 SPI trackpad on the right half provides integrated hardware cursor control, navigation, and mouse pointing without needing a separate mouse.

## What Changes

- Add a new shield `cirque_trackpad` configured for SPI communication with Cirque TM040040 trackpad.
- Configure SPI bus pinctrl on nice!nano v2 to route MISO to pin D4 (P0.22) and CS to D1 (P0.06 Active Low).
- Route trackpad Data Ready (DR) interrupt to pin D9 (P1.06).
- Enable pointing subsystem and Zephyr native `cirque,pinnacle` driver (`CONFIG_INPUT_PINNACLE=y`).
- Add split input listener and relay nodes (`zmk,input-split` / `zmk,input-listener`) to seamlessly forward pointing events from the right peripheral half to the central host over BLE.
- Update `build.yaml` to include the `nice_nano//zmk` + `rolio_right cirque_trackpad` target and comment out unused display and mikoto builds.
- Update `build.sh` target aliases and test targets to reflect the new Cirque right shield.

## Capabilities

### New Capabilities
- `cirque-trackpad`: Hardware pointing and cursor movement support via Cirque TM040040 trackpad over SPI and BLE split relay.

### Modified Capabilities
<!-- None -->

## Impact

- **Hardware / Pinout**: Right half uses D1 (CS), D2 (MOSI), D3 (SCK), D4 (MISO), and D9 (DR).
- **Firmware / Shield**: Adds `boards/shields/cirque_trackpad/`, modifies `boards/shields/rolio/rolio.dtsi` and `boards/shields/rolio/rolio_left.overlay`.
- **Build Matrix**: Replaces right display build with right trackpad build in `build.yaml` and `./build.sh`.
