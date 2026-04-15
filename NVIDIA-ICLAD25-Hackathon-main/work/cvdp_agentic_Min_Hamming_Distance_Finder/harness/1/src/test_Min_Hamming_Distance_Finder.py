import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly , Timer

import harness_library as hrs_lb
import random

def compute_expected_difference(data_A, data_B, bit_width):
    xor_result = data_A ^ data_B
    return bin(xor_result).count("1")

def compute_expected_results(query, refs, bit_width, ref_count):

    expected_distance = bit_width + 1  # Initialize with a large value
    expected_index = 0
    for i in range(ref_count):
        # Extract the i-th reference vector using bit-masking and shifting
        ref_vector = (refs >> (i * bit_width)) & ((1 << bit_width) - 1)
        curr_distance = compute_expected_difference(query, ref_vector, bit_width)
        if curr_distance < expected_distance:
            expected_distance = curr_distance
            expected_index = i
    return expected_index, expected_distance

@cocotb.test()
async def test_Min_Hamming_Distance_Finder(dut):
    """
    Test edge-case scenarios for the Min_Hamming_Distance_Finder module.
    """
    # Retrieve parameters from DUT
    BIT_WIDTH = int(dut.BIT_WIDTH.value)
    # For REFERENCE_COUNT, if it is not exposed as a signal, set it here manually.
    REFERENCE_COUNT = int(dut.REFERENCE_COUNT.value)

    dut._log.info(f"Testing Min_Hamming_Distance_Finder with BIT_WIDTH={BIT_WIDTH} and REFERENCE_COUNT={REFERENCE_COUNT}")

    # --- Case 1: All references equal to input_query (zero distance) ---
    test_query = random.randint(0, (1 << BIT_WIDTH) - 1)
    refs_temp = 0
    # Build concatenated references so that every reference equals test_query.
    for i in range(REFERENCE_COUNT):
        refs_temp |= (test_query << (i * BIT_WIDTH))
    dut.input_query.value = test_query
    dut.references.value = refs_temp
    await Timer(10, units="ns")
    exp_index, exp_distance = compute_expected_results(test_query, refs_temp, BIT_WIDTH, REFERENCE_COUNT)
    observed_index = int(dut.best_match_index.value)
    observed_distance = int(dut.min_distance.value)
    assert observed_index == exp_index, (
        f"Edge Case 1: Expected best_match_index {exp_index}, got {observed_index}."
    )
    assert observed_distance == exp_distance, (
        f"Edge Case 1: Expected min_distance {exp_distance}, got {observed_distance}."
    )
    dut._log.info(f"Edge Case 1 passed: Query={test_query:0{BIT_WIDTH}b}, Refs={refs_temp:0{REFERENCE_COUNT * BIT_WIDTH}b} -> "
                  f"Expected index={exp_index}, dist={exp_distance}; Got index={observed_index}, dist={observed_distance}.")

    # --- Case 2: One reference is an exact match and others are different ---
    test_query = random.randint(0, (1 << BIT_WIDTH) - 1)
    # Let's define references:
    # Reference 0: Completely different (invert test_query)
    ref0 = ((1 << BIT_WIDTH) - 1) ^ test_query
    # Reference 1: Random value
    ref1 = random.randint(0, (1 << BIT_WIDTH) - 1)
    # Reference 2: Exact match
    ref2 = test_query
    # Reference 3: Random value
    ref3 = random.randint(0, (1 << BIT_WIDTH) - 1)
    refs_temp = ref0 | (ref1 << BIT_WIDTH) | (ref2 << (2 * BIT_WIDTH)) | (ref3 << (3 * BIT_WIDTH))
    dut.input_query.value = test_query
    dut.references.value = refs_temp
    await Timer(10, units="ns")
    exp_index, exp_distance = compute_expected_results(test_query, refs_temp, BIT_WIDTH, REFERENCE_COUNT)
    observed_index = int(dut.best_match_index.value)
    observed_distance = int(dut.min_distance.value)
    assert observed_index == exp_index, (
        f"Edge Case 2: Expected best_match_index {exp_index}, got {observed_index}."
    )
    assert observed_distance == exp_distance, (
        f"Edge Case 2: Expected min_distance {exp_distance}, got {observed_distance}."
    )
    dut._log.info(f"Edge Case 2 passed: Query={test_query:0{BIT_WIDTH}b}, Refs={refs_temp:0{REFERENCE_COUNT * BIT_WIDTH}b} -> "
                  f"Expected index={exp_index}, dist={exp_distance}; Got index={observed_index}, dist={observed_distance}.")


    await Timer(50, units="ns")
    
    dut._log.info(f"Starting Randomized Testing for Min_Hamming_Distance_Finder with BIT_WIDTH={BIT_WIDTH} and REFERENCE_COUNT={REFERENCE_COUNT}")

    for i in range(20):
        test_query = random.randint(0, (1 << BIT_WIDTH) - 1)
        refs_temp = random.getrandbits(REFERENCE_COUNT * BIT_WIDTH)
        dut.input_query.value = test_query
        dut.references.value = refs_temp
        await Timer(10, units="ns")
        exp_index, exp_distance = compute_expected_results(test_query, refs_temp, BIT_WIDTH, REFERENCE_COUNT)
        observed_index = int(dut.best_match_index.value)
        observed_distance = int(dut.min_distance.value)

        assert observed_index == exp_index, (
            f"Random Test {i+1}: Expected best_match_index {exp_index}, got {observed_index}."
        )
        assert observed_distance == exp_distance, (
            f"Random Test {i+1}: Expected min_distance {exp_distance}, got {observed_distance}."
        )
        dut._log.info(f"Random Test {i+1} passed: Query={test_query:0{BIT_WIDTH}b}, "
                      f"Refs={refs_temp:0{REFERENCE_COUNT * BIT_WIDTH}b}, "
                      f"Expected index={exp_index}, dist={exp_distance}; Got index={observed_index}, dist={observed_distance}.")
