import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer, First
import random

# Global frequency: 1 GHz reference clock
freq = 1000000000

# ----------------------------------------
# - Test Initializations & Helper Functions
# ----------------------------------------
def randomize_variables(lR, uR, v1_less_v2):
    var1 = random.randint(lR, uR)
    var2 = random.randint(var1 + 1, var1 + uR)
    return var1, var2

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.clk_sys.value = 0
    dut.clk_test.value = 0
    dut.enable.value = 0
    dut.count_ref.value = 0

    await Timer(random.randint(100, 1000), units='ns')
    dut.rst_n.value = 1
    await Timer(random.randint(100, 1000), units='ns')

def clock_gen(signal, period_ns):
    """Generate a clock on the given signal with the specified period in nanoseconds."""
    while True:
        signal.value = 0
        yield Timer(period_ns / 2, units='ns')
        signal.value = 1
        yield Timer(period_ns / 2, units='ns')

async def start_one_enable(dut, count_ref):
    dut.enable.value = 1
    dut.count_ref.value = count_ref
    await RisingEdge(dut.clk_sys)
    await RisingEdge(dut.clk_sys)
    dut.enable.value = 0

async def get_dut_count(dut, count_ref, clk_test_freq, clk_sys_freq):
    await RisingEdge(dut.o_irq)
    clock_est = int(dut.o_clock_est.value)
    expected_count = (count_ref * clk_test_freq) / clk_sys_freq
    print(f"Expected count: {expected_count}")
    print(f"Actual count: {clock_est}")
    assert (clock_est > expected_count - 16 and clock_est < expected_count + 16), \
        f"Count mismatch: expected around {expected_count}, got {clock_est}"

# ----------------------------------------
# - Original Tests
# ----------------------------------------

# Basic test
@cocotb.test()
async def basic_test(dut):
    clk_sys_period = 10  # ns
    clk_test_period = 4  # ns
    clk_sys_freq = freq / clk_sys_period
    clk_test_freq = freq / clk_test_period
    count_ref = 100

    # Start clocks
    cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
    cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())
    cocotb.start_soon(get_dut_count(dut, count_ref, clk_test_freq, clk_sys_freq))

    await reset_dut(dut)
    await start_one_enable(dut, count_ref)

    signal_high = RisingEdge(dut.o_irq)
    timeout = Timer(10, units='us')
    event = await First(signal_high, timeout)

    if event is signal_high:
        print("basic_test: Test gracefully ended")
        assert True
    else:
        print("basic_test: Test Timeout")
        assert False

# Multi enable check
@cocotb.test()
async def multi_en_check(dut):
    clk_test_period, clk_sys_period = randomize_variables(5, 10, 1)
    clk_sys_freq = freq / clk_sys_period
    clk_test_freq = freq / clk_test_period
    print(f"multi_en_check: clk_sys = {clk_sys_period} ns, clk_test = {clk_test_period} ns")
    print(f"multi_en_check: clk_sys_freq = {clk_sys_freq}, clk_test_freq = {clk_test_freq}")

    count_ref = random.randint(100, 1000)
    print(f"multi_en_check: count_ref = {count_ref}")

    # Start clocks
    cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
    cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())
    cocotb.start_soon(get_dut_count(dut, count_ref, clk_test_freq, clk_sys_freq))

    await reset_dut(dut)
    await start_one_enable(dut, count_ref)
    await Timer(random.randint(100, 200), units='ns')
    await start_one_enable(dut, count_ref)
    await Timer(random.randint(100, 200), units='ns')
    await start_one_enable(dut, count_ref)

    signal_high = RisingEdge(dut.o_irq)
    timeout = Timer(20, units='us')
    event = await First(signal_high, timeout)

    if event is signal_high:
        print("multi_en_check: Test gracefully ended")
        assert True
    else:
        print("multi_en_check: Test Timeout")
        assert False

# ----------------------------------------
# - Additional Tests
# ----------------------------------------

# Additional Test 1: Reset Behavior Verification
@cocotb.test()
async def reset_behavior_test(dut):
    clk_sys_period = 10
    clk_test_period = 4
    cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
    cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())

    await reset_dut(dut)
    # Verify that outputs are reset
    assert int(dut.o_clock_est.value) == 0, "o_clock_est not reset to 0 after reset"
    assert int(dut.o_irq.value) == 0, "o_irq not reset to 0 after reset"
    print("reset_behavior_test: Reset behavior verified successfully.")

# Additional Test 2: Boundary Condition Testing for count_ref
@cocotb.test()
async def boundary_condition_test(dut):
    clk_sys_period = 10
    clk_test_period = 4
    clk_sys_freq = freq / clk_sys_period
    clk_test_freq = freq / clk_test_period

    # Test with a minimal count_ref (e.g., 2)
    min_count_ref = 2
    print(f"boundary_condition_test: Testing minimum count_ref = {min_count_ref}")
    cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
    cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())
    await reset_dut(dut)
    await start_one_enable(dut, min_count_ref)
    await get_dut_count(dut, min_count_ref, clk_test_freq, clk_sys_freq)

    # Test with a maximum count_ref (e.g., 1000)
    max_count_ref = 1000
    print(f"boundary_condition_test: Testing maximum count_ref = {max_count_ref}")
    await reset_dut(dut)
    await start_one_enable(dut, max_count_ref)
    await get_dut_count(dut, max_count_ref, clk_test_freq, clk_sys_freq)

# Additional Test 3: Stress/Random Testing with multiple iterations
@cocotb.test()
async def stress_test(dut):
    iterations = 10
    for i in range(iterations):
        clk_sys_period, clk_test_period = randomize_variables(5, 15, 1)
        clk_sys_freq = freq / clk_sys_period
        clk_test_freq = freq / clk_test_period
        count_ref = random.randint(50, 500)
        print(f"stress_test (Iteration {i+1}): clk_sys = {clk_sys_period} ns, clk_test = {clk_test_period} ns, count_ref = {count_ref}")

        # Start clocks (restart for each iteration)
        cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
        cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())
        cocotb.start_soon(get_dut_count(dut, count_ref, clk_test_freq, clk_sys_freq))
        await reset_dut(dut)
        await start_one_enable(dut, count_ref)
        # Wait a bit before the next iteration
        await Timer(random.randint(50, 100), units='ns')

# Additional Test 4: Interrupt Signal Behavior Check
@cocotb.test()
async def interrupt_behavior_test(dut):
    clk_sys_period = 10
    clk_test_period = 4
    cocotb.start_soon(Clock(dut.clk_sys, clk_sys_period, units='ns').start())
    cocotb.start_soon(Clock(dut.clk_test, clk_test_period, units='ns').start())

    count_ref = random.randint(100, 500)
    print(f"interrupt_behavior_test: count_ref = {count_ref}")
    await reset_dut(dut)
    await start_one_enable(dut, count_ref)
    # Wait for the interrupt signal
    await RisingEdge(dut.o_irq)
    irq_initial = int(dut.o_irq.value)
    # Wait a short period to see if it deasserts
    await Timer(50, units='ns')
    irq_after = int(dut.o_irq.value)
    print(f"interrupt_behavior_test: o_irq initially {irq_initial}, after 50 ns {irq_after}")
    assert irq_initial == 1, "o_irq was not asserted when expected"
    assert irq_after == 0, "o_irq did not deassert after completion"
    print("interrupt_behavior_test: Interrupt signal behavior verified successfully.")
