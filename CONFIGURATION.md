# Email TUI Configuration Guide

This guide explains how to configure Email TUI to work with any IMAP email account, including support for multiple accounts.

## Configuration File Location

The configuration file is stored at:
```
~/.config/email-cli/config.json
```

## Single Account Configuration

### Using a Known Provider

For popular email providers (Gmail, iCloud, Outlook, Yahoo), you only need to specify the provider name:

```json
{
  "service_provider": "gmail",
  "email": "your.email@gmail.com",
  "password": "your-password-or-app-password",
  "name": "Your Name"
}
```

**Supported providers:**
- `gmail` - Gmail (imap.gmail.com:993)
- `icloud` - iCloud Mail (imap.mail.me.com:993)
- `outlook` or `hotmail` - Outlook/Hotmail (outlook.office365.com:993)
- `yahoo` - Yahoo Mail (imap.mail.yahoo.com:993)

### Using a Custom IMAP Server

For any other IMAP provider, specify the server address and port:

```json
{
  "service_provider": "custom",
  "email": "your.email@example.com",
  "password": "your-password",
  "name": "Your Name",
  "imap_server_address": "imap.example.com",
  "imap_port": "993"
}
```

**Notes:**
- If `imap_port` is omitted, it defaults to 993 (standard IMAP SSL port)
- The `imap_server_address` takes precedence over the `service_provider` mapping

## Multiple Account Configuration

To use multiple email accounts, use the `accounts` array:

```json
{
  "accounts": [
    {
      "account_name": "Work Gmail",
      "service_provider": "gmail",
      "email": "work@gmail.com",
      "password": "work-password",
      "name": "Work Name"
    },
    {
      "account_name": "Personal Yahoo",
      "service_provider": "yahoo",
      "email": "personal@yahoo.com",
      "password": "personal-password",
      "name": "Personal Name"
    },
    {
      "account_name": "Custom Server",
      "service_provider": "custom",
      "email": "me@mydomain.com",
      "password": "my-password",
      "name": "My Name",
      "imap_server_address": "mail.mydomain.com",
      "imap_port": "993"
    }
  ],
  "active_account": 0
}
```

**Key points:**
- `active_account` specifies which account to use (0-based index)
- `account_name` is optional but helpful for identifying accounts
- Each account can use a different provider or custom server

## Security Recommendations

1. **Use App Passwords**: For Gmail and other providers that support 2FA, use app-specific passwords instead of your main password
2. **File Permissions**: The config file is automatically created with restricted permissions (0600) to protect your credentials
3. **Never Commit**: Never commit your config.json file to version control

## Gmail Setup

For Gmail accounts:
1. Enable 2-Factor Authentication in your Google Account
2. Generate an App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and your device
   - Copy the generated password
3. Use the app password in your config.json

## Testing Your Configuration

Run `./emailtui` to start the application. If there are connection issues, check:
- Email and password are correct
- IMAP server address and port are correct
- Your firewall allows connections to port 993
- For Gmail: You're using an app password if 2FA is enabled

## Switching Between Accounts

To switch the active account, edit the `active_account` value in your config file (0-based index).

Example: To switch to the second account, set `"active_account": 1`

## Backward Compatibility

The old single-account configuration format is still supported for backward compatibility. If no `accounts` array is present, the tool will use the legacy single-account fields.
