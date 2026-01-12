#!/usr/bin/env bash
#
# BATS test helper for update-blacklist.sh tests
#
# Provides:
#   - Common setup/teardown functions
#   - Mocks for external commands (curl, nft)
#   - Utility functions for loading script functions
#

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/.." && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/update-blacklist.sh"
FIXTURES_DIR="${SCRIPT_DIR}/test/fixtures"
MOCK_DIR="${BATS_TMPDIR}/mocks"
MOCK_LOG="${BATS_TMPDIR}/mock_calls.log"

# Setup function - called before each test
setup() {
  # Create temp directories
  mkdir -p "${BATS_TMPDIR}/work"
  mkdir -p "${MOCK_DIR}"

  # Clear mock log
  : > "${MOCK_LOG}"

  # Export for use in tests
  export SCRIPT_DIR SCRIPT_PATH FIXTURES_DIR MOCK_DIR MOCK_LOG
}

# Teardown function - called after each test
teardown() {
  # Cleanup temp files
  rm -rf "${BATS_TMPDIR}/work" 2>/dev/null || true
  rm -rf "${MOCK_DIR}" 2>/dev/null || true
  rm -f "${MOCK_LOG}" 2>/dev/null || true
}

#=============================================================================
# FUNCTION LOADING
#=============================================================================

# Source specific functions from the script without executing main()
# This extracts function definitions for unit testing
load_script_functions() {
  # Extract function definitions only (skip main execution)
  # We source a modified version that doesn't call main
  local temp_script="${BATS_TMPDIR}/script_functions.sh"

  # Copy script but:
  # 1. Remove set -euo pipefail to prevent early exit
  # 2. Comment out the main call
  # 3. Comment out the exit at the end
  sed -e 's/^set -euo pipefail/# set -euo pipefail/' \
      -e 's/^main "\$@"/# main "$@"/' \
      -e 's/^set +e$/# set +e/' \
      -e 's/^exit 0$/# exit 0/' \
      "${SCRIPT_PATH}" > "${temp_script}"

  # Source the modified script to get function definitions
  # shellcheck source=/dev/null
  source "${temp_script}" 2>/dev/null || true
}

#=============================================================================
# MOCK FUNCTIONS
#=============================================================================

# Mock curl - returns fixture data based on URL patterns
mock_curl() {
  echo "curl $*" >> "${MOCK_LOG}"

  local url=""
  local output_file=""

  # Parse curl arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o) output_file="$2"; shift 2 ;;
      -s|-L|-A|--connect-timeout|--max-time) shift; [[ "$1" != -* ]] && shift ;;
      -w) shift; shift ;;  # Skip -w format
      https://*|http://*|file://*) url="$1"; shift ;;
      *) shift ;;
    esac
  done

  # Return mock data based on URL
  local mock_response=""
  case "$url" in
    *spamhaus*|*blocklist*)
      mock_response="${FIXTURES_DIR}/ipv4-public.txt"
      ;;
    *ipv6*)
      mock_response="${FIXTURES_DIR}/ipv6-public.txt"
      ;;
    *)
      mock_response="${FIXTURES_DIR}/ipv4-bare.txt"
      ;;
  esac

  if [[ -n "$output_file" ]] && [[ -f "$mock_response" ]]; then
    cp "$mock_response" "$output_file"
  elif [[ -f "$mock_response" ]]; then
    cat "$mock_response"
  fi

  # Return HTTP 200
  echo "200"
}

# Mock nft - logs calls without executing
mock_nft() {
  echo "nft $*" >> "${MOCK_LOG}"
  return 0
}

# Enable mocks by creating wrapper scripts in MOCK_DIR
enable_mocks() {
  # Create curl mock
  cat > "${MOCK_DIR}/curl" << 'MOCK_EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/helpers/test_helper.bash"
mock_curl "$@"
MOCK_EOF
  chmod +x "${MOCK_DIR}/curl"

  # Create nft mock
  cat > "${MOCK_DIR}/nft" << 'MOCK_EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/helpers/test_helper.bash"
mock_nft "$@"
MOCK_EOF
  chmod +x "${MOCK_DIR}/nft"

  # Prepend mock dir to PATH
  export PATH="${MOCK_DIR}:${PATH}"
}

#=============================================================================
# ASSERTION HELPERS
#=============================================================================

# Assert file contains exactly expected lines (ignoring order)
assert_file_contains_lines() {
  local file="$1"
  shift
  local expected=("$@")

  for line in "${expected[@]}"; do
    if ! grep -qF "$line" "$file"; then
      echo "Expected line not found: $line"
      echo "File contents:"
      cat "$file"
      return 1
    fi
  done
}

# Assert file does not contain any of the specified lines
assert_file_excludes_lines() {
  local file="$1"
  shift
  local excluded=("$@")

  for line in "${excluded[@]}"; do
    if grep -qF "$line" "$file"; then
      echo "Unexpected line found: $line"
      echo "File contents:"
      cat "$file"
      return 1
    fi
  done
}

# Count lines in file
count_lines() {
  local file="$1"
  wc -l < "$file" | tr -d ' '
}

# Assert line count
assert_line_count() {
  local file="$1"
  local expected_count="$2"
  local actual
  actual=$(count_lines "$file")

  if [[ "$actual" -ne "$expected_count" ]]; then
    echo "Expected $expected_count lines, got $actual"
    echo "File contents:"
    cat "$file"
    return 1
  fi
}
