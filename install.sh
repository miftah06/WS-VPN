#!/bin/bash

set -e

# Function to prompt for domain input
get_domain() {
    read -p "Enter your domain: " domain
    echo "$domain"
}

# Function to register account and install acme.sh, then generate certificates
install_acme() {
    local domain="$1"
    local email="$2"

    echo "Installing acme.sh..."
    curl https://get.acme.sh | sh

    echo "Registering account with ZeroSSL..."
    ~/.acme.sh/acme.sh --register-account -m "$email"

    echo "Generating certificates for $domain..."
    ~/.acme.sh/acme.sh --issue --standalone -d "$domain"
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --key-file /etc/ssl/cert.key \
        --fullchain-file /etc/ssl/cert.pem
    echo "Certificates generated and installed for $domain."
}

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

# Function to move files to a destination
move_to_dest() {
    local file="$1"
    local dest="$2"

    echo "Moving $file to $dest..."
    mv "$file" "$dest"
    echo "$file moved to $dest."
}

# Function to create a Python script
create_python_script() {
    local file="$1"
    local content="$2"

    echo "Creating $file..."
    echo "$content" > "$file"
    chmod +x "$file"
    echo "$file created."
}

# Function to create a service file
create_service_file() {
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

# Prompt for domain and email input
domain=$(get_domain)
read -p "Enter your email for ZeroSSL account registration: " email

# Create necessary directories
mkdir -p /etc/ssl
mkdir -p /etc/slowdns

# Install acme.sh and generate certificates
install_acme "$domain" "$email"

# Move dnstt-server and dnstt-client to /etc/slowdns
move_to_dest "dnstt-server" "/etc/slowdns/"
move_to_dest "dnstt-client" "/etc/slowdns/"

# Create server.key and server.pub
create_python_script "/etc/slowdns/server.key" "YOUR_PRIVATE_KEY_CONTENT"
create_python_script "/etc/slowdns/server.pub" "YOUR_PUBLIC_KEY_CONTENT"

# Create systemd service file for dnstt-server
create_service_file "/etc/systemd/system/dnstt-server.service" "
[Unit]
Description=DNS Tunnel Server

[Service]
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key xxxx 127.0.0.1:443
Restart=always

[Install]
WantedBy=multi-user.target
"

# Create systemd service file for dnstt-client
create_service_file "/etc/systemd/system/dnstt-client.service" "
[Unit]
Description=DNS Tunnel Client

[Service]
ExecStart=/etc/slowdns/dnstt-client -udp 174.138.21.128:53 --pubkey-file /etc/slowdns/server.pub xxxx 127.0.0.1:88
Restart=always

[Install]
WantedBy=multi-user.target
"

# Create the wss.py script
create_python_script "/usr/bin/wss.py" "
import ssl
import websockets
import threading

def rancang(websocket, path):
    for message in websocket:
        websocket.send(f\"Echo: {message}\")

def main():
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(certfile='/etc/ssl/cert.pem', keyfile='/etc/ssl/cert.key')

    start_server = websockets.serve(rancang, 'localhost', 443, ssl=ssl_context)
    
    threading.Thread(target=start_server).start()
    print('WebSocket Secure Server started on wss://localhost:443')

if __name__ == '__main__':
    main()
"

# Create systemd service file for wss
create_service_file "/etc/systemd/system/wss.service" "
[Unit]
Description=WebSocket Secure Service

[Service]
ExecStart=/usr/bin/python -O /usr/bin/wss.py
Restart=always

[Install]
WantedBy=multi-user.target
"

# Reload systemd and enable the services
systemctl daemon-reload
systemctl enable dnstt-server.service
systemctl enable dnstt-client.service
systemctl enable wss.service
systemctl start dnstt-server.service
systemctl start dnstt-client.service
systemctl start wss.service

echo "DNS Tunnel and WebSocket Secure services installed and started."
