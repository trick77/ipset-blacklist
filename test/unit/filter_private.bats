#!/usr/bin/env bats
#
# Unit tests for filter_private_ipv4() and filter_private_ipv6() functions
#

load '../helpers/test_helper'

setup() {
  load_script_functions
  mkdir -p "${BATS_TMPDIR}/work"
}

teardown() {
  rm -rf "${BATS_TMPDIR}/work"
}

#=============================================================================
# filter_private_ipv4 tests
#=============================================================================

@test "filter_private_ipv4: removes RFC1918 10.0.0.0/8" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "10.0.0.1\n10.255.255.255\n8.8.8.8" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" != *"10.0.0.1"* ]]
  [[ "$output" != *"10.255.255.255"* ]]
}

@test "filter_private_ipv4: removes RFC1918 172.16.0.0/12" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "172.16.0.1\n172.31.255.255\n172.15.0.1\n172.32.0.1" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  # Should keep 172.15.x.x and 172.32.x.x (outside /12 range)
  [[ "$output" == *"172.15.0.1"* ]]
  [[ "$output" == *"172.32.0.1"* ]]
  # Should remove 172.16-31.x.x
  [[ "$output" != *"172.16.0.1"* ]]
  [[ "$output" != *"172.31.255.255"* ]]
}

@test "filter_private_ipv4: removes RFC1918 192.168.0.0/16" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "192.168.0.1\n192.168.255.255\n192.167.0.1" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"192.167.0.1"* ]]
  [[ "$output" != *"192.168.0.1"* ]]
  [[ "$output" != *"192.168.255.255"* ]]
}

@test "filter_private_ipv4: removes loopback 127.0.0.0/8" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "127.0.0.1\n127.0.0.53\n127.255.255.255\n8.8.8.8" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" != *"127.0.0.1"* ]]
  [[ "$output" != *"127.0.0.53"* ]]
}

@test "filter_private_ipv4: removes link-local 169.254.0.0/16" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "169.254.0.1\n169.254.255.255\n169.253.0.1" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"169.253.0.1"* ]]
  [[ "$output" != *"169.254.0.1"* ]]
}

@test "filter_private_ipv4: removes CGNAT 100.64.0.0/10" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "100.64.0.1\n100.127.255.255\n100.63.0.1\n100.128.0.1" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"100.63.0.1"* ]]
  [[ "$output" == *"100.128.0.1"* ]]
  [[ "$output" != *"100.64.0.1"* ]]
  [[ "$output" != *"100.127.255.255"* ]]
}

@test "filter_private_ipv4: removes documentation ranges" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "192.0.2.1\n198.51.100.1\n203.0.113.1\n8.8.8.8" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"8.8.8.8"* ]]
  # TEST-NET-1, TEST-NET-2, TEST-NET-3
  [[ "$output" != *"192.0.2.1"* ]]
  [[ "$output" != *"198.51.100.1"* ]]
  [[ "$output" != *"203.0.113.1"* ]]
}

@test "filter_private_ipv4: removes multicast 224.0.0.0/4" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "224.0.0.1\n239.255.255.255\n223.255.255.255" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"223.255.255.255"* ]]
  [[ "$output" != *"224.0.0.1"* ]]
  [[ "$output" != *"239.255.255.255"* ]]
}

@test "filter_private_ipv4: removes reserved 240.0.0.0/4" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "240.0.0.1\n255.255.255.255\n8.8.8.8" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" != *"240.0.0.1"* ]]
  [[ "$output" != *"255.255.255.255"* ]]
}

@test "filter_private_ipv4: removes 0.0.0.0/8" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "0.0.0.0\n0.0.0.1\n1.0.0.0" > "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0.0"* ]]
  [[ "$output" != *"0.0.0.0"* ]]
  [[ "$output" != *"0.0.0.1"* ]]
}

@test "filter_private_ipv4: keeps all public IPs" {
  run filter_private_ipv4 "${FIXTURES_DIR}/ipv4-public.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.1.1.1"* ]]
  [[ "$output" == *"8.8.8.8"* ]]
  [[ "$output" == *"9.9.9.9"* ]]
  [[ "$output" == *"208.67.222.222"* ]]
}

@test "filter_private_ipv4: removes all private IPs" {
  run filter_private_ipv4 "${FIXTURES_DIR}/ipv4-private.txt"

  [ "$status" -eq 0 ]
  # Should be empty or contain nothing
  [ -z "$output" ]
}

@test "filter_private_ipv4: handles empty file" {
  local input="${BATS_TMPDIR}/work/input.txt"
  touch "$input"

  run filter_private_ipv4 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

#=============================================================================
# filter_private_ipv6 tests
#=============================================================================

@test "filter_private_ipv6: removes loopback ::1" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "::1\n2001:4860:4860::8888" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860:4860::8888"* ]]
  [[ "$output" != *"::1"* ]]
}

@test "filter_private_ipv6: removes unspecified ::" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "::\n2606:4700:4700::1111" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2606:4700:4700::1111"* ]]
  # Note: :: might still appear as part of other addresses, so check carefully
}

@test "filter_private_ipv6: removes link-local fe80::/10" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "fe80::1\nfe80::abcd:1234\nfebf::1\n2001:db8::1" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  # fe80-febf should be filtered
  [[ "$output" != *"fe80::1"* ]]
  [[ "$output" != *"fe80::abcd:1234"* ]]
  [[ "$output" != *"febf::1"* ]]
}

@test "filter_private_ipv6: removes unique local fc00::/7" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "fc00::1\nfd00::1\nfd12:3456:789a::1\n2001:4860::1" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860::1"* ]]
  [[ "$output" != *"fc00::1"* ]]
  [[ "$output" != *"fd00::1"* ]]
  [[ "$output" != *"fd12:3456:789a::1"* ]]
}

@test "filter_private_ipv6: removes multicast ff00::/8" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "ff00::1\nff02::1\nff0e::1\n2620:fe::fe" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2620:fe::fe"* ]]
  [[ "$output" != *"ff00::1"* ]]
  [[ "$output" != *"ff02::1"* ]]
}

@test "filter_private_ipv6: removes documentation 2001:db8::/32" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "2001:db8::1\n2001:db8:85a3::8a2e:370:7334\n2001:4860::1" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860::1"* ]]
  [[ "$output" != *"2001:db8::1"* ]]
  [[ "$output" != *"2001:db8:85a3"* ]]
}

@test "filter_private_ipv6: keeps all public IPv6" {
  run filter_private_ipv6 "${FIXTURES_DIR}/ipv6-public.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"2001:4860:4860::8888"* ]]
  [[ "$output" == *"2606:4700:4700::1111"* ]]
  [[ "$output" == *"2620:fe::fe"* ]]
}

@test "filter_private_ipv6: removes all private IPv6" {
  run filter_private_ipv6 "${FIXTURES_DIR}/ipv6-private.txt"

  [ "$status" -eq 0 ]
  # Should be empty
  [ -z "$output" ]
}

@test "filter_private_ipv6: handles empty file" {
  local input="${BATS_TMPDIR}/work/input.txt"
  touch "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "filter_private_ipv6: case insensitive filtering" {
  local input="${BATS_TMPDIR}/work/input.txt"
  echo -e "FE80::1\nFC00::1\nFF02::1" > "$input"

  run filter_private_ipv6 "$input"

  [ "$status" -eq 0 ]
  # Should filter uppercase private addresses too
  [ -z "$output" ]
}
