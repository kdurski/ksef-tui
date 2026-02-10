# KSeF TUI

A Terminal User Interface for interacting with Poland's National e-Invoice System (Krajowy System e-Faktur).

![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3.0-red)
![License](https://img.shields.io/badge/license-MIT-blue)

## Features

- 🔐 Token-based authentication with KSeF API
- 📋 Browse invoices in an interactive table view
- 🔍 View detailed invoice information
- ⌨️ Keyboard navigation
- 📊 Activity log panel for real-time status updates

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

Copy the example environment file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env` with your KSeF credentials:

```env
KSEF_HOST=api.ksef.mf.gov.pl
KSEF_NIP=your_company_nip
KSEF_TOKEN=your_ksef_token
```

## Usage

```bash
ruby app.rb
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `c` | Connect to KSeF |
| `r` | Refresh invoice list |
| `↑` | Move selection up |
| `↓` | Move selection down |
| `Enter` | View invoice details |
| `b/Esc/q` | Go back / Close detail view |
| `Ctrl+C` | Quit application |

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
│       ├── client.rb           # HTTP client for KSeF API
│       ├── auth.rb             # Authentication flow
│       └── tui/
│           ├── views.rb        # UI rendering components
│           ├── input_handler.rb # Keyboard event handling
│           └── styles.rb       # TUI style definitions
└── test/                       # Test suite
```

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request
