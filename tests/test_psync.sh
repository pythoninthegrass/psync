#!/usr/bin/env bash

set -eo pipefail

# trap exit signals 2, 1, 15
trap "exit" SIGINT SIGHUP SIGTERM

# Get the root directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
TLD=$(cd "${SCRIPT_DIR}/.." && pwd)

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration
TEST_DIR="/tmp/psync_test"
SOURCE_DIR="${TEST_DIR}/source"
DEST_DIR="${TEST_DIR}/destination"
NUM_FILES=10000
MAX_FILE_SIZE=$((10 * 1024 * 1024)) # 10 MB
DEFAULT_PARALLEL=4
PSYNC_SCRIPT="${TLD}/psync"

# Create test directories
setup_test_environment() {
    echo -e "${GREEN}Setting up test environment...${NC}"
    mkdir -p "${SOURCE_DIR}" "${DEST_DIR}"
}

# Generate fake data
generate_fake_data() {
    echo -e "${GREEN}Generating fake data...${NC}"
    local file_size_sum=0
    local progress=0
    local start_time=$(date +%s)

    for i in $(seq 1 ${NUM_FILES}); do
        file_size=$((RANDOM % MAX_FILE_SIZE + 1))
        file_size_sum=$((file_size_sum + file_size))

        if [[ "$(uname)" == "Darwin" ]]; then
            mkfile -n ${file_size} "${SOURCE_DIR}/file_${i}"
        else
            head -c ${file_size} /dev/urandom > "${SOURCE_DIR}/file_${i}"
        fi

        progress=$((progress + 1))
        if ((progress % 100 == 0)); then
            current_time=$(date +%s)
            elapsed=$((current_time - start_time))
            echo -ne "\rGenerated ${progress}/${NUM_FILES} files (${elapsed}s)"
        fi
    done

    echo -e "\n${GREEN}Fake data generation complete. Total size: $((file_size_sum / 1024 / 1024)) MB${NC}"
}

# Run rsync
run_rsync() {
    echo -e "${GREEN}Running standard rsync...${NC}"
    time rsync \
		-a \
		--info=progress2 \
		"${SOURCE_DIR}/" "${DEST_DIR}_rsync/"
}

# Run psync
run_psync() {
    local parallel_processes=$1

    echo -e "${GREEN}Running psync with ${parallel_processes} parallel processes...${NC}"
    time "${PSYNC_SCRIPT}" --parallel="${parallel_processes}" \
		-a \
		--info=progress2 \
		"${SOURCE_DIR}/" "${DEST_DIR}_psync/"
}

# Clean up
cleanup() {
    echo -e "${GREEN}Cleaning up...${NC}"
    rm -rf "${TEST_DIR}"
}

# Main function
main() {
    local parallel_processes=${1:-$DEFAULT_PARALLEL}

    setup_test_environment
    generate_fake_data
    run_rsync
    run_psync "$parallel_processes"
    cleanup
}

# Run the test
main "$@"

echo -e "${GREEN}Performance test complete.${NC}"
