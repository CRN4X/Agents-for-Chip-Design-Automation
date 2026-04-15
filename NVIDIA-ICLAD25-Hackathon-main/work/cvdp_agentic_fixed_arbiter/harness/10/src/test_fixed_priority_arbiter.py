import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def apply_reset(dut, duration_ns=20):
    """Apply synchronous active-high reset."""
    dut.reset.value = 1
    dut.enable.value = 0
    dut.clear.value = 0
    dut.req.value = 0
    dut.priority_override.value = 0
    await Timer(duration_ns, units="ns")
    dut.reset.value = 0
    dut.enable.value = 1
    await RisingEdge(dut.clk)


async def drive_request(dut, request, expected_grant, expected_index=None, expected_valid=1, override=0):
    """Drive request and optional override, then verify outputs."""
    dut.req.value = request
    dut.priority_override.value = override
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")

    assert dut.grant.value == expected_grant, (
        f"Grant mismatch: req={bin(request)}, override={bin(override)} | "
        f"Expected={bin(expected_grant)}, Got={bin(dut.grant.value)}"
    )

    if expected_index is not None:
        assert dut.grant_index.value == expected_index, (
            f"grant_index mismatch: Expected={expected_index}, Got={int(dut.grant_index.value)}"
        )
        assert dut.active_grant.value == expected_index, (
            f"active_grant mismatch: Expected={expected_index}, Got={int(dut.active_grant.value)}"
        )

    assert dut.valid.value == expected_valid, (
        f"Valid mismatch: Expected={expected_valid}, Got={int(dut.valid.value)}"
    )


@cocotb.test()
async def test_fixed_priority_arbiter(dut):
    """Fixed Priority Arbiter Testbench"""

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await apply_reset(dut)

    cocotb.log.info("Test Case 1: Single request")
    await drive_request(dut, request=0b00001000, expected_grant=0b00001000, expected_index=3)

    cocotb.log.info("Test Case 2: Multiple requests (fixed priority)")
    await drive_request(dut, request=0b00111000, expected_grant=0b00001000, expected_index=3)

    cocotb.log.info("Test Case 3: Priority override active")
    await drive_request(dut, request=0b00010010, override=0b00010000, expected_grant=0b00010000, expected_index=4)

    cocotb.log.info("Test Case 4: Highest priority among requests")
    await drive_request(dut, request=0b10000001, expected_grant=0b00000001, expected_index=0)

    cocotb.log.info("Test Case 5: Grant updates dynamically")
    await drive_request(dut, request=0b00000010, expected_grant=0b00000010, expected_index=1)
    await drive_request(dut, request=0b00000100, expected_grant=0b00000100, expected_index=2)

    cocotb.log.info("Test Case 6: Priority override during request changes")
    await drive_request(dut, request=0b00000010, override=0b00100000, expected_grant=0b00100000, expected_index=5)
    await drive_request(dut, request=0b00010010, override=0b00010000, expected_grant=0b00010000, expected_index=4)

    cocotb.log.info("Test Case 7: Manual clear")
    dut.req.value = 0b00000100
    dut.clear.value = 1
    await Timer(10, units="ns")
    dut.clear.value = 0
    await RisingEdge(dut.clk)
    assert dut.grant.value == 0, "Clear failed: grant not cleared"
    assert dut.valid.value == 0, "Clear failed: valid not cleared"
    assert dut.grant_index.value == 0, "Clear failed: grant_index not reset"

  
    cocotb.log.info("Test Case 8: Reset during active requests")
    dut.req.value = 0b00000100
    await apply_reset(dut)
    assert dut.grant.value == 0, "Reset failed: grant should be 0"
    assert dut.valid.value == 0, "Reset failed: valid should be 0"
    assert dut.grant_index.value == 0, "Reset failed: grant_index should be 0"

    cocotb.log.info("All test cases passed successfully.")
