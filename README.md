# OpenVPN Manager

A modern PySide2/QML application for managing OpenVPN configurations with a beautiful dark theme interface.

## Features

- ✅ Add single OpenVPN config files or entire folders
- ✅ **Automatic DNS leak prevention** - Configs are automatically enhanced with DNS leak protection
- ✅ **Password authentication** - Secure password prompts for adding configs and connecting
- ✅ Ping all VPN servers to test connectivity and latency
- ✅ Automatically identify the best server (lowest latency)
- ✅ Connect/disconnect system-wide VPN connections
- ✅ Modern dark theme UI
- ✅ Real-time connection status monitoring
- ✅ Config management (add, remove)

## Requirements

- Python 3.6+
- PySide2
- OpenVPN installed on your system
- sudo/root privileges for system-wide VPN connections

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Make sure OpenVPN is installed:
```bash
# Ubuntu/Debian
sudo apt-get install openvpn

# Arch Linux
sudo pacman -S openvpn

# Fedora
sudo dnf install openvpn
```

3. Run the application:
```bash
python main.py
```

## Usage

1. **Add Config Files**: 
   - Click "Add Config File" to add a single `.ovpn` file, or "Add Config Folder" to add all `.ovpn` files from a directory.
   - You'll be prompted for your password to securely add and configure the files.
   - **DNS leak prevention settings are automatically injected** into all config files.

2. **Ping Servers**: Click "Ping All Servers" to test connectivity and latency for all configured VPN servers. The best server (lowest latency) will be highlighted.

3. **Connect**: 
   - Click "Connect" on any server to establish a system-wide VPN connection.
   - You'll be prompted for your password to authenticate the connection.
   - The app uses your password securely for sudo operations.

4. **Disconnect**: Click "Disconnect" to terminate the VPN connection.

## DNS Leak Prevention

The application automatically injects DNS leak prevention settings into all OpenVPN config files:

- Automatically detects and uses `/etc/openvpn/update-resolv-conf` or `/etc/openvpn/update-systemd-resolved`
- Adds `script-security 2` and DNS update scripts
- Includes IPv6 disable recommendations

**To fully prevent DNS leaks:**

1. Install openresolv (recommended):
   ```bash
   sudo apt install openresolv
   ```

2. Or ensure systemd-resolved is available (usually pre-installed on modern Linux)

3. Disable IPv6 (optional but recommended):
   ```bash
   sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
   sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
   ```

4. Test for leaks at:
   - https://ipleak.net
   - https://dnsleaktest.com
   - https://browserleaks.com

## Configuration Storage

Config files are stored in `~/.vpn_manager/configs/`. The application automatically loads all `.ovpn` files from this directory on startup.

## Permissions

The application requires sudo privileges to manage system-wide OpenVPN connections. You may want to configure passwordless sudo for the `openvpn` and `pkill` commands, or run the application with appropriate privileges.

## Troubleshooting

- **Connection fails**: Make sure OpenVPN is installed and you have sudo privileges
- **Ping fails**: Some servers may block ICMP ping. This doesn't necessarily mean the VPN won't work.
- **Configs not loading**: Check that your `.ovpn` files are valid OpenVPN configuration files

## License

MIT License - feel free to use and modify as needed.
