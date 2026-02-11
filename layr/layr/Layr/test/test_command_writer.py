"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
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

@cocotb.test()
async def test_auth_init_send(dut):
    """Test that auth_init sends CLA and INS correctly on trigger."""
    
    # Start the clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    await reset_dut(dut)

    # Initial setup
    dut.start.value = 0
    # Pack bytes: byte 0 in bits [7:0], byte 1 in [15:8]
    cla = 0xAA
    ins = 0x55
    dut.data_in.value = cla | (ins << 8)
    dut.tx_ready.value = 1  # receiver ready

    await RisingEdge(dut.clk)

    # Trigger sending
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0  # pulse start

    # Wait for CLA to be sent
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    assert dut.tx.value == 0xAA, f"CLA not sent correctly, got {dut.tx.value}"
    assert dut.tx_last.value == 0, "CLA should not be marked as last"

    # Simulate receiver accepting CLA
    await RisingEdge(dut.clk)
    assert dut.tx_valid.value == 0, "tx_valid should go low after CLA accepted"

    # Wait for INS to be sent
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    assert dut.tx.value == 0x55, f"INS not sent correctly, got {dut.tx.value}"
    assert dut.tx_last.value == 1, "INS should be marked as last"

    # Simulate receiver accepting INS
    await RisingEdge(dut.clk)
    assert dut.tx_valid.value == 0, "tx_valid should go low after INS accepted"

    dut._log.info("✓ auth_init CLA/INS send test passed")

@cocotb.test()
async def test_auth_init_multiple_triggers(dut):
    """Test multiple triggers of auth_init."""
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.tx_ready.value = 1

    # First trigger
    cla1 = 0x10
    ins1 = 0x20
    dut.data_in.value = cla1 | (ins1 << 8)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for CLA
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # accept CLA
    assert dut.tx_valid.value == 0, "tx_valid should go low after first CLA accepted"

    # Wait for INS
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)  # accept INS
    assert dut.tx_last.value == 1, "First trigger INS should be marked as last"

    # Second trigger with new bytes
    cla2 = 0x33
    ins2 = 0x44
    dut.data_in.value = cla2 | (ins2 << 8)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for CLA
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    assert dut.tx.value == 0x33, f"Second CLA not sent correctly, got {dut.tx.value}"
    await RisingEdge(dut.clk)
    assert dut.tx_valid.value == 0, "tx_valid should go low after second CLA accepted"

    # Wait for INS
    while not dut.tx_valid.value:
        await RisingEdge(dut.clk)
    assert dut.tx.value == 0x44, f"Second INS not sent correctly, got {dut.tx.value}"
    assert dut.tx_last.value == 1, "Second trigger INS should be marked as last"

    dut._log.info("✓ auth_init multiple trigger test passed")

def test_command_writer():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "src" / "command_writer.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="command_writer",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(hdl_toplevel="command_writer", test_module="test_command_writer", waves=True)

if __name__ == "__main__":
    test_command_writer()