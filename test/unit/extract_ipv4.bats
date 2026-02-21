#!/usr/bin/env bats
#
# Unit tests for extract_ipv4() function
#

load '../helpers/test_helper'

setup() {
  load_script_functions
  mkdir -p "${BATS_TMPDIR}/work"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/work"
}

@test "extract_ipv4: extracts bare IP addresses" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "1.2.3.4\n8.8.8.8\n203.0.114.50" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" == *"203.0.114.50"* ]]
}

@test "extract_ipv4: extracts IPs with CIDR notation" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "1.2.3.0/24\n10.0.0.0/8\n192.168.0.0/16" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.0/24"* ]]
  [[ "$output" == *"10.0.0.0/8"* ]]
  [[ "$output" == *"192.168.0.0/16"* ]]
}

@test "extract_ipv4: normalizes leading zeros" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "001.002.003.004" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  # Should NOT contain leading zeros
  [[ "$output" != *"001"* ]]
}

@test "extract_ipv4: extracts IPs embedded in text" {
  local input="${BATS_TMPDIR}/work/input.txt"
  cat > "$input" << 'EOF'
Blocked IP: 1.2.3.4 at time
Another line with 8.8.8.8 embedded
No IP here at all
Plain text: 203.0.114.1 is bad
EOF

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" == *"203.0.114.1"* ]]
}

@test "extract_ipv4: handles mixed IPv4 and garbage" {
  local input="${BATS_TMPDIR}/work/input.txt"
  cat > "$input" << 'EOF'
# Comment line
Valid: 1.2.3.4
Invalid: 999.999.999.999
Also valid: 8.8.8.8
2001:db8::1 is IPv6, not IPv4
EOF

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  # Should not extract the IPv6 address
  [[ "$output" != *"2001"* ]]
}

@test "extract_ipv4: handles empty file" {
  local input="${BATS_TMPDIR}/work/input.txt"
  touch "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extract_ipv4: handles file with no IPs" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "no ips here\njust text\nnothing to see" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extract_ipv4: extracts multiple IPs per line" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "Source: 1.2.3.4 Dest: 5.6.7.8" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  [[ "$output" == *"5.6.7.8"* ]]
}

@test "extract_ipv4: handles real-world blocklist format" {
  run extract_ipv4 "${FIXTURES_DIR}/ipv4-mixed-content.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.2.3.4"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" == *"10.0.0.0/8"* ]]
}

@test "extract_ipv4: preserves CIDR prefix length" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "1.0.0.0/8\n2.0.0.0/16\n3.0.0.0/24\n4.0.0.0/32" > "$input"

  run extract_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"/8"* ]]
  [[ "$output" == *"/16"* ]]
  [[ "$output" == *"/24"* ]]
  [[ "$output" == *"/32"* ]]
}
