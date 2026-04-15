import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

import harness_library as hrs_lb

def get_counter_max(dut):
    # Calculate COUNTER_MAX based on the clock frequency (assumes one second = CLK_FREQ cycles)
    clk_freq = int(dut.CLK_FREQ.value)
    return clk_freq - 1

async def wait_for_seconds(dut, num_seconds):
    """Wait for a specified number of seconds by counting clock cycles."""
    counter_max = get_counter_max(dut)
    for _ in range(num_seconds):
        # Wait for one second: (counter_max + 1) clock cycles.
        for _ in range(counter_max + 1):
            await RisingEdge(dut.clk)
        print(f"Current Time - Hours: {int(dut.hour.value)}, Minutes: {int(dut.minutes.value)}, Seconds: {int(dut.seconds.value)}")

async def check_rollover_conditions(dut, num_seconds):

    counter_max = get_counter_max(dut)
    for _ in range(num_seconds):
        # Capture the current outputs before waiting
        prev_sec   = int(dut.seconds.value)
        prev_min   = int(dut.minutes.value)
        prev_hour  = int(dut.hour.value)
        prev_s_pulse = int(dut.second_pulse.value)
        prev_m_pulse = int(dut.minute_pulse.value)
        prev_h_pulse = int(dut.hour_pulse.value)

        # Wait for one second (using clock cycles)
        for _ in range(counter_max + 1):
            await RisingEdge(dut.clk)
        curr_sec  = int(dut.seconds.value)
        curr_min  = int(dut.minutes.value)
        curr_hour = int(dut.hour.value)
        curr_s_pulse = int(dut.second_pulse.value)
        curr_m_pulse = int(dut.minute_pulse.value)
        curr_h_pulse = int(dut.hour_pulse.value)

        print(f"Rollover Current Time - Hour: {curr_hour}, Minutes: {curr_min}, Seconds: {curr_sec}")

        # Check if the stopwatch is saturated (max time reached: 1:00:00).
        if prev_hour == 1 and prev_min == 0 and prev_sec == 0:
            # In saturation, the counters remain unchanged.
            assert curr_sec == prev_sec, f"Error: Saturated seconds changed (expected {prev_sec}, got {curr_sec})."
            assert curr_min == prev_min, f"Error: Saturated minutes changed (expected {prev_min}, got {curr_min})."
            assert curr_hour == prev_hour, f"Error: Saturated hour changed (expected {prev_hour}, got {curr_hour})."
        # Otherwise, if a rollover is expected:
        elif prev_sec == 59:
            # Seconds should reset to 0.
            assert curr_sec == 0, f"Error: Seconds did not reset to 0 after reaching 59 (prev_sec={prev_sec}, curr_sec={curr_sec})."
            # Check the second_pulse was asserted.
            assert curr_s_pulse == 1 or prev_s_pulse == 1, "Error: second_pulse not asserted at seconds rollover."
            # Now check the minutes.
            if prev_min < 59:
                expected_min = prev_min + 1
                assert curr_min == expected_min, f"Error: Minutes did not increment after seconds rollover (expected {expected_min}, got {curr_min})."
                assert curr_m_pulse == 1 or prev_m_pulse == 1, "Error: minute_pulse not asserted when minutes incremented."
                # Hour remains the same.
                assert curr_hour == prev_hour, f"Error: Hour changed unexpectedly (expected {prev_hour}, got {curr_hour})."
            else:
                # When minutes are 59, rollover both seconds and minutes.
                assert curr_min == 0, f"Error: Minutes did not reset to 0 after reaching 59 (got {curr_min})."
                # For hours, assume a 1-bit hour counter that saturates at 1.
                expected_hour = 1  # or (prev_hour + 1) % 2 if wrapping is expected.
                assert curr_hour == expected_hour, f"Error: Hour did not increment correctly after minutes rollover (expected {expected_hour}, got {curr_hour})."
                assert curr_h_pulse == 1 or prev_h_pulse == 1, "Error: hour_pulse not asserted at hour rollover."
                assert int(dut.beep.value) == 0, "Error: Beep did not clear after the subsequent second pulse."
        else:
            # Otherwise, seconds should increment by one.
            expected_sec = prev_sec + 1
            # In case the increment would cause saturation, check if the design has already frozen.
            if prev_hour == 1 and prev_min == 0 and prev_sec == 0:
                # Already handled above.
                pass
            else:
                assert curr_sec == expected_sec, f"Error: Seconds did not increment as expected (expected {expected_sec}, got {curr_sec})."
                # Pulse should be asserted for the second increment.
                assert curr_s_pulse == 1 or prev_s_pulse == 1, "Error: second_pulse not asserted when seconds incremented."

async def check_pause_and_resume(dut):
    """Test that the stopwatch pauses and resumes correctly."""
    dut.start_stop.value = 1
    await wait_for_seconds(dut, 10)
    
    # Pause the stopwatch
    dut.start_stop.value = 0
    await RisingEdge(dut.clk)
    
    paused_seconds = int(dut.seconds.value)
    # Let several clock cycles pass while paused.
    for _ in range(20):
        await RisingEdge(dut.clk)
    
    # Verify the stopwatch remains paused.
    await RisingEdge(dut.clk)
    assert int(dut.seconds.value) == paused_seconds, "Error: Stopwatch did not pause correctly."

    # Resume the stopwatch and check that it continues counting.
    dut.start_stop.value = 1
    await wait_for_seconds(dut, 20)
    expected_sec = paused_seconds + 20
    assert int(dut.seconds.value) == expected_sec, f"Error: Stopwatch did not resume correctly (expected seconds {expected_sec}, got {int(dut.seconds.value)})."

async def pause_at_random_second(dut):
    dut.start_stop.value = 1
    tb_counter = 0  
    clk_freq = int(dut.CLK_FREQ.value)
    counter_max = clk_freq - 1 

    # Generate a random number of clock cycles to count before pausing.
    random_pause_duration = random.randint(1, counter_max - 1)

    # Run until reaching the random_pause_duration.
    for _ in range(random_pause_duration):
        await RisingEdge(dut.clk)
        tb_counter += 1

    # Pause the stopwatch.
    dut.start_stop.value = 0
    await RisingEdge(dut.clk)
    paused_seconds = int(dut.seconds.value)

    # Ensure the stopwatch remains paused.
    for _ in range(100):
        await RisingEdge(dut.clk)
        assert int(dut.seconds.value) == paused_seconds, "Error: Stopwatch did not remain paused as expected."

    # Resume the stopwatch and complete the remainder of the second.
    await RisingEdge(dut.clk)
    dut.start_stop.value = 1

    remaining_ticks = counter_max - tb_counter  
    for _ in range(remaining_ticks + 1):
         await RisingEdge(dut.clk)

    # Verify that the seconds counter has advanced.
    await RisingEdge(dut.clk)
    assert int(dut.seconds.value) == paused_seconds + 1, f"Stopwatch did not resume correctly from paused second. Expected: {paused_seconds + 1}, Got: {int(dut.seconds.value)}"

async def pause_at_random_minute(dut):
    dut.start_stop.value = 1
    await wait_for_seconds(dut, 50)

    # Pause the stopwatch.
    dut.start_stop.value = 0
    await RisingEdge(dut.clk)
    paused_minutes = int(dut.minutes.value)

    # Ensure the stopwatch remains paused.
    for _ in range(3600):
        await RisingEdge(dut.clk)
        assert int(dut.minutes.value) == paused_minutes, "Error: Stopwatch did not remain paused as expected."

    # Resume the stopwatch and wait for 10 seconds.
    dut.start_stop.value = 1
    await wait_for_seconds(dut, 10)

    await RisingEdge(dut.clk)
    expected_minutes = paused_minutes + 1 if paused_minutes < 59 else 0
    assert int(dut.minutes.value) == expected_minutes, f"Stopwatch did not resume correctly from paused minute. Expected: {expected_minutes}, Got: {int(dut.minutes.value)}"

@cocotb.test()
async def test_dig_stopwatch(dut):
    clk_freq = int(dut.CLK_FREQ.value)
    PERIOD = int(1_000_000_000 / clk_freq)  # Calculate clock period in ns.
    cocotb.start_soon(Clock(dut.clk, PERIOD // 2, units='ns').start())
    
    await hrs_lb.dut_init(dut)
    await hrs_lb.reset_dut(dut.reset, duration_ns=PERIOD, active=False)

    # Verify initial time values.
    assert int(dut.seconds.value) == 0, f"Initial seconds is not 0! Got: {dut.seconds.value}"
    assert int(dut.minutes.value) == 0, f"Initial minutes is not 0! Got: {dut.minutes.value}"
    assert int(dut.hour.value)   == 0, f"Initial hours is not 0! Got: {dut.hour.value}"

    await RisingEdge(dut.clk)

    # Start the stopwatch.
    dut.start_stop.value = 1
    await RisingEdge(dut.clk)

    initial_seconds = int(dut.seconds.value)
    await wait_for_seconds(dut, 10)
    # Expect seconds to have advanced by 10.
    assert int(dut.seconds.value) == initial_seconds + 10, f"Seconds did not increment correctly. Current seconds: {dut.seconds.value}"

    # Stop the stopwatch.
    dut.start_stop.value = 0
    await RisingEdge(dut.clk)
    stopped_seconds = int(dut.seconds.value)
    await RisingEdge(dut.clk)
    assert int(dut.seconds.value) == stopped_seconds, "Stopwatch did not stop as expected."

    # Restart the stopwatch.
    dut.start_stop.value = 1
    await RisingEdge(dut.clk)

    await check_pause_and_resume(dut)
    await check_rollover_conditions(dut, 3600)  # Testing rollovers for 1 hour.
    
    dut.start_stop.value = 0

    # Reset and check that time values go back to zero.
    dut.reset.value = 1
    await RisingEdge(dut.clk)
    assert int(dut.seconds.value) == 0, f"Reset failed for seconds! Got: {dut.seconds.value}"
    assert int(dut.minutes.value) == 0, f"Reset failed for minutes! Got: {dut.minutes.value}"
    assert int(dut.hour.value)   == 0, f"Reset failed for hours! Got: {dut.hour.value}"
    await RisingEdge(dut.clk)

    dut.reset.value = 0
    await pause_at_random_second(dut)
    await RisingEdge(dut.clk)

    dut.reset.value = 1
    await RisingEdge(dut.clk)
    dut.reset.value = 0

    await pause_at_random_minute(dut)
    await RisingEdge(dut.clk)
