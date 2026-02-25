#!/usr/bin/env bats
#
# Unit tests for apply_whitelist() function
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
# IPv4 tests (require iprange)
#=============================================================================

@test "apply_whitelist: IPv4 removes whitelisted IPs via iprange" {
  command -v iprange >/dev/null || skip "iprange not installed"

  local blacklist="${BATS_TMPDIR}/work/blacklist.txt"
  local whitelist="${BATS_TMPDIR}/work/whitelist.txt"
  local outfile="${BATS_TMPDIR}/work/filtered.txt"

  echo -e "1.1.1.1\n8.8.8.8\n9.9.9.9" > "$blacklist"
  echo "1.1.1.1" > "$whitelist"

  run apply_whitelist "$blacklist" "$whitelist" "$outfile" "4"

  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  assert_file_excludes_lines "$outfile" "1.1.1.1"
  assert_file_contains_lines "$outfile" "8.8.8.8" "9.9.9.9"
}

@test "apply_whitelist: IPv4 copies original when iprange unavailable" {
  command -v iprange >/dev/null && skip "iprange is installed (testing fallback only)"

  local blacklist="${BATS_TMPDIR}/work/blacklist.txt"
  local whitelist="${BATS_TMPDIR}/work/whitelist.txt"
  local outfile="${BATS_TMPDIR}/work/filtered.txt"

  echo -e "1.1.1.1\n8.8.8.8\n9.9.9.9" > "$blacklist"
  echo "1.1.1.1" > "$whitelist"

  run apply_whitelist "$blacklist" "$whitelist" "$outfile" "4"

  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  # Fallback: original file is copied as-is (whitelist not applied)
  assert_file_contains_lines "$outfile" "1.1.1.1" "8.8.8.8" "9.9.9.9"
}

#=============================================================================
# IPv6 tests (uses grep, no external dependencies)
#=============================================================================

@test "apply_whitelist: IPv6 removes exact-match whitelisted IPs" {
  local blacklist="${BATS_TMPDIR}/work/blacklist.txt"
  local whitelist="${BATS_TMPDIR}/work/whitelist.txt"
  local outfile="${BATS_TMPDIR}/work/filtered.txt"

  echo -e "2001:4860:4860::8888\n2606:4700:4700::1111\n2620:fe::fe" > "$blacklist"
  echo "2606:4700:4700::1111" > "$whitelist"

  run apply_whitelist "$blacklist" "$whitelist" "$outfile" "6"

  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  assert_file_excludes_lines "$outfile" "2606:4700:4700::1111"
  assert_file_contains_lines "$outfile" "2001:4860:4860::8888" "2620:fe::fe"
}

#=============================================================================
# Edge cases
#=============================================================================

@test "apply_whitelist: empty whitelist passes through all IPs" {
  local blacklist="${BATS_TMPDIR}/work/blacklist.txt"
  local whitelist="${BATS_TMPDIR}/work/whitelist.txt"
  local outfile="${BATS_TMPDIR}/work/filtered.txt"

  echo -e "2001:4860:4860::8888\n2606:4700:4700::1111" > "$blacklist"
  touch "$whitelist"

  run apply_whitelist "$blacklist" "$whitelist" "$outfile" "6"

  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  assert_file_contains_lines "$outfile" "2001:4860:4860::8888" "2606:4700:4700::1111"
}

@test "apply_whitelist: empty blacklist produces empty output" {
  local blacklist="${BATS_TMPDIR}/work/blacklist.txt"
  local whitelist="${BATS_TMPDIR}/work/whitelist.txt"
  local outfile="${BATS_TMPDIR}/work/filtered.txt"

  touch "$blacklist"
  echo "2001:4860:4860::8888" > "$whitelist"

  run apply_whitelist "$blacklist" "$whitelist" "$outfile" "6"

  [ "$status" -eq 0 ]
  [ -f "$outfile" ]
  [ ! -s "$outfile" ]
}
