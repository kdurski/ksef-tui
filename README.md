# KSeF TUI

A Terminal User Interface for interacting with Poland's National e-Invoice System (Krajowy System e-Faktur).

![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3.0-red)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- 🔐 **Token-based Authentication**: Securely authenticates with KSeF API.
- 📋 **Interactive Invoice Browser**: Navigate through invoices with ease.
- 🔍 **Detailed Invoice View**: Inspect individual invoice data.
- 🛡️ **Secure Logging**: Sensitive tokens are redacted from logs and debug views.
- 🐞 **Debug Mode**: Inspect raw API requests and responses in real-time.
- 🔄 **Resilient Networking**: Automatic retries for network glitches and server errors.
- ⌨️ **Keyboard Navigation**: Efficient vim-like bindings (`j`/`k`).

## Requirements

- Ruby >= 3.3
- KSeF API token (obtained from the Polish Tax Authority)

## Installation

```bash
git clone https://github.com/kdurski/ksef-tui.git
cd ksef-tui
bundle install
```

## Configuration

The application uses a configuration file at `~/.ksef.yml` to manage multiple profiles (environments).

**Example `~/.ksef.yml`:**

```yaml
default: "Production"
profiles:
  - name: "Production"
    nip: "1111111111"
    token: "prod-token"
    # host: "api.ksef.mf.gov.pl" # Optional, defaults to this
  - name: "Test"
    nip: "2222222222"
    token: "test-token"
    host: "ksef-test.mf.gov.pl"
```

You can select a profile on startup:
- **Interactive**: Run `ruby app.rb` (shows selector if no default)
- **CLI**: Run `ruby app.rb -p "Test"`
- **Default**: Defined in `~/.ksef.yml`

## Usage

```bash
ruby app.rb
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `c` | Connect to KSeF |
| `r` | Refresh invoice list |
| `j` / `↓` | Move selection down |
| `k` / `↑` | Move selection up |
| `Enter` | View invoice details |
| `Shift+D` | Open Debug View |
| `Esc` | Close current view |
| `q` | Quit application |
| `Ctrl+C` | Force quit |

## Development

### Running Tests

```bash
bundle exec rake test
```

### Test Coverage

Coverage reports are generated in `coverage/index.html`:

```bash
bundle exec rake test
open coverage/index.html
```

## Project Structure

```
├── app.rb                      # Main application entry point
├── lib/
│   └── ksef/
│       ├── client.rb           # HTTP client with retries and logging
│       ├── auth.rb             # Authentication flow (Challenge/Response)
│       ├── session.rb          # Session state management
│       ├── logger.rb           # Application and API logger
│       ├── styles.rb           # TUI style definitions
│       ├── models/             # Data models (Invoice, ApiLog)
│       └── views/              # UI components (Main, Detail, Debug)
└── test/                       # Minitest suite
```

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request
