---
name: email-an-mich
description: Sendet eine Mail an matthias.wiemeyer@schreibszene.ch (mit optionalem Anhang) ueber das EmailTUI-Repo unter ~/_AA_EmailTUI. TRIGGER, wenn der User sagt "schick mir eine Mail mit ...", "Mail an mich mit Inhalt X", "schick mir die Datei XY als Anhang". SKIP, wenn die Mail an jemand anderen geht oder wenn nur ueber Mail-Funktionen gesprochen wird, ohne dass tatsaechlich gesendet werden soll.
---

# email-an-mich — Mail an mich verschicken

Verschickt eine E-Mail an die persönliche Adresse `matthias.wiemeyer@schreibszene.ch` über das EmailTUI-CLI im Repo `~/_AA_EmailTUI`. Optional mit Anhängen.

## Wann triggern

Klare Aufforderung, etwas an die eigene Mail zu schicken:

- "Bitte schick mir eine Mail mit folgendem Inhalt: ..."
- "Mail an mich, Betreff X, Body Y"
- "Schick mir diese Datei als Anhang: /pfad/foo.pdf"
- "Mail an mich mit den Dateien A und B als Anhang und folgendem Text: ..."

## Wann NICHT triggern

- Mail soll an jemand anderen gehen (z.B. "Mail an Anna" → User soll TUI verwenden)
- User redet nur ÜBER Mail-Funktionen ("kann die App eigentlich Mails schicken?") — erst nachfragen
- User testet die Konfiguration — dann lieber `cmd/smoketest` empfehlen

## Voraussetzungen prüfen (Schritt 1)

```bash
test -x ~/_AA_EmailTUI/sendmail
```

Wenn das Binary fehlt oder älter als die Quelle ist:

```bash
cd ~/_AA_EmailTUI && ./install.sh
```

`install.sh` baut sowohl `emailtui` (TUI) als auch `sendmail` (CLI). Bricht der Build ab, dem User die Fehlermeldung zeigen — nicht weiter versuchen.

## Body in Tempdatei schreiben (Schritt 2)

Body NIE direkt als `--body "..."` übergeben — Sonderzeichen, Newlines und Anführungszeichen brechen die Shell-Argumente. Stattdessen über `--body-file`:

```bash
BODYFILE="$(mktemp -t emailanmich.XXXXXX)"
trap 'rm -f "$BODYFILE"' EXIT
cat > "$BODYFILE" <<'EOF'
<hier den Body als Heredoc>
EOF
```

## CLI aufrufen (Schritt 3)

```bash
~/_AA_EmailTUI/sendmail \
  --to "matthias.wiemeyer@schreibszene.ch" \
  --subject "<Betreff>" \
  --body-file "$BODYFILE" \
  [--attach "/pfad/datei1.pdf"] \
  [--attach "/pfad/datei2.png"]
```

Mehrere Anhänge: `--attach` mehrfach übergeben (jede Datei einzeln).

## Ergebnis melden (Schritt 4)

Bei Erfolg gibt das CLI eine Zeile aus wie:

```
OK - Mail gesendet von matthias.wiemeyer@schreibszene.ch an matthias.wiemeyer@schreibszene.ch (Betreff: "...", 1 Anhang/Anhaenge)
```

Diese 1:1 an den User weitergeben (knapp).

Bei Fehlern (Exit-Code != 0): die `FEHLER: ...`-Zeile von stderr 1:1 zeigen. Häufige Ursachen:
- SMTP-Auth fehlgeschlagen → Passwort prüfen
- Verbindung verweigert → Internet/Firewall/Server-Adresse prüfen
- Anhang nicht gefunden → Pfad prüfen

## Beispiele

**1. Einfacher Text, kein Anhang:**

User: *"Schick mir eine Mail: Erinnerung — morgen 10 Uhr Zahnarzt"*

```bash
BODYFILE="$(mktemp -t emailanmich.XXXXXX)"; trap 'rm -f "$BODYFILE"' EXIT
cat > "$BODYFILE" <<'EOF'
Erinnerung — morgen 10 Uhr Zahnarzt
EOF
~/_AA_EmailTUI/sendmail --to "matthias.wiemeyer@schreibszene.ch" \
  --subject "Erinnerung Zahnarzt" --body-file "$BODYFILE"
```

**2. Datei als Anhang:**

User: *"Schick mir die Datei /home/matthias/notes/idee.md als Anhang"*

```bash
BODYFILE="$(mktemp -t emailanmich.XXXXXX)"; trap 'rm -f "$BODYFILE"' EXIT
echo "(siehe Anhang)" > "$BODYFILE"
~/_AA_EmailTUI/sendmail --to "matthias.wiemeyer@schreibszene.ch" \
  --subject "Anhang: idee.md" --body-file "$BODYFILE" \
  --attach "/home/matthias/notes/idee.md"
```

**3. Mit Markdown-Body:**

Der Body wird automatisch von Markdown nach HTML gerendert (goldmark). Der User bekommt sowohl die Plaintext- als auch die HTML-Variante per multipart/alternative; jeder Mailclient zeigt das Sinnvolle an.

## Konfiguration

Absender und SMTP-Server stehen in `~/.config/email-cli/config.json`. Der aktive Account wird verwendet (`active_account`-Index). Per `--account <name|index|email>` kann pro Aufruf ein anderer Account gewählt werden, falls mehrere konfiguriert sind.

## Plattform

- **Linux** ✓ (Ubuntu 24.04 getestet)
- **macOS** ✓ (`install.sh` unterstützt brew-basierten Go-Install)
- **Windows** ✗ noch nicht — `install.sh` ist ein Bash-Script. Workaround heute: WSL.
