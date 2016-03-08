#! /usr/bin/env bash

source helpers/assert.bash
####################
#### Statistics ####
####################

OPEN='open'
CLOSE='close'
BEGIN='begin'
END='end'
FAILURE='failure'
ERROR='error'
MESSAGE='message'
TEST='test'
FILE='file'
SUMMARY='summary'
TRACE='trace'

function handle_event() {
  local event_type event_data event
  event_type=$1
  event_data=$2
  event="${event_type}|${event_data}|$(date +'%s')"
  echo -e "${event}" >> "$test_logfile"

  case $event_type in
    $TRACE)
      display_event "${event}"
      ;;
    $OPEN)
      display_event "${event}"
      ;;
    $TEST)
      display_event "${event}"
      display_event "$(list_current_problems)"
      ;;
    $FILE)
      display_event "${event}"
      display_event " " # Create some air
      ;;
    $SUMMARY)
      display_event "${event}"
      ;;
  esac

}

function display_event() {
  local green red reset
  green=$(echo -e '\e[32m')
  red=$(echo -e '\e[31m')
  reset=$(echo -e '\e[39m')
  echo "${1}" | sed \
    -e "s/^$OPEN|\(.*\)|.*/  \1:/" \
    -e "s/^$TEST|\(.*\)|s|.*/$green    +$reset \1/" \
    -e "s/^$TEST|\(.*\)|.*|.*|.*/$red    -$reset \1/" \
    -e "s/^$FAILURE|\(.*\)|\(.*\)|.*/$red      [Failure]$reset line \2: \1/" \
    -e "s/^$ERROR|\(.*\)|.*|.*/$red      [Error]$reset \1/" \
    -e "s/^$FILE|.*|\(.*\)|\(.*\)|\(.*\)|\(.*\)|.*/  [Sum] tests: \1 failures: \2 errors: \3 time: \4s/" \
    -e "s/^$SUMMARY|\(.*\)|\(.*\)|\(.*\)|\(.*\)|.*/[Total] tests: \1 failures: \2 errors: \3 time: \4s/" \
    -e "s/^$TRACE|\(.*\)|\(.*\)|.*/      log[\1]: \2/" \
    -e '/^$/d' >&3
}

function list_all_events() {
  sed '1!G;h;$!d' "$test_logfile"
}

function list_current_problems() {
  list_all_events | sed "/^$BEGIN|/q" | grep -E "(^$ERROR|^$FAILURE)"
}

function write_events_as_xml() {
{ list_all_events | sed \
    -e "s/^$SUMMARY|\(.*\)|\(.*\)|\(.*\)|\(.*\)|.*/<testsuites tests='\1' failures='\2' errors='\3' time='\4'>/" \
    -e "s/^$FILE|\(.*\)|\(.*\)|\(.*\)|\(.*\)|\(.*\)|.*/<testsuite name='\1' tests='\2' failures='\3' errors='\4' time='\5'>/" \
    -e "s/^$FAILURE|\(.*\)|.*|.*/<failure message='Assertion failed' type='failure'>/" \
    -e "s/^$MESSAGE|#$FAILURE#|.*/<\/failure>/" \
    -e "s/^$MESSAGE|#$ERROR#|.*/<\/error>/" \
    -e "s/^$MESSAGE|\(.*\)|.*/\1/" \
    -e "s/^$ERROR|\(.*\)|.*|.*/<error message='Error' type='error'>/" \
    -e "s/^$TEST|\(.*\)|.*|\(.*\)|.*/<testcase name='\1' time='\2'>/" \
    -e "s/^$BEGIN|.*/<\/testcase>/" \
    -e "s/^$OPEN|.*/<\/testsuite>/" \
    -e "/^$TRACE/d" \
    -e "/^$END/d" \
    -e "/^$CLOSE/d" ; echo "</testsuites>"; }  > "$xml_output_file"
}

function summarize_last_test() {
  local test_data test_name failures errors seconds status
  test_data=$(list_all_events | sed "/^$BEGIN/q")
  test_name=$(sed -n "s/^$BEGIN|\(.*\)|.*/\1/p" <(echo "$test_data"))
  failures=$(grep -c "^$FAILURE" <(echo "$test_data"))
  errors=$(grep -c "^$ERROR" <(echo "$test_data"))
  seconds=$(grep -E "(^$BEGIN|^$END)" <(echo "$test_data") | cut -d '|' -f 3 | sort -nr | paste -sd- - | bc)

  if [[ "$errors" -gt 0 ]]; then
    status='e'
  elif [[ "$failures" -gt 0 ]]; then
    status='f'
  else
    status='s'
  fi

  handle_event "$TEST" "${test_name}|${status}|${seconds}"
}

function summarize_last_file() {
  local file_data file_name tests failures errors seconds
  file_data=$(list_all_events | sed "/^$OPEN/q")
  file_name=$(sed -n "s/^$OPEN|\(.*\)|.*/\1/p" <(echo "$file_data"))
  tests=$(grep -c "^$TEST" <(echo "$file_data"))
  failures=$(grep -c "^$FAILURE" <(echo "$file_data"))
  errors=$(grep -c "^$ERROR" <(echo "$file_data"))
  seconds=$(grep "^$TEST" <(echo "$file_data") | awk -F '|' '{sum+=$4} END {print sum}')

  handle_event "$FILE" "${file_name}|${tests:-0}|${failures:-0}|${errors:-0}|${seconds}"
}

function summarize_all_files() {
  # todo apply some more awk foo here
  local sum_data tests failures errors seconds
  sum_data=$(grep "^$FILE" "$test_logfile")
  tests=$(awk -F '|' '{sum+=$3} END {print sum}' <(echo "$sum_data"))
  failures=$(awk -F '|' '{sum+=$4} END {print sum}' <(echo "$sum_data"))
  errors=$(awk -F '|' '{sum+=$5} END {print sum}' <(echo "$sum_data"))
  seconds=$(awk -F '|' '{sum+=$6} END {print sum}' <(echo "$sum_data"))

  handle_event "$SUMMARY" "${tests}|${failures}|${errors}|${seconds}"
  echo $(( errors + failures ))
}

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

