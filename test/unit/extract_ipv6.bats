#!/usr/bin/env bats
#
# Unit tests for extract_ipv6() function
#

load '../helpers/test_helper'

setup() {
  load_script_functions
  mkdir -p "${BATS_TMPDIR}/work"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/work"
}

@test "extract_ipv6: extracts full-form IPv6 addresses" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "2001:0db8:85a3:0000:0000:8a2e:0370:7334" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:0db8:85a3:0000:0000:8a2e:0370:7334"* ]] || \
  [[ "$output" == *"2001:db8:85a3::8a2e:370:7334"* ]]
}

@test "extract_ipv6: extracts compressed IPv6 addresses" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "2001:db8::1\nfe80::1\n::1" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:db8::1"* ]]
  [[ "$output" == *"fe80::1"* ]]
  [[ "$output" == *"::1"* ]]
}

@test "extract_ipv6: extracts IPv6 with CIDR notation" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "2001:db8::/32\nfe80::/10\n::/128" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:db8::/32"* ]]
  [[ "$output" == *"fe80::/10"* ]]
  [[ "$output" == *"::/128"* ]]
}

@test "extract_ipv6: converts to lowercase" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "2001:DB8:ABCD:EF01::1" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  # Output should be lowercase
  [[ "$output" == *"2001:db8:abcd:ef01::1"* ]]
  # Should NOT contain uppercase
  [[ "$output" != *"DB8"* ]]
  [[ "$output" != *"ABCD"* ]]
}

@test "extract_ipv6: extracts IPs embedded in text" {
  local input="${BATS_TMPDIR}/work/input.txt"
  cat > "$input" << 'EOF'
Malicious host: 2001:4860:4860::8888 detected
Block range 2606:4700::/32 immediately
No IP here
Address 2a00:1450:4001:82a::200e flagged
EOF

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860:4860::8888"* ]]
  [[ "$output" == *"2606:4700::/32"* ]]
  [[ "$output" == *"2a00:1450:4001:82a::200e"* ]]
}

@test "extract_ipv6: does not extract IPv4 addresses" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "1.2.3.4\n192.168.1.1\n8.8.8.8" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  # Should not match IPv4 addresses
  [[ "$output" != *"1.2.3.4"* ]]
  [[ "$output" != *"192.168.1.1"* ]]
}

@test "extract_ipv6: handles empty file" {
  local input="${BATS_TMPDIR}/work/input.txt"
  touch "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extract_ipv6: handles file with no IPv6" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "no ipv6 here\njust text\n1.2.3.4 is ipv4" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extract_ipv6: extracts Google DNS IPv6" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "2001:4860:4860::8888" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860:4860::8888"* ]]
}

@test "extract_ipv6: extracts Cloudflare DNS IPv6" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "2606:4700:4700::1111" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2606:4700:4700::1111"* ]]
}

@test "extract_ipv6: handles real-world blocklist format" {
  run extract_ipv6 "${FIXTURES_DIR}/ipv6-mixed-content.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860:4860::8888"* ]]
  [[ "$output" == *"2606:4700::/32"* ]]
  [[ "$output" == *"2a00:1450:4001:82a::200e"* ]]
}

@test "extract_ipv6: handles loopback address" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "::1" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"::1"* ]]
}

@test "extract_ipv6: handles unspecified address" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo "::" > "$input"

  run extract_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"::"* ]]
}
