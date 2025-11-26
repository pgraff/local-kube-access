#!/bin/bash

# IoT Protocol Detection Script
# Analyzes discovered IoT devices to determine which protocols they use

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Extract IoT devices from ARP scan
extract_iot_devices() {
    # Extract devices from ARP table
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ARP_OUTPUT=$(arp -a | grep -v "incomplete" | grep -v "broadcast" | grep -v "multicast")
    else
        ARP_OUTPUT=$(arp -a | grep -v "incomplete" | grep -v "broadcast" | grep -v "multicast")
    fi
    
    # Use arrays instead of associative arrays for compatibility
    DEVICE_IPS=()
    DEVICE_INFOS=()
    
    while IFS= read -r line; do
        IP=$(echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})' | head -1 | tr '[:lower:]' '[:upper:]' | tr '-' ':')
        HOSTNAME=$(echo "$line" | grep -oE '[a-zA-Z0-9_-]+\.lan' | head -1 || echo "")
        
        # Filter out non-IoT devices (gateways, broadcast, etc.)
        if [[ ! -z "$IP" && "$IP" != "192.168.86.1" && "$IP" != "192.168.86.255" ]]; then
            # Identify IoT devices by hostname patterns or MAC OUI
            IS_IOT=false
            
            # ESP devices (ESP8266/ESP32)
            if [[ "$HOSTNAME" =~ ^esp_ ]] || [[ "$MAC" =~ ^(BC:DD:C2|2C:F4:32|24:62:AB|EC:FA:BC|4C:11:AE|80:7D:3A) ]]; then
                IS_IOT=true
                DEVICE_TYPE="ESP8266/ESP32"
            fi
            
            # Sonos speakers
            if [[ "$HOSTNAME" =~ sonos ]] || [[ "$MAC" =~ ^(34:7E:5C|48:A6:B8) ]]; then
                IS_IOT=true
                DEVICE_TYPE="Sonos Speaker"
            fi
            
            # Wemo devices
            if [[ "$HOSTNAME" =~ wemo ]] || [[ "$MAC" =~ ^30:23:03 ]]; then
                IS_IOT=true
                DEVICE_TYPE="Belkin Wemo"
            fi
            
            # Raspberry Pi
            if [[ "$MAC" =~ ^(DC:A6:32|B8:27:EB|E4:5F:01) ]]; then
                IS_IOT=true
                DEVICE_TYPE="Raspberry Pi"
            fi
            
            # SoundTouch
            if [[ "$HOSTNAME" =~ soundtouch ]]; then
                IS_IOT=true
                DEVICE_TYPE="Bose SoundTouch"
            fi
            
            # Samsung Tizen (Smart TV)
            if [[ "$HOSTNAME" =~ tizen ]]; then
                IS_IOT=true
                DEVICE_TYPE="Samsung Smart TV"
            fi
            
            if [ "$IS_IOT" = true ]; then
                DEVICE_IPS+=("$IP")
                DEVICE_INFOS+=("$DEVICE_TYPE|$MAC|$HOSTNAME")
            fi
        fi
    done <<< "$ARP_OUTPUT"
    
    # Export devices for use in other functions
    for i in "${!DEVICE_IPS[@]}"; do
        echo "${DEVICE_IPS[$i]}|${DEVICE_INFOS[$i]}"
    done
}

# Scan device for protocols
scan_device_protocols() {
    local IP=$1
    local DEVICE_INFO=$2
    IFS='|' read -r DEVICE_TYPE MAC HOSTNAME <<< "$DEVICE_INFO"
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Device: ${HOSTNAME:-$IP}${NC}"
    echo -e "${YELLOW}Type: ${DEVICE_TYPE}${NC}"
    echo -e "${YELLOW}IP: ${IP} | MAC: ${MAC}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Use arrays to track protocols
    PROTOCOL_LIST=()
    PROTOCOL_PORTS=()
    
    HTTP_PORTS=()
    
    # MQTT (1883, 8883)
    echo -n "  Checking MQTT (1883)... "
    if timeout 2 nc -z "$IP" 1883 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        PROTOCOL_LIST+=("MQTT")
        PROTOCOL_PORTS+=("1883")
    else
        echo -e "${RED}✗ Closed${NC}"
    fi
    
    echo -n "  Checking MQTT/TLS (8883)... "
    if timeout 2 nc -z "$IP" 8883 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        PROTOCOL_LIST+=("MQTT-TLS")
        PROTOCOL_PORTS+=("8883")
    else
        echo -e "${RED}✗ Closed${NC}"
    fi
    
    # HTTP/HTTPS (80, 443, 8080, 8081, 9091)
    for port in 80 443 8080 8081 9091; do
        echo -n "  Checking HTTP/HTTPS (${port})... "
        if timeout 2 nc -z "$IP" "$port" 2>/dev/null; then
            echo -e "${GREEN}✓ OPEN${NC}"
            HTTP_PORTS+=("$port")
        else
            echo -e "${RED}✗ Closed${NC}"
        fi
    done
    
    if [ ${#HTTP_PORTS[@]} -gt 0 ]; then
        PROTOCOL_LIST+=("HTTP")
        HTTP_PORT_STR=$(IFS=,; echo "${HTTP_PORTS[*]}")
        PROTOCOL_PORTS+=("$HTTP_PORT_STR")
    fi
    
    # CoAP (5683, 5684)
    echo -n "  Checking CoAP (5683)... "
    if timeout 2 nc -u -z "$IP" 5683 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        PROTOCOL_LIST+=("CoAP")
        PROTOCOL_PORTS+=("5683")
    else
        echo -e "${RED}✗ Closed${NC}"
    fi
    
    # UPnP/SSDP (1900)
    echo -n "  Checking UPnP/SSDP (1900)... "
    if timeout 2 nc -u -z "$IP" 1900 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        PROTOCOL_LIST+=("UPnP")
        PROTOCOL_PORTS+=("1900")
    else
        echo -e "${RED}✗ Closed${NC}"
    fi
    
    # mDNS (5353)
    echo -n "  Checking mDNS (5353)... "
    if timeout 2 nc -u -z "$IP" 5353 2>/dev/null; then
        echo -e "${GREEN}✓ OPEN${NC}"
        PROTOCOL_LIST+=("mDNS")
        PROTOCOL_PORTS+=("5353")
    else
        echo -e "${RED}✗ Closed${NC}"
    fi
    
    # Detailed port scan with nmap
    echo -e "\n  ${BLUE}Running detailed port scan...${NC}"
    nmap_output=$(nmap -p 1883,8883,80,443,8080,8081,9091,5683,1900,5353,49152-49155 --open -sV "$IP" 2>/dev/null | grep -E "(PORT|open|tcp|udp)" || true)
    
    if [ ! -z "$nmap_output" ]; then
        echo "$nmap_output" | while IFS= read -r line; do
            if [[ "$line" =~ open ]]; then
                PORT=$(echo "$line" | grep -oE '[0-9]+/(tcp|udp)' | cut -d/ -f1)
                SERVICE=$(echo "$line" | awk '{print $3}')
                echo -e "    ${GREEN}Port ${PORT}: ${SERVICE}${NC}"
            fi
        done
    fi
    
    # Try to identify service via HTTP
    if [ ${#HTTP_PORTS[@]} -gt 0 ]; then
        HTTP_PORT="${HTTP_PORTS[0]}"
        echo -e "\n  ${BLUE}Checking HTTP service...${NC}"
        HTTP_RESPONSE=$(timeout 3 curl -s -m 2 "http://${IP}:${HTTP_PORT}" 2>/dev/null || echo "")
        if [ ! -z "$HTTP_RESPONSE" ]; then
            TITLE=$(echo "$HTTP_RESPONSE" | grep -i '<title>' | sed 's/.*<title>\(.*\)<\/title>.*/\1/' | head -1 || echo "")
            SERVER=$(curl -s -I -m 2 "http://${IP}:${HTTP_PORT}" 2>/dev/null | grep -i "Server:" | cut -d: -f2 | tr -d '\r' || echo "")
            if [ ! -z "$TITLE" ]; then
                echo -e "    ${GREEN}Web Interface: ${TITLE}${NC}"
            fi
            if [ ! -z "$SERVER" ]; then
                echo -e "    ${GREEN}Server: ${SERVER}${NC}"
            fi
        fi
    fi
    
    # Summary
    if [ ${#PROTOCOL_LIST[@]} -gt 0 ]; then
        echo -e "\n  ${GREEN}Detected Protocols:${NC}"
        for i in "${!PROTOCOL_LIST[@]}"; do
            echo -e "    ${GREEN}• ${PROTOCOL_LIST[$i]}${NC} (${PROTOCOL_PORTS[$i]})"
        done
    else
        echo -e "\n  ${YELLOW}No common IoT protocols detected on standard ports${NC}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  IoT Protocol Detection${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Check for required tools
    if ! command -v nmap &> /dev/null; then
        echo -e "${RED}Error: nmap is required${NC}"
        echo "Install with: brew install nmap"
        exit 1
    fi
    
    if ! command -v nc &> /dev/null; then
        echo -e "${RED}Error: netcat (nc) is required${NC}"
        echo "Install with: brew install netcat"
        exit 1
    fi
    
    # Extract IoT devices
    DEVICE_LIST=$(extract_iot_devices)
    
    if [ -z "$DEVICE_LIST" ]; then
        echo -e "${YELLOW}No IoT devices found in ARP table${NC}"
        echo "Make sure devices are active on the network"
        exit 0
    fi
    
    DEVICE_COUNT=$(echo "$DEVICE_LIST" | wc -l | tr -d ' ')
    echo -e "${GREEN}Found ${DEVICE_COUNT} IoT device(s)${NC}"
    echo ""
    
    # Scan each device
    echo "$DEVICE_LIST" | while IFS='|' read -r IP DEVICE_TYPE MAC HOSTNAME; do
        scan_device_protocols "$IP" "$DEVICE_TYPE|$MAC|$HOSTNAME"
    done
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Protocol detection complete!${NC}"
    echo ""
    echo -e "${YELLOW}Common IoT Protocols:${NC}"
    echo "  • MQTT (1883) - Message queuing for IoT"
    echo "  • MQTT/TLS (8883) - Secure MQTT"
    echo "  • HTTP/HTTPS (80, 443, 8080, 8081) - Web interfaces"
    echo "  • CoAP (5683) - Constrained Application Protocol"
    echo "  • UPnP/SSDP (1900) - Device discovery"
    echo "  • mDNS (5353) - Multicast DNS"
    echo ""
}

# Run main function
main

