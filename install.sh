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
        ok "Config existiert schon ($config_file) — wird NICHT angetastet."
        return
    fi

    # Template als Sicherheits-Fallback hinlegen — wird ggf. von
    # prompt_credentials() ueberschrieben, falls der User Daten eingibt.
    cp "$template" "$config_file"
    chmod 600 "$config_file"
    ok "Config-Template kopiert nach $config_file"

    prompt_credentials "$config_file"
}

# JSON-Escape fuer String-Werte (Backslash + doppelte Anfuehrungszeichen).
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Schreibt die Config-Datei mit den abgefragten Werten.
write_config() {
    local file="$1" email="$2" name="$3" provider="$4" password="$5" imap_server="$6" smtp_server="$7"

    cat > "$file" <<EOF
{
  "_comment_1_format":   "EmailTUI Konfigurationsdatei. Mehrere Accounts werden im 'accounts'-Array angelegt. Felder mit Prefix '_comment_' werden vom Parser ignoriert.",
  "_comment_2_active":   "'active_account' ist der 0-basierte Index.",
  "_comment_3_provider": "service_provider: gmail | icloud | outlook | hotmail | yahoo | custom.",
  "_comment_4_custom":   "Bei service_provider='custom' zusaetzlich 'imap_server_address' und 'smtp_server_address' setzen.",
  "_comment_5_password": "WICHTIG: Bei Gmail / Outlook / iCloud mit 2FA ein App-Passwort verwenden. Anleitung Gmail: https://myaccount.google.com/apppasswords",
  "_comment_6_ports":    "imap_port Default 993; smtp_port 587 (STARTTLS) oder 465 (implizites TLS).",
  "_comment_7_security": "Datei hat 0600-Permissions und sollte niemals committed/weitergegeben werden.",

  "active_account": 0,
  "accounts": [
    {
      "_comment":            "Per install.sh angelegter Account. Felder bei Bedarf editieren.",
      "account_name":        "$(json_escape "$name")",
      "service_provider":    "$(json_escape "$provider")",
      "email":               "$(json_escape "$email")",
      "password":            "$(json_escape "$password")",
      "name":                "$(json_escape "$name")",
      "imap_server_address": "$(json_escape "$imap_server")",
      "imap_port":           "993",
      "smtp_server_address": "$(json_escape "$smtp_server")",
      "smtp_port":           "587"
    }
  ]
}
EOF
}

# Liste der Felder, die der User noch nachtragen muss.
missing_fields_hint() {
    local config_file="$1"
    warn "Bitte folgende Felder in $config_file ergaenzen:"
    warn "  - email                Mail-Adresse"
    warn "  - service_provider     gmail | icloud | outlook | hotmail | yahoo | custom"
    warn "  - password             (bei 2FA: App-Passwort)"
    warn "  - name                 Anzeigename"
    warn "  - imap_server_address  (nur bei custom; z.B. mail.<deine-domain>)"
    warn "  - smtp_server_address  (nur bei custom; z.B. mail.<deine-domain>)"
}

prompt_credentials() {
    local config_file="$1"

    # Nur in echter Terminal-Sitzung fragen. In Pipes/CI: skippen.
    if [ ! -t 0 ]; then
        warn "Keine interaktive Sitzung — Account-Abfrage uebersprungen."
        missing_fields_hint "$config_file"
        return
    fi

    echo
    log "Account-Daten abfragen. ENTER ohne Eingabe = Feld ueberspringen."
    log "Bei Skip bleibt das Template aktiv und du ergaenzt manuell."
    echo

    local email name provider password imap_server smtp_server domain

    printf "E-Mail-Adresse:    "
    read -r email

    printf "Anzeigename:       "
    read -r name

    printf "Provider [custom]  (gmail/icloud/outlook/hotmail/yahoo/custom): "
    read -r provider
    [ -z "$provider" ] && provider="custom"

    # Passwort verdeckt — read -s ist Bash-builtin, auf Mac bash 3.2 ok.
    printf "Passwort (verdeckt, leer = spaeter eintragen): "
    read -r -s password
    echo

    # Bei custom: Server abfragen mit mail.<domain> als Vorschlag.
    if [ "$provider" = "custom" ] && [ -n "$email" ]; then
        domain="${email#*@}"
        printf "IMAP-Server [mail.%s]: " "$domain"
        read -r imap_server
        [ -z "$imap_server" ] && imap_server="mail.$domain"

        printf "SMTP-Server [mail.%s]: " "$domain"
        read -r smtp_server
        [ -z "$smtp_server" ] && smtp_server="mail.$domain"
    fi

    # Wenn weder email noch provider gesetzt: User hat komplett geskipt.
    if [ -z "$email" ] && [ -z "$name" ] && [ -z "$password" ]; then
        warn "Keine Account-Daten eingegeben — Template bleibt aktiv."
        missing_fields_hint "$config_file"
        return
    fi

    write_config "$config_file" "$email" "$name" "$provider" "$password" "$imap_server" "$smtp_server"
    chmod 600 "$config_file"
    ok "Account-Daten geschrieben nach $config_file"

    # Nachtraegliche Pflicht-Warnungen fuer einzelne fehlende Felder.
    local missing=()
    [ -z "$email" ]    && missing+=("email")
    [ -z "$password" ] && missing+=("password")
    [ -z "$name" ]     && missing+=("name")
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "Folgende Felder sind noch leer und muessen vor dem ersten Mailversand"
        warn "in $config_file ergaenzt werden: ${missing[*]}"
    fi
}

# --- Skill-Installation -------------------------------------------------------

install_skill() {
    local skill_src="$SCRIPT_DIR/skills/email-an-mich/SKILL.md"
    local skill_dir="$HOME/.claude/skills/email-an-mich"
    local skill_dst="$skill_dir/SKILL.md"

    if [ ! -f "$skill_src" ]; then
        warn "Skill-Quelle nicht gefunden: $skill_src — ueberspringe Skill-Install."
        return
    fi

    mkdir -p "$skill_dir"
    cp "$skill_src" "$skill_dst"
    ok "Skill 'email-an-mich' installiert: $skill_dst"
}

# --- Main ---------------------------------------------------------------------

OS="$(detect_os)"
log "Plattform: $OS"

ensure_go
build_app
setup_config
install_skill

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
