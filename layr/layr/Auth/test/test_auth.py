"""
Modern cocotb 2.0 testbench for the Controller module.
Uses async/await syntax and modern pythonic patterns.
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.types import LogicArray

from cocotb_tools.runner import get_runner
import random

os.environ["COCOTB_ANSI_OUTPUT"] = "1"


class AuthInitTester:
    """Helper class for auth_init testing."""

    def __init__(self, dut):
        self.dut = dut

        # Inputs
        self.clk = dut.clk
        self.rst = dut.rst
        self.busy = dut.busy
        self.done = dut.done

        # Outputs
        self.cs = dut.cs
        self.we = dut.we
        self.aes_address = dut.aes_address
        self.write_data = dut.write_data


class AuthGenerateChallengeTester:
    """Helper class for auth_generate_challenge testing."""

    def __init__(self, dut):
        self.dut = dut

        # Inputs
        self.clk = dut.clk
        self.rst = dut.rst
        self.external_ready = dut.external_ready
        self.external_valid = dut.external_valid
        self.input_cipher = dut.input_cipher

        # Outputs
        self.error = dut.error
        self.internal_ready = dut.internal_ready
        self.internal_valid = dut.internal_valid
        self.challenge_response = dut.challenge_response


class AuthVerifyIdTester:
    """Helper class for auth_verify_id testing."""

    def __init__(self, dut):
        self.dut = dut

        # Inputs
        self.clk = dut.clk
        self.rst = dut.rst
        self.external_valid = dut.external_valid
        self.id_cipher = dut.id_cipher
        self.rc = dut.rc
        self.rt = dut.rt

        # Outputs
        self.error = dut.error
        self.success = dut.success
        self.internal_ready = dut.internal_ready


@cocotb.test()
async def test_auth_init(dut):
    """Test: Check the basic functionality"""
    tester = AuthInitTester(dut)
    dut._log.info("✓ No tests implemented.")


async def test_auth_generate_challenge(dut):
    """Test: Check the basic functionality"""
    tester = AuthGenerateChallengeTester(dut)
    dut._log.info("✓ No tests implemented.")


async def test_auth_verify_id(dut):
    """Test: Check the basic functionality"""
    tester = AuthVerifyIdTester(dut)
    dut._log.info("✓ No tests implemented.")


def test_auth():
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "src" / "auth_init.sv",
        proj_path / "src" / "auth_generate_challenge.sv",
        proj_path / "src" / "auth_verify_id.sv",
    ]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="auth",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(
        hdl_toplevel="auth", test_module="auth", waves=True
    )


if __name__ == "__main__":
    test_auth()
