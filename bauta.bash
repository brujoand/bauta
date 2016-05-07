#! /usr/bin/env bash
wd=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# shellcheck source=helpers/assert.bash
source "$wd"/helpers/assert.bash
# shellcheck source=helpers/event.bash
source "$wd"/helpers/event.bash
# shellcheck source=helpers/processer.bash
source "$wd"/helpers/processer.bash

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

#######################
#### Main handling ####
#######################

exec 3>&1 # make stdout avalable to subshells
target_folder="$(pwd)/target"
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
      target_folder="${PWD}${OPTARG}"
      echo "setting folder $target_folder"
      ;;
    *)
      print_usage
      ;;
  esac
done

shift $((OPTIND-1))

if [[ -n "$1" ]]; then
  test_folder=$(cd "$1" && pwd)
  reset_output_dir
  process_test_folder
else
  print_usage
fi

