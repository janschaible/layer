"""
test_eeprom.py  –  End-to-end cocotb tests for the eeprom_spi FSM.

DUT chain
---------
cocotb drives:
    dut.cmd_valid / cmd_write / cmd_addr / cmd_wdata

Through RTL:
    eeprom_spi  →  axi_lite_master  →  axi_spi_master  →  SPI pins

AT25010B_EEPROM mock receives SPI and responds on:
    spi_clk / spi_csn0 / spi_sdo0 (MOSI) / spi_sdi0 (MISO)

Signal naming in tb_top
-----------------------
    dut.clk, dut.rst_n
    dut.cmd_valid, dut.cmd_write, dut.cmd_addr, dut.cmd_wdata
    dut.cmd_rdata, dut.cmd_done, dut.cmd_busy
    dut.spi_clk, dut.spi_csn0, dut.spi_sdo0, dut.spi_sdi0

SpiBus construction
-------------------
axi_spi_master drives MOSI on spi_sdo0 and reads MISO on spi_sdi0.
From the EEPROM mock's perspective:
    sclk  = dut.spi_clk
    cs    = dut.spi_csn0   (active-low)
    mosi  = dut.spi_sdo0   (master→slave)
    miso  = dut.spi_sdi0   (slave→master)
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, First
import os
from pathlib import Path
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "cocotbext-spi"))
from cocotbext.spi import SpiBus, SpiConfig, SpiSlaveBase
from cocotb_tools.runner import get_runner

# Simple SPI Slave


class SimpleSpiSlave(SpiSlaveBase):
    def __init__(self, bus):
        self._config = SpiConfig()
        self.content = 0
        super().__init__(bus)

    async def get_content(self):
        await self.idle.wait()
        return self.content

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        self.content = int(await self._shift(8, tx_word=(0xAA)))

        await frame_end


# ──────────────────────────────────────────────────────────────────────────────
# Constants matching eeprom_spi / axi_spi_master configuration
# ──────────────────────────────────────────────────────────────────────────────
CLK_PERIOD_NS = 10  # 100 MHz
RESET_CYCLES = 5
# Worst-case cycles to complete one full EEPROM transaction:
#   ~16 FSM states × a few AXI cycles each + SPI clocking
TRANSACTION_TIMEOUT_US = 500

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────


def build_spi_bus(dut) -> SpiBus:
    """
    Build a SpiBus from the tb_top SPI port using custom signal names.

    The SpiBus.from_entity() method automatically finds signals by name,
    so we tell it the actual signal names used in eeprom_wire_modules.sv.
    """
    return SpiBus.from_entity(
        dut,
        sclk_name="spi_clk",
        mosi_name="spi_sdo0",
        miso_name="spi_sdi0",
        cs_name="spi_csn0",
    )


async def reset_dut(dut):
    """Assert reset for RESET_CYCLES, then release and wait for init."""
    dut.rst_n.value = 1

    # TODO: set sensible defaults
    dut.req_addr_i.value = 0x0
    dut.req_wdata_i.value = 0x0
    dut.req_cs_i.value = 0x0
    dut.req_write_i.value = 0x0
    dut.req_valid_i.value = 0x0

    for _ in range(RESET_CYCLES):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 0

    # Wait for the one-time SPI clock-divider init to complete.
    # The eeprom_spi FSM starts in S_INIT_CLKDIV and transitions to S_IDLE
    # after the AXI write finishes (~8-10 cycles).  cmd_busy is NOT asserted
    # during init states, but we need to let the AXI transaction finish so
    # the SPI clock divider is properly configured before any user commands.
    for _ in range(50):
        await RisingEdge(dut.clk)


async def wait_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if int(dut.resp_done_o.value):
            return
        if int(dut.resp_error_o.value):
            raise RuntimeError("AXI error")
    raise TimeoutError("wait_done() timed out")

# ──────────────────────────────────────────────────────────────────────────────
# Common fixture: start clock + reset + attach EEPROM mock
# ──────────────────────────────────────────────────────────────────────────────


async def setup(dut):
    """,
    Start the simulation clock, reset the DUT, and attach the EEPROM mock.
    Returns the mock so tests can pre-load / inspect memory.
    """
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, unit="ns").start())
    # slave = SimpleSpiSlave(build_spi_bus(dut))
    await reset_dut(dut)
    return
    return slave


# ──────────────────────────────────────────────────────────────────────────────
# Constants for axi_spi_master Register Offsets
# ──────────────────────────────────────────────────────────────────────────────
REG_STATUS = 0x00  # [cite: 98]
REG_CLKDIV = 0x04  # [cite: 98]
REG_SPICMD = 0x08  # [cite: 98]
REG_SPIADR = 0x0C  # [cite: 98]
REG_SPILEN = 0x10  # [cite: 98]
TX_FIFO = 0x20  # Bit 3 of address high selects TX FIFO [cite: 137, 297]

async def axi_write(dut, addr, data, cs=0):
    dut.req_addr_i.value = addr
    dut.req_wdata_i.value = data
    dut.req_cs_i.value = cs
    dut.req_write_i.value = 1
    dut.req_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.req_valid_i.value = 0
    dut._log.info(f"axi_write(addr=0x{addr:02x}, data=0x{data:08x}) dispatched")


async def send_byte(dut, data_byte: int):
    # 1) Set command length (0 for simple SPI)
    dut._log.info("send_byte: writing SPICMD...")
    await axi_write(dut, REG_SPICMD, 0, cs=0)
    await wait_done(dut)
    dut._log.info("send_byte: SPICMD done")

    # 2) Set address length (0 for simple SPI)
    dut._log.info("send_byte: writing SPIADR...")
    await axi_write(dut, REG_SPIADR, 0, cs=0)
    await wait_done(dut)
    dut._log.info("send_byte: SPIADR done")

    # 3) Set data length: 8 data bits, 0 addr, 0 cmd
    dut._log.info("send_byte: writing SPILEN...")
    await axi_write(dut, REG_SPILEN, (8 << 16), cs=0)
    await wait_done(dut)
    dut._log.info("send_byte: SPILEN done")

    # 4) Write TX FIFO (MSB-aligned!)
    dut._log.info("send_byte: writing TX_FIFO...")
    await axi_write(dut, TX_FIFO, (data_byte & 0xFF) << 24, cs=0)
    await wait_done(dut)
    dut._log.info("send_byte: TX_FIFO done")

    # 5) Trigger transfer: STATUS bit1 = spi_wr
    dut._log.info("send_byte: writing STATUS (spi_wr)...")
    await axi_write(dut, REG_STATUS, 0x2, cs=0)
    dut._log.info("send_byte: STATUS write dispatched, waiting for done...")
    await wait_done(dut)
    dut._log.info("send_byte: STATUS done")


async def axi_read(dut, addr, cs=0):
    dut.req_addr_i.value  = addr
    dut.req_cs_i.value    = cs
    dut.req_write_i.value = 0
    dut.req_valid_i.value = 1
    await RisingEdge(dut.clk)
    dut.req_valid_i.value = 0
    await wait_done(dut)
    return int(dut.resp_rdata_o.value)


async def wait_spi_idle(dut, max_cycles=20000):
    for _ in range(max_cycles):
        s = await axi_read(dut, REG_STATUS)
        # spi_status[2:0] is the controller state encoding in this IP
        # In your earlier wave it looked like idle = 1. Confirm once and keep it.
        if (s & 0x7) == 1:
            return
    raise TimeoutError("SPI never returned to IDLE")

@cocotb.test(timeout_time=60, timeout_unit="sec")
async def test_send_byte(dut):
    """Verify that a byte can be sent to the mock EEPROM."""
    
    async def watchdog():
        await Timer(800, "ns")   # pick something reasonable for your sim speed
        raise TimeoutError("WATCHDOG: test hung")

    cocotb.start_soon(watchdog())
    await setup(dut)
    await RisingEdge(dut.clk)

    # Send 0xAD to the SPI bus
    await send_byte(dut, 0xAD)
    # await wait_spi_idle(dut)

    # Wait for the physical SPI hardware to return to IDLE.
    # Because AXI finishes before the SPI pins stop toggling,
    # we need a small delay or we must poll the STATUS register.
    for _ in range(200):
        await RisingEdge(dut.clk)

    # content = await slave.get_content()
    # Mock returns 0xAAAA based on its code; verify it received something
    # assert content != 0

def test_axi_spi_e2e_runner():
    """
    End-to-end test runner for eeprom_spi + axi_lite_master + axi_spi_master.

    This builds the full RTL hierarchy (all three modules + tb_top wrapper)
    and runs all tests in test_eeprom.py.
    """
    sim = os.getenv("SIM", "icarus")
    spi_module_path = Path(__file__).resolve().parent.parent.parent

    src_dir = spi_module_path / "src"

    axi_spi_ip_dir = src_dir / "axi_spi_master"

    # All RTL sources
    # IMPORTANT: axi_spi_master depends on several sub-modules from the PULP repo.
    # List them explicitly OR use a glob if they're all in rtl/
    sources = [
        # Your modules
        src_dir / "axi_lite_master.sv",
        # PULP axi_spi_master + all dependencies
        # (adjust filenames to match what you actually have)
        axi_spi_ip_dir / "axi_spi_master.sv",
        axi_spi_ip_dir / "spi_master_axi_if.sv",
        axi_spi_ip_dir / "spi_master_controller.sv",
        axi_spi_ip_dir / "spi_master_fifo.sv",
        axi_spi_ip_dir / "spi_master_clkgen.sv",
        axi_spi_ip_dir / "spi_master_rx.sv",
        axi_spi_ip_dir / "spi_master_tx.sv",
        # Testbench top-level wrapper
        spi_module_path / "test" / "test_axi_spi" / "axi_spi_test_wiring.sv",
    ]

    # Filter out any files that don't exist (in case PULP naming differs)
    sources = [s for s in sources if s.exists()]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="axi_spi_test_wiring",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(
        hdl_toplevel="axi_spi_test_wiring",
        test_module="test_axi_spi_e2e",
        waves=True,
    )


if __name__ == "__main__":
    test_axi_spi_e2e_runner()
