from __future__ import annotations

from cocotbext.spi import SpiSlaveBase, SpiConfig


def crc_a(data: list[int]) -> tuple[int, int]:
    crc = 0x6363
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0x8408
            else:
                crc >>= 1
    return crc & 0xFF, (crc >> 8) & 0xFF


class MFRC522Mock(SpiSlaveBase):
    def __init__(self, bus):
        self._config = SpiConfig(
            word_width=8,
            cpol=False,
            cpha=False,
            msb_first=True,
            cs_active_low=True,
            frame_spacing_ns=1,
            data_output_idle=0,
        )
        super().__init__(bus)

        self.regs = {}
        self.regs[0x14] = 0x80  # TxControlReg initial readback
        self.regs[0x37] = 0x92  # VersionReg
        self.regs[0x0D] = 0x00  # BitFramingReg
        self.regs[0x04] = 0x00  # ComIrqReg
        self.regs[0x05] = 0x00  # DivIrqReg
        self.regs[0x06] = 0x00  # ErrorReg
        self.regs[0x0A] = 0x00  # FIFOLevelReg
        self.regs[0x0C] = 0x10  # ControlReg

        self.fifo_in: list[int] = []
        self.fifo_out: list[int] = []
        self.irq_reads = 0

        self.trace: list[tuple[str, int, int]] = []

    async def _shift(self, num_bits, tx_word=None):
        if not self._config.cpha and tx_word is not None and tx_word != 0:
            msb = bool(tx_word & (1 << (num_bits - 1)))
            self._miso.value = int(msb)
            shifted_tx = (tx_word << 1) & ((1 << num_bits) - 1)
            return await super()._shift(num_bits, tx_word=shifted_tx)
        return await super()._shift(num_bits, tx_word=tx_word)

    def _read_reg(self, reg: int) -> int:
        if reg == 0x04:  # ComIrqReg
            if self.regs.get(0x04, 0) & 0x60:
                self.irq_reads += 1
                if self.irq_reads == 1:
                    return 0x04
                return 0x64
            return self.regs.get(0x04, 0)

        if reg == 0x05:  # DivIrqReg
            return self.regs.get(0x05, 0)

        if reg == 0x0A:  # FIFOLevelReg
            return len(self.fifo_out) & 0xFF

        if reg == 0x09:  # FIFODataReg
            if self.fifo_out:
                return self.fifo_out.pop(0)
            return 0x00

        if reg == 0x0C:  # ControlReg
            return self.regs.get(0x0C, 0x10)

        return self.regs.get(reg, 0x00)

    def _run_transceive(self):
        payload = self.fifo_in.copy()

        if payload == [0x26]:
            self.fifo_out = [0x08, 0x00]
        elif payload == [0x93, 0x20]:
            self.fifo_out = [0x0F, 0xAB, 0x33, 0x69, 0xFE]
        elif len(payload) == 9 and payload[0] == 0x93 and payload[1] == 0x70:
            self.fifo_out = [0x20, 0xFC, 0x70]
        elif payload == [0xE0, 0x50]:
            self.fifo_out = [
                0x0A,
                0x78,
                0x80,
                0x91,
                0x02,
                0x80,
                0x73,
                0xC8,
                0x21,
                0x10,
                0xC3,
                0x92,
            ]
        else:
            self.fifo_out = [0xAA, 0x55, 0x90, 0x00]

        self.regs[0x04] = 0x64
        self.regs[0x06] = 0x00
        self.regs[0x0C] = 0x10
        self.irq_reads = 0
        self.fifo_in = []

    def _write_reg(self, reg: int, val: int):
        self.regs[reg] = val & 0xFF

        if reg == 0x0A and (val & 0x80):
            self.fifo_in = []
            self.fifo_out = []

        if reg == 0x09:
            self.fifo_in.append(val & 0xFF)

        if reg == 0x04 and val == 0x7F:
            self.regs[0x04] = 0x00

        if reg == 0x05 and val == 0x04:
            self.regs[0x05] = 0x00

        if reg == 0x01 and val == 0x03:
            l, h = crc_a(self.fifo_in)
            self.regs[0x22] = l
            self.regs[0x21] = h
            self.regs[0x05] = 0x04

        if reg == 0x01 and val == 0x0F:
            self.regs[0x01] = 0x00

        if reg == 0x0D and (val & 0x80) and self.regs.get(0x01, 0) == 0x0C:
            self._run_transceive()

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        addr_byte = int(await self._shift(8, tx_word=0x00))
        is_read = bool(addr_byte & 0x80)
        reg = (addr_byte >> 1) & 0x3F

        if is_read:
            rx_val = self._read_reg(reg)
            _ = int(await self._shift(8, tx_word=rx_val))
            self.trace.append(("R", addr_byte, rx_val))
        else:
            val = int(await self._shift(8, tx_word=0x00))
            self._write_reg(reg, val)
            self.trace.append(("W", addr_byte, val))

        await frame_end
        self.idle.set()
