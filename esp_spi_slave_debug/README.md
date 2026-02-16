# SPI Slave Debug Tool — ESP32-WROOM-32

Receives SPI transactions from your FPGA and dumps them over serial
with hex + binary waveform visualization.

## Wiring

Connect your FPGA SPI master to the ESP32 as follows:

```
 FPGA                ESP32-WROOM-32
┌──────┐            ┌──────────────┐
│ MOSI ├───────────►│ GPIO 13      │
│ MISO │◄───────────┤ GPIO 12      │
│ SCLK ├───────────►│ GPIO 14      │
│ CS   ├───────────►│ GPIO 15      │
│ GND  ├────────────┤ GND          │
└──────┘            └──────────────┘
```

**Important:** Make sure FPGA and ESP32 share a common GND.

If your FPGA uses 3.3V logic levels, you can connect directly.
If it uses different voltage levels, use a level shifter.

## Pin Customization

Edit the `#define` section at the top of `main/main.c`:

```c
#define PIN_MOSI    GPIO_NUM_13
#define PIN_MISO    GPIO_NUM_12
#define PIN_SCLK    GPIO_NUM_14
#define PIN_CS      GPIO_NUM_15
#define SPI_MODE_CFG    0       // Must match your FPGA's SPI mode
```

## Build & Flash

```bash
# Set your target
idf.py set-target esp32

# Build
idf.py build

# Flash & monitor (replace PORT with your serial port)
idf.py -p /dev/ttyUSB0 flash monitor
```

## Output Example

```
────────────────────────────────────────────────
Transaction #1  |  32 bits (4 bytes) received
────────────────────────────────────────────────
  Hex dump:
  0000: de ad be ef                                      |....|

  Bit view (MSB first):
  Byte | 7 6 5 4 3 2 1 0 | Hex  | Waveform
  -----+------------------+------+-----------------
     0 | 1 1 0 1 1 1 1 0 | 0xde | ██████▁▁████████▁▁
     1 | 1 0 1 0 1 1 0 1 | 0xad | ██▁▁██▁▁████▁▁██
     2 | 1 0 1 1 1 1 1 0 | 0xbe | ██▁▁██████████▁▁
     3 | 1 1 1 0 1 1 1 1 | 0xef | ██████▁▁████████
────────────────────────────────────────────────
```

The "Waveform" column shows a visual representation of each bit:
- `██` (full block) = logic HIGH
- `▁▁` (low block)  = logic LOW

## SPI Mode Reference

| Mode | CPOL | CPHA | Clock Idle | Data Sampled |
|------|------|------|------------|--------------|
| 0    | 0    | 0    | Low        | Rising edge  |
| 1    | 0    | 1    | Low        | Falling edge |
| 2    | 1    | 0    | High       | Falling edge |
| 3    | 1    | 1    | High       | Rising edge  |

## Troubleshooting

- **No transactions received:** Check CS is wired correctly and is being driven low by the FPGA.
- **Garbage data:** SPI mode mismatch — try modes 0-3 until data looks correct.
- **Missing bytes:** Increase `SPI_BUF_SIZE` if your transactions are larger than 128 bytes.
- **DMA errors:** Ensure buffers are word-aligned (the `WORD_ALIGNED_ATTR` macro handles this).
