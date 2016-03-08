function setup() {
  myname=brujoand
}

function cleanup() {
  echo "doing my cleanup"
}

function test_that_the_setup_has_side_effects() {
  assert_equals "$myname" "brujoand"
}

function test_the_overflow() {
  long=$(echo -e "Some weird Runtim Exception:\nthis one has newlines, many\n new lines\n yes many\n hoho")
  assert_equals "$long" "$long"
}
