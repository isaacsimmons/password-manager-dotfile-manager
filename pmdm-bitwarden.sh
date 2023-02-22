# Guard against direct execution
# This is intended to be sourced by the main pmdm.sh script and will not work
[ "${BASH_SOURCE[0]}" -ef "$0" ] && (>&2echo "Don't invoke this directly"; exit 1)

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
