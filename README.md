# Brouter

Brouter is a small macOS app that acts as a programmable default browser.
Instead of opening every link the same way, it routes URLs to different commands based on simple regex rules.

When macOS opens a URL, Brouter finds the first matching rule and executes its command.

## Installation

### From a release

1. Download the latest `Brouter.app` from the GitHub releases page.
1. Move it into your `~/Applications` folder.
1. Remove macOS quarantine attributes:
   - `xattr -cr ~/Applications/Brouter.app`
1. Set Brouter as your default browser in System Settings.

### From source

1. Build and install the app into `~/Applications`:
   - `make install`
1. Then open System Settings to set it as the default browser:
   - `make open-default-browser-settings`

## Configuration

- Create a config file in `${XDG_CONFIG_HOME:-~/.config}/brouter/config`
- Each line defines a routing rule:
  - `<regex> <command...>`
  - Rules are evaluated top to bottom; first match wins
  - Lines starting with `#` and empty lines are ignored
- Example:

  ```
  # Open youtube and twitch in my personal profile
  .*youtube\.com.* open -na "Google Chrome" --args --profile-directory="Personal"
  .*twitch\.com.* open -na "Google Chrome" --args --profile-directory="Personal"

  # Open everything else in my work profile
  .* open -na "Google Chrome" --args --profile-directory="Work"
  ```

- `./src/example-config` has more examples for common browsers
