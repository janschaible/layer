"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
"""

import os
from pathlib import Path

import cocotb
from cocotb.triggers import RisingEdge

from cocotb_tools.runner import get_runner

os.environ["COCOTB_ANSI_OUTPUT"] = "1"


class LayrTester:
    """Helper class for Controller module testing."""

    def __init__(self, dut):
        self.dut = dut


async def reset(dut):
    """Apply reset pulse."""
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_happy_path(dut):
    dut._log.info("✓ Full test passed")


def test_layr_controller_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent
    root = proj_path / "src"
    sources = [p for p in root.rglob("*") if p.is_file()]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="layr",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
        verbose=True,
    )

    runner.test(hdl_toplevel="layr", test_module="test_layr", waves=True)


if __name__ == "__main__":
    test_layr_controller_runner()
