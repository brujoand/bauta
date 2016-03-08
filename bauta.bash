#! /usr/bin/env bash
wd=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# shellcheck source=helpers/assert.bash
source "$wd"/helpers/assert.bash
# shellcheck source=helpers/event.bash
source "$wd"/helpers/event.bash

######################
#### Test Running ####
######################

function bauta_log() {
  if [[ "$show_trace" -eq 1 ]]; then
    handle_event "$TRACE" "${BASH_SOURCE[1]}/${FUNCNAME[1]}|$1"
  fi
}

function overflow_message() { # Only put one message in the error/assert
  local action=$1
  local full_message=$2
  handle_event "$MESSAGE" "#$action#"
  sed '1!G;h;$!d' <(echo "${full_message}") | while IFS= read -r line; do
    handle_event "$MESSAGE" "$line"
  done
  if [[ "$(echo "${full_message}" | wc -l)" -gt 1 ]]; then
    echo "$(echo "${full_message}" | head -n 1) (see output xml for full message)"
  else
    echo "$full_message"
  fi
}

function process_helper() {
  # This sucks, but we can't use a subshell
  local test_name=$1
  local tmp_file="/tmp/bauta.$test_name.$RANDOM.tmp"
  local output
  set -e
  "$test_name" &> "$tmp_file"
  local status=$?
  output=$(cat "$tmp_file")
  set +e

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
  . "$test_file"

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

#######################
#### Main handling ####
#######################

exec 3>&1 # make stdout avalable to subshells
target_folder="$(pwd)/test-reports"
show_trace=0

function reset_output_dir() {
  test_logfile="$target_folder/test.log"
  xml_output_file="$target_folder/test.xml"
  [[ -d "$target_folder" ]] && rm -rf "$target_folder"
  mkdir -p "$target_folder"
  touch "$test_logfile"
}

function print_usage() {
  echo -e "Usage: \t$0 <flags> <test_folder>"
  echo " "
  echo "Flags:"
  echo -e "\t-l show log statements"
  echo -e "\t-h show this help text"
  echo -e "\t-o <dir> set output dir (will be overwritten/created)"
  exit 1
}

# Handling arguments
while getopts :o:l flag; do
  case $flag in
    l)
      show_trace=1
      echo setting trace
      ;;
    o)
      target_folder=$OPTARG
      echo "setting folder $target_folder"
      ;;
    *)
      print_usage
      ;;
  esac
done

shift $((OPTIND-1))

if [[ -n "$1" ]]; then
  test_folder=${1%/}
  reset_output_dir
  process_test_folder
else
  print_usage
fi

