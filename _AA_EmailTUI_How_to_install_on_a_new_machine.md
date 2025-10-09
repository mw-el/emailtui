# Installation Guide: EmailTUI

## Overview
EmailTUI is a terminal-based email client written in Go, featuring a modern TUI (Text User Interface) built with Bubble Tea and Lip Gloss. It provides email reading, composing, and management directly from the terminal.

## System Requirements
- Ubuntu 24.04 (or compatible Linux distribution)
- Go 1.24.5 or later
- Internet connection for email access

## Prerequisites

### 1. Install Go
If Go is not already installed:
```bash
# Download Go 1.24.5 (or latest version)
wget https://go.dev/dl/go1.24.5.linux-amd64.tar.gz

# Remove old Go installation (if any)
sudo rm -rf /usr/local/go

# Extract new installation
sudo tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz

# Add to PATH (add to ~/.bashrc or ~/.profile for persistence)
export PATH=$PATH:/usr/local/go/bin
```

Verify installation:
```bash
go version
# Should show: go version go1.24.5 linux/amd64 (or similar)
```

## Installation Steps

### 1. Copy the Application Folder
Copy the entire `_AA_EmailTUI` folder to your home directory:
```bash
cp -r _AA_EmailTUI ~/_AA_EmailTUI
cd ~/_AA_EmailTUI
```

### 2. Build the Application
The application uses Go modules (defined in `go.mod`). Build the binary:

```bash
# Download dependencies
go mod download

# Build the binary
go build -o emailtui main.go
```

This will create an `emailtui` executable in the current directory.

Alternatively, if a pre-built binary already exists:
```bash
# Make sure the binary is executable
chmod +x emailtui
```

### 3. Configure Email Account
Create or edit the configuration file in `config/`:
```bash
mkdir -p config
```

The app will prompt for email configuration on first run, or you can create a config file manually.

### 4. Test the Application
```bash
./emailtui
```

## Dependencies

The application uses the following Go packages (automatically managed by go.mod):

**Core TUI:**
- github.com/charmbracelet/bubbletea v1.3.6 - TUI framework
- github.com/charmbracelet/bubbles v0.21.0 - TUI components
- github.com/charmbracelet/lipgloss v1.1.0 - Terminal styling

**Email:**
- github.com/emersion/go-imap v1.2.1 - IMAP protocol
- github.com/emersion/go-message v0.18.2 - Email parsing

**Utilities:**
- github.com/PuerkitoBio/goquery v1.10.3 - HTML parsing
- github.com/yuin/goldmark v1.7.13 - Markdown rendering
- github.com/google/uuid v1.6.0 - UUID generation
- golang.org/x/text v0.27.0 - Text processing

All dependencies will be automatically downloaded when you run `go build` or `go mod download`.

## Configuration

### Email Settings
The application supports IMAP email accounts. Configuration is typically stored in `~/.config/emailtui/` or the local `config/` directory.

Basic email configuration includes:
- IMAP server address
- IMAP port (usually 993 for SSL)
- Email address
- Password or app-specific password

### First Run
On first run, the app will guide you through initial setup.

## Usage

### Launch the Application
```bash
cd ~/_AA_EmailTUI
./emailtui
```

### Key Features
- Read emails with markdown rendering
- Compose and send emails
- Navigate with keyboard shortcuts
- Modern terminal UI with colors and styling
- IMAP support for various email providers
- HTML email rendering

## Troubleshooting

### Go Not Found
Ensure Go is properly installed and in your PATH:
```bash
which go
go version
```

If not found, add to your PATH:
```bash
export PATH=$PATH:/usr/local/go/bin
```

### Build Errors
If you encounter build errors, ensure you have the latest dependencies:
```bash
go mod tidy
go mod download
go build -o emailtui main.go
```

### Connection Issues
- Verify your internet connection
- Check IMAP server settings
- Ensure your email provider allows IMAP access
- For Gmail: Enable "Less secure app access" or use an app-specific password
- Check firewall settings (port 993 for IMAP SSL)

### Missing Dependencies
All dependencies are managed by Go modules. If you see import errors:
```bash
go mod tidy
go mod verify
```

## Building from Source

### Clean Build
```bash
# Clean any previous builds
go clean

# Download fresh dependencies
go mod download

# Build
go build -o emailtui main.go
```

### Build with Optimizations
```bash
# Build with size optimizations
go build -ldflags="-s -w" -o emailtui main.go
```

## Optional: System-wide Installation

To install the binary system-wide:
```bash
# Build the binary
go build -o emailtui main.go

# Install to /usr/local/bin (requires sudo)
sudo cp emailtui /usr/local/bin/

# Now you can run from anywhere
emailtui
```

## Notes
- No external system dependencies required (beyond Go)
- Pure Go application - no Python/Node.js needed
- All dependencies are Go libraries
- Lightweight and fast
- Works entirely in the terminal
- See README.md for detailed feature documentation

## File Structure
```
_AA_EmailTUI/
├── main.go                  # Main application entry point
├── emailtui                 # Compiled binary (after build)
├── go.mod                   # Go module definition
├── go.sum                   # Dependency checksums
├── config/                  # Configuration directory
├── fetcher/                 # Email fetching modules
├── sender/                  # Email sending modules
├── tui/                     # TUI components
├── view/                    # View logic
├── public/                  # Static assets
├── README.md                # Feature documentation
└── How to install on a new machine.md (this file)
```

## Development

For development:
```bash
# Run without building
go run main.go

# Run tests
go test ./...

# Format code
go fmt ./...
```
