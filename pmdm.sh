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

do-config() {
  echo "doing config!"
  # ask for password manager (default to current value if set)
  PASSWORD_MANAGER="${PASSWORD_MANAGER:-bw}"
  read -p "What password manager would you like to use (op, bw) [${PASSWORD_MANAGER}]: " PASSWORD_MANAGER_INPUT
  PASSWORD_MANAGER="${PASSWORD_MANAGER_INPUT:-$PASSWORD_MANAGER}"
  [[ -n "${PASSWORD_MANAGER_INPUT}" ]] && write-config

  source-password-manager-implementation
  ensure-password-manager-installed
  ensure-password-manager-logged-in
  configure-password-manager

  # anytime they answer something other than the default, call write-config
}

source-password-manager-implementation() {
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
  echo "MY_OWN_PATH=\"${CONFIG_FILE}\"
PASSWORD_MANAGER=\"${PASSWORD_MANAGER}\"" > "${CONFIG_FILE}"
}

###### DONE FUNCTION DEFINITIONS #########

[[ "${EUID}" -eq 0 ]] && exiterr "Don't run this as root"

# Create my own config dir if needed
[[ -d "${CONFIG_DIR}" ]] || mkdir -p "${CONFIG_DIR}"
# If config file exists, source it
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

COMMAND="${1:-}"

[[ -n "$COMMAND" ]] || print-usage

# Special check for "config" command first before we require a bunch of configuration values
if [[ "${COMMAND}" == "config" ]]; then
  do-config
  exit 0
fi

# Make sure the password manager is set and configured
require-env PASSWORD_MANAGER
source-password-manager-implementation
ensure-password-manager-installed
ensure-password-manager-logged-in
assert-password-manager-configured

# then a big case statement for $COMMAND and do the thing that was asked of me
