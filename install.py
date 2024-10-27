import subprocess
import os
import sys

def run_command(command):
    """Run a system command and handle errors."""
    try:
        subprocess.run(command, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        sys.exit(1)

def install_service(service_name, service_file):
    """Install and enable a systemd service."""
    print(f"Installing {service_name} service...")
    run_command(f"cp -r {service_file} /etc/systemd/system/{service_name}")
    run_command(f"systemctl enable {service_name}")
    run_command(f"systemctl start {service_name}")
    print(f"{service_name} service installed and started.")

def extract_zip(zip_file, dest_dir):
    """Extract a zip file."""
    print(f"Extracting {zip_file} to {dest_dir}...")
    os.makedirs(dest_dir, exist_ok=True)
    run_command(f"unzip -o {zip_file} -d {dest_dir}")
    print("Extraction complete.")

def move_to_usr_bin(file):
    """Move a file to /usr/bin."""
    print(f"Moving {file} to /usr/bin...")
    run_command(f"mv {file} /usr/bin/")
    print(f"{file} moved to /usr/bin.")

def create_key_file(file, content):
    """Create a key file with the given content."""
    print(f"Creating {file}...")
    with open(file, 'w') as f:
        f.write(content)
    print(f"{file} created.")

# Ensure the script is run as root
if os.geteuid() != 0:
    print("This script must be run as root")
    sys.exit(1)

# Define paths
WS_SERVICE = "websocket/ws.service"
SOCKS_SERVICE = "websocket/socks.service"
PLUGIN_ZIP = "plugin.zip"
PLUGIN_DEST = "/usr/bin/dnstt-server"
SLOWDNS_ZIP = "slowdns.zip"
SLOWDNS_DEST = "/etc/slowdns"
SLOWDNS_SERVICE = "slowdns/slowdns.service"
CLIENT_SERVICE = "slowdns/client.service"

# Main installation process
print("Starting installation process...")

# Install WebSocket and SOCKS services
install_service("ws.service", WS_SERVICE)
install_service("socks.service", SOCKS_SERVICE)

# Extract plugin.zip and slowdns.zip
extract_zip(PLUGIN_ZIP, PLUGIN_DEST)
extract_zip(SLOWDNS_ZIP, SLOWDNS_DEST)

# Install slowdns service and client service
install_service("slowdns.service", SLOWDNS_SERVICE)
install_service("client.service", CLIENT_SERVICE)

# Move tun.conf and ws to /usr/bin
move_to_usr_bin("tun.conf")
move_to_usr_bin("ws")

# Create ws.py script in /usr/bin
ws_script = """#!/usr/bin/python3.7

class WebSocketServer:
    def __init__(self):
        self.config = "/usr/bin/tun.conf"

    def start(self):
        print("Starting WebSocket server with config:", self.config)

if __name__ == "__main__":
    server = WebSocketServer()
    server.start()
"""
with open("/usr/bin/ws.py", 'w') as f:
    f.write(ws_script)
run_command("chmod +x /usr/bin/ws.py")

# Create systemd service file for ws
with open("/etc/systemd/system/ws.service", 'w') as f:
    f.write("""[Unit]
Description=WebSocket Service

[Service]
ExecStart=/usr/bin/ws -f /usr/bin/tun.conf
Restart=always

[Install]
WantedBy=multi-user.target
""")

# Reload systemd and enable the ws service
run_command("systemctl daemon-reload")
run_command("systemctl enable ws.service")
run_command("systemctl start ws.service")
print("WebSocket service installed and started.")

# Create the /etc/slowdns directory if it doesn't exist
os.makedirs("/etc/slowdns", exist_ok=True)

# Move dnstt-server and dnstt-client to /etc/slowdns
move_to_usr_bin("dnstt-server")
move_to_usr_bin("dnstt-client")

# Create server.key and server.pub
create_key_file("/etc/slowdns/server.key", "YOUR_PRIVATE_KEY_CONTENT")
create_key_file("/etc/slowdns/server.pub", "YOUR_PUBLIC_KEY_CONTENT")

# Create systemd service file for dnstt-server
with open("/etc/systemd/system/dnstt-server.service", 'w') as f:
    f.write("""[Unit]
Description=DNS Tunnel Server

[Service]
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key xxxx 127.0.0.1:443
Restart=always

[Install]
WantedBy=multi-user.target
""")

# Create systemd service file for dnstt-client
with open("/etc/systemd/system/dnstt-client.service", 'w') as f:
    f.write("""[Unit]
Description=DNS Tunnel Client

[Service]
ExecStart=/etc/slowdns/dnstt-client -udp 174.138.21.128:53 --pubkey-file /etc/slowdns/server.pub xxxx 127.0.0.1:88
Restart=always

[Install]
WantedBy=multi-user.target
""")

# Reload systemd and enable the services
run_command("systemctl daemon-reload")
run_command("systemctl enable dnstt-server.service")
run_command("systemctl enable dnstt-client.service")
run_command("systemctl start dnstt-server.service")
run_command("systemctl start dnstt-client.service")

print("DNS Tunnel services installed and started.")

# Create certificate files in /etc/ssl if they don't exist
os.makedirs("/etc/ssl/certs", exist_ok=True)

# Create cert.key and cert.pem files in /etc/ssl/certs directory
create_key_file("/etc/ssl/certs/cert.key", "YOUR_PRIVATE_KEY_CONTENT")
create_key_file("/etc/ssl/certs/cert.pem", "YOUR_CERTIFICATE_CONTENT")

print("Certificate files created.")
print("Installation complete.")
