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
