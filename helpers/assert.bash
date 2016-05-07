function assert_equals() { # assert that $1 is equal to $2
  local called_by_line="${BASH_LINENO[0]}"
  local message
  if [[ ! "$1" == "$2" ]]; then
    message=$(overflow_message "$FAILURE" "Expected '${1}' but got '${2}'")
    handle_event "$FAILURE" "${message}|${called_by_line}"
  fi
}

function assert_none_empty() { # assert that $1 is not empty or only spaces
  local called_by_line="${BASH_LINENO[0]}"
  local message
  if [[ -z "${1// }" ]]; then
    message=$(overflow_message "$FAILURE" "Value was empty, when expecting nonEmpty")
    handle_event "$FAILURE" "${message}|${called_by_line}"
  fi
}


function assert_substring() { # assert that $1 is a substring of $2
  local called_by_line="${BASH_LINENO[0]}"
  local message
  if [[ ! "$2" =~ $1 ]]; then
    message=$(overflow_message "$FAILURE" "'${1}' was not a substring of '${2}'")
    handle_event "$FAILURE" "${message}|${called_by_line}"
 fi
}

function assert_number() { # assert that $1 is a number
  local called_by_line="${BASH_LINENO[0]}"
  local message
  re='^[0-9]+$'
  if ! [[ "$1" =~ $re ]] ; then
    message=$(overflow_message "$FAILURE" "'${1}' was not a number")
    handle_event "$FAILURE" "${message}|${called_by_line}"
  fi
}

function assert_length() {
  local called_by_line="${BASH_LINENO[0]}"
  local message
  if ! [[ "${#1}" -eq "$2" ]] ; then
    message=$(overflow_message "$FAILURE" "'${1}' did not have asserted length '${2}'")
    handle_event "$FAILURE" "${message}|${called_by_line}"
  fi

}
