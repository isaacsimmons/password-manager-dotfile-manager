#!/usr/bin/env bash

set -euo pipefail

#TODO: apply consistent style guide (Google Shell Styleguide, ShellCheck, etc)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/password-manager-dotfile-manager"
CONFIG_FILE="${CONFIG_DIR}/pmdm.env"

# Define some helper functions
exiterr() {
  >&2 echo "ERROR: ${1}"
  exit 1
}

require-env() {
  local var_name="${1}"
  [[ -z "${!var_name:-}" ]] && exiterr "${CONFIG_FILE} missing required environtment variable: ${var_name}"
  return 0
}

print-usage() {
  exiterr "Usage message goes here"
}

do-config() {

TODO: Rip out a ton of this and just make them config things manually?


  # ask for password manager (default to current value if set)
  PASSWORD_MANAGER="${PASSWORD_MANAGER:-bw}"
  read -p "What password manager would you like to use (op, bw) [${PASSWORD_MANAGER}]: " PASSWORD_MANAGER_INPUT
  PASSWORD_MANAGER="${PASSWORD_MANAGER_INPUT:-$PASSWORD_MANAGER}"

  # Update the config file if they answered anything but the default
  [[ -n "${PASSWORD_MANAGER_INPUT}" ]] && write-config

  # Apply a default if the root directories aren't yet set
  if [[ -z "${PMDM_ROOT_DIRECTORIES:-}" ]]; then
    PMDM_ROOT_DIRECTORIES="[HOME]=\"${HOME}\""
    write-config
  fi

  require-env PMDM_ROOT_DIRECTORIES
  eval "declare -A ROOT_DIRECTORY_MAP=( ${PMDM_ROOT_DIRECTORIES} )"

  echo "Any files stored in named root directories will be referred to by relative path instead of absolute path"
  while true; do
    # Print existing directories
    for ALIAS_PREFIX in "${!ROOT_DIRECTORY_MAP[@]}"
    do
      echo "[${ALIAS_PREFIX}] ${ROOT_DIRECTORY_MAP[$ALIAS_PREFIX]}"
    done

    read -p "Enter an existing alias to modify or delete it, a new alias to create a new root directory, or nothing to continue: " ALIAS_INPUT
    if [[ -z "${ALIAS_INPUT}" ]]; then
      break;
    fi

    if [[ -n "${ROOT_DIRECTORY_MAP[${ALIAS_INPUT}]:-}" ]]; then # An existing alias
      read -p "Enter a new absolute path to modify ${ALIAS_INPUT} or leave blank to remove: " PATH_INPUT
      if [[ -z "${PATH_INPUT}" ]]; then
        # Remove an existing value
        unset ROOT_DIRECTORY_MAP[$ALIAS_INPUT]
      else
        # Update an existing value
        ROOT_DIRECTORY_MAP[$ALIAS_INPUT]="${PATH_INPUT}"
      fi
    else # Add a new value (fix these comments)
      read -p "Enter absolute path for ${ALIAS_INPUT}: " PATH_INPUT
      if [[ -n "${PATH_INPUT}" ]]; then
        ROOT_DIRECTORY_MAP[$ALIAS_INPUT]="${PATH_INPUT}"
      fi
    fi

    PMDM_ROOT_DIRECTORIES="$( declare -p ROOT_DIRECTORY_MAP | sed 's/^.*(//;s/)$//' )"
    write-config
  done

  source-password-manager-implementation
  ensure-password-manager-installed
  ensure-password-manager-logged-in
  configure-password-manager
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

write-config() {
  echo "PASSWORD_MANAGER=\"${PASSWORD_MANAGER:-}\"
PMDM_ROOT_DIRECTORIES=\"$( echo "${PMDM_ROOT_DIRECTORIES}" | sed "s/\"/\\\\\"/g")\"
" > "${CONFIG_FILE}"
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

to-abs-path() {
  local REL_PATH="${1}"

  if [[ -d "${REL_PATH}" ]]; then
    (cd "${REL_PATH}"; pwd)
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

###### DONE FUNCTION DEFINITIONS #########

[[ "${EUID}" -eq 0 ]] && exiterr "Don't run this as root"

# Create my own config dir if needed
[[ -d "${CONFIG_DIR}" ]] || mkdir -p "${CONFIG_DIR}"
# If config file exists, source it
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

COMMAND="${1:-}"
shift

[[ -n "$COMMAND" ]] || print-usage

# Special check for "config" command first before we make assertions about being properly configured
if [[ "${COMMAND}" == "config" ]]; then
  do-config
  exit 0
fi

source-password-manager-implementation

require-env PMDM_ROOT_DIRECTORIES
eval "declare -A ROOT_DIRECTORY_MAP=( ${PMDM_ROOT_DIRECTORIES} )"

ensure-password-manager-installed
ensure-password-manager-logged-in
assert-password-manager-configured

# then a big case statement for $COMMAND and do the thing that was asked of me
case "${COMMAND}" in
  "add")
    # add a new file or update an existing file
    # immediately push to password manager
    [[ -z "${1:-}" ]] && print-usage
    echo "TODO: add a file"
    [[ -f "${1}" ]] || exiterr "${1}: file not found"

    ABS_PATH="$( to-abs-path "$1" )"
    ITEM_NAME="$( create-item-name "$ABS_PATH" )"

    echo create-password-manager-item "${ITEM_NAME}" "${ABS_PATH}"
    ;;
  "rm")
    echo "TODO: remove a file"
    # remove a file from the password manager
    # take some flag to also rm the local copy?
    ;;
  "sync")
    echo "TODO: sync files"
    # check for --prefer-local or --prefer-remote flag
    # loop through everything in password manager vault
    # check if the local file exists
    #
    ;;
  *)
    echo "Unknown command ${COMMAND}"
    print-usage
    ;;
esac
