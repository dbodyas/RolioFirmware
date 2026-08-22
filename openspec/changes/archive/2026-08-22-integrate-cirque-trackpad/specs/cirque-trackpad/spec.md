## Purpose

Provides physical trackpad pointing and cursor input using an integrated Cirque TM040040 SPI module on the right half of the Rolio46 split keyboard.

## ADDED Requirements

### Requirement: Right half trackpad SPI communication
The right peripheral half SHALL communicate with the Cirque TM040040 trackpad via SPI0 using dedicated Chip Select and Data Ready interrupt GPIO lines.

#### Scenario: Trackpad hardware initialization
- **WHEN** the right half powers on or resets
- **THEN** the firmware initializes the Cirque Pinnacle driver over SPI0 at 1MHz using CS (P0.06 Active Low) and DR (P1.06 Active High).

### Requirement: Cursor movement and coordinate reporting
The trackpad SHALL capture 2D finger motion in relative mode and report X/Y displacement events.

#### Scenario: Moving finger across trackpad
- **WHEN** a user glides a finger across the trackpad surface
- **THEN** the trackpad generates relative X/Y coordinate displacement events with Y-axis inversion applied.

### Requirement: Split peripheral pointing event forwarding
The peripheral right half SHALL forward all pointing input events to the central left half over Bluetooth Low Energy.

#### Scenario: Relaying pointer events to host
- **WHEN** pointer events are generated on the peripheral right half
- **THEN** the `zmk,input-split` subsystem forwards the events to the central half, which emits standard USB/BLE HID mouse reports to the connected host.

### Requirement: Build matrix target configuration
The build system SHALL provide a dedicated build target for the right half with the Cirque trackpad shield enabled.

#### Scenario: Compiling right trackpad firmware
- **WHEN** running `./build.sh` or GitHub Actions with target `rolio_right cirque_trackpad`
- **THEN** the firmware compiles successfully and outputs a `.uf2` artifact.
