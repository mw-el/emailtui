package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// Account stores a single email account configuration.
type Account struct {
	ServiceProvider   string `json:"service_provider"`
	Email             string `json:"email"`
	Password          string `json:"password"`
	Name              string `json:"name"`
	IMAPServerAddress string `json:"imap_server_address,omitempty"` // Custom IMAP server address (optional)
	IMAPPort          string `json:"imap_port,omitempty"`           // Custom IMAP port (optional, defaults to 993)
	AccountName       string `json:"account_name,omitempty"`        // Friendly name for the account (optional)
}

// Config stores the user's email configuration (supports multiple accounts).
type Config struct {
	// For backward compatibility: single account mode
	ServiceProvider   string `json:"service_provider,omitempty"`
	Email             string `json:"email,omitempty"`
	Password          string `json:"password,omitempty"`
	Name              string `json:"name,omitempty"`
	IMAPServerAddress string `json:"imap_server_address,omitempty"`
	IMAPPort          string `json:"imap_port,omitempty"`

	// Multi-account mode
	Accounts       []Account `json:"accounts,omitempty"`
	ActiveAccount  int       `json:"active_account,omitempty"` // Index of the active account (0-based)
}

// configDir returns the path to the configuration directory.
func configDir() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "email-cli"), nil
}

// configFile returns the full path to the configuration file.
func configFile() (string, error) {
	dir, err := configDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.json"), nil
}

// SaveConfig saves the given configuration to the config file.
func SaveConfig(config *Config) error {
	path, err := configFile()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0600)
}

// LoadConfig loads the configuration from the config file.
func LoadConfig() (*Config, error) {
	path, err := configFile()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, err
	}
	return &config, nil
}

// GetActiveAccount returns the currently active account configuration.
// If multi-account mode is used, it returns the account at ActiveAccount index.
// Otherwise, it returns the legacy single-account config as an Account.
func (c *Config) GetActiveAccount() (*Account, error) {
	// Multi-account mode
	if len(c.Accounts) > 0 {
		if c.ActiveAccount < 0 || c.ActiveAccount >= len(c.Accounts) {
			return nil, fmt.Errorf("invalid active account index: %d", c.ActiveAccount)
		}
		return &c.Accounts[c.ActiveAccount], nil
	}

	// Legacy single-account mode
	if c.Email != "" {
		return &Account{
			ServiceProvider:   c.ServiceProvider,
			Email:             c.Email,
			Password:          c.Password,
			Name:              c.Name,
			IMAPServerAddress: c.IMAPServerAddress,
			IMAPPort:          c.IMAPPort,
		}, nil
	}

	return nil, fmt.Errorf("no account configured")
}

// AddAccount adds a new account to the configuration.
func (c *Config) AddAccount(account Account) {
	c.Accounts = append(c.Accounts, account)
	// If this is the first account, make it active
	if len(c.Accounts) == 1 {
		c.ActiveAccount = 0
	}
}

// SwitchAccount changes the active account by index.
func (c *Config) SwitchAccount(index int) error {
	if index < 0 || index >= len(c.Accounts) {
		return fmt.Errorf("invalid account index: %d", index)
	}
	c.ActiveAccount = index
	return nil
}

// GetAccountByEmail finds an account by email address.
func (c *Config) GetAccountByEmail(email string) (*Account, int, error) {
	for i, acc := range c.Accounts {
		if acc.Email == email {
			return &acc, i, nil
		}
	}
	return nil, -1, fmt.Errorf("account not found: %s", email)
}

// IMAPServer returns the IMAP server address for an account.
func (a *Account) IMAPServer() string {
	// If a custom IMAP server is specified, use it
	if a.IMAPServerAddress != "" {
		if a.IMAPPort != "" {
			return a.IMAPServerAddress + ":" + a.IMAPPort
		}
		return a.IMAPServerAddress + ":993" // Default IMAP SSL port
	}

	// Otherwise, use known provider mappings
	switch a.ServiceProvider {
	case "gmail":
		return "imap.gmail.com:993"
	case "icloud":
		return "imap.mail.me.com:993"
	case "outlook", "hotmail":
		return "outlook.office365.com:993"
	case "yahoo":
		return "imap.mail.yahoo.com:993"
	case "custom":
		// For custom provider, user must specify IMAPServerAddress
		return ""
	default:
		return ""
	}
}

// IMAPServer returns the IMAP server for the active account (legacy method for backward compatibility).
func (c *Config) IMAPServer() string {
	acc, err := c.GetActiveAccount()
	if err != nil {
		return ""
	}
	return acc.IMAPServer()
}
