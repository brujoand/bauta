function process_helper() {
  # This sucks, but we can't use a subshell
  local test_name=$1
  local tmp_file="/tmp/bauta.$test_name.$RANDOM.tmp"
  local output
  "$test_name" &> "$tmp_file"
  status=$?
  output=$(cat "$tmp_file")

  if [[ "$status" -gt 0 ]]; then
    local message
    handle_event "$BEGIN" "$test_name"
    message=$(overflow_message "$ERROR" "${output}")
    handle_event "$ERROR" "${message}|${status}"
    handle_event "$END" "$test_name"
    summarize_last_test
  fi
  rm "$tmp_file"
}

function process_test() {
    local test_name=$1
    local message
    handle_event "$BEGIN" "$test_name"

    # This variable can't be made local. Find out why
    local output status
    output=$(set -e;$test_name 2>&1; set +e)
    status=$?

    if [[ "$status" -gt 0 ]]; then
      message=$(overflow_message "$ERROR" "${output}")
      handle_event "$ERROR" "${message}|${status}"
    fi

    handle_event "$END" "$test_name"
    summarize_last_test
}

function process_file() {
  # todo sanitycheck the file
  local test_file=$1
  # shellcheck source=/dev/null
  source "$test_file"

  handle_event "$OPEN" "$test_file"

  # Run setup function if defined
  grep -q '^function setup()' "$test_file" && process_helper "setup"

  sed -n 's/^function \(test_.*\)().*/\1/p' "$test_file" | while IFS= read -r test_name; do
    process_test "$test_name"
  done

  # Run cleanup if defined
  grep -q '^function cleanup()' "$test_file" && process_helper "cleanup"

  handle_event "$CLOSE" "$test_file"
  summarize_last_file
}

function process_test_folder() {
  while IFS= read -r -d '' file; do
    (process_file "$file")
  done < <(find "$test_folder" -type f \( -name '*.bash' -or -name '*.sh' \) -print0)
  local problems
  problems=$(summarize_all_files)
  write_events_as_xml
  if [[ "$problems" == 0 ]]; then
    exit 0
  else
    exit 1
  fi
}
