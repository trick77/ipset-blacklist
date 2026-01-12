#!/usr/bin/env bats
#
# Integration tests for update-blacklist.sh using --dry-run mode
#

load '../helpers/test_helper'

setup() {
  # Create output directory for dry-run
  export TEST_OUTPUT_DIR="${BATS_TMPDIR}/nftables-blacklist"
  mkdir -p "${TEST_OUTPUT_DIR}"
  chmod 777 "${TEST_OUTPUT_DIR}"

  # Create test config
  export TEST_CONFIG="${BATS_TMPDIR}/test-config.conf"
  cat > "${TEST_CONFIG}" << EOF
# Test configuration for dry-run tests

# Use file:// URLs pointing to fixtures for offline testing
BLACKLISTS=(
  "file://${FIXTURES_DIR}/ipv4-public.txt"
  "file://${FIXTURES_DIR}/ipv6-public.txt"
)

# Output paths
NFT_BLACKLIST_SCRIPT="${TEST_OUTPUT_DIR}/blacklist.nft"
IP_BLACKLIST="${TEST_OUTPUT_DIR}/ip-blacklist.list"

# Table/set names
NFT_TABLE_NAME="test_blacklist"
NFT_SET_NAME_V4="test_blacklist4"
NFT_SET_NAME_V6="test_blacklist6"
NFT_CHAIN_NAME="test_input"
NFT_CHAIN_PRIORITY=-200

# Enable both IP versions
ENABLE_IPV4=yes
ENABLE_IPV6=yes

# No whitelist for basic tests
WHITELIST=()
AUTO_WHITELIST=no

# Small chunk for testing
CHUNK_SIZE=100
EOF
}

teardown() {
  rm -rf "${BATS_TMPDIR}/nftables-blacklist"
  rm -f "${TEST_CONFIG}"
}

@test "dry-run: exits successfully with valid config" {
  run "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ "$status" -eq 0 ]
}

@test "dry-run: outputs DRY-RUN indicator" {
  run "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY-RUN]"* ]]
}

@test "dry-run: creates nftables script file" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ -f "${TEST_OUTPUT_DIR}/blacklist.nft" ]
}

@test "dry-run: creates IP list file" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ -f "${TEST_OUTPUT_DIR}/ip-blacklist.list" ]
}

@test "dry-run: nftables script contains flush commands" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  grep -q "flush set" "${TEST_OUTPUT_DIR}/blacklist.nft"
}

@test "dry-run: nftables script contains table name" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  grep -q "test_blacklist" "${TEST_OUTPUT_DIR}/blacklist.nft"
}

@test "dry-run: nftables script contains IPv4 elements" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  grep -q "test_blacklist4" "${TEST_OUTPUT_DIR}/blacklist.nft"
}

@test "dry-run: nftables script contains IPv6 elements" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  grep -q "test_blacklist6" "${TEST_OUTPUT_DIR}/blacklist.nft"
}

@test "dry-run: IP list contains public IPv4" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  grep -q "1.1.1.1" "${TEST_OUTPUT_DIR}/ip-blacklist.list" || \
  grep -q "8.8.8.8" "${TEST_OUTPUT_DIR}/ip-blacklist.list"
}

@test "dry-run: IP list does not contain private ranges" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  ! grep -qE "^10\." "${TEST_OUTPUT_DIR}/ip-blacklist.list"
  ! grep -qE "^192\.168\." "${TEST_OUTPUT_DIR}/ip-blacklist.list"
  ! grep -qE "^172\.(1[6-9]|2[0-9]|3[0-1])\." "${TEST_OUTPUT_DIR}/ip-blacklist.list"
}

@test "dry-run: reports IP counts" {
  run "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"IPv4:"* ]]
  [[ "$output" == *"IPv6:"* ]]
}

@test "dry-run: --help shows usage" {
  run "${SCRIPT_PATH}" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "dry-run: missing config file fails" {
  run "${SCRIPT_PATH}" --dry-run /nonexistent/config.conf

  [ "$status" -eq 1 ]
}

@test "dry-run: no config file argument fails" {
  run "${SCRIPT_PATH}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"specify a configuration file"* ]]
}

@test "dry-run: unknown option fails" {
  run "${SCRIPT_PATH}" --invalid-option "${TEST_CONFIG}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown option"* ]]
}

@test "dry-run: creates separate IPv4 list file" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ -f "${TEST_OUTPUT_DIR}/ip-blacklist.list.v4" ]
}

@test "dry-run: creates separate IPv6 list file" {
  "${SCRIPT_PATH}" --dry-run "${TEST_CONFIG}"

  [ -f "${TEST_OUTPUT_DIR}/ip-blacklist.list.v6" ]
}
