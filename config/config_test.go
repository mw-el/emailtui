package config

import (
	"reflect"
	"testing"
)

// TestSaveAndLoadConfig verifies that the config can be saved to and loaded from a file correctly.
func TestSaveAndLoadConfig(t *testing.T) {
	// Create a temporary directory for the test to avoid interfering with actual user config.
	tempDir := t.TempDir()

	// Temporarily override the user home directory to our temp directory.
	// This ensures that our config file is written to a predictable, temporary location.
	t.Setenv("HOME", tempDir)

	// Define a sample configuration to save.
	expectedConfig := &Config{
		ServiceProvider: "gmail",
		Email:           "test@example.com",
		Password:        "supersecret",
		Name:            "Test User",
	}

	// Attempt to save the configuration.
	err := SaveConfig(expectedConfig)
	if err != nil {
		t.Fatalf("SaveConfig() failed: %v", err)
	}

	// Attempt to load the configuration back.
	loadedConfig, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() failed: %v", err)
	}

	// Compare the loaded configuration with the original one.
	// reflect.DeepEqual is used for a deep comparison of the structs.
	if !reflect.DeepEqual(loadedConfig, expectedConfig) {
		t.Errorf("Loaded config does not match expected config.\nGot:  %+v\nWant: %+v", loadedConfig, expectedConfig)
	}
}

// TestIMAPServer tests the logic that determines the IMAP server address.
func TestIMAPServer(t *testing.T) {
	testCases := []struct {
		name     string
		provider string
		want     string
	}{
		{"Gmail", "gmail", "imap.gmail.com:993"},
		{"iCloud", "icloud", "imap.mail.me.com:993"},
		{"Outlook", "outlook", "outlook.office365.com:993"},
		{"Yahoo", "yahoo", "imap.mail.yahoo.com:993"},
		{"CustomLeer", "custom", ""},
		{"Empty", "", ""},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Email muss gesetzt sein, sonst liefert GetActiveAccount() einen Fehler
			// und Config.IMAPServer() returnt "" — das wuerde die Provider-Logik
			// nie erreichen.
			cfg := &Config{
				ServiceProvider: tc.provider,
				Email:           "test@example.com",
			}
			got := cfg.IMAPServer()
			if got != tc.want {
				t.Errorf("IMAPServer() = %q, want %q", got, tc.want)
			}
		})
	}
}

// TestAccountSMTPServer tests the logic that determines the SMTP host and port.
func TestAccountSMTPServer(t *testing.T) {
	testCases := []struct {
		name     string
		account  Account
		wantHost string
		wantPort int
	}{
		{"Gmail", Account{ServiceProvider: "gmail"}, "smtp.gmail.com", 587},
		{"iCloud", Account{ServiceProvider: "icloud"}, "smtp.mail.me.com", 587},
		{"Outlook", Account{ServiceProvider: "outlook"}, "smtp.office365.com", 587},
		{"Hotmail", Account{ServiceProvider: "hotmail"}, "smtp.office365.com", 587},
		{"Yahoo", Account{ServiceProvider: "yahoo"}, "smtp.mail.yahoo.com", 587},
		{
			"Custom mit explizitem Port",
			Account{ServiceProvider: "custom", SMTPServerAddress: "smtp.example.com", SMTPPort: "465"},
			"smtp.example.com", 465,
		},
		{
			"Custom ohne Port -> Default 587",
			Account{ServiceProvider: "custom", SMTPServerAddress: "smtp.example.com"},
			"smtp.example.com", 587,
		},
		{
			"Custom ohne Server -> leer",
			Account{ServiceProvider: "custom"},
			"", 0,
		},
		{
			"SMTPServerAddress hat Vorrang vor bekanntem Provider",
			Account{ServiceProvider: "gmail", SMTPServerAddress: "smtp.relay.local", SMTPPort: "25"},
			"smtp.relay.local", 25,
		},
		{"Unbekannter Provider", Account{ServiceProvider: "exotic"}, "", 0},
		{"Leer", Account{}, "", 0},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			gotHost, gotPort := tc.account.SMTPServer()
			if gotHost != tc.wantHost || gotPort != tc.wantPort {
				t.Errorf("SMTPServer() = (%q, %d), want (%q, %d)",
					gotHost, gotPort, tc.wantHost, tc.wantPort)
			}
		})
	}
}
