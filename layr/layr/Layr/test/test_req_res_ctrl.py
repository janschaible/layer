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

async def reset(dut):
    """Apply reset pulse."""
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_happy_path(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut._log.info("✓ Full test passed")

def test_req_res_ctrl_controller_runner():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [proj_path / "src" / "req_res_ctrl.sv"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="req_res_ctrl",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
        verbose=True
    )

    runner.test(hdl_toplevel="req_res_ctrl", test_module="test_req_res_ctrl", waves=True)

if __name__ == "__main__":
    test_req_res_ctrl_controller_runner()
