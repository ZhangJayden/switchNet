using System.Diagnostics;
using System.Drawing;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Windows.Forms;

namespace SwitchNet.Windows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new TrayAppContext());
    }
}

internal sealed class TrayAppContext : ApplicationContext
{
    private readonly ProfileStore _profileStore = new();
    private readonly NetworkManager _networkManager = new();
    private readonly NotifyIcon _notifyIcon;
    private readonly List<NetworkProfile> _profiles;
    private MainForm? _mainForm;
    private NetworkSnapshot _snapshot = NetworkSnapshot.Empty;

    public TrayAppContext()
    {
        _profiles = _profileStore.Load();
        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "SwitchNet",
            Visible = true
        };

        _notifyIcon.DoubleClick += (_, _) => ShowProfiles();
        RefreshSnapshot();
        RebuildMenu();
    }

    private void RefreshSnapshot()
    {
        try
        {
            _snapshot = _networkManager.GetSnapshot();
        }
        catch (Exception ex)
        {
            _snapshot = NetworkSnapshot.Empty with { Message = ex.Message };
        }
    }

    private void RebuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add(DisabledItem($"SSID: {_snapshot.Ssid}"));
        menu.Items.Add(DisabledItem($"Interface: {_snapshot.InterfaceName}"));
        menu.Items.Add(DisabledItem($"IP: {_snapshot.IpAddress}"));
        menu.Items.Add(DisabledItem($"Gateway: {_snapshot.Gateway}"));
        menu.Items.Add(DisabledItem($"DNS: {(_snapshot.DnsServers.Count == 0 ? "Automatic" : string.Join(", ", _snapshot.DnsServers))}"));

        if (!string.IsNullOrWhiteSpace(_snapshot.Message))
        {
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(DisabledItem(_snapshot.Message));
        }

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Use DHCP", null, (_, _) => ApplyDHCP());

        foreach (var profile in _profiles)
        {
            menu.Items.Add($"Apply {profile.Name}", null, (_, _) => ApplyProfile(profile));
        }

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Manage Profiles...", null, (_, _) => ShowProfiles());
        menu.Items.Add("Refresh Status", null, (_, _) =>
        {
            RefreshSnapshot();
            RebuildMenu();
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit SwitchNet", null, (_, _) => ExitThread());

        _notifyIcon.ContextMenuStrip = menu;
    }

    private static ToolStripMenuItem DisabledItem(string text)
    {
        return new ToolStripMenuItem(text) { Enabled = false };
    }

    private void ApplyDHCP()
    {
        try
        {
            _networkManager.ApplyDHCP(_snapshot.InterfaceName);
            MessageBox.Show("DHCP command was sent. Windows may ask for administrator approval.", "SwitchNet");
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "SwitchNet", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        RefreshSnapshot();
        RebuildMenu();
    }

    private void ApplyProfile(NetworkProfile profile)
    {
        try
        {
            _networkManager.ApplyProfile(profile, string.IsNullOrWhiteSpace(profile.InterfaceName) ? _snapshot.InterfaceName : profile.InterfaceName);
            MessageBox.Show("Static profile command was sent. Windows may ask for administrator approval.", "SwitchNet");
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "SwitchNet", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        RefreshSnapshot();
        RebuildMenu();
    }

    private void ShowProfiles()
    {
        if (_mainForm is null || _mainForm.IsDisposed)
        {
            _mainForm = new MainForm(_profiles, _snapshot, _profileStore, _networkManager, () =>
            {
                RefreshSnapshot();
                RebuildMenu();
            });
        }

        _mainForm.Show();
        _mainForm.WindowState = FormWindowState.Normal;
        _mainForm.Activate();
    }

    protected override void ExitThreadCore()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        base.ExitThreadCore();
    }
}

internal sealed class MainForm : Form
{
    private readonly List<NetworkProfile> _profiles;
    private readonly ProfileStore _profileStore;
    private readonly NetworkManager _networkManager;
    private readonly Action _afterChange;
    private readonly ListBox _profileList = new();
    private readonly Label _currentLabel = new();
    private readonly TextBox _nameText = new();
    private readonly TextBox _interfaceText = new();
    private readonly TextBox _ipText = new();
    private readonly TextBox _subnetText = new();
    private readonly TextBox _gatewayText = new();
    private readonly TextBox _dnsText = new();
    private readonly TextBox _ssidText = new();

    public MainForm(
        List<NetworkProfile> profiles,
        NetworkSnapshot snapshot,
        ProfileStore profileStore,
        NetworkManager networkManager,
        Action afterChange)
    {
        _profiles = profiles;
        _profileStore = profileStore;
        _networkManager = networkManager;
        _afterChange = afterChange;

        Text = "SwitchNet Profiles";
        Width = 820;
        Height = 520;
        MinimumSize = new Size(720, 420);
        StartPosition = FormStartPosition.CenterScreen;

        _currentLabel.Text = FormatSnapshot(snapshot);
        _currentLabel.AutoSize = false;
        _currentLabel.Height = 72;
        _currentLabel.Dock = DockStyle.Top;
        _currentLabel.Padding = new Padding(12);

        var split = new SplitContainer
        {
            Dock = DockStyle.Fill,
            SplitterDistance = 240
        };

        _profileList.Dock = DockStyle.Fill;
        _profileList.DisplayMember = nameof(NetworkProfile.Name);
        _profileList.SelectedIndexChanged += (_, _) => LoadSelectedProfile();
        split.Panel1.Controls.Add(_profileList);
        split.Panel1.Controls.Add(BuildSidebarButtons());
        split.Panel2.Controls.Add(BuildEditor());

        Controls.Add(split);
        Controls.Add(_currentLabel);

        ReloadList();
    }

    private Control BuildSidebarButtons()
    {
        var panel = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 44,
            FlowDirection = FlowDirection.LeftToRight,
            Padding = new Padding(8)
        };

        panel.Controls.Add(Button("Add", (_, _) =>
        {
            var profile = new NetworkProfile
            {
                Name = "Office Static",
                InterfaceName = "Wi-Fi",
                IpAddress = "192.168.1.88",
                SubnetMask = "255.255.255.0",
                Gateway = "192.168.1.1",
                DnsServers = ["223.5.5.5", "8.8.8.8"]
            };
            _profiles.Add(profile);
            Save();
            ReloadList(profile);
        }));

        panel.Controls.Add(Button("Delete", (_, _) =>
        {
            if (_profileList.SelectedItem is not NetworkProfile profile)
            {
                return;
            }

            _profiles.Remove(profile);
            Save();
            ReloadList();
        }));

        return panel;
    }

    private Control BuildEditor()
    {
        var panel = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 2,
            RowCount = 9,
            Padding = new Padding(16)
        };

        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 110));
        panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        AddRow(panel, 0, "Name", _nameText);
        AddRow(panel, 1, "Interface", _interfaceText);
        AddRow(panel, 2, "IP Address", _ipText);
        AddRow(panel, 3, "Subnet Mask", _subnetText);
        AddRow(panel, 4, "Gateway", _gatewayText);
        AddRow(panel, 5, "DNS", _dnsText);
        AddRow(panel, 6, "Bind SSID", _ssidText);

        var buttonPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.LeftToRight
        };

        buttonPanel.Controls.Add(Button("Save", (_, _) =>
        {
            SaveCurrentEditor();
            Save();
        }));
        buttonPanel.Controls.Add(Button("Apply Now", (_, _) =>
        {
            SaveCurrentEditor();
            Save();

            if (_profileList.SelectedItem is NetworkProfile profile)
            {
                _networkManager.ApplyProfile(profile, profile.InterfaceName);
                MessageBox.Show("Static profile command was sent. Windows may ask for administrator approval.", "SwitchNet");
                _afterChange();
            }
        }));
        buttonPanel.Controls.Add(Button("Use DHCP", (_, _) =>
        {
            var name = string.IsNullOrWhiteSpace(_interfaceText.Text) ? "Wi-Fi" : _interfaceText.Text.Trim();
            _networkManager.ApplyDHCP(name);
            MessageBox.Show("DHCP command was sent. Windows may ask for administrator approval.", "SwitchNet");
            _afterChange();
        }));

        panel.Controls.Add(buttonPanel, 1, 8);
        return panel;
    }

    private static void AddRow(TableLayoutPanel panel, int row, string label, TextBox textBox)
    {
        textBox.Dock = DockStyle.Fill;
        panel.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
        panel.Controls.Add(new Label { Text = label, TextAlign = ContentAlignment.MiddleLeft, Dock = DockStyle.Fill }, 0, row);
        panel.Controls.Add(textBox, 1, row);
    }

    private static Button Button(string text, EventHandler onClick)
    {
        var button = new Button
        {
            Text = text,
            AutoSize = true,
            Height = 30
        };
        button.Click += onClick;
        return button;
    }

    private void ReloadList(NetworkProfile? selected = null)
    {
        _profileList.DataSource = null;
        _profileList.DataSource = _profiles;
        _profileList.DisplayMember = nameof(NetworkProfile.Name);

        if (selected is not null)
        {
            _profileList.SelectedItem = selected;
        }
        else if (_profiles.Count > 0)
        {
            _profileList.SelectedIndex = 0;
        }
    }

    private void LoadSelectedProfile()
    {
        if (_profileList.SelectedItem is not NetworkProfile profile)
        {
            return;
        }

        _nameText.Text = profile.Name;
        _interfaceText.Text = profile.InterfaceName;
        _ipText.Text = profile.IpAddress;
        _subnetText.Text = profile.SubnetMask;
        _gatewayText.Text = profile.Gateway;
        _dnsText.Text = string.Join(", ", profile.DnsServers);
        _ssidText.Text = profile.BoundSSID;
    }

    private void SaveCurrentEditor()
    {
        if (_profileList.SelectedItem is not NetworkProfile profile)
        {
            return;
        }

        profile.Name = _nameText.Text.Trim();
        profile.InterfaceName = string.IsNullOrWhiteSpace(_interfaceText.Text) ? "Wi-Fi" : _interfaceText.Text.Trim();
        profile.IpAddress = _ipText.Text.Trim();
        profile.SubnetMask = _subnetText.Text.Trim();
        profile.Gateway = _gatewayText.Text.Trim();
        profile.DnsServers = _dnsText.Text
            .Split([',', ' ', ';', '\r', '\n', '\t'], StringSplitOptions.RemoveEmptyEntries)
            .Select(value => value.Trim())
            .ToList();
        profile.BoundSSID = _ssidText.Text.Trim();
        ReloadList(profile);
    }

    private void Save()
    {
        _profileStore.Save(_profiles);
        _afterChange();
    }

    private static string FormatSnapshot(NetworkSnapshot snapshot)
    {
        return $"Current: {snapshot.Ssid} | {snapshot.InterfaceName} | {snapshot.IpAddress} | Gateway {snapshot.Gateway} | DNS {(snapshot.DnsServers.Count == 0 ? "Automatic" : string.Join(", ", snapshot.DnsServers))}";
    }
}

internal sealed class NetworkManager
{
    public NetworkSnapshot GetSnapshot()
    {
        var interfaceName = DetectWirelessInterface();
        var ssid = DetectSSID();
        var escapedInterfaceName = EscapePowerShell(interfaceName);
        var json = RunPowerShell(string.Join(Environment.NewLine, [
            $"$config = Get-NetIPConfiguration -InterfaceAlias '{escapedInterfaceName}' -ErrorAction Stop",
            $"$dns = Get-DnsClientServerAddress -InterfaceAlias '{escapedInterfaceName}' -AddressFamily IPv4 -ErrorAction SilentlyContinue",
            "[PSCustomObject]@{",
            "  InterfaceName = $config.InterfaceAlias",
            "  IPAddress = @($config.IPv4Address)[0].IPAddress",
            "  PrefixLength = @($config.IPv4Address)[0].PrefixLength",
            "  Gateway = @($config.IPv4DefaultGateway)[0].NextHop",
            "  DnsServers = @($dns.ServerAddresses)",
            "} | ConvertTo-Json -Depth 4"
        ]));

        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        var prefixLength = ReadInt(root, "PrefixLength");

        return new NetworkSnapshot(
            InterfaceName: ReadString(root, "InterfaceName") ?? interfaceName,
            Ssid: ssid,
            IpAddress: ReadString(root, "IPAddress") ?? "-",
            SubnetMask: PrefixLengthToMask(prefixLength),
            Gateway: ReadString(root, "Gateway") ?? "-",
            DnsServers: ReadStringArray(root, "DnsServers"),
            Message: null
        );
    }

    public void ApplyDHCP(string interfaceName)
    {
        ValidateInterface(interfaceName);
        RunElevatedCommands([
            $"netsh interface ip set address name={CmdQuote(interfaceName)} source=dhcp",
            $"netsh interface ip set dnsservers name={CmdQuote(interfaceName)} source=dhcp"
        ]);
    }

    public void ApplyProfile(NetworkProfile profile, string interfaceName)
    {
        ValidateProfile(profile);
        ValidateInterface(interfaceName);

        var commands = new List<string>
        {
            $"netsh interface ip set address name={CmdQuote(interfaceName)} static {profile.IpAddress} {profile.SubnetMask} {profile.Gateway}"
        };

        if (profile.DnsServers.Count == 0)
        {
            commands.Add($"netsh interface ip set dnsservers name={CmdQuote(interfaceName)} source=dhcp");
        }
        else
        {
            commands.Add($"netsh interface ip set dnsservers name={CmdQuote(interfaceName)} static {profile.DnsServers[0]} primary");
            for (var index = 1; index < profile.DnsServers.Count; index++)
            {
                commands.Add($"netsh interface ip add dnsservers name={CmdQuote(interfaceName)} {profile.DnsServers[index]} index={index + 1}");
            }
        }

        RunElevatedCommands(commands);
    }

    private static string DetectWirelessInterface()
    {
        var output = RunProcess("netsh.exe", "wlan show interfaces");
        var match = Regex.Match(output, @"^\s*Name\s*:\s*(.+)$", RegexOptions.Multiline);
        if (match.Success)
        {
            return match.Groups[1].Value.Trim();
        }

        var fallback = RunPowerShell("""
            $adapter = Get-NetAdapter -Physical | Where-Object {
              $_.Name -match 'Wi-Fi|Wireless|WLAN' -or $_.InterfaceDescription -match 'Wi-Fi|Wireless|WLAN'
            } | Select-Object -First 1
            if ($adapter) { $adapter.Name } else { 'Wi-Fi' }
            """);
        return string.IsNullOrWhiteSpace(fallback) ? "Wi-Fi" : fallback.Trim();
    }

    private static string DetectSSID()
    {
        var output = RunProcess("netsh.exe", "wlan show interfaces");
        var match = Regex.Match(output, @"^\s*SSID\s*:\s*(.+)$", RegexOptions.Multiline);
        return match.Success ? match.Groups[1].Value.Trim() : "Unknown";
    }

    private static void RunElevatedCommands(IEnumerable<string> commands)
    {
        var batchPath = Path.Combine(Path.GetTempPath(), $"SwitchNet-{Guid.NewGuid():N}.cmd");
        File.WriteAllText(batchPath, "@echo off\r\n" + string.Join("\r\n", commands) + "\r\n");

        var process = new ProcessStartInfo
        {
            FileName = batchPath,
            Verb = "runas",
            UseShellExecute = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        using var started = Process.Start(process);
        started?.WaitForExit();

        try
        {
            File.Delete(batchPath);
        }
        catch
        {
            // The temp command file is harmless if Windows still has it locked.
        }
    }

    private static string RunPowerShell(string command)
    {
        return RunProcess("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -Command " + CmdQuote(command));
    }

    private static string RunProcess(string fileName, string arguments)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        process.Start();
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? output : error);
        }

        return output.Trim();
    }

    private static void ValidateProfile(NetworkProfile profile)
    {
        ValidateIPv4(profile.IpAddress, "IP address");
        ValidateIPv4(profile.SubnetMask, "subnet mask");
        ValidateIPv4(profile.Gateway, "gateway");

        foreach (var dnsServer in profile.DnsServers)
        {
            ValidateIPv4(dnsServer, "DNS server");
        }
    }

    private static void ValidateInterface(string interfaceName)
    {
        if (string.IsNullOrWhiteSpace(interfaceName))
        {
            throw new InvalidOperationException("Network interface name is required.");
        }
    }

    private static void ValidateIPv4(string value, string fieldName)
    {
        if (!IPAddress.TryParse(value, out var address) || address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            throw new InvalidOperationException($"Invalid {fieldName}: {value}");
        }
    }

    private static string CmdQuote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static string EscapePowerShell(string value)
    {
        return value.Replace("'", "''");
    }

    private static string? ReadString(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var property) || property.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return null;
        }

        return property.GetString();
    }

    private static int ReadInt(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var property) || property.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return 24;
        }

        return property.GetInt32();
    }

    private static List<string> ReadStringArray(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var property))
        {
            return [];
        }

        if (property.ValueKind == JsonValueKind.String)
        {
            var value = property.GetString();
            return string.IsNullOrWhiteSpace(value) ? [] : [value];
        }

        if (property.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return property.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString())
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value!)
            .ToList();
    }

    private static string PrefixLengthToMask(int prefixLength)
    {
        if (prefixLength <= 0 || prefixLength > 32)
        {
            return "-";
        }

        var mask = uint.MaxValue << (32 - prefixLength);
        return string.Join(".", [
            (mask >> 24) & 255,
            (mask >> 16) & 255,
            (mask >> 8) & 255,
            mask & 255
        ]);
    }
}

internal sealed class ProfileStore
{
    private readonly string _filePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SwitchNet",
        "profiles.windows.json"
    );

    public List<NetworkProfile> Load()
    {
        if (!File.Exists(_filePath))
        {
            return
            [
                new NetworkProfile
                {
                    Name = "Office Static",
                    InterfaceName = "Wi-Fi",
                    IpAddress = "192.168.1.88",
                    SubnetMask = "255.255.255.0",
                    Gateway = "192.168.1.1",
                    DnsServers = ["223.5.5.5", "8.8.8.8"]
                }
            ];
        }

        try
        {
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize<List<NetworkProfile>>(json) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void Save(List<NetworkProfile> profiles)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_filePath)!);
        var json = JsonSerializer.Serialize(profiles, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(_filePath, json);
    }
}

internal sealed class NetworkProfile
{
    public string Name { get; set; } = "";
    public string InterfaceName { get; set; } = "Wi-Fi";
    public string IpAddress { get; set; } = "";
    public string SubnetMask { get; set; } = "";
    public string Gateway { get; set; } = "";
    public List<string> DnsServers { get; set; } = [];
    public string BoundSSID { get; set; } = "";
}

internal sealed record NetworkSnapshot(
    string InterfaceName,
    string Ssid,
    string IpAddress,
    string SubnetMask,
    string Gateway,
    List<string> DnsServers,
    string? Message)
{
    public static NetworkSnapshot Empty { get; } = new(
        InterfaceName: "Wi-Fi",
        Ssid: "Unknown",
        IpAddress: "-",
        SubnetMask: "-",
        Gateway: "-",
        DnsServers: [],
        Message: null
    );
}
