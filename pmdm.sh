#!/usr/bin/env bash

set -euo pipefail

#TODO: apply consistent style guide (Google Shell Styleguide, ShellCheck, etc)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/password-manager-dotfile-manager"
CONFIG_FILE="${CONFIG_DIR}/pmdm.env"
CONFIG_FILE_TEMPLATE="${SCRIPT_DIR}/pmdm.env.template"
FILE_HASHES_FILE="${CONFIG_DIR}/pmdm-hashes.txt"

# Define some helper functions
exiterr() {
  >&2 echo "ERROR: ${1}"
  exit 1
}

store-file-hash() {
  local ITEM_NAME="${1}"
  local FILE_PATH="${2}"

  # FIXME: ensure md5sum is installed in the setup steps
  FILE_HASH="$( md5sum "${FILE_PATH}" | head -c32 )"

  touch "${FILE_HASHES_FILE}"



}

require-env() {
  local var_name="${1}"
  [[ -z "${!var_name:-}" ]] && exiterr "${CONFIG_FILE} missing required environtment variable: ${var_name}"
  return 0
}

print-usage() {
  exiterr "Usage message goes here"
}

source-password-manager-implementation() {
  require-env PASSWORD_MANAGER
  case "${PASSWORD_MANAGER}" in
    "bw")
      source "${SCRIPT_DIR}/pmdm-bitwarden.sh"
      ;;
    "op")
      source "${SCRIPT_DIR}/pmdm-1password.sh"
      ;;
    *)
      exiterr "Unknown password manager ${PASSWORD_MANAGER}"
      ;;
  esac
}

# Takes an absolute filesystem path and checks it against the ROOT_DIRECTORY aliases, possibly shortening it
create-item-name() {
  local ABS_PATH="${1}"

  # Since prefixes can be subsets of eachother, look for the most specific/longest matching one
  LONGEST_PREFIX_ALIAS=""
  LONGEST_PREFIX_LENGTH=0
  for ALIAS_PREFIX in "${!ROOT_DIRECTORY_MAP[@]}"
  do
    ALIAS_PATH="${ROOT_DIRECTORY_MAP[$ALIAS_PREFIX]%/}" # Drop trailing / if one was present

    if [[ "${ABS_PATH}" == "${ALIAS_PATH}"* ]] && [[ ${#ALIAS_PATH} -gt "${LONGEST_PREFIX_LENGTH}" ]]; then
      LONGEST_PREFIX_ALIAS="${ALIAS_PREFIX}"
      LONGEST_PREFIX_LENGTH="${#ALIAS_PATH}"
    fi
  done

  # TODO: should I even allow absolute paths that don't match any root directory?

  echo "${LONGEST_PREFIX_ALIAS}$( echo "${ABS_PATH}" | cut -c$(( ${LONGEST_PREFIX_LENGTH} + 1 ))- )"
}

from-item-name() {
  local ITEM_NAME="${1}"

  # TODO: this
  ALIAS_PREFIX=""
  PATH_REMAINDER=""

  ALIAS_PATH="${ROOT_DIRECTORY_MAP[$ALIAS_PREFIX]%/}" # Drop trailing / if one was present

  echo "${ALIAS_PATH}/${PATH_REMAINDER}"
}

to-rel-path() {
  local ABS_PATH="${1}"

  local COMMON_PATH="${PWD}" # Initialize with current directory
  local RESULT=""

  # keep going up levels finding a common prefix
  while [[ "${ABS_PATH#$COMMON_PATH}" == "${ABS_PATH}" ]]; do
    COMMON_PATH="$(dirname "${COMMON_PATH}" )"
    # TODO: can I collapse this if/else into something simpler?
    if [[ -z "${RESULT}" ]]; then
      RESULT=".."
    else
      RESULT="../${RESULT}"
    fi
  done

  # special case for no common path
  if [[ "${COMMON_PATH}" == "/" ]]; then
    RESULT="${RESULT}/"
  fi

  # compute the non-common part by removing the common part 
  FORWARD_PATH="${ABS_PATH#$COMMON_PATH}"

  if [[ -n "${RESULT}" ]] && [[ -n "${FORWARD_PATH}" ]]; then
    echo "$RESULT$FORWARD_PATH"
  elif [[ -n "${FORWARD_PATH}" ]]; then
    echo "${FORWARD_PATH:1}" # TODO: why bother with the last "if" -- seems like a "neither branch" result isn't really acceptable
  fi
}

to-abs-path() {
  local REL_PATH="${1}"

  if [[ -d "${REL_PATH}" ]]; then
    ( cd "${REL_PATH}"; pwd )
  elif [[ -f "${REL_PATH}" ]]; then
    if [[ "${REL_PATH}" == /* ]]; then
      echo "${REL_PATH}"
    elif [[ ${REL_PATH} == */* ]]; then
      echo "$(cd "${REL_PATH%/*}"; pwd)/${REL_PATH##*/}"
    else
      echo "${PWD}/${REL_PATH}"
    fi
  fi
}

push-one() {
  local FORCE="${1}"
  local REL_PATH="${2}"

  [[ -f "${REL_PATH}" ]] || exiterr "${REL_PATH}: file not found"

  # push <file> -- push to remote a single file, interactive prompt if any remote changes would be overwritten
  # push --force <file> -- push to remote a single file, overwriting any remote changes

  # push <file> push local file that is unchanged in the repo, WARN if there are remote changes
  # push --force <file> push file overwriting changes in the repo

  ABS_PATH="$( to-abs-path "${REL_PATH}" )"
  ITEM_NAME="$( create-item-name "${ABS_PATH}" )"

  # remote doesn't exist -- add new
  # remote exists and matches -- no-op, already up to date
  # remote exists and differs, remote = last hash -- save it
  # remote exists and differs and doesn't == last hash -- warn or save based on --force flag

  upsert-password-manager-item "${ITEM_NAME}" "${ABS_PATH}"
}

pull-one() {
  # pull <file> -- grab locally a single file, interactive prompt if there are local changes that would be overwritten
  # pull --force <file> -- grab locally a single file, overwriting any local changes
  exiterr "pull not implemented"
}

push-all() {
  # push <no args> push all locally modified files that are unchanged in the repo, WARN for ones that are changed

  # loop the items (that exists locally)
  # call pull-one on each

  exiterr "push all not implemented"
}

pull-all() {
  # pull <no args> pull all locally modified files that are absent or unchanged on disk, WARN for ones that are changed

  # loop the items
  # call pull-one on each
  exiterr "pull all not implemented"
}

###### DONE FUNCTION DEFINITIONS #########

[[ "${EUID}" -eq 0 ]] && exiterr "Don't run this as root"

# Create my own config dir if needed
[[ -d "${CONFIG_DIR}" ]] || mkdir -p "${CONFIG_DIR}"
# Copy template config file if none exists yet
[[ -f "${CONFIG_FILE}" ]] || cp "${CONFIG_FILE_TEMPLATE}" "${CONFIG_FILE}"
# Source config file
source "${CONFIG_FILE}"

# Ensure some dependencies are installed
command -v md5sum &> /dev/null || exiterr "md5sum command not found. Please install it"

source-password-manager-implementation

# TODO: re-format ROOT_DIRECTORIES to be ALIAS=/path:ALIAS2=/path/2
require-env PMDM_ROOT_DIRECTORIES
# TODO: parse root_directories here manually
eval "declare -A ROOT_DIRECTORY_MAP=( ${PMDM_ROOT_DIRECTORIES} )"

ensure-password-manager-installed
ensure-password-manager-logged-in
assert-password-manager-configured

# Parse args and process commands
COMMAND="${1:-}"
shift
[[ -n "$COMMAND" ]] || print-usage

# then a big case statement for $COMMAND and do the thing that was asked of me
case "${COMMAND}" in
  "push")
    # add a new file or update an existing file
    # immediately push to password manager

    PUSH_FORCE=0
    if [[ "${1:-}" == "--force" ]]; then
      PUSH_FORCE=1
      shift
    fi

    if [[ -n "${1:-}" ]]; then
      push-one "${PUSH_FORCE}" "${1}"
    else
      [[ "${PUSH_FORCE}" == "1" ]] && print-usage 
      push-all
    fi
    ;;
  "pull")
    # pull the copy from the password manager to the local disk

    PULL_FORCE=0
    if [[ "${1:-}" == "--force" ]]; then
      PULL_FORCE=1
      shift
    fi

    if [[ -n "${1:-}" ]]; then
      pull-one "${PULL_FORCE}" "${1}"
    else
      [[ "${PULL_FORCE}" == "1" ]] && print-usage 
      pull-all
    fi
    ;;
  "rm")
    [[ -z "${1:-}" ]] && print-usage

    ABS_PATH="$( to-abs-path "$1" )"
    ITEM_NAME="$( create-item-name "$ABS_PATH" )"

    delete-password-manager-item "${ITEM_NAME}"
    ;;
  "diff")
    # just a single file, print detailed outputs
    # feel free to use a temp directory (or two)
    # diff -- size, timestamp, full contents / `diff` output, "changed locally", "changed remote", "both changed"
    exiterr "diff not implemented"
    ;;
  "status")
    exiterr "status not implemented"

    # status -- just print info about each

    # loop the items in password manager
    # get local hash, remote hash, last hash, timestamps?
    # print statuses
    # local missing
    # local missing + parent directory absent
    # match / up to date
    # different (different local changed, different remote changed, different both changed)
    # no such thing as "remote missing" since we're enumerating the files stored in the remote
    # TODO: check if its like, a symlink and complain? (or is that actually fine?)
    # if local file is a folder, exiterr

    # File last modified time in the same format as the JSON returned by bw (but what about 1pass??)
    # Maybe better to go the other way and convert them all into unix timestamps
    # date -u -r "${ABS_PATH}" "+%Y-%m-%dT%H:%M:%S.%N" | sed -r "s/[0-9]{6}$/Z/"

    # TODO: set the modify timestamps to the password manager ones on clone?

    # TODO: keep track of "what was the contents the last time I checked it out" in order to have a better automatic resolution option?

    # list items (get ID/name pairs)
    # turn item_name back into abs path
    # get parent folder
    # if file exists
    #   check if same
    #   if same, do nothing
    #   if conflict mode undefined, prompt and ask
    # TODO: do I have timestamps on both??
    #   if conflict mode prefer-local then add
    #   if conflict mode prefer-remote then check it out
    # else if parent folder exists
    #   check it out
    # else
    #   print a warning about parent folder ain't exist, skipping file
    # fi
    ;;
  *)
    echo "Unknown command ${COMMAND}"
    print-usage
    ;;
esac
