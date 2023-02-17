# Guard against direct execution
# This is intended to be sourced by the main pmdm.sh script and will not work
[ "${BASH_SOURCE[0]}" -ef "$0" ] && (>&2echo "Don't invoke this directly"; exit 1)

BITWARDEN_CONFIG_FILE="${CONFIG_DIR}/pmdm-bitwarden.env"

write-password-manager-config() {
  echo "BITWARDEN_EMAIL=\"${BITWARDEN_EMAIL:-}\"
BITWARDEN_FOLDER_ID=\"${BITWARDEN_FOLDER_ID:-}\"
" > "${BITWARDEN_CONFIG_FILE}"
}

install-bitwarden-cli() {
  echo -n "Installing bitwarden CLI..."
  [[ "$(getconf LONG_BIT)" == "64" ]] || exiterr "Unsupported architecture. Please install bitwarden CLI manually"
  case "${OSTYPE}" in
    "linux-gnu"*)
      exiterr "unimplemented"
      ;;
    "darwin"*)
      exiterr "unimplemented"
      ;;
    "msys") # What about other windows bash flavors? WSL2?
      rm -f /tmp/bw.zip
      curl -SsL "https://vault.bitwarden.com/download/?app=cli&platform=windows" -o /tmp/bw.zip
      unzip /tmp/bw.zip -d "${HOME}/bin"
      rm /tmp/bw.zip
      ;;
    *)
      exiterr "Unsupported platform ${OSTYPE}. Please install bitwarden CLI manually"
      ;;
  esac
  echo " done."
}

install-jq() {
  echo -n "Installing JQ..."
  [[ "$(getconf LONG_BIT)" == "64" ]] || exiterr "Unsupported architecture. Please install jq manually"
  case "${OSTYPE}" in
    "linux-gnu"*)
      # TODO: untested
      curl -SsL "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -o "${HOME}/bin/jq"
      ;;
    "darwin"*)
      # TODO: untested
      # TODO: how about arm64?
      curl -SsL "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" -o "${HOME}/bin/jq"
      ;;
    "msys") # What about other windows bash flavors? WSL2?
      curl -SsL "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-win64.exe" -o "${HOME}/bin/jq.exe"
      ;;
    *)
      exiterr "Unsupported platform ${OSTYPE}. Please install jq manually"
      ;;
  esac
  echo " done."
}

ensure-password-manager-installed() {
  command -v bw &> /dev/null || install-bitwarden-cli
  command -v jq &> /dev/null || install-jq

  UPDATE_URL="$(bw update --raw)"
  if [[ -n "${UPDATE_URL}" ]]; then
    # Ignore the returned update URL, just reinstall from scratch
    # FIXME: untested
    # do I need to rm the old file first? will this overwrite?
    echo "Bitwarden CLI out of date, fetching new version"
    install-bitwarden-cli
  fi
}

ensure-password-manager-logged-in() {
  if [[ -z "${BITWARDEN_EMAIL:-}" ]]; then
    read -p "What is your bitwarden email: " BITWARDEN_EMAIL
    [[ -z "${BITWARDEN_EMAIL}" ]] && exiterr "Unable to read bitwarden email"
    write-password-manager-config
  fi

  if ! bw login --check &> /dev/null; then
    export BW_SESSION="$(bw login "{$BITWARDEN_EMAIL}" --raw)"
  elif ! bw unlock --check &> /dev/null; then
    export BW_SESSION="$(bw unlock --raw)"
  fi
}

configure-password-manager() {
  local DEFAULT_FOLDER_NAME="dotfiles"
  # TODO: scope a ton of variables in all these files as 'local'?

  ID_MATCH_ROW=""
  DEFAULT_NAME_MATCH_ROW=""
  echo "Select a folder for pmdm to store its data in:"

  OLD_FOLDER_ID="${BITWARDEN_FOLDER_ID:-}"

  ROW=1
  while read FOLDER_LINE; do
    # Split the line to get ID and Name
    FOLDER_ID="$( echo "${FOLDER_LINE}" | cut -d: -f1 )"
    FOLDER_NAME="$( echo "${FOLDER_LINE}" | cut -d: -f2- )"

    # Check for rows matching the existing folder or the default folder name
    if [[ "${FOLDER_ID}" == "${BITWARDEN_FOLDER_ID:-}" ]]; then
      ID_MATCH_ROW="${ROW}"
    elif [[ "${FOLDER_NAME}" == "${DEFAULT_FOLDER_NAME}" ]]; then
      DEFAULT_NAME_MATCH_ROW="${ROW}"
    fi

    # Store the IDs for later
    FOLDER_IDS[$ROW]="${FOLDER_ID}"

    # Write row prompt
    echo "[${ROW}] ${FOLDER_NAME}"
    ROW=$((ROW + 1))
  done <<<$(bw list folders | jq -r ".[] | .id + \":\" + .name" | grep -v "No Folder")
  PROMPT_DEFAULT="${ID_MATCH_ROW:-${DEFAULT_NAME_MATCH_ROW:-${DEFAULT_FOLDER_NAME}}}"
  read -p "Select existing by line number or enter a name to create a new folder [${PROMPT_DEFAULT}]:" RAW_FOLDER_INPUT
  FOLDER_INPUT="${RAW_FOLDER_INPUT:-${PROMPT_DEFAULT}}"

  if [[ "${FOLDER_INPUT}" =~ ^[0-9]+$ ]]; then # They entered a number, treat as id of an existing folder
    # TODO: do I need an "export" to use this immediately? (also, maybe I don't care?)
    BITWARDEN_FOLDER_ID="${FOLDER_IDS[$FOLDER_INPUT]}"
  else # Not a number, must be a name for a new folder
    BITWARDEN_FOLDER_ID="$( bw get template folder | jq ".name=\"${FOLDER_INPUT}\"" | bw encode | bw create folder | jq -r ".id" )"
  fi

  if [[ "${OLD_FOLDER_ID}" != "${BITWARDEN_FOLDER_ID}" ]]; then
    write-password-manager-config
  fi
}

assert-password-manager-configured() {
  require-env BITWARDEN_EMAIL
  require-env BITWARDEN_FOLDER_ID
}

find-note-by-id() {
  local ITEM_NAME="${1}"
  # Look up exisiting object with a combination of bw CLI fuzzy search and jq filtering
  bw list items --folderid "${BITWARDEN_FOLDER_ID}" --search "${ITEM_NAME}" | jq -r ".[] | select(.name == \"${ITEM_NAME}\" and .type == 2) | .id"
}

upsert-password-manager-item() {
  local ITEM_NAME="${1}"
  local FILE_PATH="${2}"

  JSON_FILE_CONTENTS="$( jq -Rs '.' ${FILE_PATH} )"

  # Look up exisiting object with a combination of bw CLI fuzzy search and jq filtering
  EXISTING_ITEM_ID="$( find-note-by-id "${ITEM_NAME}" )"

  if [[ -n "${EXISTING_ITEM_ID}" ]]; then
    # Edit the existing item
    bw get item "${EXISTING_ITEM_ID}" | jq ".notes = ${JSON_FILE_CONTENTS}" | bw encode | bw edit item "${EXISTING_ITEM_ID}"
  else
    # Create a new secure note
    bw get template item | jq ".type = 2 | .secureNote.type = 0 | .notes = ${JSON_FILE_CONTENTS} | .name = \"${ITEM_NAME}\" | .folderId = \"${BITWARDEN_FOLDER_ID}\"" | bw encode | bw create item
  fi
}

delete-password-manager-item() {
  local ITEM_NAME="${1}"

  EXISTING_ITEM_ID="$( find-note-by-id "${ITEM_NAME}" )"
  if [[ -z "${EXISTING_ITEM_ID}" ]]; then
    exiterr "Item ${ITEM_NAME} not found"
  fi

  bw delete item "${EXISTING_ITEM_ID}"
}

list-password-manager-items() {
  # just spit out a list of all the names of notes in the folder
  # maybe its name/ID pairs
  echo "unimplemented"
}

# assumes parent folder for path already exists
# will blindly overwrite -- you should check ahead of time if that's not what you want
get-password-manager-item() {
  local ITEM_NAME="${1}"
  local FILE_PATH="${2}"

}

# something for sync?
# is it just a combination of "list" and "check if its changed", "get" and "upsert"


# Done Function Definitions

# If config file exists, source it
[[ -f "${BITWARDEN_CONFIG_FILE}" ]] && source "${BITWARDEN_CONFIG_FILE}"

# TODO: bw config server https://self.hosted.server.hostname
