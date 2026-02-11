# Review Notes for test_axi_master.py

## Quick Summary

This test file **cannot run** in its current state due to:

1. **Missing module file**: References `axi_master.sv` which doesn't exist
2. **Interface mismatch**: Expects simplified interface that doesn't match actual `axi_spi_master` module

## Required Actions

### Immediate (Blocking):

1. **Fix module reference** (Lines 189, 194, 200):
   - Determine if a wrapper module `axi_master` should exist
   - If yes: Create the wrapper module with the interface expected by tests
   - If no: Update tests to use `axi_spi_master` interface directly

2. **Fix signal names**:
   - Current test expects: `req_addr`, `req_wdata`, `req_write`, `req_valid`, etc.
   - Actual module has: `s_axi_awaddr`, `s_axi_wdata`, etc. (full AXI4 interface)

### Recommended (Quality):

1. **Line 34**: Change `if self.dut.resp_done == 1:` to `if self.dut.resp_done.value == 1:` for consistency
2. **Setup function**: Initialize all AXI signals to safe defaults
3. **Add test**: Create `test_read_error_response_flagged()` to match write error test
4. **Use constants**: Replace magic numbers (0x08, 0x06, 0x20) with named constants

## Testing Checklist

- [ ] Module file exists and can be found by test runner
- [ ] Signal names match between test and module
- [ ] Tests can be built (compile HDL)
- [ ] Tests can run
- [ ] Tests pass

## See Also

Full detailed review in: `/CODE_REVIEW_AXI_SPI_TESTS.md`
