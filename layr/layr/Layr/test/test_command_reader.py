"""
Cocotb testbench for the command_reader module.
Receives a fixed number of bytes and assembles them into a packed bus.
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb_tools.runner import get_runner


async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst.value = 1
    await Timer(2, unit="ns")
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_byte(dut, value, last=False):
    """Drive a single byte on rx with a one-cycle rx_valid pulse."""
    dut.rx.value = value
    dut.rx_last.value = int(last)
    dut.rx_valid.value = 1
    await RisingEdge(dut.clk)
    dut.rx_valid.value = 0
    dut.rx_last.value = 0


@cocotb.test()
async def test_single_command_two_bytes(dut):
    """Receive a two-byte command and assemble it correctly."""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    # Clear inputs
    dut.rx_valid.value = 0
    dut.rx.value = 0
    dut.rx_last.value = 0

    # Send two bytes: byte0 = 0xAA, byte1 = 0x55
    byte0 = 0xAA
    byte1 = 0x55

    await send_byte(dut, byte0, last=False)
    await send_byte(dut, byte1, last=True)

    # Wait until data_valid is asserted
    while not dut.data_valid.value:
        await RisingEdge(dut.clk)

    expected = byte0 | (byte1 << 8)
    assert int(dut.data_out.value) == expected, (
        f"Assembled command incorrect: got 0x{int(dut.data_out.value):04X}, "
        f"expected 0x{expected:04X}"
    )

    dut._log.info("✓ command_reader two-byte receive test passed")


@cocotb.test()
async def test_multiple_commands(dut):
    """Receive two back-to-back commands."""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.rx_valid.value = 0
    dut.rx.value = 0
    dut.rx_last.value = 0

    async def send_command(b0, b1):
        await send_byte(dut, b0, last=False)
        await send_byte(dut, b1, last=True)
        while not dut.data_valid.value:
            await RisingEdge(dut.clk)

    # First command
    c1_b0, c1_b1 = 0x10, 0x20
    await send_command(c1_b0, c1_b1)
    expected1 = c1_b0 | (c1_b1 << 8)
    assert int(dut.data_out.value) == expected1

    # Second command
    c2_b0, c2_b1 = 0x33, 0x44
    await send_command(c2_b0, c2_b1)
    expected2 = c2_b0 | (c2_b1 << 8)
    assert int(dut.data_out.value) == expected2

    dut._log.info("✓ command_reader multiple-command test passed")


def test_command_reader():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "src" / "command_reader.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="command_reader",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(
        hdl_toplevel="command_reader", test_module="test_command_reader", waves=True
    )


if __name__ == "__main__":
    test_command_reader()
