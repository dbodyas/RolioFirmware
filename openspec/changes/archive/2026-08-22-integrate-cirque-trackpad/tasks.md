## 1. Shield Setup

- [x] 1.1 Create `boards/shields/cirque_trackpad/Kconfig.shield` and `Kconfig.defconfig`
- [x] 1.2 Create `boards/shields/cirque_trackpad/cirque_trackpad.conf` with input, pointing, and Pinnacle driver configs
- [x] 1.3 Create `boards/shields/cirque_trackpad/cirque_trackpad.zmk.yml` shield metadata file

## 2. Devicetree & Pinctrl Configuration

- [x] 2.1 Create `boards/shields/cirque_trackpad/boards/nice_nano_nrf52840_zmk.overlay` with SPI0 pinctrl (MISO on P0.22/D4, CS on P0.06/D1 Active Low)
- [x] 2.2 Create `boards/shields/cirque_trackpad/cirque_trackpad.overlay` configuring `&glidepoint` node with DR pin on P1.06/D9 and attaching to `&glidepoint_split`
- [x] 2.3 Update `boards/shields/rolio/rolio.dtsi` to define shared `split_inputs` and `glidepoint_listener` nodes
- [x] 2.4 Update `boards/shields/rolio/rolio_left.overlay` to enable `&glidepoint_listener` on the central half

## 3. Build Matrix & Tooling

- [x] 3.1 Update `build.yaml` to include `rolio_right cirque_trackpad` and comment out mikoto and right display targets
- [x] 3.2 Update `build.sh` target aliases and pre-push test targets for the new Cirque right shield

## 4. Verification

- [x] 4.1 Compile firmware using `./build.sh --test`
- [x] 4.2 Verify generated `.uf2` binaries in `./artifacts/`
