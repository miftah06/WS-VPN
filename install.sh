#!/bin/bash

set -e

# Function to install and enable a service
install_service() {
    local service_name="$1"
    local service_file="$2"

    echo "Installing $service_name service..."
    cp "$service_file" "/etc/systemd/system/$service_name"
    systemctl enable "$service_name"
    systemctl start "$service_name"
    echo "$service_name service installed and started."
}

# Function to extract a zip file
extract_zip() {
    local zip_file="$1"
    local dest_dir="$2"

    echo "Extracting $zip_file to $dest_dir..."
    mkdir -p "$dest_dir"
    unzip -o "$zip_file" -d "$dest_dir"
    echo "Extraction complete."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Define paths
WS_SERVICE="websocket/ws.service"
SOCKS_SERVICE="websocket/socks.service"
PLUGIN_ZIP="plugin.zip"
PLUGIN_DEST="/usr/bin/dnstt-server"
SLOWDNS_ZIP="slowdns.zip"
SLOWDNS_DEST="/etc/slowdns"
SLOWDNS_SERVICE="slowdns/slowdns.service"
CLIENT_SERVICE="slowdns/client.service"
CERT_PATH="cert.pem"
KEY_PATH="cert.key"

# Main installation process
echo "Starting installation process..."

# Install WebSocket and SOCKS services
install_service "ws.service" "$WS_SERVICE"
install_service "socks.service" "$SOCKS_SERVICE"

# Extract plugin.zip to /etc/dnstt-server
extract_zip "$PLUGIN_ZIP" "$PLUGIN_DEST"

# Extract slowdns.zip to /etc/slowdns
extract_zip "$SLOWDNS_ZIP" "$SLOWDNS_DEST"

# Install slowdns service and client service
install_service "slowdns.service" "$SLOWDNS_SERVICE"
install_service "client.service" "$CLIENT_SERVICE"

#!/bin/bash

set -e

# Function to move files to /usr/bin
move_to_usr_bin() {
    local file="$1"

    echo "Moving $file to /usr/bin..."
    mv "$file" /usr/bin/
    echo "$file moved to /usr/bin."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Move tun.conf and ws to /usr/bin
move_to_usr_bin "tun.conf"
move_to_usr_bin "ws"

# Create ws.py script in /usr/bin
cat << 'EOF' > /usr/bin/ws.py
#!/usr/bin/python -O

class WebSocketServer:
    def __init__(self):
        self.config = "/usr/bin/tun.conf"

    def start(self):
        # Placeholder for starting the WebSocket server
        print("Starting WebSocket server with config:", self.config)

if __name__ == "__main__":
    server = WebSocketServer()
    server.start()
EOF

# Make ws.py executable
chmod +x /usr/bin/ws.py

# Create systemd service file for ws
cat << 'EOF' > /etc/systemd/system/ws.service
[Unit]
Description=WebSocket Service

[Service]
ExecStart=/usr/bin/ws -f /usr/bin/tun.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the ws service
systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service

echo "WebSocket service installed and started."

#!/bin/bash

set -e

# Function to move files to /etc/slowdns
move_to_slowdns() {
    local file="$1"

    echo "Moving $file to /etc/slowdns..."
    mv "$file" /etc/slowdns/
    echo "$file moved to /etc/slowdns."
}

# Function to create key files
create_key_file() {
    local file="$1"
    local content="$2"

    echo "Creating $file..."
    echo "$content" > "$file"
    echo "$file created."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Create the /etc/slowdns directory if it doesn't exist
mkdir -p /etc/slowdns

# Move dnstt-server and dnstt-client to /etc/slowdns
move_to_slowdns "dnstt-server"
move_to_slowdns "dnstt-client"

# Create server.key and server.pub
create_key_file "/etc/slowdns/server.key" "YOUR_PRIVATE_KEY_CONTENT"
create_key_file "/etc/slowdns/server.pub" "YOUR_PUBLIC_KEY_CONTENT"

# Create systemd service file for dnstt-server
cat << 'EOF' > /etc/systemd/system/dnstt-server.service
[Unit]
Description=DNS Tunnel Server

[Service]
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key xxxx 127.0.0.1:443
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for dnstt-client
cat << 'EOF' > /etc/systemd/system/dnstt-client.service
[Unit]
Description=DNS Tunnel Client

[Service]
ExecStart=/etc/slowdns/dnstt-client -udp 174.138.21.128:53 --pubkey-file /etc/slowdns/server.pub xxxx 127.0.0.1:88
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the services
systemctl daemon-reload
systemctl enable dnstt-server.service
systemctl enable dnstt-client.service
systemctl start dnstt-server.service
systemctl start dnstt-client.service

echo "DNS Tunnel services installed and started."

#!/bin/bash

set -e

# Function to create certificate files
create_cert_file() {
    local file="$1"
    local content="$2"

    echo "Creating $file..."
    echo "$content" > "$file"
    echo "$file created."
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Create the /etc/ssl directory if it doesn't exist
mkdir -p /etc/ssl

# Create cert.key and cert.pem
create_cert_file "/etc/ssl/cert.key" "YOUR_PRIVATE_KEY_CONTENT"
create_cert_file "/etc/ssl/cert.pem" "YOUR_CERTIFICATE_CONTENT"

echo "Certificate files created."

#!/bin/bash

set -e

# Function to prompt for domain input
get_domain() {
    read -p "Enter your domain: " domain
    echo "$domain"
}

# Function to install acme.sh and generate certificates
install_acme() {
    local domain="$1"
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --issue --standalone -d "$domain"
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file /etc/ssl/cert.key \
        --fullchain-file /etc/ssl/cert.pem
    echo "Certificates generated and installed for $domain."
}

# Function to create wss.service file
create_service_file() {
    local file="$1"

    echo "Creating $file..."
    cat << 'EOF' > "$file"
[Unit]
Description=WebSocket Secure Service

[Service]
ExecStart=/usr/bin/python -O /usr/bin/wss.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    echo "$file created."
}

# Function to create wss.py script
create_wss_script() {
    local file="$1"

    echo "Creating $file..."
    cat << 'EOF' > "$file"
import ssl
import websockets
import threading

def rancang(websocket, path):
    for message in websocket:
        websocket.send(f"Echo: {message}")

def main():
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(certfile='/etc/ssl/cert.pem', keyfile='/etc/ssl/cert.key')

    start_server = websockets.serve('localhost', 443, ssl=ssl_context)
    
    threading.Thread(target=start_server).start()
    print("WebSocket Secure Server started on wss://localhost:443")

if __name__ == "__main__":
    main()
EOF
    echo "$file created."
    chmod +x "$file"
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Create the /etc/ssl directory if it doesn't exist
mkdir -p /etc/ssl

# Get domain input from user
domain=$(get_domain)

# Install acme.sh and generate certificates
install_acme "$domain"

# Create wss.service file
create_service_file "/etc/systemd/system/wss.service"

# Create wss.py script
create_wss_script "/usr/bin/wss.py"

# Reload systemd and enable the service
systemctl daemon-reload
systemctl enable wss.service
systemctl start wss.service

echo "WebSocket Secure service installed and started."

# Copy certificates
echo "Copying certificates..."
mkdir -p /etc/ssl/certs
cp "$CERT_PATH" "/etc/ssl/certs/cert.pem"
cp "$KEY_PATH" "/etc/ssl/certs/cert.key"
echo "Certificates copied."

echo "Installation complete."
