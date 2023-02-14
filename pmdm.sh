#!/usr/bin/env bash

set -euo pipefail

#TODO: apply consistent style guide (Google Shell Styleguide, ShellCheck, etc)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/password-manager-dotfile-manager"
CONFIG_FILE="${CONFIG_DIR}/pmdm.env"
echo "Using config in ${CONFIG_DIR}/"

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

find-longest-root-directory-prefix() {
  REL_PATH="${1}"
  ABS_PATH=""
  LONGEST_PREXIX_ALIAS=""
  LONGEST_PREFIX_LENGTH=0

  # TODO: implement this
  # loop over PMDM_ROOT_DIRECTORIES {
  #   if absPath.startsWith rootDir.path && rootDir.path.length > LONGEST_PREFIX_LENGTH {
  #     LONGEST_PREFIX_ALIAS=rootDir.alias
  #     LONGEST_PREFIX_LENGTH=rootDir.path.length
  #   }
  # }

  echo "${LONGEST_PREFIX_ALIAS}"
}

extract-root-directories() {
  require-env PMDM_ROOT_DIRECTORIES
  unset ROOT_DIRECTORY_MAP
  eval "declare -A ROOT_DIRECTORY_MAP=( ${PMDM_ROOT_DIRECTORIES} )"
  export ROOT_DIRECTORY_MAP
}

pack-root-directories() {
  PMDM_ROOT_DIRECTORIES="$( declare -p ROOT_DIRECTORY_MAP | sed 's/^.*(//;s/)$//' )"
}

do-config() {
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

  # extract-root-directories
  require-env PMDM_ROOT_DIRECTORIES
  unset ROOT_DIRECTORY_MAP
  eval "declare -A ROOT_DIRECTORY_MAP=( ${PMDM_ROOT_DIRECTORIES} )"

  echo "Any files stored in named root directories will be referred to by relative path instead of absolute path"
  while true; do
    # Print existing directories
    # echo "${PMDM_ROOT_DIRECTORIES}" | sed "s/:/\n/g" # FIXME: this 'sed' doesn't work with the new assoc array syntax
    declare -p ROOT_DIRECTORY_MAP

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

    pack-root-directories
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

###### DONE FUNCTION DEFINITIONS #########

[[ "${EUID}" -eq 0 ]] && exiterr "Don't run this as root"

# Create my own config dir if needed
[[ -d "${CONFIG_DIR}" ]] || mkdir -p "${CONFIG_DIR}"
# If config file exists, source it
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

COMMAND="${1:-}"

[[ -n "$COMMAND" ]] || print-usage

# Special check for "config" command first before we make assertions about being properly configured
if [[ "${COMMAND}" == "config" ]]; then
  do-config
  exit 0
fi

source-password-manager-implementation
extract-root-directories

ensure-password-manager-installed
ensure-password-manager-logged-in
assert-password-manager-configured

# then a big case statement for $COMMAND and do the thing that was asked of me
case "${PASSWORD_MANAGER}" in
  "add")
    echo "TODO: add a file"
     ;;
  "rm")
    echo "TODO: remove a file"
     ;;
  "sync")
    echo "TODO: sync files"
    ;;
  *)
    echo "Unknown command ${COMMAND}"
    print-usage
    ;;
esac
