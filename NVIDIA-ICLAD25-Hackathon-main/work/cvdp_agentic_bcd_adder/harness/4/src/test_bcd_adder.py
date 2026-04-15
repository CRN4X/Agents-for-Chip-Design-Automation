import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly , Timer

import harness_library as hrs_lb
import random

# Utility: Convert integer to packed BCD (4 bits per digit, little-endian)
def int_to_bcd(value, digits):
    bcd = 0
    for i in range(digits):
        bcd |= ((value % 10) & 0xF) << (i * 4)
        value //= 10
    return bcd

# Utility: Convert BCD to string for readable log output
def bcd_to_str(bcd, digits):
    s = ""
    for i in reversed(range(digits)):
        digit = (bcd >> (4 * i)) & 0xF
        s += chr(digit + ord('0'))
    return s

@cocotb.test()
async def test_bcd_top_compare(dut):
    """
    Test the bcd_top comparator module with multiple cases.
    """

    N   = int(dut.N.value)
    max_value = 10 ** N

    total_tests = 0
    passed_tests = 0

    async def run_test_case(test_num, A_int, B_int, description=""):
        nonlocal total_tests, passed_tests

        bcd_A = int_to_bcd(A_int, N)
        bcd_B = int_to_bcd(B_int, N)

        dut.A.value = bcd_A
        dut.B.value = bcd_B

        await Timer(5, units='ns')  # Allow time for signals to propagate

        # Read DUT outputs
        A_lt = int(dut.A_less_B.value)
        A_eq = int(dut.A_equal_B.value)
        A_gt = int(dut.A_greater_B.value)

        # Expected results
        exp_lt = int(A_int < B_int)
        exp_eq = int(A_int == B_int)
        exp_gt = int(A_int > B_int)

        A_str = bcd_to_str(bcd_A, N)
        B_str = bcd_to_str(bcd_B, N)
        
        dut._log.info(f"Test {test_num}: {description}")
        dut._log.info(f"Inputs:     A = {A_int} , B = {B_int}")
        dut._log.info(f"Expected:   LT = {exp_lt}, EQ = {exp_eq}, GT = {exp_gt}")
        dut._log.info(f"From DUT:   LT = {A_lt}, EQ = {A_eq}, GT = {A_gt}")
        
        total_tests += 1
        if A_lt == exp_lt and A_eq == exp_eq and A_gt == exp_gt:
            passed_tests += 1
            dut._log.info(f"[PASS] Test {test_num}: {description}")
        else:
            dut._log.error(
                f"[FAIL] Test {test_num}: {description} | A={A_str}, B={B_str} | "
                f"Expected: LT/EQ/GT = {exp_lt}/{exp_eq}/{exp_gt} | "
                f"Got: {A_lt}/{A_eq}/{A_gt}"
            )

    # Fixed test cases
    await run_test_case(1, 0, 0, "A = 0, B = 0")
    await run_test_case(2, 0, 1, "A < B")
    await run_test_case(3, 1, 0, "A > B")
    await run_test_case(4, 1234, 1234, "A == B (multi-digit)")
    await run_test_case(5, 1000, 999, "A > B (borrow boundary)")
    await run_test_case(6, 9999, 0, "A > B (max vs min)")
    await run_test_case(7, 0, 9999, "A < B (min vs max)")

    # Random test cases
    for i in range(8, 38):
        A_rand = random.randint(0, max_value - 1)
        B_rand = random.randint(0, max_value - 1)
        await run_test_case(i, A_rand, B_rand, "Random compare")

    # Summary
    dut._log.info("===============================================")
    dut._log.info(f"TOTAL TESTS  : {total_tests}")
    dut._log.info(f"TESTS PASSED : {passed_tests}")
    dut._log.info(f"TESTS FAILED : {total_tests - passed_tests}")
    dut._log.info("===============================================")