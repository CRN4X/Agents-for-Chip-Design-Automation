# File: arithmetic_progression_generator.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random
import time
import math

def clog2(N):
    return math.ceil(math.log2(N))

@cocotb.test()
async def test_arithmetic_progression_generator(dut):
     
    # Randomly execute this statement in one of the iterations
    MIN_CLOCK_PERIOD = 4
    # clock_period_ns = random.randint(MIN_CLOCK_PERIOD, 15)  # For example, 10ns clock period
    clock_period_ns = 10  # For example, 10ns clock period
    cocotb.start_soon(Clock(dut.clk, clock_period_ns, units='ns').start())
    print("[INFO] Clock started.")
    
    # Initialize DUT
    await hrs_lb.dut_init(dut)
    
    # Apply reset 
    await hrs_lb.reset_dut(dut.resetn, clock_period_ns)
    await RisingEdge(dut.clk)   
    await RisingEdge(dut.clk)   

    # Extract parameters from the DUT
    DATA_WIDTH = int(dut.DATA_WIDTH.value)
    SEQUENCE_LENGTH = int(dut.SEQUENCE_LENGTH.value)
    if SEQUENCE_LENGTH == 0:
        SEQUENCE_LENGTH_MOD = 1
        EXPECTED_WIDTH_OUT_VAL = 1 + (DATA_WIDTH)
    else :
        SEQUENCE_LENGTH_MOD = SEQUENCE_LENGTH
        EXPECTED_WIDTH_OUT_VAL = clog2(SEQUENCE_LENGTH_MOD) + (DATA_WIDTH)
    WIDTH_OUT_VAL = int(dut.WIDTH_OUT_VAL.value)
    
    print(f"DATA_WIDTH= {DATA_WIDTH}, SEQUENCE_LENGTH= {SEQUENCE_LENGTH_MOD}, WIDTH_OUT_VAL={WIDTH_OUT_VAL} ")
    
    reset_system = 0
    # if random.choice([True, False]):
    #    reset_system = 1
    #    N_cycles_reset = random.randint(2, 5)
    #    Positive_delta = random.randint(3, 10)
    #    # Generate start_cycle mostly greater than SEQUENCE_LENGTH
    #    if random.random() < 0.8:  # 80% chance to be greater
    #        start_cycle_reset = random.randint(SEQUENCE_LENGTH_MOD + 2 , SEQUENCE_LENGTH_MOD + Positive_delta)
    #    else:  # 20% chance to be less
    #        start_cycle_reset = random.randint(1, SEQUENCE_LENGTH_MOD - 1)
    #    print(f"Reset will be given at {start_cycle_reset + 1} cycle for {N_cycles_reset} cycles!")
       
    Dessert_enable = 0
    # if random.choice([True, False]):
    #    Dessert_enable = 1
    #    N_cycles = random.randint(1, 3)
    #    start_cycle = random.randint(1, SEQUENCE_LENGTH_MOD-1)
    #    print(f"Enable will be deasserted at {start_cycle + 1} cycle for {N_cycles} cycles !")

    # Test-specific variables
    MAX_VALUE =  (1 << DATA_WIDTH) - 1 
    start_val = random.randint(1, MAX_VALUE)  # Example start value
    step_size = random.randint(1, MAX_VALUE)  # Example step size
    if random.choice([True, False]):
        start_val = MAX_VALUE  # Example start value
        step_size = MAX_VALUE  # Example start value
        print(f"Overflow check !")
        print(f"WIDTH_OUT_VAL = {WIDTH_OUT_VAL}, EXPECTED_WIDTH_OUT_VAL = {EXPECTED_WIDTH_OUT_VAL}")

    cycle_num = random.randint( SEQUENCE_LENGTH_MOD + 2, 100)
    cycle = 0
    expected_value = 0
    expected_value_s1 = 0
    expected_done = 0
    expected_done_s1 = 0
    counter = 0
    reset = 0
    
    for cycle in range(cycle_num):  # Run the test for random number of cycles
        ###############################################################
        ######### Applying reset to the system randomly
        ###############################################################
        dut.resetn.value = 1
        if reset_system == 1 :
            #reset applied for N cycles after start_cycle 
            reset = 0
            if cycle >= start_cycle_reset and cycle < start_cycle_reset + N_cycles_reset  :
                reset = 1
                dut.resetn.value = 0
                print(f"Reset applied for {N_cycles_reset} cycles!")
                expected_value = 0
                expected_value_s1 = 0
                expected_value_s2 = 0
                expected_done = 0
                expected_done_s1 = 0
                expected_done_s2 = 0
                counter = 0
        ###############################################################
        ######### Controlling enable signal randomly
        ###############################################################               
        enable = 1
        if Dessert_enable == 1 :
            #valid in 0 for N cycles after start_cycle 
            if cycle >= start_cycle and cycle < start_cycle + N_cycles  :
               enable = 0
               print(f"Enable deasserted for {N_cycles} cycles!")
        dut.enable.value = enable
        dut.start_val.value = start_val
        dut.step_size.value = step_size
        
        ###############################################################
        ######### Verification function
        ###############################################################
        if enable == 1 and not reset and SEQUENCE_LENGTH > 0:
            if counter < SEQUENCE_LENGTH :
                if counter == 0 : 
                    expected_value = start_val
                    expected_done = 0
                    counter = counter + 1
                else :
                    expected_value += step_size
                    expected_done = 0
                    counter = counter + 1
            else :
                expected_done = 1
        else : 
            expected_value = expected_value
            expected_done = expected_done
            counter = counter
        
        ###############################################################
        ######### Clock rise edge
        ###############################################################
        expected_value_s2 = expected_value_s1
        expected_done_s2 = expected_done_s1
        await RisingEdge(dut.clk)   
        expected_value_s1 = expected_value
        expected_done_s1 = expected_done
        
        ###############################################################
        ######### Actual RTL module
        ############################################################### 
        actual_value =dut.out_val.value.to_unsigned()
        actual_done = dut.done.value.to_unsigned()

        ###############################################################
        ######### Assertions
        ############################################################### 
        ##Assertion to check data out, assertion to check overflow
        assert actual_value == expected_value_s2, f"Error at step {i}: expected {expected_value_s2}, got {int(dut.out_val.value)}"
        ##Assertion to check done 
        assert actual_done == expected_done, "Done signal not asserted after sequence completion"
        ##Assertion to check val_out width 
        assert WIDTH_OUT_VAL == EXPECTED_WIDTH_OUT_VAL, "Wrong calculation of WIDTH_OUT_VAL"
        ##Assertion to check reset 
        if reset == 1 :
            assert actual_value == expected_value_s2 == 0 , f"Error at step {i}:At reset, expected {expected_value_s2}, got {actual_value}"
            assert actual_done == expected_done == 0 , f"Error at step {i}:At reset, expected_done {expected_done}, got {actual_done}"

        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: start_val = {hex(start_val)}")
        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: step_size = {step_size}")
        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: enable = {enable}")
        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: expected_value = {hex(expected_value_s2)}, expected_done = {expected_done}")
        print(f"[DEBUG] Cycle {cycle+1}/{cycle_num}: actual_value   = {hex(actual_value)}, actual_done   = {actual_done}")
        print(f"\n")
        