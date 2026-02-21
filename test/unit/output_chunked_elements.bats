#!/usr/bin/env bats
#
# Unit tests for output_chunked_elements() function
#

load '../helpers/test_helper'

setup() {
  load_script_functions
  mkdir -p "${BATS_TMPDIR}/work"
  export NFT_TABLE_NAME="blacklist"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/work"
}

@test "output_chunked_elements: small file produces single add element line" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  printf '%s\n' "1.2.3.4" "5.6.7.8" "9.10.11.12" > "$input"

  run output_chunked_elements "$input" "blacklist4" "IPv4 addresses"

  [ "$status" -eq 0 ]
  [[ "$output" == *"# IPv4 addresses"* ]]
  [[ "$output" == *"add element inet blacklist blacklist4 { 1.2.3.4, 5.6.7.8, 9.10.11.12 }"* ]]
}

@test "output_chunked_elements: file exceeding chunk size produces multiple lines" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  # Generate 8 IPs with chunk size of 3 -> expect 3 add element lines (3+3+2)
  for i in $(seq 1 8); do
    echo "10.0.0.$i"
  done > "$input"

  CHUNK_SIZE=3 run output_chunked_elements "$input" "blacklist4" "IPv4 addresses"

  [ "$status" -eq 0 ]
  # Count the number of "add element" lines
  local add_count
  add_count=$(echo "$output" | grep -c "^add element")
  [ "$add_count" -eq 3 ]

  # First chunk: 3 IPs
  [[ "$output" == *"add element inet blacklist blacklist4 { 10.0.0.1, 10.0.0.2, 10.0.0.3 }"* ]]
  # Second chunk: 3 IPs
  [[ "$output" == *"add element inet blacklist blacklist4 { 10.0.0.4, 10.0.0.5, 10.0.0.6 }"* ]]
  # Third chunk: 2 remaining IPs
  [[ "$output" == *"add element inet blacklist blacklist4 { 10.0.0.7, 10.0.0.8 }"* ]]
}

@test "output_chunked_elements: empty file produces no output" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  touch "$input"

  run output_chunked_elements "$input" "blacklist4" "IPv4 addresses"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "output_chunked_elements: nonexistent file produces no output" {
  run output_chunked_elements "${BATS_TMPDIR}/work/nonexistent.txt" "blacklist4" "IPv4 addresses"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "output_chunked_elements: comma-separated format is correct" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  printf '%s\n' "192.168.1.0/24" "10.0.0.0/8" > "$input"

  run output_chunked_elements "$input" "blacklist4" "test"

  [ "$status" -eq 0 ]
  # Verify exact format: comma-space separated, wrapped in braces
  [[ "$output" == *"{ 192.168.1.0/24, 10.0.0.0/8 }"* ]]
}

@test "output_chunked_elements: works with IPv6 addresses" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  printf '%s\n' "2001:db8::1" "fe80::1" "::1" > "$input"

  run output_chunked_elements "$input" "blacklist6" "IPv6 addresses"

  [ "$status" -eq 0 ]
  [[ "$output" == *"add element inet blacklist blacklist6 { 2001:db8::1, fe80::1, ::1 }"* ]]
}

@test "output_chunked_elements: exact chunk size boundary" {
  local input="${BATS_TMPDIR}/work/ips.txt"
  # Generate exactly 3 IPs with chunk size of 3 -> should produce exactly 1 add element line
  printf '%s\n' "10.0.0.1" "10.0.0.2" "10.0.0.3" > "$input"

  CHUNK_SIZE=3 run output_chunked_elements "$input" "blacklist4" "test"

  [ "$status" -eq 0 ]
  local add_count
  add_count=$(echo "$output" | grep -c "^add element")
  [ "$add_count" -eq 1 ]
  [[ "$output" == *"{ 10.0.0.1, 10.0.0.2, 10.0.0.3 }"* ]]
}
