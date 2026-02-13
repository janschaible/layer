"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from cocotb_tools.runner import get_runner

os.environ["COCOTB_ANSI_OUTPUT"] = "1"


async def reset(dut):
    """Apply reset pulse."""
    dut.generate_challenge.value = 0

    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_generating_multiple_challenges(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    for _ in range(3):
        dut.generate_challenge.value = 1
        for _ in range(20):
            await RisingEdge(dut.clk)

        assert dut.chip_challenge_generated.value == 1, (
            "Expected the challenge to be generated"
        )
        assert dut.chip_challenge.value == 2**128 - 1, "Expected valid challenge"

        await reset(dut)
        assert dut.chip_challenge_generated.value == 0, (
            "Expected the challenge generated to be reset"
        )
        assert dut.chip_challenge.value == 0, "Expected challenge to be reset"


def test_layr_auth_controller_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent
    root = proj_path / "src"
    sources = [p for p in root.rglob("*") if p.is_file()]
    mocks = proj_path / "test" / "mocks"
    sources += [p for p in mocks.rglob("*") if p.is_file()]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="layr_auth",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
        verbose=True,
    )

    runner.test(hdl_toplevel="layr_auth", test_module="test_layr_auth", waves=True)


if __name__ == "__main__":
    test_layr_auth_controller_runner()
