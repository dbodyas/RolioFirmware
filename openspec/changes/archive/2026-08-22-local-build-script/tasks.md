## 1. Setup and Environment

- [x] 1.1 Update `.gitignore` to ignore `./artifacts/` and ephemeral build directories
- [x] 1.2 Implement YAML parsing helper in `build.sh` using Python 3 to extract target definitions from `build.yaml`

## 2. Docker & West Compilation Pipeline

- [x] 2.1 Implement Docker daemon availability check with clear diagnostic messages
- [x] 2.2 Implement Docker named volume cache initialization (`rolio-zmk-cache`) with `west init` and `west update`
- [x] 2.3 Implement compilation step (`west build`) matching GitHub Actions parameters (`-DZMK_CONFIG`, `-DZMK_EXTRA_MODULES`, snippets, CMake args) and `.uf2` extraction to `./artifacts/`

## 3. CLI Interface and Modes

- [x] 3.1 Implement interactive target selection menu when `./build.sh` is invoked without arguments
- [x] 3.2 Implement target name / alias matching (e.g. `./build.sh left`, `./build.sh right`, `./build.sh reset`, or exact artifact name)
- [x] 3.3 Implement `--test` (pre-push verification) mode to build the 3 primary combinations with summary status reporting
- [x] 3.4 Implement `--clean` and `--update` flags to manage Docker cache volume and sync dependencies

## 4. Validation

- [x] 4.1 Verify `./build.sh --help` and CLI argument handling
- [x] 4.2 Run test build verification and verify that `.uf2` files are generated in `./artifacts/`
