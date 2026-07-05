# SwitchNet for Windows

This is a Windows tray demo for switching a Wi-Fi interface between DHCP and saved static IP profiles.

## Requirements

- Windows 10 or later.
- .NET 8 SDK.
- Administrator approval is required when applying DHCP or static network settings.

## Run

```powershell
cd windows\SwitchNet.Windows
dotnet run
```

SwitchNet appears in the Windows system tray. Right-click the tray icon to refresh status, switch to DHCP, apply a saved profile, or open the profile editor.

## What It Uses

- `netsh wlan show interfaces` to detect Wi-Fi interface and SSID.
- `Get-NetIPConfiguration` and `Get-DnsClientServerAddress` to read current settings.
- `netsh interface ip set address` and `netsh interface ip set dnsservers` to apply DHCP or static settings.

Profiles are saved at:

```text
%APPDATA%\SwitchNet\profiles.windows.json
```

## Publish

```powershell
dotnet publish -c Release -r win-x64 --self-contained true
```

The published executable will be under `bin\Release\net8.0-windows\win-x64\publish`.
