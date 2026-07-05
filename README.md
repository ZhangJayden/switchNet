# SwitchNet

SwitchNet is a small macOS menu bar demo for quickly switching the current Wi-Fi service between DHCP and saved static network profiles.

## Run

```sh
swift run SwitchNet
```

The app stays in the macOS menu bar. Use **Manage Profiles...** to edit static IP profiles.

## Current Demo Features

- Menu bar app with current Wi-Fi status.
- Switch current Wi-Fi service to DHCP.
- Apply saved static IP, subnet mask, gateway, and DNS profiles.
- Edit multiple local profiles.
- Store profiles at `~/Library/Application Support/SwitchNet/profiles.json`.
- Toggle Launch at Login through macOS `SMAppService`.

## Important Notes

- Applying DHCP or a static profile runs `/usr/sbin/networksetup` and may ask for an administrator password.
- The demo is currently a Swift Package executable. Launch at Login is wired, but it is best validated after packaging as a real `.app` bundle.
- Wrong static IP settings can disconnect the current network. Check the profile before using **Apply Now**.

## Useful Commands

```sh
swift build
swift run SwitchNet
```
