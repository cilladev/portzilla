# Portzilla

A macOS menu bar app for listing and killing processes bound to local ports. Hit `EADDRINUSE`? Click once instead of running `lsof` + `kill`.

![Portzilla](docs/screenshot.png)

## Requirements

- macOS 13+ (Ventura)
- Swift 5.9+

## Quick start

```bash
git clone <repo-url> && cd portzilla
swift run
```

## Build .app bundle

```bash
make bundle
# → Portzilla.app (ad-hoc signed, right-click → Open first time)
```

## Set as login item

System Settings → General → Login Items → add `Portzilla.app`

## Hotkey

**⌃⌥P** (Control + Option + P) toggles the popover from any app.

## Development

```bash
make run      # swift run
make build    # swift build -c release
make test     # swift test
make clean    # rm -rf .build Portzilla.app
```

## License

MIT
