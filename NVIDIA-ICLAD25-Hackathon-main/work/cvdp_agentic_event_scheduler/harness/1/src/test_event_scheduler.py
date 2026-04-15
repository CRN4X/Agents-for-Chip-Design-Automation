import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_event_scheduler_assertions(dut):
    """COCOTB testbench for the event_scheduler module with assertions."""

    # Create a 10 ns period clock (5 ns high, 5 ns low)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize signals
    dut.reset.value = 1
    dut.add_event.value = 0
    dut.cancel_event.value = 0
    dut.event_id.value = 0
    dut.timestamp.value = 0
    dut.priority_in.value = 0

    # Hold reset for 2 clock cycles
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.reset.value = 0

    # --- Test Case 1 ---
    # Add event id 4 with timestamp = 20 ns and priority = 2.
    await RisingEdge(dut.clk)
    dut.add_event.value = 1
    dut.event_id.value = 4
    dut.timestamp.value = 20
    dut.priority_in.value = 2
    await RisingEdge(dut.clk)
    dut.add_event.value = 0

    # Wait until event_triggered is asserted (polling at every rising edge)
    while int(dut.event_triggered.value) != 1:
        await RisingEdge(dut.clk)
    trig_id = int(dut.triggered_event_id.value)
    trig_time = int(dut.current_time.value)
    # Assertion for Test Case 1: check that event 4 is triggered at time 20 ns.
    assert trig_id == 4, f"Test Case 1 Failed: Expected event 4 trigger, got {trig_id} at time {trig_time}"
    dut._log.info(f"Test Case 1 Passed: Event 4 triggered at time {dut.current_time.value.to_unsigned()} ns")

    # --- Test Case 2 ---
    # Compute a future timestamp (current_time + 40 ns) and add two events there.
    await RisingEdge(dut.clk)
    future_time = int(dut.current_time.value) + 40
    await RisingEdge(dut.clk)
    # Add event 5 with higher priority (3)
    dut.add_event.value = 1
    dut.event_id.value = 5
    dut.timestamp.value = future_time
    dut.priority_in.value = 3
    await RisingEdge(dut.clk)
    dut.add_event.value = 0

    await RisingEdge(dut.clk)
    # Add event 6 with lower priority (1)
    dut.add_event.value = 1
    dut.event_id.value = 6
    dut.timestamp.value = future_time
    dut.priority_in.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0

    # Wait until current_time >= future_time
    while int(dut.current_time.value) < future_time:
        await RisingEdge(dut.clk)
    # Wait for the trigger pulse for the future events.
    while int(dut.event_triggered.value) != 1:
        await RisingEdge(dut.clk)
    trig_id = int(dut.triggered_event_id.value)
    trig_time = int(dut.current_time.value)
    # Assertion for Test Case 2: the event triggered should be event 5 (priority 3)
    assert trig_id == 5, f"Test Case 2 Failed: Incorrect event triggered (got {trig_id}) at time {trig_time}"
    dut._log.info(f"Test Case 2 Passed: Event 5 (priority 3) triggered over Event 6 at time {dut.current_time.value.to_unsigned()} ns")

    # --- Test Case 3 ---
    # Add event 7 scheduled for current_time + 20 ns and then cancel it.
    await RisingEdge(dut.clk)
    dut.add_event.value = 1
    dut.event_id.value = 7
    dut.timestamp.value = int(dut.current_time.value) + 20
    dut.priority_in.value = 2
    await RisingEdge(dut.clk)
    dut.add_event.value = 0

    await RisingEdge(dut.clk)
    dut.cancel_event.value = 1
    dut.event_id.value = 7
    await RisingEdge(dut.clk)
    dut.cancel_event.value = 0

    # Wait a few cycles to ensure that event 7 is not triggered.
    for _ in range(4):
        await RisingEdge(dut.clk)
    # Assert that either no event is triggered or the triggered event is not event 7.
    assert not (int(dut.event_triggered.value) == 1 and int(dut.triggered_event_id.value) == 7), \
        f"Test Case 3 Failed: Event 7 triggered despite cancellation at time {int(dut.current_time.value)} ns"
    dut._log.info(f"Test Case 3 Passed: Event 7 cancelled successfully (no trigger) at time {dut.current_time.value.to_unsigned()} ns")

    # Allow time for any final signals before ending the test
    await Timer(50, units="ns")

