# LAYR Guardian - RFID Access Control System

An RFID-based access control system designed for the Infineon XMC4700 Relax Kit. This project consists of two main components: an RFID reader and EEPROM programmer for managing access credentials.

## 🔧 Hardware Requirements

- **Microcontroller**: Infineon XMC4700 Relax Kit
- **RFID Reader**: MFRC522 (compatible with ISO/IEC 14443A cards)
- **EEPROM**: SPI-based EEPROM module
- **Additional Components**:
  - Solenoid/Lock mechanism (connected to pin 7)
  - SPI connections for RFID and EEPROM modules

### Pin Configuration

| Component | Pin | Description |
|-----------|-----|-------------|
| RFID Module | Pin 9 | Chip Select (SS_RFID) |
| EEPROM | Pin 8 | Chip Select (SS_EEPROM) |
| Lock/Unlock | Pin 7 | Unlock Signal Output |

## 📦 Software Requirements

- **PlatformIO Core** (CLI) or **PlatformIO IDE**
- **Python 3.6+** (for PlatformIO)
- **Git** (optional, for version control)

### Installing PlatformIO

#### Option 1: Install PlatformIO Core (CLI)
```bash
# Using pip
pip install platformio

# Or using your package manager (Ubuntu/Debian)
sudo apt-get install platformio
```

#### Option 2: Install PlatformIO IDE
- Install as VS Code extension: Search for "PlatformIO IDE" in VS Code Extensions
- Or download standalone PlatformIO IDE from: https://platformio.org/platformio-ide

## 🚀 Getting Started

### 1. Clone or Navigate to Project

```bash
cd /path/to/challenge
```

### 2. Project Structure

```
challenge/
├── XMC_Reader/          # Main RFID reader application
│   ├── platformio.ini   # PlatformIO configuration
│   ├── src/
│   │   └── main.cpp     # Main application code
│   ├── include/         # Header files
│   ├── lib/             # Custom libraries
│   └── test/            # Test files
│
├── XMC_EEPROM/          # EEPROM programmer utility
│   ├── platformio.ini   # PlatformIO configuration
│   └── src/
│       └── main.cpp     # EEPROM programming code
│
└── README.md            # This file
```

## 📝 Programming with PlatformIO

### Basic PlatformIO Commands

#### Building the Project
```bash
# Navigate to project directory
cd XMC_Reader

# Compile the project
pio run
```

#### Uploading to Board
```bash
# Upload firmware to XMC4700
pio run --target upload

# Or specify upload port (if multiple devices connected)
pio run --target upload --upload-port /dev/ttyUSB0
```

#### Serial Monitor
```bash
# Open serial monitor (115200 baud)
pio device monitor

# Or combine upload and monitor in one command
pio run --target upload --target monitor
```

#### Clean Build Files
```bash
# Clean build artifacts
pio run --target clean

# Full clean (including dependencies)
pio run --target fullclean
```

### Working with XMC_Reader (Main Application)

```bash
cd XMC_Reader

# Build, upload, and monitor in one command
pio run --target upload --target monitor

# Just build
pio run

# Upload only
pio run --target upload
```

### Working with XMC_EEPROM (Programmer)

```bash
cd XMC_EEPROM

# Build and upload EEPROM programmer
pio run --target upload --target monitor
```

## 🔐 System Operation

### XMC_Reader (Access Control)

The RFID reader validates cards against stored credentials in EEPROM:

1. **Startup**: Initializes MFRC522 reader and SPI communication
2. **Card Detection**: Continuously polls for ISO14443A cards
3. **Authentication**: 
   - Reads card UID
   - Performs RATS (Request for Answer To Select)
   - Selects application (AID: F0 00 00 0C DC 00)
   - Retrieves card ID via custom command
4. **Validation**: Compares card data with EEPROM stored credentials
5. **Access Control**:
   - **GRANTED**: Activates unlock signal for 5 seconds
   - **DENIED**: Returns to ready state

### XMC_EEPROM (Credential Programming)

Used to write authorized card credentials to EEPROM for validation.

## 🛠️ Configuration

### Modifying Library Dependencies

Edit `platformio.ini` to add/modify libraries:

```ini
[env:xmc4700_relax_kit]
platform = infineonxmc
board = xmc4700_relax_kit
framework = arduino
lib_deps = 
    computer991/Arduino_MFRC522v2@^2.0.1
    # Add more libraries here
monitor_speed = 115200
```

### Changing Upload Settings

```ini
# Specify upload protocol
upload_protocol = jlink

# Set upload port
upload_port = /dev/ttyUSB0

# Increase upload speed
upload_speed = 460800
```

## 🐛 Debugging

### Enable Verbose Output
```bash
# Verbose build
pio run -v

# Verbose upload
pio run --target upload -v
```

### Check Serial Output
```bash
# Monitor with specific baud rate
pio device monitor --baud 115200

# Filter serial output
pio device monitor --filter send_on_enter
```

### Common Issues

**Issue**: `Device not found`
- **Solution**: Check USB connection, ensure board is powered
- Run: `pio device list` to see connected devices

**Issue**: `Permission denied` on Linux
- **Solution**: Add user to dialout group
  ```bash
  sudo usermod -a -G dialout $USER
  # Then logout and login
  ```

**Issue**: `Firmware version 0x00 or 0xFF`
- **Solution**: MFRC522 not connected properly, check SPI wiring

## 📊 Serial Monitor Output

Expected output on successful card read:
```
==================================
   LAYR GUARDIAN - DEBUG MODE
==================================
[1] SPI Bus Started
[2] Reader Firmware Version: 0x92
Ready — present card...

Card UID: [16 bytes in HEX]

[ACCESS GRANTED]
```

## 🔄 Updating Dependencies

```bash
# Update all libraries
pio pkg update

# Update specific library
pio pkg update -l "Arduino_MFRC522v2"

# Update platform
pio pkg update -p infineonxmc
```

## 📚 Additional Resources

- [PlatformIO Documentation](https://docs.platformio.org/)
- [XMC4700 Relax Kit](https://www.infineon.com/cms/en/product/evaluation-boards/kit_xmc47_relax_v1/)
- [MFRC522 Datasheet](https://www.nxp.com/docs/en/data-sheet/MFRC522.pdf)
- [Arduino Framework for XMC](https://github.com/Infineon/XMC-for-Arduino)

## 📄 License

This project is provided as-is for educational and development purposes.

## 👤 Author

Hardware/Mechatronics Code Design Challenge

---

**Note**: Always ensure proper wiring and power supply before uploading firmware to prevent hardware damage.