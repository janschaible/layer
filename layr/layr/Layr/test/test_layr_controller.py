"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, FallingEdge, RisingEdge, NextTimeStep, ReadOnly
from cocotb.types import LogicArray

from cocotb_tools.runner import get_runner

os.environ['COCOTB_ANSI_OUTPUT'] = '1'


@cocotb.test()
async def test_happy_path(dut):
    """Test: verify happy path."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.start = 1
    await RisingEdge(dut.clk)
    assert dut.initialize_auth == 1, "Should start by initializing the auth"


    dut._log.info("✓ Full test passed")

def test_bcd_converter_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "src" / "layr_controller.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="layr_controller",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(hdl_toplevel="layr_controller", test_module="test_layr_controller", waves=True)

if __name__ == "__main__":
    test_bcd_converter_runner()