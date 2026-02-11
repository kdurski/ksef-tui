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
- ⌨️ **Keyboard Navigation**: Arrow-key based navigation.

## Requirements

- Ruby >= 3.3
- KSeF API token (obtained from the Polish Tax Authority)

## Installation

```bash
git clone https://github.com/kdurski/ksef-tui.git
cd ksef-tui
bundle install
```

## Config

The application uses a config file at `~/.ksef.yml` with two sections:

- Generic settings (`settings`): retries, timeouts, locale, default host.
- Profile-specific settings (`profiles`): profile `name`, `nip`, `token`, optional `host`.

**Example `~/.ksef.yml`:**

```yaml
settings:
  locale: "en"
  default_host: "api.ksef.mf.gov.pl"
  max_retries: 3
  open_timeout: 10
  read_timeout: 15
  write_timeout: 10

default_profile: "Production"
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
- **Interactive**: Run `bundle exec rake tui` (shows selector if no default)
- **CLI**: Run `bundle exec rake "tui[Test]"` or `PROFILE=Test bundle exec rake tui`
- **Default**: Defined in `~/.ksef.yml`

## Usage

```bash
bundle exec rake tui
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `c` | Connect to KSeF |
| `r` | Refresh invoice list |
| `↓` | Move selection down |
| `↑` | Move selection up |
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

### Git Hooks

To enforce style checks before each commit, enable the repository hook path:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook runs:

```bash
bundle exec standardrb
```

### Test Coverage

Coverage reports are generated in `coverage/index.html`:

```bash
bundle exec rake test
open coverage/index.html
```

## Project Structure

```
├── lib/
│   └── ksef/
│       ├── core/               # Shared domain and KSeF API integration
│       │   ├── client.rb       # HTTP client with retries and logging
│       │   ├── auth.rb         # Authentication flow (Challenge/Response)
│       │   ├── session.rb      # Session state management
│       │   ├── logger.rb       # Application and API logger
│       │   ├── config.rb       # Config loading/saving
│       │   ├── i18n.rb         # Internationalization setup
│       │   └── models/         # Data models (Invoice, ApiLog, Profile)
│       └── tui/                # Terminal user interface
│           ├── app.rb          # TUI app orchestration
│           ├── runner.rb       # CLI option handling for TUI startup
│           ├── styles.rb       # TUI style definitions
│           └── views/          # UI components (Main, Detail, Debug)
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
