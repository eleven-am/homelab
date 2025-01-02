#!/bin/bash

# ANSI color codes
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

# Default values
CONTAINER_ID="100"
STORAGE="local-lvm"
PASSWORD="yourpassword"
TUNNEL_NAME="headscale-tunnel"
CONFIG_FILE=""
ACL_FILE=""

# Required dependencies with their package names
declare -A DEPENDENCIES=(
    ["curl"]="curl"
    ["jq"]="jq"
    ["openssl"]="openssl"
    ["pct"]="pve-container"  # Already installed on Proxmox
    ["python3"]="python3"    # Added for YAML validation
    ["python3-yaml"]="python3-yaml"  # Added for YAML validation
)

# Logging functions
log() {
    local level="$1"
    local message="$2"
    local color="$RESET"

    case "$level" in
        INFO)  color="$GREEN" ;;
        WARN)  color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        DEBUG) color="$BLUE" ;;
    esac

    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message${RESET}"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Function to extract hostname from domain
get_hostname_from_domain() {
    local domain="$1"
    echo "${domain%%.*}"
}

# Function to check if running on Proxmox
check_proxmox() {
    if [ ! -f /etc/pve/.version ]; then
        error_exit "This script must be run on a Proxmox VE host"
    fi
}

# Enhanced dependency check and installation
install_host_dependencies() {
    log "INFO" "Checking and installing host dependencies..."

    local missing_deps=()
    local to_install=()

    # Check which dependencies are missing
    for dep in "${!DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
            if [[ "${DEPENDENCIES[$dep]}" != "pve-container" ]]; then  # Skip pct as it should be there
                to_install+=("${DEPENDENCIES[$dep]}")
            fi
        fi
    done

    # If pct is missing, something is very wrong
    if ! command -v pct >/dev/null 2>&1; then
        error_exit "pct command not found. Are you running this on Proxmox VE?"
    fi

    # Install missing dependencies if any
    if [ ${#to_install[@]} -ne 0 ]; then
        log "INFO" "Installing missing dependencies: ${to_install[*]}"
        if ! DEBIAN_FRONTEND=noninteractive apt-get update && \
           DEBIAN_FRONTEND=noninteractive apt-get install -y "${to_install[@]}"; then
            error_exit "Failed to install dependencies"
        fi
    fi

    log "INFO" "All host dependencies are installed"
}

# Function to validate input parameters
validate_params() {
    local errors=()
    local dot_count=0

    # Validate required parameters
    [[ -z "$API_TOKEN" ]] && errors+=("API token is required")
    [[ -z "$DOMAIN" ]] && errors+=("Domain name is required")
    [[ -z "$ACCOUNT_ID" ]] && errors+=("Account ID is required")

    # Validate API token format
    if [[ -n "$API_TOKEN" && ! "$API_TOKEN" =~ ^[A-Za-z0-9_-]{40,}$ ]]; then
        errors+=("Invalid API token format")
    fi

    # Validate domain format - must be a subdomain
    if [[ -n "$DOMAIN" ]]; then
        dot_count=$(echo "$DOMAIN" | tr -cd '.' | wc -c)
        if [[ $dot_count -lt 2 ]]; then
            errors+=("Domain must be a subdomain (e.g., vpn.example.com)")
        elif ! [[ "$DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
            errors+=("Invalid domain format")
        fi
    fi

    # Extract and store hostname
    if [[ -n "$DOMAIN" && ${#errors[@]} -eq 0 ]]; then
        HOSTNAME=$(get_hostname_from_domain "$DOMAIN")
        if [[ -z "$HOSTNAME" ]]; then
            errors+=("Failed to extract hostname from domain")
        fi
    fi

    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ ! -f "$CONFIG_FILE" ]]; then
            errors+=("Config file does not exist: $CONFIG_FILE")
        else
            if ! python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
                errors+=("Invalid YAML format in config file: $CONFIG_FILE")
            fi
        fi
    fi

    if [[ -n "$ACL_FILE" ]]; then
        if [[ ! -f "$ACL_FILE" ]]; then
            errors+=("ACL file does not exist: $ACL_FILE")
        else
            if ! python3 -c "import yaml; yaml.safe_load(open('$ACL_FILE'))" 2>/dev/null; then
                errors+=("Invalid YAML format in ACL file: $ACL_FILE")
            fi
        fi
    fi

    # Validate Account ID format (typically hexadecimal)
    if [[ -n "$ACCOUNT_ID" ]]; then
        if ! [[ "$ACCOUNT_ID" =~ ^[0-9a-fA-F]{32}$ ]]; then
            errors+=("Invalid Account ID format. Should be 32 hexadecimal characters")
        fi
    fi

    # Validate Container ID
    if ! [[ "$CONTAINER_ID" =~ ^[1-9][0-9]{2,}$ ]]; then
        errors+=("Invalid Container ID. Should be a number >= 100")
    fi

    # Validate storage name format
    if ! [[ "$STORAGE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        errors+=("Invalid storage name. Should only contain letters, numbers, underscores, or hyphens")
    fi

    # Validate password strength
    if [[ ${#PASSWORD} -lt 8 ]]; then
        errors+=("Password must be at least 8 characters long")
    elif ! [[ "$PASSWORD" =~ [A-Z] ]]; then
        errors+=("Password must contain at least one uppercase letter")
    elif ! [[ "$PASSWORD" =~ [a-z] ]]; then
        errors+=("Password must contain at least one lowercase letter")
    elif ! [[ "$PASSWORD" =~ [0-9] ]]; then
        errors+=("Password must contain at least one number")
    fi

    # Validate tunnel name format
    if ! [[ "$TUNNEL_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$ ]]; then
        errors+=("Invalid tunnel name. Should be 1-64 characters, start with alphanumeric, and contain only letters, numbers, underscores, or hyphens")
    fi

    # Check if storage exists in Proxmox
    if ! pvesm status | grep -q "^${STORAGE}"; then
        errors+=("Storage '$STORAGE' does not exist in Proxmox")
    fi

    # Check if Container ID is already in use
    if pct list | grep -q "^${CONTAINER_ID}"; then
        errors+=("Container ID $CONTAINER_ID is already in use")
    fi

    if [ ${#errors[@]} -ne 0 ]; then
        log "ERROR" "Parameter validation failed:"
        for error in "${errors[@]}"; do
            log "ERROR" "- $error"
        done
        exit 1
    fi

    log "INFO" "All parameters validated successfully"
    log "DEBUG" "Extracted hostname: $HOSTNAME"
}

# Function to display detailed usage
show_usage() {
    cat << 'EOF'
Headscale Setup Script for Proxmox
=================================

This script sets up a Headscale VPN server in a Proxmox container with Cloudflare tunnel integration.

Required Parameters:
------------------
    -t, --api-token TOKEN    Cloudflare API token
    -d, --domain DOMAIN      Domain name (MUST be a subdomain, e.g., vpn.example.com)
    -a, --account ACCOUNT    Cloudflare account ID

Optional Parameters:
------------------
    -i, --id ID             Container ID (default: 100)
    -s, --storage NAME      Storage name (default: local-lvm)
    -p, --password PASS     Container root password (default: yourpassword)
    -n, --name NAME         Tunnel name (default: headscale-tunnel)
    -c, --config FILE       Path to Headscale config file (optional)
    -l, --acl FILE         Path to ACL policy file (optional)
    -h, --help             Display this help message

How to Get Required Data:
------------------------
1. Cloudflare API Token:
   a. Go to https://dash.cloudflare.com/profile/api-tokens
   b. Click "Create Token"
   c. Select "Create Custom Token"
   d. Grant the following permissions:
      - Zone > DNS > Edit
      - Account > Cloudflare Tunnel > Edit
      - Zone > Zone > Read

2. Domain Name:
   - Use a domain managed by Cloudflare (must be added to Cloudflare first)
   - Example: example.com

3. Account ID:
   a. Go to https://dash.cloudflare.com
   b. Select your domain
   c. On the right side under "API", find "Account ID"

Examples:
--------
Basic usage with required parameters:
    $0 -t your-api-token -d example.com -a your-account-id

Custom container setup:
    $0 -t your-api-token -d example.com -a your-account-id -i 101 -s local-zfs -p MyStr0ngPass!

Notes:
-----
- The script must be run on a Proxmox host
- Container ID must be >= 100
- Password must be at least 8 characters with uppercase, lowercase, and numbers
- Storage must exist in Proxmox
- Domain must be managed by Cloudflare
- API token must have sufficient permissions

After Setup:
-----------
The script will create:
1. A Proxmox container running Headscale
2. A Cloudflare tunnel for secure access
3. DNS records for:
   - vpn.yourdomain.com (Headscale server)
   - admin.vpn.yourdomain.com (Admin interface)

EOF
    exit 1
}

# Function to parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--api-token)
                API_TOKEN="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -a|--account)
                ACCOUNT_ID="$2"
                shift 2
                ;;
            -i|--id)
                CONTAINER_ID="$2"
                shift 2
                ;;
            -s|--storage)
                STORAGE="$2"
                shift 2
                ;;
            -p|--password)
                PASSWORD="$2"
                shift 2
                ;;
            -n|--name)
                TUNNEL_NAME="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -l|--acl)
                ACL_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

# Get zone ID
get_zone_id() {
    local zone_domain="${DOMAIN#*.}"  # Remove the subdomain part
    local response
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_domain" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    echo "$response" | jq -r '.result[0].id'
}

# Function to create or update Cloudflare tunnel
create_or_update_tunnel() {
    local existing_tunnels
    existing_tunnels=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tunnels" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    if [[ $(echo "$existing_tunnels" | jq -r '.success') != "true" ]]; then
        error_exit "Failed to fetch existing tunnels"
    fi

    # Find any existing tunnels with our name that aren't deleted
    local tunnel_ids
    tunnel_ids=$(echo "$existing_tunnels" | jq -r --arg name "$TUNNEL_NAME" \
        '.result[] | select(.name == $name and .deleted_at == null) | .id')

    # Delete any existing tunnels
    if [[ -n "$tunnel_ids" ]]; then
        while IFS= read -r tunnel_id; do
            if [[ -n "$tunnel_id" ]]; then
                curl -s -X DELETE "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tunnels/$tunnel_id" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" > /dev/null
            fi
        done <<< "$tunnel_ids"

        # Wait a moment for deletions to process
        sleep 5
    fi

    # Create a new tunnel
    local response
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tunnels" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"name\": \"$TUNNEL_NAME\",
            \"tunnel_secret\": \"$(openssl rand -hex 32)\"
        }")

    # Validate response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        error_exit "Invalid response from Cloudflare API"
    fi

    if [[ $(echo "$response" | jq -r '.success') != "true" ]]; then
        local errors
        errors=$(echo "$response" | jq -r '.errors[].message' 2>/dev/null || echo "Unknown error")
        error_exit "Failed to create tunnel: $errors"
    fi

    # Extract and validate the new tunnel's details
    local tunnel_id
    local tunnel_token
    tunnel_id=$(echo "$response" | jq -r '.result.id')
    tunnel_token=$(echo "$response" | jq -r '.result.token')

    if [[ -z "$tunnel_id" || "$tunnel_id" == "null" ]]; then
        error_exit "Failed to get valid tunnel ID from response"
    fi

    if [[ -z "$tunnel_token" || "$tunnel_token" == "null" ]]; then
        error_exit "Failed to get valid tunnel token from response"
    fi

    echo "$response"
}

# Function to create or update DNS record
create_or_update_dns_record() {
    local hostname="$1"
    local tunnel_id="$2"

    # Get the base domain (remove subdomain part)
    local zone_domain="${DOMAIN#*.}"

    # Validate tunnel ID
    if [[ ! "$tunnel_id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        error_exit "Invalid tunnel ID format: $tunnel_id"
    fi

    log "INFO" "Managing DNS record for $hostname in zone $zone_domain..."

    # First, get all DNS records for this hostname
    local existing_records
    existing_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$hostname.$zone_domain" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")

    if [[ $(echo "$existing_records" | jq -r '.success') != "true" ]]; then
        error_exit "Failed to fetch DNS records"
    fi

    # Get all record IDs for this hostname
    local record_ids
    record_ids=$(echo "$existing_records" | jq -r '.result[].id')

    # Delete all existing records
    if [[ -n "$record_ids" ]]; then
        log "INFO" "Found existing DNS records. Cleaning up..."
        while IFS= read -r record_id; do
            if [[ -n "$record_id" ]]; then
                log "INFO" "Deleting DNS record: $record_id"
                local delete_response
                delete_response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json")

                if [[ $(echo "$delete_response" | jq -r '.success') != "true" ]]; then
                    log "WARN" "Failed to delete DNS record $record_id"
                fi
            fi
        done <<< "$record_ids"

        # Wait a moment for deletions to process
        sleep 3
    fi

    # Create new CNAME record using the hostname from the input domain
    log "INFO" "Creating new CNAME record for $hostname.$zone_domain..."
    local response
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"CNAME\",
            \"name\": \"$hostname\",
            \"content\": \"${tunnel_id}.cfargotunnel.com\",
            \"proxied\": true
        }")

    # Debug output
    log "DEBUG" "DNS Creation Response: $(echo "$response" | jq -c '.')"

    # Check if the operation was successful
    if [[ $(echo "$response" | jq -r '.success') != "true" ]]; then
        local errors
        errors=$(echo "$response" | jq -r '.errors[].message' 2>/dev/null || echo "Unknown error")
        error_exit "Failed to create DNS record: $errors"
    fi

    log "INFO" "DNS record for $hostname.$zone_domain successfully created"
}

# Function to create Cloudflare tunnel
configure_tunnel_routes() {
    local tunnel_id="$1"

    log "INFO" "Configuring tunnel routes..."
    local response
    response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/tunnels/$tunnel_id/configurations" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{
            \"config\": {
                \"ingress\": [
                    {
                        \"hostname\": \"$DOMAIN\",
                        \"path\": \"/admin\",
                        \"service\": \"http://headscale-admin:80\"
                    },
                    {
                        \"hostname\": \"$DOMAIN\",
                        \"service\": \"http://headscale:8080\"
                    },
                    {
                        \"service\": \"http_status:404\"
                    }
                ]
            }
        }")
}

# Container management functions
create_container() {
    log "INFO" "Creating Proxmox container..."

    if ! pct create "$CONTAINER_ID" "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst" \
        --hostname headscale \
        --password "$PASSWORD" \
        --rootfs "$STORAGE:2" \
        --memory 2048 \
        --swap 512 \
        --cores 2 \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --unprivileged 1 \
        --features nesting=1; then
        error_exit "Failed to create Proxmox container"
    fi
}

# Function to create Cloudflare tunnel
setup_container() {
    log "INFO" "Setting up container..."

    # Start container
    pct start "$CONTAINER_ID" || error_exit "Failed to start container"
    sleep 10  # Wait for container to initialize

    # Install dependencies
    pct exec "$CONTAINER_ID" -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get upgrade -y
        apt-get install -y \
            curl \
            docker.io \
            docker-compose \
            snapd \
            git \
            wget \
            gnupg2 \
            apt-transport-https \
            ca-certificates \
            software-properties-common

        systemctl enable --now docker
    ' || error_exit "Failed to install dependencies in container"
}

# Function to create Cloudflare tunnel
create_directory_structure() {
    log "INFO" "Creating directory structure..."
    pct exec "$CONTAINER_ID" -- bash -c '
        mkdir -p /opt/headscale/config
        mkdir -p /opt/headscale/data
        mkdir -p /opt/headscale-admin
        mkdir -p /etc/cloudflared
    ' || error_exit "Failed to create directory structure"
}

# Function to create Cloudflare tunnel
create_configurations() {
    local tunnel_token="$1"

    log "INFO" "Creating service configurations..."

    # Create Cloudflare config
    pct exec "$CONTAINER_ID" -- bash -c "cat > /etc/cloudflared/config.yml << EOL
tunnel: ${tunnel_token}
ingress:
  - hostname: $DOMAIN
    path: /admin
    service: http://headscale-admin:80
  - hostname: $DOMAIN
    service: http://headscale:8080
  - service: http_status:404
log-level: info
EOL" || error_exit "Failed to create Cloudflare configuration"

    # Create docker-compose config
    pct exec "$CONTAINER_ID" -- bash -c "cat > /opt/docker-compose.yml << EOL
version: \"3.8\"

services:
  headscale:
    container_name: headscale
    image: headscale/headscale:latest
    volumes:
      - /opt/headscale/config:/etc/headscale
      - /opt/headscale/data:/var/lib/headscale
      - /var/run/headscale:/var/run/headscale
    restart: unless-stopped
    entrypoint: headscale serve
    networks:
      - headscale-net

  headscale-admin:
    image: goodieshq/headscale-admin:latest
    container_name: headscale-admin
    depends_on:
      - headscale
    restart: unless-stopped
    networks:
      - headscale-net

  cloudflared:
    container_name: cloudflared
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run
    volumes:
      - /etc/cloudflared:/etc/cloudflared:ro
    environment:
      - TUNNEL_TOKEN=${tunnel_token}
    restart: unless-stopped
    networks:
      - headscale-net

networks:
  headscale-net:
    name: headscale-net
EOL" || error_exit "Failed to create docker-compose configuration"

    # Handle Headscale config
    if [[ -n "$CONFIG_FILE" ]]; then
        # Copy provided config file
        log "INFO" "Using provided config file..."
        cp "$CONFIG_FILE" /tmp/headscale_config.yaml
        pct push "$CONTAINER_ID" /tmp/headscale_config.yaml /opt/headscale/config/config.yaml
        rm /tmp/headscale_config.yaml
    else
        # Create minimal default config
        log "INFO" "Creating minimal default config..."
        pct exec "$CONTAINER_ID" -- bash -c "cat > /opt/headscale/config/config.yaml << EOL
# Minimal Headscale Configuration
server_url: https://${DOMAIN}
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 0.0.0.0:50443
grpc_allow_insecure: false

noise:
  private_key_path: /var/lib/headscale/noise_private.key

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48

derp:
  server:
    enabled: true
    region_id: 999
    region_code: \"headscale\"
    region_name: \"Headscale Embedded DERP\"
    stun_listen_addr: \"0.0.0.0:3478\"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: 1.2.3.4
    ipv6: 2001:db8::1

  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m

database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite

acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: \":http\"
tls_cert_path: ""
tls_key_path: ""

log:
  format: text
  level: info

dns:
  nameservers:
    global:
      - 1.1.1.1
      - 8.8.8.8
  magic_dns: false
  base_domain: ${DOMAIN}

log:
  level: info

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: \"0770\"
EOL" || error_exit "Failed to create Headscale configuration"
    fi

    # Handle ACL file
    if [[ -n "$ACL_FILE" ]]; then
        # Copy provided ACL file
        log "INFO" "Using provided ACL file..."
        cp "$ACL_FILE" /tmp/acl.yaml
        pct push "$CONTAINER_ID" /tmp/acl.yaml /opt/headscale/config/acl.yaml
        rm /tmp/acl.yaml
    else
        # Create default empty ACL file
        log "INFO" "Creating default empty ACL file..."
        pct exec "$CONTAINER_ID" -- bash -c "cat > /opt/headscale/config/acl.yaml << EOL
# Default empty ACL
groups: {}
hosts: {}
acls: []
EOL"
    fi

    # Create required directories
    pct exec "$CONTAINER_ID" -- bash -c "mkdir -p /var/run/headscale && chmod 770 /var/run/headscale" || \
        error_exit "Failed to create headscale runtime directory"
}

# Function to create Headscale API key
create_headscale_api_key() {
    log "INFO" "Creating Headscale API key..."

    # Wait a bit for Headscale to fully initialize
    sleep 10

    # Create API key
    local api_key_response
    api_key_response=$(pct exec "$CONTAINER_ID" -- bash -c 'docker exec headscale headscale apikeys create')

    if [[ $? -ne 0 || -z "$api_key_response" ]]; then
        log "ERROR" "Failed to create API key. Error: $api_key_response"
        return 1
    fi

    # Store API key in a file for reference
    pct exec "$CONTAINER_ID" -- bash -c "echo '$api_key_response' > /opt/headscale/api_key.txt"

    log "INFO" "API key created successfully and stored in /opt/headscale/api_key.txt"
    log "INFO" "API Key: $api_key_response"
}

# Function to create Cloudflare tunnel
start_services() {
    log "INFO" "Starting services..."
    pct exec "$CONTAINER_ID" -- bash -c 'cd /opt && docker-compose up -d' || \
        error_exit "Failed to start services"
}

# Main function
main() {
    parse_arguments "$@"
    validate_params

    check_proxmox
    install_host_dependencies

    # Get zone ID
    ZONE_ID=$(get_zone_id)
    if [[ -z "$ZONE_ID" ]]; then
        error_exit "Failed to get zone ID"
    fi

    # Create or update tunnel and process response
    log "DEBUG" "Managing Cloudflare tunnel..."
    TUNNEL_RESPONSE=$(create_or_update_tunnel)
    log "DEBUG" "Tunnel Response: $TUNNEL_RESPONSE"
    if ! echo "$TUNNEL_RESPONSE" | jq . >/dev/null 2>&1; then
        error_exit "Invalid tunnel response"
    fi

    # Extract tunnel details
    TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | jq -r '.result.id')
    TUNNEL_TOKEN=$(echo "$TUNNEL_RESPONSE" | jq -r '.result.token')

    # Validate tunnel details
    if [[ -z "$TUNNEL_ID" || "$TUNNEL_ID" == "null" ]]; then
        error_exit "Failed to extract tunnel ID from response"
    fi

    if [[ -z "$TUNNEL_TOKEN" || "$TUNNEL_TOKEN" == "null" ]]; then
        error_exit "Failed to extract tunnel token from response"
    fi

    # Create DNS records
    local subdomain="${DOMAIN%%.*}"

    # Create DNS record
    log "INFO" "Setting up DNS records..."
    create_or_update_dns_record "$subdomain" "$TUNNEL_ID"

    # Configure tunnel routes
    configure_tunnel_routes "$TUNNEL_ID"

    # Create and configure container
    create_container
    setup_container
    create_directory_structure
    create_configurations "$TUNNEL_TOKEN"
    start_services

    # Create Headscale API key
    create_headscale_api_key

    log "INFO" "Setup completed successfully!"
    log "INFO" "Your services will be available at:"
    log "INFO" "- Headscale: https://$DOMAIN"
    log "INFO" "- Headscale Admin: https://$DOMAIN/admin"
    log "INFO" "Container ID: $CONTAINER_ID"
    log "INFO" "To access the container: pct enter $CONTAINER_ID"
}

# Execute main function
main "$@"
