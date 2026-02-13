# KSeF

KSeF client project currently centered on a Terminal UI, with a Rails Web UI being rebuilt and expanded.

## Project Status

- Terminal UI based on RatatuiRuby for previewing invoices
- Rails Web UI is in progress and will become a first-class interface.
- Core KSeF client/domain logic is shared so both interfaces can evolve together.

## Current Capabilities (TUI)

- Token-based authentication with KSeF API.
- Interactive invoice list and detail view.
- Debug/API inspection views.
- Profile-based configuration from `~/.ksef.yml`.

## Requirements

- Ruby 4.0.1 
- Access to KSeF API credentials (NIP + token).

## Configuration

Create `~/.ksef.yml`:

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
  - name: "Test"
    nip: "2222222222"
    token: "test-token"
    host: "api-test.ksef.mf.gov.pl"
```

## Run TUI

From project root:

```bash
rake tui
```

You can also pass profile:

```bash
rake "tui[Test]"
```

or:

```bash
PROFILE=Test rake tui
```

If your shell does not auto-activate bundle context, use `bundle exec rake tui`.

## Keyboard Shortcuts

| Key | Action |
| --- | --- |
| `c` | Connect to KSeF |
| `r` | Refresh invoices |
| `p` | Profile selector |
| `Shift+D` | Debug view |
| `L` | Toggle locale |
| `Enter` | Open details |
| `Esc` | Back |
| `q` | Quit |

## Screenshots

### Main View (Disconnected)

![Main TUI view before connecting to KSeF](doc/tui-main-empty.png)

### Invoice List (Connected)

![Invoice list after connecting to KSeF](doc/tui-invoices-list.png)

### Profile Selector

![Profile selection dialog](doc/tui-profile-selector.png)

### Invoice Detail

![Detailed view of selected invoice](doc/tui-invoice-detail.png)

### Debug View

![Debug/API logs view](doc/tui-debug-view.png)

## Tests

Run full suite:

```bash
bin/rails test
```

## Roadmap

- Complete Rails Web UI
- Add notifications for new invoices  
  - email notifications
  - SMS notifications
- Add background jobs for monitoring, alerts, and periodic sync.

## License

MIT - see `LICENSE`.
