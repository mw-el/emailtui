#!/usr/bin/env bash
# EmailTUI install script — Linux + macOS.
#
# Was dieses Script tut:
#   1. Pruefen, ob Go installiert ist (>= GO_MIN_VERSION). Wenn nicht: versuchen
#      zu installieren (macOS: Homebrew, Linux: offizieller tar-Download).
#   2. 'go mod download' und './emailtui' bauen.
#   3. Config-Verzeichnis ~/.config/email-cli/ anlegen und (nur wenn noch keine
#      config.json existiert) das Template aus config/config.example.json
#      dorthin kopieren, mit 0600-Permissions.
#
# Es wird NICHTS systemweit installiert — das Binary liegt im Repo-Root.
#
# Aufruf:
#   ./install.sh

set -euo pipefail

# --- Konstanten ---------------------------------------------------------------

GO_MIN_VERSION="1.24.5"   # muss zur 'go' Direktive in go.mod passen
GO_INSTALL_VERSION="1.24.5"

# --- Hilfsfunktionen ----------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log()  { printf "\033[1;34m[install]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok    ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[ warn  ]\033[0m %s\n" "$*" >&2; }
die()  { printf "\033[1;31m[ FEHL  ]\033[0m %s\n" "$*" >&2; exit 1; }

# Vergleicht zwei Versionsstrings ('1.24.5' vs '1.21.0'); 0 wenn $1 >= $2.
version_ge() {
    # sort -V vergleicht semver-mässig; das groesste Element steht zuletzt.
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]
}

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      die "Nicht unterstuetztes Betriebssystem: $(uname -s)" ;;
    esac
}

detect_arch_linux() {
    case "$(uname -m)" in
        x86_64)         echo "amd64" ;;
        aarch64|arm64)  echo "arm64" ;;
        *)              die "Nicht unterstuetzte Linux-Architektur: $(uname -m)" ;;
    esac
}

# --- Go-Setup -----------------------------------------------------------------

go_version_installed() {
    if ! command -v go >/dev/null 2>&1; then
        echo ""
        return
    fi
    # 'go version' Ausgabe: "go version go1.24.5 linux/amd64"
    go version | awk '{print $3}' | sed 's/^go//'
}

install_go_macos() {
    log "macOS: versuche Go via Homebrew zu installieren ..."
    if ! command -v brew >/dev/null 2>&1; then
        die "Homebrew nicht gefunden. Bitte zuerst installieren: https://brew.sh"
    fi
    brew install go
}

install_go_linux() {
    local arch tarball url tmpdir
    arch="$(detect_arch_linux)"
    tarball="go${GO_INSTALL_VERSION}.linux-${arch}.tar.gz"
    url="https://go.dev/dl/${tarball}"

    log "Linux: lade Go ${GO_INSTALL_VERSION} (${arch}) von ${url}"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' RETURN

    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar "$url" -o "$tmpdir/$tarball"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$tmpdir/$tarball" "$url"
    else
        die "Weder 'curl' noch 'wget' gefunden — bitte eines installieren."
    fi

    log "entpacke nach /usr/local/go (sudo erforderlich)"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$tmpdir/$tarball"

    # Im aktuellen Script-Run sofort verfuegbar machen.
    export PATH="/usr/local/go/bin:$PATH"

    warn "Go liegt in /usr/local/go/bin. Fuer dauerhafte Verfuegbarkeit ergaenze:"
    warn "    export PATH=\"/usr/local/go/bin:\$PATH\""
    warn "in ~/.bashrc, ~/.zshrc oder ~/.profile."
}

ensure_go() {
    local current
    current="$(go_version_installed)"

    if [ -n "$current" ] && version_ge "$current" "$GO_MIN_VERSION"; then
        ok "Go ${current} bereits installiert (>= ${GO_MIN_VERSION})."
        return
    fi

    if [ -n "$current" ]; then
        warn "Go ${current} ist installiert, aber EmailTUI braucht >= ${GO_MIN_VERSION}."
    else
        log "Go ist nicht installiert."
    fi

    case "$OS" in
        macos) install_go_macos ;;
        linux) install_go_linux ;;
    esac

    current="$(go_version_installed)"
    [ -n "$current" ] || die "Go-Installation fehlgeschlagen ('go' nicht im PATH)."
    version_ge "$current" "$GO_MIN_VERSION" || die "Go ${current} immer noch zu alt (brauche >= ${GO_MIN_VERSION})."
    ok "Go ${current} installiert."
}

# --- Build --------------------------------------------------------------------

build_app() {
    log "lade Go-Module ..."
    go mod download
    log "baue Binary ./emailtui ..."
    go build -o emailtui main.go
    ok "Binary gebaut: $SCRIPT_DIR/emailtui"
    log "baue Binary ./sendmail (CLI fuer den 'email-an-mich' Skill) ..."
    go build -o sendmail ./cmd/sendmail
    ok "Binary gebaut: $SCRIPT_DIR/sendmail"
}

# --- Config-Setup -------------------------------------------------------------

setup_config() {
    local config_dir="$HOME/.config/email-cli"
    local config_file="$config_dir/config.json"
    local template="$SCRIPT_DIR/config/config.example.json"

    [ -f "$template" ] || die "Config-Template nicht gefunden: $template"

    mkdir -p "$config_dir"
    chmod 700 "$config_dir" 2>/dev/null || true

    if [ -f "$config_file" ]; then
        ok "Config existiert schon ($config_file) — wird NICHT ueberschrieben."
        return
    fi

    cp "$template" "$config_file"
    chmod 600 "$config_file"
    ok "Config-Template kopiert nach $config_file"
}

# --- Main ---------------------------------------------------------------------

OS="$(detect_os)"
log "Plattform: $OS"

ensure_go
build_app
setup_config

cat <<EOF

============================================================
  EmailTUI Installation abgeschlossen.
============================================================

Naechste Schritte:

  1. Config ausfuellen:
       \$EDITOR ~/.config/email-cli/config.json

  2. App starten:
       cd "$SCRIPT_DIR"
       ./emailtui

Hinweis: Die Datei ~/.config/email-cli/config.json hat 0600-
Permissions und enthaelt dein Passwort im Klartext. Niemals
committen oder weitergeben.

EOF
