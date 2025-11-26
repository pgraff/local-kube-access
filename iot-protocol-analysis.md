# IoT Device Protocol Analysis

**Scan Date**: Generated from protocol detection scan  
**Network**: 192.168.86.0/24

## Summary

Scanned **23 IoT devices** on your network and identified the protocols they use. 

### Key Findings

**Most Common Protocols:**
- **CoAP (5683)** - Used by **100%** of IoT devices
- **UPnP/SSDP (1900)** - Used by **100%** of IoT devices  
- **mDNS (5353)** - Used by **100%** of IoT devices
- **HTTP/HTTPS** - Used by **3 devices** (SoundTouch, Samsung TV, Raspberry Pi)

**Notable:**
- **NO devices detected using MQTT** (ports 1883, 8883) on standard ports
- This suggests devices may need configuration to connect to your Mosquitto MQTT broker

## Device Breakdown

### ESP8266/ESP32 Devices (15 devices)
**Protocols**: CoAP, UPnP, mDNS

These are microcontroller-based IoT devices:
- `esp_59da26.lan` (192.168.86.26)
- `esp_6a612c.lan` (192.168.86.27)
- `esp_59db0f.lan` (192.168.86.31)
- `esp_5a05cf.lan` (192.168.86.38)
- `esp_052b71.lan` (192.168.86.44)
- `esp_597ff4.lan` (192.168.86.45)
- `esp_053931.lan` (192.168.86.46)
- `esp_053ea9.lan` (192.168.86.47)
- `esp_6a42f1.lan` (192.168.86.48)
- `esp_354b4a.lan` (192.168.86.57)
- `esp_127e86.lan` (192.168.86.59)
- `esp_2c969c.lan` (192.168.86.66)
- `esp_354532.lan` (192.168.86.86)
- `esp_2c9582.lan` (192.168.86.99)

**Protocol Usage:**
- **CoAP (5683)** - Lightweight protocol for constrained devices
- **UPnP (1900)** - Device discovery and control
- **mDNS (5353)** - Local name resolution

### Sonos Speakers (4 devices)
**Protocols**: CoAP, UPnP, mDNS

- `sonoszp.lan` (192.168.86.43)
- `sonoszp.lan` (192.168.86.75)
- `sonoszp.lan` (192.168.86.109)
- Sonos device (192.168.86.53)
- Sonos device (192.168.86.74)

**Protocol Usage:**
- **CoAP (5683)** - Control and status
- **UPnP (1900)** - Media control (UPnP AV)
- **mDNS (5353)** - Service discovery

### Bose SoundTouch (1 device)
**Protocols**: HTTP, CoAP, UPnP, mDNS

- `soundtouch-wave-soundtouch.lan` (192.168.86.37)

**Protocol Usage:**
- **HTTP (80, 8080)** - Web interface ("SoundTouch Access Point Setup")
- **CoAP (5683)** - Device control
- **UPnP (1900)** - Media control
- **mDNS (5353)** - Service discovery

### Belkin Wemo (1 device)
**Protocols**: CoAP, UPnP, mDNS

- `wemo.lan` (192.168.86.68)

**Protocol Usage:**
- **CoAP (5683)** - Device control
- **UPnP (1900)** - Device discovery and control
- **mDNS (5353)** - Service discovery

### Raspberry Pi (1 device)
**Protocols**: CoAP, UPnP, mDNS

- `dashboard.lan` (192.168.86.121) - MAC: DC:A6:32:CD:CD:F9

**Protocol Usage:**
- **CoAP (5683)** - IoT communication
- **UPnP (1900)** - Device discovery
- **mDNS (5353)** - Service discovery

### Samsung Smart TV (1 device)
**Protocols**: HTTP, CoAP, UPnP, mDNS

- `tizen-yza6otc6mjc6mgy6mgu6nzmk.lan` (192.168.86.191)

**Protocol Usage:**
- **HTTPS (443)** - Web interface
- **CoAP (5683)** - Device control
- **UPnP (1900)** - Media control (DLNA)
- **mDNS (5353)** - Service discovery

## Protocol Details

### CoAP (Constrained Application Protocol) - Port 5683
- **Usage**: Used by ALL IoT devices
- **Purpose**: Lightweight protocol for resource-constrained devices
- **Characteristics**: UDP-based, RESTful, low overhead
- **Common Use Cases**: Sensor data, device control, status updates

### UPnP/SSDP (Universal Plug and Play) - Port 1900
- **Usage**: Used by ALL IoT devices
- **Purpose**: Device discovery and control
- **Characteristics**: UDP multicast, automatic device discovery
- **Common Use Cases**: Media control (DLNA), device management, network configuration

### mDNS (Multicast DNS) - Port 5353
- **Usage**: Used by ALL IoT devices
- **Purpose**: Local name resolution without a DNS server
- **Characteristics**: UDP multicast, zero-configuration
- **Common Use Cases**: `.local` domain names, service discovery

### HTTP/HTTPS - Ports 80, 443, 8080
- **Usage**: Used by 3 devices (SoundTouch, Samsung TV, potentially Raspberry Pi)
- **Purpose**: Web interfaces and REST APIs
- **Common Use Cases**: Configuration, status dashboards, API access

## MQTT Status

**No devices detected using MQTT** on standard ports (1883, 8883).

This means:
1. Devices may not be configured to use MQTT yet
2. Devices may use MQTT on non-standard ports
3. Devices may need firmware/configuration updates to connect to your Mosquitto broker

### Recommendations for MQTT Integration

To connect your IoT devices to your Kubernetes MQTT broker (Mosquitto):

1. **For ESP8266/ESP32 devices:**
   - Update firmware to include MQTT client
   - Configure devices to connect to `192.168.86.54` (k8s-cp-01) or use port-forwarding
   - Use MQTT port 1883 (or 8883 for TLS)

2. **For Sonos/Wemo/SoundTouch:**
   - These devices typically don't support MQTT natively
   - Consider using a bridge/gateway (like Home Assistant, OpenHAB, or Node-RED)
   - Bridge can translate UPnP/CoAP to MQTT

3. **For Raspberry Pi:**
   - Install MQTT client libraries (paho-mqtt, mosquitto-clients)
   - Configure to connect to Mosquitto broker
   - Can act as a bridge for other devices

## Integration with Your IoT Stack

Your Kubernetes IoT stack includes:
- **Mosquitto** (MQTT broker) - Port 1883
- **Hono** (Device gateway) - Can bridge MQTT to Kafka
- **Kafka** - Message broker
- **ThingsBoard** - Device management and dashboards
- **Node-RED** - Automation and bridging

### Suggested Integration Path

1. **Use Node-RED as a Bridge:**
   - Node-RED can listen to CoAP, UPnP, and HTTP
   - Convert messages to MQTT format
   - Publish to Mosquitto broker
   - Messages flow: Devices → Node-RED → Mosquitto → Hono → Kafka → ThingsBoard

2. **Direct MQTT for ESP devices:**
   - Configure ESP devices to publish directly to Mosquitto
   - Use topics like `home/sensors/temperature`, `home/esp_59da26/status`
   - Hono can consume from Kafka and create digital twins in Ditto

3. **UPnP/CoAP to MQTT Bridge:**
   - Use Node-RED with appropriate nodes:
     - `node-red-contrib-coap` for CoAP
     - `node-red-contrib-upnp` for UPnP
     - Built-in MQTT nodes for publishing

## Next Steps

1. **Configure ESP devices for MQTT:**
   ```bash
   # Access Mosquitto broker
   ./access-mosquitto.sh
   # Test MQTT connection from a device
   ```

2. **Set up Node-RED flows:**
   - Access Node-RED: `./access-nodered.sh`
   - Create flows to bridge CoAP/UPnP to MQTT
   - Configure MQTT nodes to connect to Mosquitto

3. **Monitor device communication:**
   - Use Kafka UI to see messages: `./access-kafka-ui.sh`
   - Use ThingsBoard for device management: `./access-thingsboard.sh`

## Protocol Comparison

| Protocol | Transport | Overhead | Use Case | Your Devices |
|----------|-----------|----------|----------|--------------|
| **MQTT** | TCP | Low | Pub/Sub messaging | 0 (not detected) |
| **CoAP** | UDP | Very Low | Constrained devices | 23 (100%) |
| **UPnP** | UDP/TCP | Medium | Device discovery | 23 (100%) |
| **mDNS** | UDP | Very Low | Name resolution | 23 (100%) |
| **HTTP** | TCP | High | Web interfaces | 3 (13%) |

## Files Generated

- `scan-iot-devices.sh` - Network scanner script
- `detect-iot-protocols.sh` - Protocol detection script
- `iot-device-scan-results/` - Detailed scan results

---

**Last Updated**: Generated from protocol detection scan  
**Total IoT Devices**: 23  
**Protocols Detected**: CoAP, UPnP, mDNS, HTTP/HTTPS

