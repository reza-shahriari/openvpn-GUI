"""
VPN Manager Backend - Handles OpenVPN configuration management and connections
"""
import os
import re
import subprocess
import threading
import time
import shutil
from pathlib import Path
from typing import List, Dict, Optional
from PySide2.QtCore import QObject, Signal, Property, QThread, Slot, QTimer
from PySide2.QtWidgets import QFileDialog, QApplication


class PingWorker(QThread):
    """Worker thread for pinging VPN servers"""
    ping_result = Signal(str, float, bool)  # config_name, latency, success
    
    def __init__(self, configs: List[Dict]):
        super().__init__()
        self.configs = configs
        self.should_stop = False
    
    def run(self):
        for config in self.configs:
            if self.should_stop:
                break
            
            config_path = config['path']
            server = self._extract_server(config_path)
            
            if server:
                latency = self._ping_server(server)
                self.ping_result.emit(config['name'], latency, latency > 0)
            else:
                self.ping_result.emit(config['name'], -1, False)
    
    def _extract_server(self, config_path: str) -> Optional[str]:
        """Extract server address from OpenVPN config file"""
        try:
            with open(config_path, 'r') as f:
                content = f.read()
                
            # Try to find remote server
            remote_match = re.search(r'remote\s+([^\s]+)', content, re.IGNORECASE)
            if remote_match:
                return remote_match.group(1)
            
            # Try to find server directive
            server_match = re.search(r'server\s+([^\s]+)', content, re.IGNORECASE)
            if server_match:
                return server_match.group(1)
                
        except Exception as e:
            print(f"Error reading config: {e}")
        
        return None
    
    def _ping_server(self, server: str) -> float:
        """Ping a server and return latency in ms, or -1 if failed"""
        try:
            # Remove port if present
            server = server.split(':')[0]
            
            # Ping with 1 packet, timeout 2 seconds
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '2', server],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                # Extract time from ping output
                match = re.search(r'time=([\d.]+)', result.stdout)
                if match:
                    return float(match.group(1))
            
            return -1
        except Exception:
            return -1
    
    def stop(self):
        self.should_stop = True


class VPNManager(QObject):
    """Main VPN Manager class exposed to QML"""
    
    # Signals
    configs_changed = Signal()
    connection_status_changed = Signal(str)  # "connected", "disconnected", "connecting", "error"
    ping_progress = Signal(str, float, bool)  # config_name, latency, success
    ping_complete = Signal()
    error_occurred = Signal(str)
    password_requested = Signal(str)  # message
    password_cancelled = Signal()
    confirm_delete_all = Signal(int)  # number of configs
    vpn_credentials_requested = Signal(str)  # config_name or "folder" for folder addition
    vpn_credentials_cancelled = Signal()
    
    def __init__(self):
        super().__init__()
        self._configs = []
        self._connected_config = None
        self._connection_process = None
        self._ping_worker = None
        self.config_dir = os.path.expanduser("~/.vpn_manager/configs")
        os.makedirs(self.config_dir, exist_ok=True)
        self._pending_file_path = None
        self._pending_folder_path = None
        self._pending_connect_config = None
        self._stored_password = None
        self._pending_vpn_username = None
        self._pending_vpn_password = None
        self._pending_config_for_credentials = None  # Store config path(s) waiting for VPN credentials
        self._load_configs()
    
    @Property(list, notify=configs_changed)
    def configs(self):
        return self._configs
    
    @Property(str, notify=connection_status_changed)
    def connection_status(self):
        if self._connection_process and self._connection_process.poll() is None:
            return "connected" if self._connected_config else "connecting"
        return "disconnected"
    
    @Property(str, notify=connection_status_changed)
    def connected_config_name(self):
        return self._connected_config['name'] if self._connected_config else ""
    
    def _load_configs(self):
        """Load all .ovpn config files from the config directory"""
        self._configs = []
        
        if not os.path.exists(self.config_dir):
            return
        
        for file_path in Path(self.config_dir).rglob("*.ovpn"):
            config_name = file_path.stem
            self._configs.append({
                'name': config_name,
                'path': str(file_path),
                'latency': -1,
                'ping_success': False
            })
        
        self.configs_changed.emit()
    
    def _inject_dns_leak_prevention(self, config_path: str):
        """Inject DNS leak prevention settings into OpenVPN config file"""
        try:
            with open(config_path, 'r') as f:
                content = f.read()
            
            # Check if DNS settings already exist
            if 'update-resolv-conf' in content or 'update-systemd-resolved' in content:
                return  # Already configured
            
            # Determine which DNS update method to use
            dns_script = None
            if os.path.exists('/etc/openvpn/update-resolv-conf'):
                dns_script = '/etc/openvpn/update-resolv-conf'
            elif os.path.exists('/etc/openvpn/update-systemd-resolved'):
                dns_script = '/etc/openvpn/update-systemd-resolved'
            
            # Add DNS leak prevention settings
            dns_settings = [
                '',
                '# DNS Leak Prevention (added by VPN Manager)',
                'script-security 2'
            ]
            
            if dns_script:
                dns_settings.extend([
                    f'up {dns_script}',
                    f'down {dns_script}',
                    'down-pre'
                ])
            else:
                # Fallback: block DNS leaks manually
                dns_settings.extend([
                    '# Note: Install openresolv for automatic DNS handling:',
                    '# sudo apt install openresolv',
                    '# Or use systemd-resolved if available'
                ])
            
            # Add IPv6 disable recommendation
            dns_settings.extend([
                '',
                '# Disable IPv6 to prevent leaks (run manually if needed):',
                '# sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1',
                '# sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1'
            ])
            
            # Append to config file
            with open(config_path, 'a') as f:
                f.write('\n' + '\n'.join(dns_settings) + '\n')
                
        except Exception as e:
            print(f"Warning: Could not inject DNS settings: {e}")
    
    @Slot()
    def show_file_dialog(self):
        """Show file dialog to select a config file and then request VPN credentials"""
        file_path, _ = QFileDialog.getOpenFileName(
            None,
            "Select OpenVPN Config File",
            "",
            "OpenVPN Config (*.ovpn);;All Files (*)"
        )
        if file_path:
            # Directly request VPN credentials for this config (no sudo password needed to copy files)
            self._pending_config_for_credentials = file_path
            config_name = Path(file_path).stem
            # Use QTimer so the file dialog can fully close before showing the credentials dialog
            QTimer.singleShot(100, lambda: self.vpn_credentials_requested.emit(config_name))
    
    @Slot()
    def show_folder_dialog(self):
        """Show folder dialog to select a folder with configs and then request VPN credentials"""
        folder_path = QFileDialog.getExistingDirectory(
            None,
            "Select Folder with OpenVPN Configs"
        )
        if folder_path:
            # Directly request VPN credentials for all configs in this folder
            self._pending_config_for_credentials = folder_path
            QTimer.singleShot(100, lambda: self.vpn_credentials_requested.emit("folder"))
    
    @Slot(str)
    def provide_password(self, password: str):
        """Handle sudo password input from QML"""
        # Currently we only need sudo password for connecting/disconnecting VPN,
        # not for adding config files (those are handled by vpn_credentials_requested).
        if self._pending_connect_config:
            self._connect_vpn_with_password(password)
    
    @Slot(str, str)
    def provide_vpn_credentials(self, username: str, password: str):
        """Handle VPN username/password input from QML"""
        if not username or not password:
            self.error_occurred.emit("Username and password are required")
            return
        
        self._pending_vpn_username = username
        self._pending_vpn_password = password
        
        if self._pending_config_for_credentials:
            if isinstance(self._pending_config_for_credentials, str):
                if os.path.isfile(self._pending_config_for_credentials):
                    # Single file
                    self._add_config_file_with_credentials(self._pending_config_for_credentials, username, password)
                else:
                    # Folder
                    self._add_config_folder_with_credentials(self._pending_config_for_credentials, username, password)
            
            self._pending_config_for_credentials = None
            self._pending_vpn_username = None
            self._pending_vpn_password = None
    
    @Slot()
    def cancel_password(self):
        """Cancel password input"""
        self._pending_file_path = None
        self._pending_folder_path = None
        self._pending_connect_config = None
        self.password_cancelled.emit()
    
    @Slot()
    def cancel_vpn_credentials(self):
        """Cancel VPN credentials input"""
        self._pending_config_for_credentials = None
        self._pending_vpn_username = None
        self._pending_vpn_password = None
        self.vpn_credentials_cancelled.emit()
    
    def _create_auth_file(self, config_path: str, username: str, password: str) -> str:
        """Create an auth file for OpenVPN credentials"""
        auth_dir = os.path.join(os.path.dirname(config_path), 'auth')
        os.makedirs(auth_dir, exist_ok=True)
        
        config_name = Path(config_path).stem
        auth_file = os.path.join(auth_dir, f"{config_name}.auth")
        
        # Write username and password to auth file (first line username, second line password)
        with open(auth_file, 'w') as f:
            f.write(f"{username}\n{password}\n")
        
        # Set restrictive permissions (readable only by owner)
        os.chmod(auth_file, 0o600)
        
        return auth_file
    
    def _inject_auth_credentials(self, config_path: str, auth_file: str):
        """Inject auth-user-pass directive into OpenVPN config"""
        try:
            with open(config_path, 'r') as f:
                content = f.read()
            
            # Check if auth-user-pass already exists
            if re.search(r'auth-user-pass', content, re.IGNORECASE):
                # Replace existing auth-user-pass line
                content = re.sub(
                    r'auth-user-pass\s+[^\n]*',
                    f'auth-user-pass {auth_file}',
                    content,
                    flags=re.IGNORECASE
                )
            else:
                # Add auth-user-pass directive
                content += f'\n# VPN Credentials (added by VPN Manager)\nauth-user-pass {auth_file}\n'
            
            with open(config_path, 'w') as f:
                f.write(content)
                
        except Exception as e:
            print(f"Warning: Could not inject auth credentials: {e}")
    
    def _add_config_file_with_credentials(self, file_path: str, username: str, password: str):
        """Add a single OpenVPN config file with VPN credentials"""
        try:
            if not os.path.exists(file_path):
                self.error_occurred.emit(f"File not found: {file_path}")
                return
            
            if not file_path.endswith('.ovpn'):
                self.error_occurred.emit("File must be a .ovpn file")
                return
            
            # Copy to config directory
            filename = os.path.basename(file_path)
            dest_path = os.path.join(self.config_dir, filename)
            
            shutil.copy2(file_path, dest_path)
            
            # Create auth file
            auth_file = self._create_auth_file(dest_path, username, password)
            
            # Inject auth credentials
            self._inject_auth_credentials(dest_path, auth_file)
            
            # Inject DNS leak prevention settings
            self._inject_dns_leak_prevention(dest_path)
            
            # Add to configs list
            config_name = Path(filename).stem
            self._configs.append({
                'name': config_name,
                'path': dest_path,
                'latency': -1,
                'ping_success': False
            })
            
            self.configs_changed.emit()
            
        except Exception as e:
            self.error_occurred.emit(f"Error adding config: {str(e)}")
    
    def _add_config_folder_with_credentials(self, folder_path: str, username: str, password: str):
        """Add all .ovpn files from a folder with VPN username/password authentication"""
        try:
            if not os.path.exists(folder_path):
                self.error_occurred.emit(f"Folder not found: {folder_path}")
                return
            
            added_count = 0
            for file_path in Path(folder_path).rglob("*.ovpn"):
                filename = os.path.basename(file_path)
                dest_path = os.path.join(self.config_dir, filename)
                
                # Skip if already exists
                if os.path.exists(dest_path):
                    continue
                
                shutil.copy2(file_path, dest_path)

                # Create auth file for this config
                auth_file = self._create_auth_file(dest_path, username, password)

                # Inject auth credentials
                self._inject_auth_credentials(dest_path, auth_file)

                # Inject DNS leak prevention settings
                self._inject_dns_leak_prevention(dest_path)

                config_name = Path(filename).stem
                self._configs.append({
                    'name': config_name,
                    'path': dest_path,
                    'latency': -1,
                    'ping_success': False
                })
                added_count += 1
            
            if added_count > 0:
                self.configs_changed.emit()
            else:
                self.error_occurred.emit("No new .ovpn files found in folder")
                
        except Exception as e:
            self.error_occurred.emit(f"Error adding folder: {str(e)}")
    
    @Slot()
    def ping_all(self):
        """Ping all VPN servers"""
        if self._ping_worker and self._ping_worker.isRunning():
            return
        
        # Reset latencies
        for config in self._configs:
            config['latency'] = -1
            config['ping_success'] = False
        
        self._ping_worker = PingWorker(self._configs)
        self._ping_worker.ping_result.connect(self._on_ping_result)
        self._ping_worker.finished.connect(self.ping_complete.emit)
        self._ping_worker.start()
    
    def _on_ping_result(self, config_name: str, latency: float, success: bool):
        """Handle ping result for a config"""
        for config in self._configs:
            if config['name'] == config_name:
                config['latency'] = latency
                config['ping_success'] = success
                break
        
        self.ping_progress.emit(config_name, latency, success)
        self.configs_changed.emit()
    
    @Slot(str)
    def connect_vpn(self, config_name: str):
        """Request password and connect to a VPN using the specified config"""
        if self._connection_process and self._connection_process.poll() is None:
            self.error_occurred.emit("Already connected. Please disconnect first.")
            return
        
        # Find the config
        config = None
        for c in self._configs:
            if c['name'] == config_name:
                config = c
                break
        
        if not config:
            self.error_occurred.emit(f"Config not found: {config_name}")
            return
        
        self._pending_connect_config = config
        self.password_requested.emit("Enter your password to connect to VPN")
    
    def _connect_vpn_with_password(self, password: str):
        """Connect to VPN with password"""
        if not self._pending_connect_config:
            return
        
        config = self._pending_connect_config
        self._pending_connect_config = None
        
        try:
            self.connection_status_changed.emit("connecting")
            
            # Use sudo with password via stdin
            # Note: This requires sudo/root privileges for system-wide connection
            sudo_process = subprocess.Popen(
                ['sudo', '-S', 'openvpn', '--config', config['path'], '--daemon'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Send password
            sudo_process.stdin.write(password + '\n')
            sudo_process.stdin.flush()
            sudo_process.stdin.close()
            
            # Wait for sudo to process
            return_code = sudo_process.wait(timeout=5)
            
            if return_code == 0:
                # Wait a moment for OpenVPN to start
                time.sleep(2)
                
                # Check if OpenVPN is running
                result = subprocess.run(['pgrep', '-f', 'openvpn'], capture_output=True)
                if result.returncode == 0:
                    self._connected_config = config
                    self._stored_password = password  # Store for disconnect
                    self.connection_status_changed.emit("connected")
                else:
                    self.error_occurred.emit("Failed to start OpenVPN. Check if OpenVPN is installed and config is valid.")
                    self.connection_status_changed.emit("error")
            else:
                stderr = sudo_process.stderr.read() if sudo_process.stderr else ""
                error_msg = "Authentication failed" if "password" in stderr.lower() or return_code == 1 else "Failed to connect"
                self.error_occurred.emit(f"{error_msg}. Please check your password and OpenVPN installation.")
                self.connection_status_changed.emit("error")
                
        except subprocess.TimeoutExpired:
            self.error_occurred.emit("Connection timeout. Please try again.")
            self.connection_status_changed.emit("error")
        except Exception as e:
            self.error_occurred.emit(f"Error connecting: {str(e)}")
            self.connection_status_changed.emit("error")
    
    @Slot()
    def disconnect_vpn(self):
        """Disconnect from VPN"""
        try:
            # Kill OpenVPN processes using stored password if available
            if self._stored_password:
                sudo_process = subprocess.Popen(
                    ['sudo', '-S', 'pkill', 'openvpn'],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                sudo_process.stdin.write(self._stored_password + '\n')
                sudo_process.stdin.flush()
                sudo_process.stdin.close()
                sudo_process.wait()
            else:
                # Try without password (might work if sudo doesn't require password)
                subprocess.run(['sudo', 'pkill', 'openvpn'], check=False)
            
            if self._connection_process:
                self._connection_process.terminate()
                self._connection_process.wait()
                self._connection_process = None
            
            self._connected_config = None
            self._stored_password = None
            self.connection_status_changed.emit("disconnected")
            
        except Exception as e:
            self.error_occurred.emit(f"Error disconnecting: {str(e)}")
    
    @Slot(str)
    def remove_config(self, config_name: str):
        """Remove a config file"""
        try:
            config = None
            for c in self._configs:
                if c['name'] == config_name:
                    config = c
                    break
            
            if config:
                if os.path.exists(config['path']):
                    os.remove(config['path'])
                
                self._configs.remove(config)
                self.configs_changed.emit()
                
        except Exception as e:
            self.error_occurred.emit(f"Error removing config: {str(e)}")
    
    @Slot()
    def request_delete_all(self):
        """Request confirmation to delete all configs"""
        if len(self._configs) == 0:
            self.error_occurred.emit("No configs to delete")
            return
        
        # Disconnect if connected
        if self._connected_config:
            self.disconnect_vpn()
        
        self.confirm_delete_all.emit(len(self._configs))
    
    @Slot()
    def delete_all_configs(self):
        """Delete all config files"""
        try:
            deleted_count = 0
            for config in list(self._configs):  # Create a copy to iterate over
                try:
                    if os.path.exists(config['path']):
                        os.remove(config['path'])
                    deleted_count += 1
                except Exception as e:
                    print(f"Error deleting {config['name']}: {e}")
            
            self._configs.clear()
            self.configs_changed.emit()
            
        except Exception as e:
            self.error_occurred.emit(f"Error deleting configs: {str(e)}")
    
    @Slot(result=str)
    def get_best_server(self) -> str:
        """Get the name of the server with the lowest latency"""
        best_config = None
        best_latency = float('inf')
        
        for config in self._configs:
            if config['ping_success'] and config['latency'] > 0:
                if config['latency'] < best_latency:
                    best_latency = config['latency']
                    best_config = config
        
        return best_config['name'] if best_config else ""


