# Brouter - Browser x Router

Registers as a macOS app that can be set as the default browser.
When opened with a URL, it matches the URL against a set of regex rules and executes the command for the first match.

## Install

- Build + install to `~/Applications`:
  - `make install`
- Open System Settings to set it as default browser:
  - `make open-default-browser-settings`

## Config

Create a config at either:

- `${XDG_CONFIG_HOME:-~/.config}/brouter/config`
- `~/Library/Application Support/Brouter/config`

Format: one rule per line:

- `<regex> <command...>`
- First matching regex wins
- Lines starting with `#` are ignored

Example:

- `^https://(corp\.|jira\.) open -a "Google Chrome"`
- `.* open -a "Safari"`
