// EmailTUI Smoke Test — verifiziert IMAP-Abruf und SMTP-Versand
// gegen die Konfiguration in ~/.config/email-cli/config.json,
// ohne die TUI zu starten.
//
// Nutzung (vom Projekt-Root):
//   go run ./cmd/smoketest
package main

import (
	"fmt"
	"os"
	"time"

	"github.com/andrinoff/email-cli/config"
	"github.com/andrinoff/email-cli/fetcher"
	"github.com/andrinoff/email-cli/sender"
)

const recipient = "matthias.wiemeyer@schreibszene.ch"

func main() {
	fmt.Println("=== EmailTUI Smoke Test ===")

	cfg, err := config.LoadConfig()
	if err != nil {
		fail("config laden", err)
	}

	acc, err := cfg.GetActiveAccount()
	if err != nil {
		fail("aktiven Account ermitteln", err)
	}

	if acc.Email == "" || acc.Password == "" || acc.ServiceProvider == "" {
		fmt.Fprintln(os.Stderr, "FEHLER: aktiver Account hat leere Pflichtfelder (email/password/service_provider).")
		fmt.Fprintln(os.Stderr, "Bitte ~/.config/email-cli/config.json ausfuellen und erneut starten.")
		os.Exit(1)
	}

	fmt.Printf("Aktiver Account: %q (email=%s, provider=%s)\n", acc.AccountName, acc.Email, acc.ServiceProvider)
	fmt.Printf("IMAP-Server:     %s\n\n", acc.IMAPServer())

	// --- Schritt 1: IMAP-Abruf ---
	fmt.Println("[1/2] IMAP-Test: hole 3 neueste Mails ...")
	emails, err := fetcher.FetchEmails(cfg, 3, 0)
	if err != nil {
		fail("FetchEmails", err)
	}
	fmt.Printf("OK - %d Mails geholt:\n", len(emails))
	for i, e := range emails {
		subj := e.Subject
		if len(subj) > 80 {
			subj = subj[:80] + "..."
		}
		fmt.Printf("  %d. [%s] %s\n      %q\n", i+1, e.Date.Format("2006-01-02 15:04"), e.From, subj)
	}
	fmt.Println()

	// --- Schritt 2: SMTP-Versand ---
	fmt.Printf("[2/2] SMTP-Test: sende Test-Mail an %s ...\n", recipient)
	now := time.Now()
	subject := fmt.Sprintf("EmailTUI Smoke Test - %s", now.Format(time.RFC3339))
	plain := fmt.Sprintf(
		"Dies ist eine automatische Test-E-Mail aus dem EmailTUI Smoke Test.\n\n"+
			"Absender-Account: %s\n"+
			"Provider:         %s\n"+
			"Zeit:             %s\n\n"+
			"Wenn diese Mail bei dir angekommen ist: SMTP-Versand funktioniert.\n",
		acc.Email, acc.ServiceProvider, now.Format(time.RFC1123),
	)
	html := "<p>Dies ist eine automatische Test-E-Mail aus dem EmailTUI Smoke Test.</p>" +
		"<p>Wenn diese Mail bei dir angekommen ist: SMTP-Versand funktioniert.</p>"

	if err := sender.SendEmail(cfg, []string{recipient}, subject, plain, html, nil, nil, "", nil); err != nil {
		fail("SendEmail", err)
	}
	fmt.Println("OK - Mail abgeschickt.")

	fmt.Println("\n=== Smoke-Test bestanden ===")
}

func fail(step string, err error) {
	fmt.Fprintf(os.Stderr, "FEHLER bei %s: %v\n", step, err)
	os.Exit(1)
}
