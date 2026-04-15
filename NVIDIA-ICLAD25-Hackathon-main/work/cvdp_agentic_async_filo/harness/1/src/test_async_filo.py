import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


async def run_filo_test(dut, w_clk_period, r_clk_period):

    # Dynamically retrieve parameters from DUT
    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    DEPTH = int(dut.DEPTH.value)
    MAX_VALUE = (1 << DATA_WIDTH) - 1 

    # Log parameters
    cocotb.log.info(f"Running FILO test with DEPTH={DEPTH}, DATA_WIDTH={DATA_WIDTH}, "
                    f"w_clk_period={w_clk_period}ns, r_clk_period={r_clk_period}ns")

    # Initialize FILO state variables
    counter = 0  
    max_depth = DEPTH  

    cocotb.start_soon(Clock(dut.w_clk, w_clk_period, units="ns").start())  
    cocotb.start_soon(Clock(dut.r_clk, r_clk_period, units="ns").start()) 

    async def reset_filo():
        """Apply reset to the FILO."""
        dut.w_rst.value = 1
        dut.r_rst.value = 1
        dut.push.value = 0
        dut.pop.value = 0
        dut.w_data.value = 0
        await Timer(20, units="ns")
        dut.w_rst.value = 0
        dut.r_rst.value = 0
        await RisingEdge(dut.w_clk)
        cocotb.log.info("Reset complete")

    def dut_full():
        """Check if the FILO is full and return 1 for full, 0 otherwise."""
        return 1 if counter == max_depth else 0

    def dut_empty():
        """Check if the FILO is empty and return 1 for empty, 0 otherwise."""
        return 1 if counter == 0 else 0

    async def push(value):
        """Push a value into the FILO."""
        nonlocal counter
        if dut_full():
            cocotb.log.error(f"Cannot push {value:#x}, FILO is full (counter={counter}).")
            return
        dut.push.value = 1
        dut.w_data.value = value
        await RisingEdge(dut.w_clk)
        dut.push.value = 0
        counter += 1
        cocotb.log.info(f"Pushed: {value:#x} | Counter: {counter} | Full={dut_full()} | Empty={dut_empty()}")

    async def pop():
        """Pop a value from the FILO."""
        nonlocal counter
        if dut_empty():
            assert cocotb.log.error("Cannot pop, FILO is empty (counter=0).")
            return
        dut.pop.value = 1
        await RisingEdge(dut.r_clk)
        dut.pop.value = 0
        await Timer(1, units="ns")  
        popped_value = int(dut.r_data.value)
        counter -= 1
        cocotb.log.info(f"Popped: {popped_value:#x} | Counter: {counter} | Full={dut_full()} | Empty={dut_empty()}")

    # Test Case 1: Reset Test
    async def reset_test():
        cocotb.log.info("Starting reset test...")
        await reset_filo()
        if dut_empty() == 1 and dut_full() == 0:
            cocotb.log.info("Reset test passed: FILO is empty after reset.")
            assert dut_empty() == 1, f"Reset test failed: FILO should be empty after reset. Counter={counter}, Empty={dut_empty()}."
            assert dut_full() == 0, f"Reset test failed: FILO should not be full after reset. Counter={counter}, Full={dut_full()}."
        else:
            assert cocotb.log.error(f"Reset test failed: Counter={counter}, Full={dut_full()}, Empty={dut_empty()}.")

    # Test Case 2: Push to Full
    async def push_to_full_test():
        cocotb.log.info("Starting push to full test...")
        for _ in range(max_depth):
            await push(random.randint(0, (1 << DATA_WIDTH) - 1))
        if dut_full() == 1:
            cocotb.log.info("Push to full test passed: FILO is full.")
            assert dut_full() == 1, f"Push to full test failed: FILO should be full. Counter={counter}, Full={dut_full()}."
            assert dut_empty() == 0, f"Push to full test failed: FILO should not be empty when full. Counter={counter}, Empty={dut_empty()}."

        else:
            assert cocotb.log.error(f"Push to full test failed: Counter={counter}, Full={dut_full()}.")

    # Test Case 3: Pop to Empty
    async def pop_to_empty_test():
        cocotb.log.info("Starting pop to empty test...")
        while dut_empty() == 0:
            await pop()
        if dut_empty() == 1:
            cocotb.log.info("Pop to empty test passed: FILO is empty.")
            assert dut_full() == 0, f"Push to full test failed: FILO should be full. Counter={counter}, Full={dut_full()}."
            assert dut_empty() == 1, f"Push to full test failed: FILO should not be empty when full. Counter={counter}, Empty={dut_empty()}."

        else:
            assert cocotb.log.error(f"Pop to empty test failed: Counter={counter}, Empty={dut_empty()}.")

    # Run Tests
    await reset_test()
    await push_to_full_test()
    await pop_to_empty_test()

    cocotb.log.info(f"All tests completed with w_clk={w_clk_period}ns and r_clk={r_clk_period}ns.")


@cocotb.test()
async def test_filo_default_clocks(dut):
    """Run FILO test with default clock frequencies."""
    await run_filo_test(dut, w_clk_period=10, r_clk_period=15)


@cocotb.test()
async def test_filo_random_clocks(dut):
    """Run FILO test with random clock frequencies."""
    random_w_clk = random.randint(5, 50) 
    random_r_clk = random.randint(5, 50)  
    cocotb.log.info(f"Running FILO test with random clocks: w_clk={random_w_clk}ns, r_clk={random_r_clk}ns")
    await run_filo_test(dut, w_clk_period=random_w_clk, r_clk_period=random_r_clk)
