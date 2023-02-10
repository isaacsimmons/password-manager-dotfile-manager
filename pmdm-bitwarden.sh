[ "${BASH_SOURCE[0]}" -ef "$0" ] && (>&2echo "Don't invoke this directly"; exit 1)

require-password-manager-config() {
  echo "yo, require that bitwarden is configured"
}

interactive-password-manager-config() {
  echo "yo, let's configure bitwarden"
}

ensure-password-manager-installed() {
  if command -v bw &> /dev/null; then
    echo "Bitwarden CLI installed"
    return
  fi

  echo "Installing bitwarden CLI..."
  [[ "$(getconf LONG_BIT)" == "64" ]] || exiterr "Non-64-bit architectures not supported"
  case "${OSTYPE}" in
    "linux-gnu"*)
      exiterr "does exiterr even work here?"
      ;;
    "darwin"*)
      exiterr "does exiterr even work here?"
      ;;
    "msys") # What about other windows bash flavors? WSL2?
      rm -f /tmp/bw.zip
      curl -SsL "https://vault.bitwarden.com/download/?app=cli&platform=windows" -o /tmp/bw.zip
      unzip /tmp/bw.zip -d "${HOME}/bin"
      rm /tmp/bw.zip
      ;;
    *)
      exiterr "Unsupported platform ${OSTYPE}"
      ;;
  esac
}