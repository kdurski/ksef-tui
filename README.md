# KSeF

KSeF client project currently centered on a Terminal UI, with a Rails Web UI being rebuilt and expanded.

## Project Status

- TUI is the primary working interface.
- Rails Web UI is in progress and will become a first-class interface.
- Core KSeF client/domain logic is shared so both interfaces can evolve together.

## Current Capabilities (TUI)

- Token-based authentication with KSeF API.
- Interactive invoice list and detail view.
- Debug/API inspection views.
- Retry-aware networking and configurable timeouts.
- Profile-based configuration from `~/.ksef.yml`.

## Requirements

- Ruby 4.0.1 (project managed via `asdf`).
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
    host: "ksef-test.mf.gov.pl"
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

## Tests

Run full suite:

```bash
PARALLEL_WORKERS=1 bin/rails test
```

Run only TUI tests:

```bash
bin/rails test test/tui
```

Run only core/client tests:

```bash
bin/rails test test/core
```

## Roadmap

- Complete Rails Web UI flow parity with the TUI.
- Add richer dashboard and invoice filtering/search in Web UI.
- Add asynchronous notifications for key events:
  - email notifications
  - SMS notifications
  - delivery status and retry visibility
- Add background jobs for monitoring, alerts, and periodic sync.
- Add stronger operational tooling (auditing, observability, deployment hardening).

## License

MIT - see `LICENSE`.
