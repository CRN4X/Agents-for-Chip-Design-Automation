import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

async def reset_dut(dut):
    await FallingEdge(dut.i_clk)
    """Apply an asynchronous reset to the DUT"""
    dut.i_rst_b.value = 0
    dut.i_vehicle_sensor_input.value = 0
    
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Deassert reset
    dut.i_rst_b.value = 1

@cocotb.test()
async def test_traffic_light_controller_top(dut):
    """Full test of the traffic light controller (FSM + timer)."""

    # Create and start a clock on i_clk
    cocotb.start_soon(Clock(dut.i_clk, 10, units='ns').start())

    # Reset the DUT
    await reset_dut(dut)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    #
    # 1) Check initial state after reset: we expect S1 => (main=1, side=4).
    #
    # Because the FSM updates on the rising edge, we wait a bit:
    await RisingEdge(dut.i_clk)
    # Now check
    assert dut.o_main.value == 1, f"After reset, expected main=1 (green), got {dut.o_main.value}"
    assert dut.o_side.value == 4, f"After reset, expected side=4 (red), got {dut.o_side.value}"
    dut._log.info("Starting in S1 (main=green, side=red) as expected.")

    #
    # The FSM triggers the long timer in S1. By default, LONG_COUNT_PARAM=20.
    # If no vehicle is present, S1 won't change, because S1 transitions only if:
    #    (i_vehicle_sensor_input & i_long_timer) == 1
    # So let's confirm that with no vehicle sensor, the FSM stays in S1 indefinitely.
    #
    # Wait a bit more than 20 cycles to see if it changes:
    for i in range(25):
        await RisingEdge(dut.i_clk)

    assert dut.o_main.value == 1, (
        "No vehicle present -> we should STILL be in S1 (main=1) even though "
        "the long timer expired. The FSM requires vehicle=1 to leave S1."
    )
    dut._log.info("Confirmed that with vehicle=0, the FSM remains in S1 after the timer expires.")

    #
    # 2) Now introduce a vehicle sensor input => i_vehicle_sensor_input=1.
    # Next time the long timer triggers (which will happen again after we re-enter S1?), 
    # the FSM will go from S1 -> S2.
    #
    dut.i_vehicle_sensor_input.value = 1
    dut._log.info("Vehicle arrived -> i_vehicle_sensor_input=1. Waiting for next long timer expiration...")
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    # Now we expect S2 => main=2 (yellow), side=4 (red).
    assert dut.o_main.value == 2, f"Expected S2 => main=2, got {dut.o_main.value}"
    assert dut.o_side.value == 4, f"Expected side=4, got {dut.o_side.value}"
    dut._log.info("Transitioned to S2 (main=yellow, side=red).")

    #
    # 3) In S2, the FSM triggers the short timer. The default SHORT_COUNT_PARAM=10.
    # Wait ~10 cycles so that short timer expires, causing S2 -> S3.
    #
    for i in range(13):
        await RisingEdge(dut.i_clk)

    # Now we expect S3 => main=4 (red), side=1 (green).
    assert dut.o_main.value == 4, f"Expected S3 => main=4 (red), got {dut.o_main.value}"
    assert dut.o_side.value == 1, f"Expected side=1 (green), got {dut.o_side.value}"
    dut._log.info("Transitioned to S3 (main=red, side=green).")

    #
    # 4) In S3, the FSM triggers the long timer again. The default is 20 cycles.
    # We remain in S3 until either no vehicle is detected or the long timer expires.
    # We'll just let the long timer expire. 
    #
    for i in range(25):
        await RisingEdge(dut.i_clk)

    # Once the long timer expires, we go to S4 => main=4 (red), side=2 (yellow).
    assert dut.o_main.value == 4, f"Expected S4 => main=4 (red), got {dut.o_main.value}"
    assert dut.o_side.value == 2, f"Expected side=2 (yellow), got {dut.o_side.value}"
    dut._log.info("Transitioned to S4 (main=red, side=yellow).")

    #
    # 5) Finally, in S4, the FSM triggers the short timer again (10 cycles).
    # After it expires, we should return to S1 => main=1, side=4.
    #
    for i in range(12):
        await RisingEdge(dut.i_clk)

    assert dut.o_main.value == 1, f"Expected S1 => main=1 (green), got {dut.o_main.value}"
    assert dut.o_side.value == 4, f"Expected side=4 (red), got {dut.o_side.value}"
    dut._log.info("Returned to S1 (main=green, side=red). Test complete!")
    # Reset
    await reset_dut(dut)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Confirm starting in S1 => main=1, side=4
    assert dut.o_main.value == 1, "Should be in S1 => main=green"
    assert dut.o_side.value == 4, "Should be in S1 => side=red"
    dut._log.info("Start in S1 with no vehicle.")

    # We'll wait a very long time to confirm we never leave S1
    for _ in range(200):  # e.g. 200 cycles
        await RisingEdge(dut.i_clk)

    # If no vehicle is present, FSM should STILL be in S1
    # despite the long timer expiring repeatedly
    assert dut.o_main.value == 1, "Expected to remain in S1 (main=green)"
    assert dut.o_side.value == 4, "Expected to remain in S1 (side=red)"
    dut._log.info("FSM stayed in S1 for a long time with no vehicle. Test passed.")
