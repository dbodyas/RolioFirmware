## Context

The Rolio46 is a split wireless keyboard running ZMK `main` (Zephyr 4.1) on `nice!nano v2` (nRF52840) boards. The central half (left) connects to the host via USB/BLE, while the peripheral half (right) communicates with the central half over BLE.

Previously, the right half supported a secondary display on SPI pins (D1/D2/D3). The Cirque TM040040 trackpad replaces the display on the right half.

See `proposal.md` for motivation and `specs/cirque-trackpad/spec.md` for behavioral requirements.

## Goals / Non-Goals

**Goals:**
- Provide a clean, modular shield `cirque_trackpad` for the Cirque TM040040 module.
- Use native Zephyr 4.1 Pinnacle driver without external `west.yml` module dependencies.
- Map SPI pins with MISO routed to D4 (P0.22) and DR interrupt to D9 (P1.06).
- Use standard ZMK `zmk,input-split` and `zmk,input-listener` for split forwarding.
- Update `build.yaml` and `./build.sh` for fast local builds.

**Non-Goals:**
- Physical hardware mouse button integration (BTN1-3) on trackpad pins (handled via keymap `&mkp` behaviors).
- Dual-display configurations on the right half.
- Mikoto board support for trackpad.

## Decisions

### 1. Upstream Zephyr 4.1 Driver
- **Decision**: Use `CONFIG_INPUT_PINNACLE=y` and compatible `"cirque,pinnacle"`.
- **Rationale**: Since the repository is upgraded to ZMK `main` (Zephyr 4.1), the Cirque driver is built directly into Zephyr, avoiding out-of-tree module maintenance.
- **Alternative considered**: Using `petejohanson/cirque-input-module` in `west.yml`. Rejected because upstream Zephyr driver is already present.

### 2. Pin Routing & Pinctrl Override
- **Decision**: Define board overlay `boards/shields/cirque_trackpad/boards/nice_nano_nrf52840_zmk.overlay` that configures:
  - SCK: P0.20 (D3)
  - MOSI: P0.17 (D2)
  - MISO: P0.22 (D4)
  - CS: P0.06 (D1, Active Low)
  - DR: P1.06 (D9, Active High)
- **Rationale**: The default `nice_nano` SPI pinctrl uses P0.25 for MISO (internal/unexposed pin). Reassigning MISO to D4 allows bi-directional SPI communication.

### 3. Split Pointing Architecture
- **Decision**: 
  - In `rolio.dtsi`: Define `split_inputs` with `glidepoint_split: glidepoint_split@0` and `glidepoint_listener: glidepoint_listener` (status = "disabled").
  - In `rolio_left.overlay`: Enable `&glidepoint_listener { status = "okay"; };`.
  - In `cirque_trackpad.overlay`: Attach `device = <&glidepoint>;` to `&glidepoint_split` and apply `INPUT_TRANSFORM_Y_INVERT`.
- **Rationale**: This is the standard ZMK split input pattern. The central listener processes incoming BLE packets and generates host HID events.

### 4. Build Matrix Simplification
- **Decision**: In `build.yaml`, comment out all `mikoto//zmk` entries and right display entries (`rolio_right vista508`, `rolio_right nice_view`). Add `nice_nano//zmk` + `rolio_right cirque_trackpad`.
- **Rationale**: Keeps CI and local build times minimal, focusing only on active builds.

## Risks / Trade-offs

- **[Hardware Jumper R1]** → Cirque module must have resistor R1 populated (470 kΩ) for SPI mode; if unpopulated, module boots in I2C mode.
- **[CS Active Low Polarity]** → Vista508 used Active High; Cirque requires Active Low. Handled via `cs-gpios = <&pro_micro 1 GPIO_ACTIVE_LOW>;`.
- **[BLE Pointer Re-pairing]** → Adding HID pointing to BLE descriptor requires forgetting and re-pairing keyboard on host OS if previously paired without pointer capability.

## Migration Plan

1. Create `boards/shields/cirque_trackpad/` files.
2. Update `boards/shields/rolio/rolio.dtsi` and `rolio_left.overlay`.
3. Update `build.yaml` and `./build.sh`.
4. Compile with `./build.sh --test` to verify both left and right builds.
