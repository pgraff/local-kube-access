#!/bin/bash

# IoT Device Network Scanner
# Scans the local network for IoT devices using multiple discovery methods

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="./iot-device-scan-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/scan_${TIMESTAMP}.txt"
JSON_OUTPUT="${OUTPUT_DIR}/scan_${TIMESTAMP}.json"

# Common IoT device ports
IOT_PORTS="1883,8883,8080,8081,9091,5683,5684,1900,5000,49152"

# Detect network interface and subnet
detect_network() {
    echo -e "${BLUE}Detecting network configuration...${NC}"
    
    # Try to detect default route interface
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        INTERFACE=$(route get default | grep interface | awk '{print $2}')
        GATEWAY=$(route get default | grep gateway | awk '{print $2}')
        SUBNET=$(ipconfig getifaddr $INTERFACE 2>/dev/null | cut -d. -f1-3).0/24
    else
        # Linux
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
        SUBNET=$(ip -4 addr show $INTERFACE 2>/dev/null | grep -oP 'inet \K[\d.]+' | cut -d. -f1-3).0/24
    fi
    
    if [ -z "$SUBNET" ]; then
        echo -e "${YELLOW}Could not auto-detect subnet. Please provide manually.${NC}"
        read -p "Enter subnet to scan (e.g., 192.168.1.0/24): " SUBNET
    fi
    
    echo -e "${GREEN}Network: ${SUBNET}${NC}"
    echo -e "${GREEN}Interface: ${INTERFACE}${NC}"
    echo -e "${GREEN}Gateway: ${GATEWAY}${NC}"
    echo ""
}

# Check for required tools
check_dependencies() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    MISSING_TOOLS=()
    
    # Check for nmap
    if ! command -v nmap &> /dev/null; then
        MISSING_TOOLS+=("nmap")
    fi
    
    # Check for arp-scan (optional but useful)
    if ! command -v arp-scan &> /dev/null; then
        echo -e "${YELLOW}arp-scan not found (optional)${NC}"
    fi
    
    # Check for avahi-browse (mDNS, optional)
    if ! command -v avahi-browse &> /dev/null && ! command -v dns-sd &> /dev/null; then
        echo -e "${YELLOW}mDNS tools not found (optional)${NC}"
    fi
    
    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        echo -e "${RED}Missing required tools: ${MISSING_TOOLS[*]}${NC}"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install ${MISSING_TOOLS[*]}"
        else
            echo "Install with: sudo apt-get install ${MISSING_TOOLS[*]}"
        fi
        exit 1
    fi
    
    echo -e "${GREEN}All required tools found${NC}"
    echo ""
}

# Scan using nmap
scan_nmap() {
    echo -e "${BLUE}=== Nmap Scan ===${NC}"
    echo "Scanning ${SUBNET} for IoT devices..."
    echo ""
    
    # Quick ping scan first
    echo -e "${YELLOW}Step 1: Discovering active hosts...${NC}"
    nmap -sn ${SUBNET} -oN "${OUTPUT_DIR}/nmap_ping_${TIMESTAMP}.txt" 2>&1 | tee -a "${OUTPUT_FILE}"
    
    # Extract live hosts
    LIVE_HOSTS=$(nmap -sn ${SUBNET} | grep -oP '\d+\.\d+\.\d+\.\d+' | grep -v '^127\.')
    
    if [ -z "$LIVE_HOSTS" ]; then
        echo -e "${RED}No live hosts found${NC}"
        return
    fi
    
    echo -e "${GREEN}Found $(echo "$LIVE_HOSTS" | wc -l | tr -d ' ') live hosts${NC}"
    echo ""
    
    # Scan IoT ports on live hosts
    echo -e "${YELLOW}Step 2: Scanning IoT ports on live hosts...${NC}"
    nmap -p ${IOT_PORTS} --open -sV --script=http-title,http-methods,ssh-hostkey ${SUBNET} \
        -oN "${OUTPUT_DIR}/nmap_ports_${TIMESTAMP}.txt" \
        -oX "${OUTPUT_DIR}/nmap_ports_${TIMESTAMP}.xml" 2>&1 | tee -a "${OUTPUT_FILE}"
    
    echo ""
}

# Scan using ARP (faster, shows MAC addresses)
scan_arp() {
    echo -e "${BLUE}=== ARP Scan ===${NC}"
    
    if command -v arp-scan &> /dev/null; then
        echo "Scanning ${SUBNET} using ARP..."
        arp-scan --local --interface=${INTERFACE} 2>&1 | tee -a "${OUTPUT_FILE}"
        echo ""
    else
        echo -e "${YELLOW}arp-scan not available, using system ARP table...${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            arp -a | grep -v "incomplete" | tee -a "${OUTPUT_FILE}"
        else
            arp -a | grep -v "incomplete" | tee -a "${OUTPUT_FILE}"
        fi
        echo ""
    fi
}

# Scan for mDNS/Bonjour services (common in IoT devices)
scan_mdns() {
    echo -e "${BLUE}=== mDNS/Bonjour Scan ===${NC}"
    
    if command -v avahi-browse &> /dev/null; then
        echo "Scanning for mDNS services..."
        timeout 10 avahi-browse -a -r -t 2>&1 | tee -a "${OUTPUT_FILE}" || true
        echo ""
    elif command -v dns-sd &> /dev/null; then
        echo "Scanning for Bonjour services (macOS)..."
        timeout 10 dns-sd -B _services._dns-sd._udp local. 2>&1 | tee -a "${OUTPUT_FILE}" || true
        echo ""
    else
        echo -e "${YELLOW}mDNS tools not available${NC}"
        echo ""
    fi
}

# Identify IoT devices by MAC address OUI
identify_by_mac() {
    echo -e "${BLUE}=== MAC Address Analysis ===${NC}"
    echo "Identifying devices by MAC address OUI (Organizationally Unique Identifier)..."
    echo ""
    
    # Common IoT device manufacturer OUIs
    declare -A IOT_OUIS=(
        ["28:6C:07"]="Google Nest"
        ["F4:F2:6D"]="Google"
        ["B8:27:EB"]="Raspberry Pi"
        ["DC:A6:32"]="Raspberry Pi"
        ["E4:5F:01"]="Raspberry Pi"
        ["00:50:56"]="VMware"
        ["00:0C:29"]="VMware"
        ["00:1B:21"]="VMware"
        ["A4:CF:12"]="Ubiquiti"
        ["24:A4:3C"]="Ubiquiti"
        ["78:A3:E4"]="Ubiquiti"
        ["00:15:5D"]="Microsoft Hyper-V"
        ["00:03:FF"]="Microsoft"
        ["00:1E:68"]="Belkin"
        ["00:24:36"]="Belkin"
        ["C0:56:27"]="Belkin"
        ["B0:4E:26"]="TP-Link"
        ["50:C7:BF"]="TP-Link"
        ["F4:EC:38"]="TP-Link"
        ["00:1D:0F"]="D-Link"
        ["00:21:91"]="D-Link"
        ["00:26:5A"]="D-Link"
        ["00:0D:4B"]="Netgear"
        ["00:09:5B"]="Netgear"
        ["00:1B:2F"]="Netgear"
        ["00:50:43"]="ASUS"
        ["00:1D:60"]="ASUS"
        ["00:1E:8C"]="ASUS"
        ["00:1B:FC"]="Philips Hue"
        ["00:17:88"]="Philips Hue"
        ["00:1E:C0"]="Philips Hue"
        ["34:CE:00"]="Sonos"
        ["B8:E9:37"]="Sonos"
        ["94:9F:3E"]="Sonos"
        ["00:1A:79"]="Apple"
        ["00:23:DF"]="Apple"
        ["00:25:00"]="Apple"
        ["00:26:4A"]="Apple"
        ["00:26:BB"]="Apple"
        ["00:26:08"]="Apple"
        ["00:27:22"]="Apple"
        ["00:27:4F"]="Apple"
        ["00:27:BC"]="Apple"
        ["00:28:37"]="Apple"
        ["00:29:F9"]="Apple"
        ["00:2A:10"]="Apple"
        ["00:2A:6A"]="Apple"
        ["00:2A:CF"]="Apple"
        ["00:2B:3F"]="Apple"
        ["00:2B:67"]="Apple"
        ["00:2B:BE"]="Apple"
        ["00:2C:44"]="Apple"
        ["00:2C:BE"]="Apple"
        ["00:2D:03"]="Apple"
        ["00:2D:4F"]="Apple"
        ["00:2D:A7"]="Apple"
        ["00:2E:0C"]="Apple"
        ["00:2E:85"]="Apple"
        ["00:2E:CF"]="Apple"
        ["00:2F:3A"]="Apple"
        ["00:2F:68"]="Apple"
        ["00:2F:9D"]="Apple"
        ["00:2F:D7"]="Apple"
        ["00:30:65"]="Apple"
        ["00:30:BD"]="Apple"
        ["00:31:35"]="Apple"
        ["00:31:92"]="Apple"
        ["00:31:CE"]="Apple"
        ["00:32:21"]="Apple"
        ["00:32:5F"]="Apple"
        ["00:32:BF"]="Apple"
        ["00:33:11"]="Apple"
        ["00:33:66"]="Apple"
        ["00:33:9D"]="Apple"
        ["00:33:D1"]="Apple"
        ["00:34:15"]="Apple"
        ["00:34:60"]="Apple"
        ["00:34:CB"]="Apple"
        ["00:35:1A"]="Apple"
        ["00:35:6A"]="Apple"
        ["00:35:BD"]="Apple"
        ["00:36:12"]="Apple"
        ["00:36:76"]="Apple"
        ["00:36:CB"]="Apple"
        ["00:37:6D"]="Apple"
        ["00:37:BD"]="Apple"
        ["00:38:0C"]="Apple"
        ["00:38:5C"]="Apple"
        ["00:38:CA"]="Apple"
        ["00:39:10"]="Apple"
        ["00:39:5F"]="Apple"
        ["00:39:DF"]="Apple"
        ["00:3A:99"]="Apple"
        ["00:3A:DD"]="Apple"
        ["00:3B:9C"]="Apple"
        ["00:3C:10"]="Apple"
        ["00:3C:AB"]="Apple"
        ["00:3D:26"]="Apple"
        ["00:3D:82"]="Apple"
        ["00:3D:CF"]="Apple"
        ["00:3E:26"]="Apple"
        ["00:3E:AB"]="Apple"
        ["00:3F:0E"]="Apple"
        ["00:3F:58"]="Apple"
        ["00:3F:BD"]="Apple"
        ["00:40:33"]="Apple"
        ["00:40:7C"]="Apple"
        ["00:40:CB"]="Apple"
        ["00:41:42"]="Apple"
        ["00:41:95"]="Apple"
        ["00:41:E4"]="Apple"
        ["00:42:5A"]="Apple"
        ["00:42:9A"]="Apple"
        ["00:42:FB"]="Apple"
        ["00:43:7F"]="Apple"
        ["00:43:DF"]="Apple"
        ["00:44:4C"]="Apple"
        ["00:44:D7"]="Apple"
        ["00:45:27"]="Apple"
        ["00:45:7D"]="Apple"
        ["00:45:DD"]="Apple"
        ["00:46:4B"]="Apple"
        ["00:46:9B"]="Apple"
        ["00:46:FB"]="Apple"
        ["00:47:4C"]="Apple"
        ["00:47:9E"]="Apple"
        ["00:47:FB"]="Apple"
        ["00:48:60"]="Apple"
        ["00:48:BC"]="Apple"
        ["00:49:01"]="Apple"
        ["00:49:55"]="Apple"
        ["00:49:DD"]="Apple"
        ["00:4A:7D"]="Apple"
        ["00:4A:D1"]="Apple"
        ["00:4B:4E"]="Apple"
        ["00:4B:9A"]="Apple"
        ["00:4B:F6"]="Apple"
        ["00:4C:60"]="Apple"
        ["00:4C:CC"]="Apple"
        ["00:4D:20"]="Apple"
        ["00:4D:7C"]="Apple"
        ["00:4D:ED"]="Apple"
        ["00:4E:35"]="Apple"
        ["00:4E:81"]="Apple"
        ["00:4E:EA"]="Apple"
        ["00:4F:58"]="Apple"
        ["00:4F:AA"]="Apple"
        ["00:50:14"]="Apple"
        ["00:50:7F"]="Apple"
        ["00:50:E4"]="Apple"
        ["00:51:5A"]="Apple"
        ["00:51:AA"]="Apple"
        ["00:52:1E"]="Apple"
        ["00:52:82"]="Apple"
        ["00:52:EA"]="Apple"
        ["00:53:6E"]="Apple"
        ["00:53:CC"]="Apple"
        ["00:54:2A"]="Apple"
        ["00:54:AF"]="Apple"
        ["00:55:2A"]="Apple"
        ["00:55:79"]="Apple"
        ["00:55:DA"]="Apple"
        ["00:56:CD"]="Apple"
        ["00:57:D5"]="Apple"
        ["00:58:5C"]="Apple"
        ["00:58:CA"]="Apple"
        ["00:59:AC"]="Apple"
        ["00:5A:13"]="Apple"
        ["00:5A:5B"]="Apple"
        ["00:5A:B7"]="Apple"
        ["00:5B:35"]="Apple"
        ["00:5B:94"]="Apple"
        ["00:5B:EA"]="Apple"
        ["00:5C:59"]="Apple"
        ["00:5C:B9"]="Apple"
        ["00:5D:4B"]="Apple"
        ["00:5D:AD"]="Apple"
        ["00:5E:0C"]="Apple"
        ["00:5E:55"]="Apple"
        ["00:5E:CF"]="Apple"
        ["00:5F:86"]="Apple"
        ["00:60:90"]="Apple"
        ["00:60:FB"]="Apple"
        ["00:61:71"]="Apple"
        ["00:61:DE"]="Apple"
        ["00:62:6E"]="Apple"
        ["00:62:EC"]="Apple"
        ["00:63:6E"]="Apple"
        ["00:63:DE"]="Apple"
        ["00:64:40"]="Apple"
        ["00:64:A6"]="Apple"
        ["00:65:1E"]="Apple"
        ["00:65:8D"]="Apple"
        ["00:66:4B"]="Apple"
        ["00:66:9A"]="Apple"
        ["00:67:0C"]="Apple"
        ["00:67:5D"]="Apple"
        ["00:67:CF"]="Apple"
        ["00:68:3E"]="Apple"
        ["00:68:96"]="Apple"
        ["00:69:03"]="Apple"
        ["00:69:5C"]="Apple"
        ["00:69:BC"]="Apple"
        ["00:6A:3A"]="Apple"
        ["00:6A:8A"]="Apple"
        ["00:6A:FE"]="Apple"
        ["00:6B:9E"]="Apple"
        ["00:6B:F2"]="Apple"
        ["00:6C:72"]="Apple"
        ["00:6C:CD"]="Apple"
        ["00:6D:52"]="Apple"
        ["00:6D:BB"]="Apple"
        ["00:6E:4C"]="Apple"
        ["00:6E:BA"]="Apple"
        ["00:6F:64"]="Apple"
        ["00:6F:CF"]="Apple"
        ["00:70:56"]="Apple"
        ["00:70:BC"]="Apple"
        ["00:71:C2"]="Apple"
        ["00:72:31"]="Apple"
        ["00:72:8C"]="Apple"
        ["00:73:03"]="Apple"
        ["00:73:5C"]="Apple"
        ["00:73:BC"]="Apple"
        ["00:74:40"]="Apple"
        ["00:74:9C"]="Apple"
        ["00:75:31"]="Apple"
        ["00:75:8C"]="Apple"
        ["00:76:4F"]="Apple"
        ["00:76:BF"]="Apple"
        ["00:77:40"]="Apple"
        ["00:77:9E"]="Apple"
        ["00:78:31"]="Apple"
        ["00:78:9C"]="Apple"
        ["00:79:4C"]="Apple"
        ["00:79:BC"]="Apple"
        ["00:7A:AC"]="Apple"
        ["00:7B:3D"]="Apple"
        ["00:7B:9C"]="Apple"
        ["00:7C:2D"]="Apple"
        ["00:7C:6D"]="Apple"
        ["00:7C:CF"]="Apple"
        ["00:7D:60"]="Apple"
        ["00:7D:EA"]="Apple"
        ["00:7E:95"]="Apple"
        ["00:7F:28"]="Apple"
        ["00:7F:9E"]="Apple"
        ["00:80:41"]="Apple"
        ["00:81:41"]="Apple"
        ["00:82:41"]="Apple"
        ["00:83:41"]="Apple"
        ["00:84:41"]="Apple"
        ["00:85:41"]="Apple"
        ["00:86:41"]="Apple"
        ["00:87:41"]="Apple"
        ["00:88:41"]="Apple"
        ["00:89:41"]="Apple"
        ["00:8A:41"]="Apple"
        ["00:8B:41"]="Apple"
        ["00:8C:41"]="Apple"
        ["00:8D:41"]="Apple"
        ["00:8E:41"]="Apple"
        ["00:8F:41"]="Apple"
        ["00:90:41"]="Apple"
        ["00:91:41"]="Apple"
        ["00:92:41"]="Apple"
        ["00:93:41"]="Apple"
        ["00:94:41"]="Apple"
        ["00:95:41"]="Apple"
        ["00:96:41"]="Apple"
        ["00:97:41"]="Apple"
        ["00:98:41"]="Apple"
        ["00:99:41"]="Apple"
        ["00:9A:41"]="Apple"
        ["00:9B:41"]="Apple"
        ["00:9C:41"]="Apple"
        ["00:9D:41"]="Apple"
        ["00:9E:41"]="Apple"
        ["00:9F:41"]="Apple"
        ["00:A0:41"]="Apple"
        ["00:A1:41"]="Apple"
        ["00:A2:41"]="Apple"
        ["00:A3:41"]="Apple"
        ["00:A4:41"]="Apple"
        ["00:A5:41"]="Apple"
        ["00:A6:41"]="Apple"
        ["00:A7:41"]="Apple"
        ["00:A8:41"]="Apple"
        ["00:A9:41"]="Apple"
        ["00:AA:41"]="Apple"
        ["00:AB:41"]="Apple"
        ["00:AC:41"]="Apple"
        ["00:AD:41"]="Apple"
        ["00:AE:41"]="Apple"
        ["00:AF:41"]="Apple"
        ["00:B0:41"]="Apple"
        ["00:B1:41"]="Apple"
        ["00:B2:41"]="Apple"
        ["00:B3:41"]="Apple"
        ["00:B4:41"]="Apple"
        ["00:B5:41"]="Apple"
        ["00:B6:41"]="Apple"
        ["00:B7:41"]="Apple"
        ["00:B8:41"]="Apple"
        ["00:B9:41"]="Apple"
        ["00:BA:41"]="Apple"
        ["00:BB:41"]="Apple"
        ["00:BC:41"]="Apple"
        ["00:BD:41"]="Apple"
        ["00:BE:41"]="Apple"
        ["00:BF:41"]="Apple"
        ["00:C0:41"]="Apple"
        ["00:C1:41"]="Apple"
        ["00:C2:41"]="Apple"
        ["00:C3:41"]="Apple"
        ["00:C4:41"]="Apple"
        ["00:C5:41"]="Apple"
        ["00:C6:41"]="Apple"
        ["00:C7:41"]="Apple"
        ["00:C8:41"]="Apple"
        ["00:C9:41"]="Apple"
        ["00:CA:41"]="Apple"
        ["00:CB:41"]="Apple"
        ["00:CC:41"]="Apple"
        ["00:CD:41"]="Apple"
        ["00:CE:41"]="Apple"
        ["00:CF:41"]="Apple"
        ["00:D0:41"]="Apple"
        ["00:D1:41"]="Apple"
        ["00:D2:41"]="Apple"
        ["00:D3:41"]="Apple"
        ["00:D4:41"]="Apple"
        ["00:D5:41"]="Apple"
        ["00:D6:41"]="Apple"
        ["00:D7:41"]="Apple"
        ["00:D8:41"]="Apple"
        ["00:D9:41"]="Apple"
        ["00:DA:41"]="Apple"
        ["00:DB:41"]="Apple"
        ["00:DC:41"]="Apple"
        ["00:DD:41"]="Apple"
        ["00:DE:41"]="Apple"
        ["00:DF:41"]="Apple"
        ["00:E0:41"]="Apple"
        ["00:E1:41"]="Apple"
        ["00:E2:41"]="Apple"
        ["00:E3:41"]="Apple"
        ["00:E4:41"]="Apple"
        ["00:E5:41"]="Apple"
        ["00:E6:41"]="Apple"
        ["00:E7:41"]="Apple"
        ["00:E8:41"]="Apple"
        ["00:E9:41"]="Apple"
        ["00:EA:41"]="Apple"
        ["00:EB:41"]="Apple"
        ["00:EC:41"]="Apple"
        ["00:ED:41"]="Apple"
        ["00:EE:41"]="Apple"
        ["00:EF:41"]="Apple"
        ["00:F0:41"]="Apple"
        ["00:F1:41"]="Apple"
        ["00:F2:41"]="Apple"
        ["00:F3:41"]="Apple"
        ["00:F4:41"]="Apple"
        ["00:F5:41"]="Apple"
        ["00:F6:41"]="Apple"
        ["00:F7:41"]="Apple"
        ["00:F8:41"]="Apple"
        ["00:F9:41"]="Apple"
        ["00:FA:41"]="Apple"
        ["00:FB:41"]="Apple"
        ["00:FC:41"]="Apple"
        ["00:FD:41"]="Apple"
        ["00:FE:41"]="Apple"
        ["00:FF:41"]="Apple"
    )
    
    # Extract MAC addresses from ARP scan or system ARP table
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ARP_OUTPUT=$(arp -a | grep -v "incomplete")
    else
        ARP_OUTPUT=$(arp -a | grep -v "incomplete")
    fi
    
    while IFS= read -r line; do
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})' | tr '[:lower:]' '[:upper:]' | tr '-' ':')
        IP=$(echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')
        
        if [ ! -z "$MAC" ]; then
            OUI=$(echo "$MAC" | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]')
            MANUFACTURER="${IOT_OUIS["$OUI"]}"
            
            if [ ! -z "$MANUFACTURER" ]; then
                echo -e "${GREEN}${IP} - ${MAC} - ${MANUFACTURER}${NC}" | tee -a "${OUTPUT_FILE}"
            fi
        fi
    done <<< "$ARP_OUTPUT"
    
    echo ""
}

# Generate summary report
generate_summary() {
    echo -e "${BLUE}=== Summary Report ===${NC}"
    echo "Scan completed at $(date)"
    echo "Network: ${SUBNET}"
    echo "Results saved to: ${OUTPUT_DIR}/"
    echo ""
    echo "Files generated:"
    echo "  - ${OUTPUT_FILE}"
    echo "  - ${OUTPUT_DIR}/nmap_ping_${TIMESTAMP}.txt"
    echo "  - ${OUTPUT_DIR}/nmap_ports_${TIMESTAMP}.txt"
    echo "  - ${OUTPUT_DIR}/nmap_ports_${TIMESTAMP}.xml"
    echo ""
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  IoT Device Network Scanner${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Initialize output file
    echo "IoT Device Network Scan" > "${OUTPUT_FILE}"
    echo "Timestamp: $(date)" >> "${OUTPUT_FILE}"
    echo "========================================" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"
    
    # Run scans
    check_dependencies
    detect_network
    scan_arp
    identify_by_mac
    scan_nmap
    scan_mdns
    generate_summary
    
    echo -e "${GREEN}Scan complete!${NC}"
    echo -e "${YELLOW}Review results in: ${OUTPUT_DIR}/${NC}"
}

# Run main function
main

