#!/usr/bin/env bash

function test_that_we_can_match_substring() {
  string="This is a long string"
  substring="string"
  assert_substring "$substring" "$string"
}

function test_that_we_can_assert_non_empty() {
  string="heioghopp"
  assert_none_empty "$string"
  echo "This should not print anywhere"
}

function test_that_we_can_assert_number() {
  number=1
  assert_number "$number"
}
