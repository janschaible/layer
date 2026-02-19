from __future__ import annotations

import os
import re
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout
from cocotb_tools.runner import get_runner
from cocotbext.spi import SpiBus

from mfrc522_mock import MFRC522Mock


def _bytes_to_int(byte_list: list[int]) -> int:
    val = 0
    for b in byte_list:
        val = (val << 8) | (b & 0xFF)
    val <<= (32 - len(byte_list)) * 8
    return val


def _find_serial_log() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        candidate = parent / "arduino" / "mrfc522_rats_simplified" / "serial_log.txt"
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "Could not locate arduino/mrfc522_rats_simplified/serial_log.txt"
    )


def _parse_golden_trace() -> list[tuple[str, int, int]]:
    text = _find_serial_log().read_text(errors="ignore")

    start_init = text.find("--- MFRC522 Soft Reset ---")
    end_init = text.find("Ready")
    first_select = text.find(">>> PICC_ReadCardSerial <<<")
    start_activation = text.rfind(">>> PICC_IsNewCardPresent <<<", 0, first_select)
    end = text.find(">>> doRATS <<<")
    if start_init == -1 or end_init == -1 or start_activation == -1 or end == -1:
        raise RuntimeError("Could not find golden activation window in serial log")
    window = text[start_init:end_init] + text[start_activation:end]

    pattern = re.compile(
        r"\[SPI-(WR|RD)\] TX: 0x([0-9A-F]{2}) 0x([0-9A-F]{2})\s+(?:RX: 0x([0-9A-F]{2}))?",
        re.IGNORECASE,
    )

    trace: list[tuple[str, int, int]] = []
    for m in pattern.finditer(window):
        kind = m.group(1).upper()
        tx0 = int(m.group(2), 16)
        if kind == "WR":
            tx1 = int(m.group(3), 16)
            trace.append(("W", tx0, tx1))
        else:
            rx0 = int(m.group(4), 16)
            trace.append(("R", tx0, rx0))

    # Ignore polling variability.
    filtered = [t for t in trace if not (t[0] == "R" and t[1] == 0x88)]
    return filtered


def _is_subsequence(
    expected: list[tuple[str, int, int]], observed: list[tuple[str, int, int]]
) -> bool:
    i = 0
    for item in observed:
        if i < len(expected) and item == expected[i]:
            i += 1
    return i == len(expected)


def _normalize_for_compare(
    trace: list[tuple[str, int, int]],
) -> list[tuple[str, int, int | None]]:
    normalized: list[tuple[str, int, int | None]] = []
    for kind, addr, val in trace:
        if kind == "W":
            normalized.append((kind, addr, val))
        else:
            normalized.append((kind, addr, None))
    return normalized


def _is_subsequence_relaxed(
    expected: list[tuple[str, int, int | None]],
    observed: list[tuple[str, int, int | None]],
) -> bool:
    return _match_progress(expected, observed) == len(expected)


def _match_progress(
    expected: list[tuple[str, int, int | None]],
    observed: list[tuple[str, int, int | None]],
) -> int:
    i = 0
    for okind, oaddr, oval in observed:
        if i >= len(expected):
            break
        ekind, eaddr, eval_ = expected[i]
        if okind != ekind or oaddr != eaddr:
            continue
        if eval_ is None or oval == eval_:
            i += 1
    return i


async def _reset(dut):
    dut.rst.value = 1
    dut.eeprom_start.value = 0
    dut.eeprom_get_key.value = 0
    dut.mfrc_tx_valid.value = 0
    dut.mfrc_tx_len.value = 0
    dut.mfrc_tx_data.value = 0
    dut.mfrc_tx_last_bits.value = 0
    dut.spi_miso.value = 0

    for _ in range(8):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    for _ in range(8):
        await RisingEdge(dut.clk)


@cocotb.test()
async def test_activation_trace_matches_golden(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    spi_bus = SpiBus.from_entity(
        dut,
        sclk_name="spi_sclk",
        mosi_name="spi_mosi",
        miso_name="spi_miso",
        cs_name="cs_0",
    )
    mfrc = MFRC522Mock(spi_bus)

    await _reset(dut)

    await with_timeout(RisingEdge(dut.mfrc_init_done), 2, "ms")
    await with_timeout(RisingEdge(dut.mfrc_card_present), 4, "ms")

    assert int(dut.mfrc_atqa.value) == 0x0800, (
        f"Unexpected ATQA {int(dut.mfrc_atqa.value):#06x}"
    )

    saw_coll = False
    for _ in range(400000):
        await RisingEdge(dut.clk)
        if ("W", 0x1C, 0x80) in mfrc.trace:
            saw_coll = True
            break
    assert saw_coll, "Activation did not reach anticollision step"

    saw_rats = False
    for _ in range(400000):
        await RisingEdge(dut.clk)
        trace = mfrc.trace
        for i in range(len(trace) - 1):
            if trace[i] == ("W", 0x12, 0xE0) and trace[i + 1] == ("W", 0x12, 0x50):
                saw_rats = True
                break
        if saw_rats:
            break
    assert saw_rats, "RATS payload (E0 50) was not observed on FIFO writes"

    saw_post_rats = False
    for _ in range(200000):
        await RisingEdge(dut.clk)
        if ("W", 0x56, 0x3E) in mfrc.trace:
            saw_post_rats = True
            break
    assert saw_post_rats, "Post-RATS timer configuration write was not observed"

    observed = [t for t in mfrc.trace if not (t[0] == "R" and t[1] == 0x88)]
    golden = [
        ("W", 0x02, 0x0F),
        ("R", 0x82, 0x20),
        ("W", 0x24, 0x00),
        ("W", 0x26, 0x00),
        ("W", 0x48, 0x26),
        ("W", 0x54, 0x80),
        ("W", 0x56, 0xA9),
        ("W", 0x58, 0x03),
        ("W", 0x5A, 0xE8),
        ("W", 0x2A, 0x40),
        ("W", 0x22, 0x3D),
        ("R", 0xEE, 0x92),
        ("W", 0x12, 0x26),
        ("W", 0x1C, 0x80),
        ("W", 0x12, 0x93),
        ("W", 0x12, 0x20),
        ("W", 0x0A, 0x04),
        ("R", 0xC4, 0x00),
        ("R", 0xC2, 0x00),
        ("W", 0x12, 0xE0),
        ("W", 0x12, 0x50),
        ("W", 0x26, 0x80),
        ("W", 0x54, 0x8D),
        ("W", 0x56, 0x3E),
    ]

    golden_relaxed = _normalize_for_compare(golden)
    observed_relaxed = _normalize_for_compare(observed)

    matched = _match_progress(golden_relaxed, observed_relaxed)
    assert matched == len(golden_relaxed), (
        "Observed SPI sequence does not contain golden activation trace in order; "
        f"matched {matched}/{len(golden_relaxed)} items, next expected={golden_relaxed[matched]}"
    )


@cocotb.test()
async def test_host_transceive_path(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    spi_bus = SpiBus.from_entity(
        dut,
        sclk_name="spi_sclk",
        mosi_name="spi_mosi",
        miso_name="spi_miso",
        cs_name="cs_0",
    )
    _mfrc = MFRC522Mock(spi_bus)

    await _reset(dut)
    await with_timeout(RisingEdge(dut.mfrc_card_present), 4, "ms")

    while int(dut.mfrc_tx_ready.value) == 0:
        await RisingEdge(dut.clk)

    payload = [0xDE, 0xAD, 0xBE, 0xEF]
    dut.mfrc_tx_data.value = _bytes_to_int(payload)
    dut.mfrc_tx_len.value = len(payload)
    dut.mfrc_tx_last_bits.value = 0
    dut.mfrc_tx_valid.value = 1
    await RisingEdge(dut.clk)
    dut.mfrc_tx_valid.value = 0

    await with_timeout(RisingEdge(dut.mfrc_rx_valid), 2, "ms")

    rx_len = int(dut.mfrc_rx_len.value)
    assert rx_len == 4, f"Unexpected host rx len {rx_len}"

    rx_data = int(dut.mfrc_rx_data.value)
    rx0 = (rx_data >> 248) & 0xFF
    rx1 = (rx_data >> 240) & 0xFF
    rx2 = (rx_data >> 232) & 0xFF
    rx3 = (rx_data >> 224) & 0xFF
    assert [rx0, rx1, rx2, rx3] == [0xAA, 0x55, 0x90, 0x00]


def test_mfrc_activation_runner():
    sim = os.getenv("SIM", "icarus")

    test_dir = Path(__file__).resolve().parent
    proj_dir = test_dir.parent.parent  # layr/layr/SPI
    spi_ext_dir = str(test_dir.parent / "cocotbext-spi")

    src = proj_dir / "src"

    sources = [
        src / "clock_divider.sv",
        src / "spi_master.sv",
        src / "spi_ctrl.sv",
        src / "spi_arb.sv",
        src / "eeprom_spi.sv",
        src / "eeprom_ctrl.sv",
        src / "mfrc522_ctrl.sv",
        src / "spi_top.sv",
        test_dir / "test_mfrc_top_tb.sv",
    ]

    extra_paths = [str(test_dir), spi_ext_dir]
    existing = os.environ.get("PYTHONPATH", "")
    if existing:
        extra_paths.append(existing)
    os.environ["PYTHONPATH"] = os.pathsep.join(extra_paths)

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="test_mfrc_top_tb",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )

    runner.test(
        hdl_toplevel="test_mfrc_top_tb",
        test_module="test_mfrc_activation",
        waves=True,
    )


if __name__ == "__main__":
    test_mfrc_activation_runner()
