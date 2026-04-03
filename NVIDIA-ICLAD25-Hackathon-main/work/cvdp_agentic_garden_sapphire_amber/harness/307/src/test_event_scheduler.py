import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

# Start a clock with a 10 ns period.
async def start_clock(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

# Reset the DUT for 2 clock cycles.
async def reset_dut(dut):
    dut.reset.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.reset.value = 0
    await RisingEdge(dut.clk)

# Clear all control signals (only control signals, not internal storage).
async def clear_signals(dut):
    dut.add_event.value = 0
    dut.cancel_event.value = 0
    dut.modify_event.value = 0
    dut.event_id.value = 0
    dut.timestamp.value = 0
    dut.priority_in.value = 0
    dut.new_timestamp.value = 0
    dut.new_priority.value = 0
    dut.recurring_event.value = 0
    dut.recurring_interval.value = 0
    await RisingEdge(dut.clk)

# Wait until event_triggered becomes high and immediately capture outputs.
async def wait_for_trigger(dut, timeout_ns=500):
    remaining = timeout_ns
    while remaining > 0:
        await RisingEdge(dut.clk)
        if int(dut.event_triggered.value) == 1:
            return {
                "event_triggered": int(dut.event_triggered.value),
                "triggered_event_id": int(dut.triggered_event_id.value),
                "log_event_time": int(dut.log_event_time.value),
                "log_event_id": int(dut.log_event_id.value),
                "current_time": int(dut.current_time.value)
            }
        remaining -= 10
    raise Exception("Timed out waiting for event_triggered signal.")

###############################################################################
# Test Case 1: Add a new event and wait for it to trigger.
@cocotb.test()
async def tc1_add_event_and_trigger(dut):
    """TC1: Add event ID=1 with timestamp = current_time+30, priority=2 and wait for trigger."""
    cocotb.log.info("TC1: Starting test: add event and trigger")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    dut.event_id.value = 1
    dut.timestamp.value = base_time + 30
    dut.priority_in.value = 2
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)
    result = await wait_for_trigger(dut)
    assert result["event_triggered"] == 1, "Event did not trigger"
    assert result["triggered_event_id"] == 1, "Triggered event id is not 1"
    assert int(dut.error.value) == 0, "Error flag unexpectedly asserted"
    cocotb.log.info(f"TC1: current_time={result['current_time']}, log_event_time={result['log_event_time']}, log_event_id={result['log_event_id']}")

###############################################################################
# Test Case 2: Add an event then cancel it so it never triggers.
@cocotb.test()
async def tc2_cancel_event(dut):
    """TC2: Add event ID=2 with timestamp=current_time+50 then cancel it before trigger."""
    cocotb.log.info("TC2: Starting test: add event then cancel it")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    dut.event_id.value = 2
    dut.timestamp.value = base_time + 50
    dut.priority_in.value = 3
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    # Cancel the event.
    dut.event_id.value = 2
    dut.cancel_event.value = 1
    await RisingEdge(dut.clk)
    dut.cancel_event.value = 0
    await clear_signals(dut)
    for _ in range(5):
        await RisingEdge(dut.clk)
    assert int(dut.event_triggered.value) == 0, "Event unexpectedly triggered after cancel"
    cocotb.log.info(f"TC2: current_time={int(dut.current_time.value)}")

###############################################################################
# Test Case 3: Add an event then modify it so that the modified event triggers.
@cocotb.test()
async def tc3_modify_event(dut):
    """TC3: Add event ID=3, then modify it (timestamp=current_time+90, priority=4) and wait for trigger."""
    cocotb.log.info("TC3: Starting test: add event then modify it")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    # Add event ID 3.
    dut.event_id.value = 3
    dut.timestamp.value = base_time + 70
    dut.priority_in.value = 1
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    # Modify event ID 3.
    dut.event_id.value = 3
    dut.new_timestamp.value = base_time + 90
    dut.new_priority.value = 4
    dut.modify_event.value = 1
    await RisingEdge(dut.clk)
    dut.modify_event.value = 0
    await clear_signals(dut)
    result = await wait_for_trigger(dut)
    assert result["triggered_event_id"] == 3, "Modified event did not trigger with event ID 3"
    cocotb.log.info(f"TC3: current_time={result['current_time']}, log_event_time={result['log_event_time']}")

###############################################################################
# Test Case 4: Try adding an event twice to generate an error.
@cocotb.test()
async def tc4_duplicate_add(dut):
    """TC4: Add event ID=4 twice; expect error on duplicate addition."""
    cocotb.log.info("TC4: Starting test: duplicate add event")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    # First addition.
    dut.event_id.value = 4
    dut.timestamp.value = base_time + 40
    dut.priority_in.value = 2
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    # Duplicate addition.
    dut.event_id.value = 4
    dut.timestamp.value = base_time + 60
    dut.priority_in.value = 3
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    # Wait one extra cycle for error flag to settle.
    await RisingEdge(dut.clk)
    await clear_signals(dut)
    assert int(dut.error.value) == 1, "Error flag not set on duplicate add"
    cocotb.log.info(f"TC4: current_time={int(dut.current_time.value)}, log_event_time={int(dut.log_event_time.value)}")

###############################################################################
# Test Case 5: Attempt to modify a non-existent event.
@cocotb.test()
async def tc5_modify_nonexistent(dut):
    """TC5: Attempt to modify event ID=5 (which hasn't been added); expect error."""
    cocotb.log.info("TC5: Starting test: modify non-existent event")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    dut.event_id.value = 5
    dut.new_timestamp.value = 100
    dut.new_priority.value = 5
    dut.modify_event.value = 1
    await RisingEdge(dut.clk)
    dut.modify_event.value = 0
    await clear_signals(dut)
    for _ in range(2):
        await RisingEdge(dut.clk)
    assert int(dut.error.value) == 1, "Error flag not set when modifying non-existent event"
    cocotb.log.info(f"TC5: current_time={int(dut.current_time.value)}")

###############################################################################
# Test Case 6: Attempt to cancel a non-existent event.
@cocotb.test()
async def tc6_cancel_nonexistent(dut):
    """TC6: Attempt to cancel event ID=6 (which hasn't been added); expect error."""
    cocotb.log.info("TC6: Starting test: cancel non-existent event")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    dut.event_id.value = 6
    dut.cancel_event.value = 1
    await RisingEdge(dut.clk)
    dut.cancel_event.value = 0
    await clear_signals(dut)
    for _ in range(2):
        await RisingEdge(dut.clk)
    assert int(dut.error.value) == 1, "Error flag not set when cancelling non-existent event"
    cocotb.log.info(f"TC6: current_time={int(dut.current_time.value)}")

###############################################################################
# Test Case 7: Add a recurring event and observe multiple triggers.
@cocotb.test()
async def tc7_recurring_event(dut):
    """TC7: Add recurring event ID=7 with recurring_interval=20 and verify repeated triggers."""
    cocotb.log.info("TC7: Starting test: recurring event")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    dut.event_id.value = 7
    dut.timestamp.value = base_time + 20
    dut.priority_in.value = 3
    dut.recurring_event.value = 1
    dut.recurring_interval.value = 20
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    result1 = await wait_for_trigger(dut)
    assert result1["triggered_event_id"] == 7, "Recurring event did not trigger with event ID 7"
    cocotb.log.info(f"TC7: First trigger at time {result1['log_event_time']}")
    result2 = await wait_for_trigger(dut)
    cocotb.log.info(f"TC7: Second trigger at time {result2['log_event_time']}")
    assert result2["log_event_time"] > result1["log_event_time"], "Second recurring trigger did not occur"

###############################################################################
# Test Case 8: Add an event and verify logging outputs.
@cocotb.test()
async def tc8_logging(dut):
    """TC8: Add event ID=8 and verify log_event_time and log_event_id outputs."""
    cocotb.log.info("TC8: Starting test: event logging")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    # Schedule event ID 8 at base_time+30.
    dut.event_id.value = 8
    dut.timestamp.value = base_time + 30
    dut.priority_in.value = 2
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    # Do not clear signals immediately—allow the event to remain in memory.
    result = await wait_for_trigger(dut)
    captured_id = result["log_event_id"]
    assert captured_id == 8, f"Expected log_event_id 8, got {captured_id}"
    cocotb.log.info(f"TC8: Triggered at time {result['log_event_time']} with event id {captured_id}")

###############################################################################
# Test Case 9: Add an event, then modify and cancel it so that no trigger occurs.
@cocotb.test()
async def tc9_modify_then_cancel(dut):
    """TC9: Add event ID=9, then modify and cancel it; expect no trigger."""
    cocotb.log.info("TC9: Starting test: modify then cancel event")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    # Add event ID 9.
    dut.event_id.value = 9
    dut.timestamp.value = base_time + 150
    dut.priority_in.value = 2
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    # Modify event ID 9.
    dut.event_id.value = 9
    dut.new_timestamp.value = base_time + 170
    dut.new_priority.value = 4
    dut.modify_event.value = 1
    await RisingEdge(dut.clk)
    dut.modify_event.value = 0
    await clear_signals(dut)

    # Cancel event ID 9.
    dut.event_id.value = 9
    dut.cancel_event.value = 1
    await RisingEdge(dut.clk)
    dut.cancel_event.value = 0
    await clear_signals(dut)

    for _ in range(3):
        await RisingEdge(dut.clk)
    assert int(dut.event_triggered.value) == 0, "Event triggered despite cancellation"
    cocotb.log.info(f"TC9: current_time={int(dut.current_time.value)}")

###############################################################################
# Test Case 10: Add two events sequentially (in consecutive cycles) with same timestamp but different priorities.
@cocotb.test()
async def tc10_priority_selection(dut):
    """TC10: Add event ID=10 and then event ID=11 (with same target timestamp) in consecutive cycles; expect event with higher priority (ID 11) to trigger."""
    cocotb.log.info("TC10: Starting test: concurrent events with priority selection")
    await start_clock(dut)
    await reset_dut(dut)
    await clear_signals(dut)
    base_time = int(dut.current_time.value)

    # Add event ID 10.
    dut.event_id.value = 10
    dut.timestamp.value = base_time + 170
    dut.priority_in.value = 2
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    # Add event ID 11 in the next cycle with the same target timestamp.
    dut.event_id.value = 11
    dut.timestamp.value = base_time + 170
    dut.priority_in.value = 5
    dut.add_event.value = 1
    await RisingEdge(dut.clk)
    dut.add_event.value = 0
    await clear_signals(dut)

    result = await wait_for_trigger(dut)
    captured_triggered = result["triggered_event_id"]
    assert captured_triggered == 11, f"Expected triggered_event_id 11, got {captured_triggered}"
    cocotb.log.info(f"TC10: Triggered event id {captured_triggered} at time {result['log_event_time']}")

