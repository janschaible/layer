/**
 * SPI Slave Debug Tool for ESP32-WROOM-32
 * 
 * Receives SPI data from an FPGA (or any SPI master) and dumps it
 * over UART/serial for debugging.
 * 
 * Default SPI pin mapping (directly directly directly directly):
 *   MOSI  -> GPIO 13
 *   MISO  -> GPIO 12
 *   SCLK  -> GPIO 14
 *   CS    -> GPIO 15
 * 
 * Output modes:
 *   - HEX dump with transaction index and length
 *   - Binary bit-level view (for waveform-like inspection)
 *   - Configurable via menuconfig or #defines below
 * 
 * Built for ESP-IDF v5.x
 */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/spi_slave.h"
#include "driver/gpio.h"
#include "esp_log.h"

/* ──────────────────────────────────────────────
 * Configuration — adjust to match your FPGA
 * ────────────────────────────────────────────── */

// SPI pins (directly directly directly directly directly)
#define PIN_MOSI    GPIO_NUM_13
#define PIN_MISO    GPIO_NUM_12
#define PIN_SCLK    GPIO_NUM_14
#define PIN_CS      GPIO_NUM_15

// SPI mode (0-3). Must match what the FPGA master sends.
// Mode 0: CPOL=0, CPHA=0  (most common)
// Mode 1: CPOL=0, CPHA=1
// Mode 2: CPOL=1, CPHA=0
// Mode 3: CPOL=1, CPHA=1
#define SPI_MODE_CFG    0

// Max bytes per SPI transaction
#define SPI_BUF_SIZE    128

// Number of queued transactions
#define SPI_QUEUE_SIZE  6

// Output format
#define OUTPUT_HEX      1   // Print hex dump
#define OUTPUT_BINARY   1   // Print binary bit view (waveform-like)
#define OUTPUT_ASCII    1   // Print ASCII alongside hex

static const char *TAG = "spi_slave_dbg";

/* ──────────────────────────────────────────────
 * DMA-capable buffers (must be word-aligned)
 * ────────────────────────────────────────────── */
WORD_ALIGNED_ATTR uint8_t rx_buf[SPI_BUF_SIZE] = {0};
WORD_ALIGNED_ATTR uint8_t tx_buf[SPI_BUF_SIZE] = {0};

/* ──────────────────────────────────────────────
 * Pretty-print helpers
 * ────────────────────────────────────────────── */

/**
 * Print a separator line
 */
static void print_separator(void)
{
    printf("────────────────────────────────────────────────\n");
}

/**
 * Print hex dump of a buffer, 16 bytes per line
 */
static void print_hex_dump(const uint8_t *buf, size_t len)
{
    for (size_t i = 0; i < len; i += 16) {
        // Offset
        printf("  %04x: ", (unsigned)i);

        // Hex bytes
        for (size_t j = 0; j < 16; j++) {
            if (i + j < len) {
                printf("%02x ", buf[i + j]);
            } else {
                printf("   ");
            }
            if (j == 7) printf(" ");
        }

#if OUTPUT_ASCII
        // ASCII representation
        printf(" |");
        for (size_t j = 0; j < 16 && (i + j) < len; j++) {
            uint8_t c = buf[i + j];
            printf("%c", (c >= 0x20 && c <= 0x7e) ? c : '.');
        }
        printf("|");
#endif
        printf("\n");
    }
}

/**
 * Print binary bit view — gives a waveform-like visualization
 * Shows each byte as 8 bits with visual high/low representation
 */
static void print_binary_view(const uint8_t *buf, size_t len)
{
    printf("  Bit view (MSB first):\n");

    // Print bit index header
    printf("  Byte | 7 6 5 4 3 2 1 0 | Hex  | Waveform\n");
    printf("  -----+------------------+------+-----------------\n");

    for (size_t i = 0; i < len; i++) {
        uint8_t b = buf[i];

        // Byte index
        printf("  %4u | ", (unsigned)i);

        // Individual bits
        for (int bit = 7; bit >= 0; bit--) {
            printf("%c ", (b & (1 << bit)) ? '1' : '0');
        }

        // Hex value
        printf("| 0x%02x | ", b);

        // Visual waveform: use block chars for high/low
        for (int bit = 7; bit >= 0; bit--) {
            if (b & (1 << bit)) {
                printf("\u2588\u2588"); // Full block = HIGH
            } else {
                printf("\u2581\u2581"); // Lower block = LOW
            }
        }
        printf("\n");
    }
}

/* ──────────────────────────────────────────────
 * Callbacks (called from ISR context)
 * ────────────────────────────────────────────── */

/**
 * Called after a transaction is queued but before it starts.
 * Use this to set up TX data if needed.
 */
static void IRAM_ATTR spi_post_setup_cb(spi_slave_transaction_t *trans)
{
    // You could toggle a GPIO here for scope triggering
}

/**
 * Called after a transaction completes.
 */
static void IRAM_ATTR spi_post_trans_cb(spi_slave_transaction_t *trans)
{
    // You could toggle a GPIO here for scope triggering
}

/* ──────────────────────────────────────────────
 * Main
 * ────────────────────────────────────────────── */
void app_main(void)
{
    ESP_LOGI(TAG, "=== SPI Slave Debug Tool ===");
    ESP_LOGI(TAG, "Pin config: MOSI=%d  MISO=%d  SCLK=%d  CS=%d",
             PIN_MOSI, PIN_MISO, PIN_SCLK, PIN_CS);
    ESP_LOGI(TAG, "SPI Mode: %d  |  Buffer size: %d bytes", SPI_MODE_CFG, SPI_BUF_SIZE);
    ESP_LOGI(TAG, "Waiting for SPI transactions from master...\n");

    // Enable pull-up on CS so it doesn't float
    gpio_set_pull_mode(PIN_CS, GPIO_PULLUP_ONLY);

    // Bus configuration
    spi_bus_config_t buscfg = {
        .mosi_io_num   = PIN_MOSI,
        .miso_io_num   = PIN_MISO,
        .sclk_io_num   = PIN_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = SPI_BUF_SIZE,
    };

    // Slave interface configuration
    spi_slave_interface_config_t slvcfg = {
        .spics_io_num   = PIN_CS,
        .flags          = 0,
        .queue_size     = SPI_QUEUE_SIZE,
        .mode           = SPI_MODE_CFG,
        .post_setup_cb  = spi_post_setup_cb,
        .post_trans_cb  = spi_post_trans_cb,
    };

    // Initialize SPI slave on HSPI (SPI2)
    esp_err_t ret = spi_slave_initialize(SPI2_HOST, &buscfg, &slvcfg, SPI_DMA_CH_AUTO);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SPI slave init failed: %s", esp_err_to_name(ret));
        return;
    }
    ESP_LOGI(TAG, "SPI slave initialized successfully on SPI2_HOST");

    // Optionally pre-fill TX buffer with a known pattern
    // (useful if the master also reads data back)
    memset(tx_buf, 0xAA, SPI_BUF_SIZE);

    uint32_t transaction_count = 0;

    while (1) {
        // Prepare the transaction descriptor
        spi_slave_transaction_t trans = {
            .length    = SPI_BUF_SIZE * 8,  // length is in BITS
            .tx_buffer = tx_buf,
            .rx_buffer = rx_buf,
        };

        // Clear RX buffer before each transaction
        memset(rx_buf, 0, SPI_BUF_SIZE);

        // Wait for a transaction from the master (blocks indefinitely)
        ret = spi_slave_transmit(SPI2_HOST, &trans, portMAX_DELAY);
        if (ret != ESP_OK) {
            ESP_LOGE(TAG, "SPI transaction error: %s", esp_err_to_name(ret));
            continue;
        }

        // Calculate actual bytes received
        size_t bits_received = trans.trans_len;  // actual bits transferred
        size_t bytes_received = (bits_received + 7) / 8;

        if (bytes_received == 0) {
            continue;  // empty transaction, skip
        }

        // ── Print transaction info ──
        transaction_count++;
        printf("\n");
        print_separator();
        printf("Transaction #%lu  |  %u bits (%u bytes) received\n",
               (unsigned long)transaction_count,
               (unsigned)bits_received,
               (unsigned)bytes_received);
        print_separator();

#if OUTPUT_HEX
        printf("  Hex dump:\n");
        print_hex_dump(rx_buf, bytes_received);
        printf("\n");
#endif

#if OUTPUT_BINARY
        print_binary_view(rx_buf, bytes_received);
#endif

        print_separator();
        printf("\n");

        // Flush stdout to ensure immediate display
        fflush(stdout);
    }
}
