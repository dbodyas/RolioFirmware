#!/usr/bin/env bash
# ==============================================================================
# RolioFirmware Local ZMK Build Script
# Replicates GitHub Actions CI (build-user-config.yml) using Docker
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DOCKER_IMAGE="zmkfirmware/zmk-build-arm:stable"
CACHE_VOLUME="rolio-zmk-cache"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
BUILD_YAML="$SCRIPT_DIR/build.yaml"

# Colors for terminal output
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

# ------------------------------------------------------------------------------
# Helper: Python YAML Parser for build.yaml
# ------------------------------------------------------------------------------
parse_targets_py() {
    python3 -c "
import sys, json, re

def parse_build_yaml(filepath):
    try:
        import yaml
        with open(filepath, 'r') as f:
            return yaml.safe_load(f).get('include', [])
    except ImportError:
        pass
    
    entries = []
    current = None
    with open(filepath, 'r') as f:
        for line in f:
            line_str = line.rstrip()
            if not line_str or line_str.startswith('#') or line_str == '---':
                continue
            m_item = re.match(r'^\s*-\s+([\w-]+):\s*(.*)$', line_str)
            if m_item:
                if current:
                    entries.append(current)
                current = {}
                k, v = m_item.group(1), m_item.group(2).strip().strip('\"\'')
                current[k] = v
                continue
            m_field = re.match(r'^\s+([\w-]+):\s*(.*)$', line_str)
            if m_field and current is not None:
                k, v = m_field.group(1), m_field.group(2).strip().strip('\"\'')
                current[k] = v
        if current:
            entries.append(current)
    return entries

targets = parse_build_yaml('$BUILD_YAML')
action = sys.argv[1] if len(sys.argv) > 1 else 'list'

if action == 'list':
    for i, t in enumerate(targets):
        art = t.get('artifact-name', '')
        board = t.get('board', '')
        shield = t.get('shield', '')
        print(f\"{i+1}|{art}|{board}|{shield}\")

elif action == 'get':
    query = sys.argv[2]
    matched = None
    if query.isdigit():
        idx = int(query) - 1
        if 0 <= idx < len(targets):
            matched = targets[idx]
    else:
        # Common aliases
        aliases = {
            'left': 'zmk-rolio461-nicenano_v2-vista508-left',
            'right': 'zmk-rolio461-nicenano_v2-cirque_trackpad-right',
            'trackpad': 'zmk-rolio461-nicenano_v2-cirque_trackpad-right',
            'cirque': 'zmk-rolio461-nicenano_v2-cirque_trackpad-right',
            'reset': 'zmk-nicenano_v2-settings_reset',
            'nice-left': 'zmk-rolio461-nicenano_v2-nice_view-left',
            'nice-right': 'zmk-rolio461-nicenano_v2-nice_view-right',
            'mikoto-left': 'zmk-rolio461-mikoto720-vista508-left',
            'mikoto-right': 'zmk-rolio461-mikoto720-vista508-right',
            'mikoto-reset': 'zmk-mikoto720-settings_reset'
        }
        resolved_name = aliases.get(query.lower(), query)
        for t in targets:
            if t.get('artifact-name') == resolved_name or query.lower() in t.get('artifact-name', '').lower():
                matched = t
                break

    if matched:
        print(json.dumps(matched))
    else:
        sys.exit(1)

elif action == 'test_targets':
    test_artifacts = [
        'zmk-rolio461-nicenano_v2-vista508-left',
        'zmk-rolio461-nicenano_v2-cirque_trackpad-right',
        'zmk-nicenano_v2-settings_reset'
    ]
    matched_targets = [t for t in targets if t.get('artifact-name') in test_artifacts]
    print(json.dumps(matched_targets))

elif action == 'all':
    print(json.dumps(targets))
" "$@"
}

# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: 'docker' command not found.${NC}"
        echo "Please install Docker or OrbStack and make sure it is on your PATH."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: Docker daemon is not running or unreachable.${NC}"
        echo "Please start Docker Desktop or OrbStack and try again."
        exit 1
    fi
}

show_help() {
    echo -e "${BOLD}RolioFirmware Local Build Tool${NC}"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo "  ./build.sh                     Interactive selection menu"
    echo "  ./build.sh <target|alias>      Build a specific target"
    echo "  ./build.sh --test, -t          Run pre-push verification (builds core 3 targets)"
    echo "  ./build.sh --all, -a           Build all targets in build.yaml"
    echo "  ./build.sh --clean             Remove Docker cache volume & artifacts"
    echo "  ./build.sh --update, -u        Force 'west update' in cache volume"
    echo "  ./build.sh --help, -h          Show this help message"
    echo
    echo -e "${CYAN}Available Aliases:${NC}"
    echo "  left         -> zmk-rolio461-nicenano_v2-vista508-left"
    echo "  right        -> zmk-rolio461-nicenano_v2-cirque_trackpad-right"
    echo "  trackpad     -> zmk-rolio461-nicenano_v2-cirque_trackpad-right"
    echo "  reset        -> zmk-nicenano_v2-settings_reset"
    echo "  nice-left    -> zmk-rolio461-nicenano_v2-nice_view-left"
    echo "  nice-right   -> zmk-rolio461-nicenano_v2-nice_view-right"
}

# ------------------------------------------------------------------------------
# Core Build Function (runs inside Docker container)
# ------------------------------------------------------------------------------
build_target_json() {
    local target_json="$1"
    local force_update="$2"

    local board shield snippet cmake_args artifact_name
    board=$(echo "$target_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('board', ''))")
    shield=$(echo "$target_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('shield', ''))")
    snippet=$(echo "$target_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('snippet', ''))")
    cmake_args=$(echo "$target_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cmake-args', ''))")
    artifact_name=$(echo "$target_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('artifact-name', ''))")

    if [ -z "$artifact_name" ]; then
        artifact_name="zmk-${board//\//_}-${shield// /_}"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}🔨 Building target:${NC} ${GREEN}${artifact_name}${NC}"
    echo -e "   Board:      ${board}"
    echo -e "   Shield:     ${shield:-<none>}"
    [ -n "$snippet" ] && echo -e "   Snippet:    ${snippet}"
    [ -n "$cmake_args" ] && echo -e "   CMake args: ${cmake_args}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    mkdir -p "$ARTIFACTS_DIR"

    local snippet_arg=""
    if [ -n "$snippet" ]; then
        snippet_arg="-S ${snippet}"
    fi

    # Docker container script
    docker run --rm \
        -v "$CACHE_VOLUME:/workspace" \
        -v "$SCRIPT_DIR:/work_src:ro" \
        -v "$ARTIFACTS_DIR:/artifacts_out" \
        -w /workspace \
        -e FORCE_UPDATE="$force_update" \
        -e BOARD="$board" \
        -e SHIELD="$shield" \
        -e SNIPPET_ARG="$snippet_arg" \
        -e CMAKE_ARGS="$cmake_args" \
        -e ARTIFACT_NAME="$artifact_name" \
        "$DOCKER_IMAGE" \
        /bin/bash -c '
            set -e
            export ZEPHYR_BASE="/workspace/zephyr"
            cd /workspace

            # Sync current config into workspace
            mkdir -p /workspace/config
            cp -r /work_src/config/* /workspace/config/

            # 1. Initialize workspace if not present
            if [ ! -d "/workspace/.west" ]; then
                echo "📦 Initializing West workspace (first-time setup)..."
                west init -l config
                echo "⬇️  Updating West dependencies (this may take a couple minutes on first run)..."
                west update
                west zephyr-export
            elif [ ! -d "/workspace/zmk" ] || [ ! -d "/workspace/zephyr" ] || [ "$FORCE_UPDATE" = "true" ]; then
                echo "⬇️  Updating West dependencies..."
                west update
                west zephyr-export
            fi

            # 2. Build parameters matching GitHub Actions
            build_dir="/workspace/build"
            rm -rf "${build_dir}"

            # Ensure Zephyr package is registered for CMake in container
            west zephyr-export >/dev/null 2>&1 || true

            extra_cmake_args=()
            if [ -n "${SHIELD}" ]; then
                extra_cmake_args+=("-DSHIELD=${SHIELD}")
            fi
            if [ -n "${CMAKE_ARGS}" ]; then
                # evaluate cmake_args into array
                eval "parsed_flags=(${CMAKE_ARGS})"
                extra_cmake_args+=("${parsed_flags[@]}")
            fi

            echo "⚡ Compiling firmware with Zephyr/West..."
            west build -s /workspace/zmk/app \
                -d "${build_dir}" \
                -b "${BOARD}" \
                ${SNIPPET_ARG} \
                -- \
                -DZMK_CONFIG="/work_src/config" \
                -DZMK_EXTRA_MODULES="/work_src" \
                "${extra_cmake_args[@]}"

            # 3. Export artifact
            if [ -f "${build_dir}/zephyr/zmk.uf2" ]; then
                cp "${build_dir}/zephyr/zmk.uf2" "/artifacts_out/${ARTIFACT_NAME}.uf2"
                chmod 666 "/artifacts_out/${ARTIFACT_NAME}.uf2" || true
                echo "✅ Generated: artifacts/${ARTIFACT_NAME}.uf2"
            elif [ -f "${build_dir}/zephyr/zmk.bin" ]; then
                cp "${build_dir}/zephyr/zmk.bin" "/artifacts_out/${ARTIFACT_NAME}.bin"
                chmod 666 "/artifacts_out/${ARTIFACT_NAME}.bin" || true
                echo "✅ Generated: artifacts/${ARTIFACT_NAME}.bin"
            elif [ -f "${build_dir}/zephyr/zmk.hex" ]; then
                cp "${build_dir}/zephyr/zmk.hex" "/artifacts_out/${ARTIFACT_NAME}.hex"
                chmod 666 "/artifacts_out/${ARTIFACT_NAME}.hex" || true
                echo "✅ Generated: artifacts/${ARTIFACT_NAME}.hex"
            else
                echo "❌ Error: Build output binary not found."
                exit 1
            fi
        '

    echo -e "${GREEN}✓ Successfully built:${NC} ${BOLD}artifacts/${artifact_name}.uf2${NC}\n"
}

# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------
clean_all() {
    echo -e "${YELLOW}🧹 Cleaning build artifacts and Docker cache volume...${NC}"
    rm -rf "$ARTIFACTS_DIR"
    if docker volume inspect "$CACHE_VOLUME" >/dev/null 2>&1; then
        docker volume rm "$CACHE_VOLUME" >/dev/null
        echo -e "${GREEN}✓ Docker volume '$CACHE_VOLUME' removed.${NC}"
    fi
    echo -e "${GREEN}✓ Clean complete.${NC}"
}

run_tests() {
    check_docker
    echo -e "${BOLD}${CYAN}🚀 Running Pre-Push Verification Test Suite...${NC}"
    echo -e "Testing key board and shield combinations before pushing to remote.\n"

    local targets_json
    targets_json=$(parse_targets_py test_targets)
    local count
    count=$(echo "$targets_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

    local failed=0
    local passed=0

    for i in $(seq 0 $((count - 1))); do
        local t_json
        t_json=$(echo "$targets_json" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)[$i]))")
        local name
        name=$(echo "$t_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('artifact-name', ''))")

        if build_target_json "$t_json" "false"; then
            passed=$((passed + 1))
        else
            echo -e "${RED}❌ Build failed for target:${NC} $name"
            failed=$((failed + 1))
        fi
    done

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Pre-Push Verification Summary:${NC}"
    echo -e "  ${GREEN}Passed: $passed${NC}"
    if [ "$failed" -gt 0 ]; then
        echo -e "  ${RED}Failed: $failed${NC}"
        echo -e "${RED}❌ Some builds failed. Fix errors before pushing!${NC}"
        exit 1
    else
        echo -e "  ${RED}Failed: 0${NC}"
        echo -e "${GREEN}✅ All verification targets built successfully! Safe to push.${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_all() {
    check_docker
    echo -e "${BOLD}${CYAN}🚀 Building all matrix targets from build.yaml...${NC}\n"

    local targets_json
    targets_json=$(parse_targets_py all)
    local count
    count=$(echo "$targets_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")

    for i in $(seq 0 $((count - 1))); do
        local t_json
        t_json=$(echo "$targets_json" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin)[$i]))")
        build_target_json "$t_json" "false"
    done

    echo -e "${GREEN}✅ All targets built successfully! Check ./artifacts/ directory.${NC}"
}

run_interactive() {
    check_docker
    echo -e "${BOLD}Select a firmware configuration to build:${NC}\n"

    local list_output
    list_output=$(parse_targets_py list)

    echo -e "   ${CYAN}Special Targets:${NC}"
    echo -e "   [t] ${BOLD}Pre-push verification test${NC} (builds 3 core targets)"
    echo -e "   [a] ${BOLD}Build all targets${NC} (all 10 matrix builds)"
    echo -e "   [u] ${BOLD}Force update dependencies${NC} (west update)"
    echo -e "   [c] ${BOLD}Clean cache & artifacts${NC}"
    echo -e "   [q] ${BOLD}Quit${NC}\n"
    echo -e "   ${CYAN}Matrix Targets:${NC}"

    while IFS='|' read -r idx art board shield; do
        printf "   [%2d] %-46s %s\n" "$idx" "$art" "($board)"
    done <<< "$list_output"

    echo
    read -rp "Enter choice [1-10, t, a, u, c, q]: " choice

    case "$choice" in
        t|T) run_tests ;;
        a|A) run_all ;;
        u|U)
            local first_target
            first_target=$(parse_targets_py get 1)
            build_target_json "$first_target" "true"
            ;;
        c|C) clean_all ;;
        q|Q) exit 0 ;;
        *)
            if [ -n "$choice" ]; then
                local target_json
                if target_json=$(parse_targets_py get "$choice" 2>/dev/null); then
                    build_target_json "$target_json" "false"
                else
                    echo -e "${RED}Invalid choice: $choice${NC}"
                    exit 1
                fi
            fi
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Main Entrypoint
# ------------------------------------------------------------------------------
case "$1" in
    "")
        run_interactive
        ;;
    -h|--help|help)
        show_help
        ;;
    -t|--test|test)
        run_tests
        ;;
    -a|--all|all)
        run_all
        ;;
    --clean|clean)
        clean_all
        ;;
    -u|--update|update)
        check_docker
        first_target=$(parse_targets_py get 1)
        build_target_json "$first_target" "true"
        ;;
    *)
        check_docker
        if target_json=$(parse_targets_py get "$1" 2>/dev/null); then
            build_target_json "$target_json" "false"
        else
            echo -e "${RED}❌ Unknown target or option:${NC} $1"
            echo "Run './build.sh --help' to see available options and aliases."
            exit 1
        fi
        ;;
esac
