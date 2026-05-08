// sendmail — nicht-interaktives CLI zum Versand einer Mail ueber den
// in ~/.config/email-cli/config.json konfigurierten Account.
//
// Wird vor allem vom Claude-Skill 'email-an-mich' aufgerufen, kann aber
// auch direkt benutzt werden:
//
//   ~/_AA_EmailTUI/sendmail \
//     --to matthias.wiemeyer@schreibszene.ch \
//     --subject "Notiz" \
//     --body-file /tmp/note.txt \
//     --attach /pfad/datei.pdf
//
// Pflicht-Flags: --to, --subject, und entweder --body oder --body-file.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/andrinoff/email-cli/config"
	"github.com/andrinoff/email-cli/sender"
	"github.com/yuin/goldmark"
)

type stringSlice []string

func (s *stringSlice) String() string     { return strings.Join(*s, ",") }
func (s *stringSlice) Set(v string) error { *s = append(*s, v); return nil }

func main() {
	var (
		to       = flag.String("to", "", "Empfaenger (mehrere kommagetrennt) — Pflicht")
		subject  = flag.String("subject", "", "Betreff — Pflicht")
		body     = flag.String("body", "", "Mailtext (Plaintext, alternativ --body-file)")
		bodyFile = flag.String("body-file", "", "Pfad zur Datei mit dem Mailtext (alternativ --body)")
		account  = flag.String("account", "", "Account-Auswahl per Index, AccountName oder Email (default: active_account)")
	)
	var attach stringSlice
	flag.Var(&attach, "attach", "Pfad zum Anhang (mehrfach erlaubt)")
	flag.Parse()

	if *to == "" {
		die("--to ist Pflicht")
	}
	if *subject == "" {
		die("--subject ist Pflicht")
	}
	bodyText, err := readBody(*body, *bodyFile)
	if err != nil {
		die(err.Error())
	}

	cfg, err := config.LoadConfig()
	if err != nil {
		die(fmt.Sprintf("config laden: %v", err))
	}
	if *account != "" {
		if err := selectAccount(cfg, *account); err != nil {
			die(err.Error())
		}
	}

	recipients := splitRecipients(*to)
	if len(recipients) == 0 {
		die("kein Empfaenger angegeben")
	}

	attachments, err := loadAttachments(attach)
	if err != nil {
		die(err.Error())
	}

	htmlBody := renderMarkdown(bodyText)

	if err := sender.SendEmail(cfg, recipients, *subject, bodyText, htmlBody, nil, attachments, "", nil); err != nil {
		die(fmt.Sprintf("senden: %v", err))
	}

	acc, _ := cfg.GetActiveAccount()
	fmt.Printf("OK - Mail gesendet von %s an %s (Betreff: %q",
		acc.Email, strings.Join(recipients, ", "), *subject)
	if len(attachments) > 0 {
		fmt.Printf(", %d Anhang/Anhaenge", len(attachments))
	}
	fmt.Println(")")
}

func readBody(direct, file string) (string, error) {
	if direct != "" && file != "" {
		return "", fmt.Errorf("--body und --body-file sind exklusiv")
	}
	if file != "" {
		b, err := os.ReadFile(file)
		if err != nil {
			return "", fmt.Errorf("body-file lesen: %w", err)
		}
		return string(b), nil
	}
	if direct != "" {
		return direct, nil
	}
	return "", fmt.Errorf("--body oder --body-file ist Pflicht")
}

func selectAccount(cfg *config.Config, sel string) error {
	if len(cfg.Accounts) == 0 {
		return fmt.Errorf("--account: config nutzt Legacy-Single-Account-Modus, hat kein 'accounts'-Array")
	}
	if idx, err := strconv.Atoi(sel); err == nil {
		if idx < 0 || idx >= len(cfg.Accounts) {
			return fmt.Errorf("--account: Index %d ausserhalb des Bereichs (0..%d)", idx, len(cfg.Accounts)-1)
		}
		cfg.ActiveAccount = idx
		return nil
	}
	for i, a := range cfg.Accounts {
		if a.AccountName == sel || a.Email == sel {
			cfg.ActiveAccount = i
			return nil
		}
	}
	return fmt.Errorf("--account: kein Account mit Name/Email %q gefunden", sel)
}

func splitRecipients(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func loadAttachments(paths []string) (map[string][]byte, error) {
	if len(paths) == 0 {
		return nil, nil
	}
	out := make(map[string][]byte, len(paths))
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			return nil, fmt.Errorf("anhang %q lesen: %w", p, err)
		}
		out[filepath.Base(p)] = data
	}
	return out, nil
}

func renderMarkdown(md string) string {
	var buf bytes.Buffer
	if err := goldmark.New().Convert([]byte(md), &buf); err != nil {
		return "<pre>" + md + "</pre>"
	}
	return buf.String()
}

func die(msg string) {
	fmt.Fprintln(os.Stderr, "FEHLER:", msg)
	os.Exit(1)
}
