"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
"""

import os
from pathlib import Path

import secrets
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge, NextTimeStep, ReadOnly
from cocotb.types import LogicArray


from cocotb_tools.runner import get_runner

os.environ['COCOTB_ANSI_OUTPUT'] = '1'

async def reset(dut):
    """Apply reset pulse."""
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_transmission_mode_cannot_be_changed_when_running(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)
    challenge = secrets.token_bytes(16)
    expected = int.from_bytes(0x08011000010.to_bytes(5, byteorder="big") + challenge, byteorder="big")

    dut.auth.value = 1
    dut.card_challenge_rc.value = int.from_bytes(challenge, byteorder="big")
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.state.value == 1, "Expected the fsm to be in sending state"
    assert dut.active_transmission.value == 1, "Expected active transmission to be of type auth"
    assert dut.command.value == expected, f"Expected the value to be {bin(expected)}"

    dut.auth_init.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    assert dut.state.value == 1, "Expected the fsm to still be in sending state"
    assert dut.active_transmission.value == 1, "Expected active transmission to still be of type auth"
    assert dut.command.value == expected

    dut._log.info("✓ Full test passed")

def test_command_mux_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "src" / "command_mux.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="command_mux",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
        verbose=True
    )

    runner.test(hdl_toplevel="command_mux", test_module="test_command_mux", waves=True)

if __name__ == "__main__":
    test_command_mux_runner()
