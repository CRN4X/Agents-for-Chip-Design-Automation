import random
from math import gcd

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def wait_for_operation_done(dut):
    """
    Wait until both key validation and encryption processes signal completion.
    This helper function waits until both 'done_key_check' and 'done_encryption'
    are asserted.
    """
    while True:
        await RisingEdge(dut.clk)
        if int(dut.done_key_check.value) == 1 and int(dut.done_encryption.value) == 1:
            break


def get_width(dut):
    """
    Retrieve the WIDTH parameter from the DUT if available.
    If unavailable, default to 8.
    """
    try:
        width = int(dut.WIDTH.value)
    except AttributeError:
        width = 8
    return width


@cocotb.test()
async def test_key_validation_and_encryption(dut):
    """
    Production-level testbench for the crypto accelerator:
      - Validates key validation for both valid and invalid keys.
      - Executes randomized stress tests using the parameterized WIDTH.
      - Checks boundary conditions based on the computed maximum value.
    """
    # Start clock on 'clk' with a 10 ns period using start_soon
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    width = get_width(dut)
    max_val = (2 ** width) - 1

    dut._log.info(f"Testbench started with WIDTH={width} (max value = {max_val})")

    # Reset the DUT.
    dut.rst.value             = 1
    dut.start_key_check.value = 0
    dut.candidate_e.value     = 0
    dut.totient.value         = 0
    dut.plaintext.value       = 0
    dut.modulus.value         = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value             = 0

    ##############
    # Test Case 1: Valid Key Scenario
    # For a valid key, choose candidate_e and totient such that gcd(candidate_e, totient)==1.
    ##############
    valid_candidate   = 3 if 3 <= max_val else 1
    valid_totient     = 10 if 10 <= max_val else max_val - 1
    valid_plaintext   = 7 if 7 <= max_val else 1
    valid_modulus     = 11 if 11 <= max_val else max_val - 1
    expected_key_valid = 1
    expected_ciphertext = pow(valid_plaintext, valid_candidate, valid_modulus)

    dut._log.info("Test Case 1: Valid Key Scenario")
    dut._log.info(f"Stimulus: candidate_e = {valid_candidate}, totient = {valid_totient}, "
                   f"plaintext = {valid_plaintext}, modulus = {valid_modulus}")
    dut._log.info(f"Expected: key_valid = {expected_key_valid} and ciphertext = {expected_ciphertext}")
    dut.candidate_e.value     = valid_candidate
    dut.totient.value         = valid_totient
    dut.plaintext.value       = valid_plaintext
    dut.modulus.value         = valid_modulus
    dut.start_key_check.value = 1  # Trigger the operation.
    await RisingEdge(dut.clk)
    dut.start_key_check.value = 0  # Deassert after one clock cycle.

    await wait_for_operation_done(dut)

    actual_key_valid = int(dut.key_valid.value)
    actual_ciphertext = int(dut.ciphertext.value)
    dut._log.info(f"Actual: key_valid = {actual_key_valid}, ciphertext = {actual_ciphertext}")

    assert actual_key_valid == expected_key_valid, (
        f"Test Case 1: Valid key not detected. Expected key_valid=1, got {actual_key_valid}."
    )
    assert actual_ciphertext == expected_ciphertext, (
        f"Test Case 1: Incorrect ciphertext. Expected {expected_ciphertext}, got {actual_ciphertext}."
    )
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    ##############
    # Test Case 2: Invalid Key Scenario
    # Use candidate_e = 4 and totient = 10, so that gcd(4,10)==2.
    ##############
    invalid_candidate = 4 if 4 <= max_val else 2
    expected_key_valid = 0
    # For an invalid key, expected ciphertext should be 0.
    expected_ciphertext = 0

    dut._log.info("Test Case 2: Invalid Key Scenario")
    dut._log.info(f"Stimulus: candidate_e = {invalid_candidate}, totient = {valid_totient}, "
                   f"plaintext = {valid_plaintext}, modulus = {valid_modulus}")
    dut._log.info(f"Expected: key_valid = {expected_key_valid} and ciphertext = {expected_ciphertext}")
    dut.candidate_e.value     = invalid_candidate
    dut.totient.value         = valid_totient  # Reuse totient from above.
    dut.plaintext.value       = valid_plaintext
    dut.modulus.value         = valid_modulus
    dut.start_key_check.value = 1
    await RisingEdge(dut.clk)
    dut.start_key_check.value = 0

    await wait_for_operation_done(dut)

    actual_key_valid = int(dut.key_valid.value)
    actual_ciphertext = int(dut.ciphertext.value)
    dut._log.info(f"Actual: key_valid = {actual_key_valid}, ciphertext = {actual_ciphertext}")

    assert actual_key_valid == expected_key_valid, (
        f"Test Case 2: Invalid key not detected. Expected key_valid=0, got {actual_key_valid}."
    )
    assert actual_ciphertext == expected_ciphertext, (
        f"Test Case 2: Incorrect ciphertext. Expected {expected_ciphertext}, got {actual_ciphertext}."
    )
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    ##############
    # Test Case 3: Randomized Stress Test
    # Run multiple randomized test iterations using parameterized max_val.
    ##############
    NUM_RANDOM_TESTS = 50
    dut._log.info("Test Case 3: Randomized Stress Test")
    for i in range(NUM_RANDOM_TESTS):
        candidate   = random.randint(1, max_val)
        totient_val = random.randint(1, max_val)
        plaintext_val = random.randint(0, max_val)
        modulus_val   = random.randint(1, max_val)

        # Determine expected key valid flag.
        expected_key_valid = 1 if gcd(candidate, totient_val) == 1 else 0
        # If key is valid, compute expected ciphertext; otherwise, it should be 0.
        if expected_key_valid == 1:
            expected_ciphertext = pow(plaintext_val, candidate, modulus_val)
        else:
            expected_ciphertext = 0

        dut.candidate_e.value     = candidate
        dut.totient.value         = totient_val
        dut.plaintext.value       = plaintext_val
        dut.modulus.value         = modulus_val
        dut.start_key_check.value = 1

        await RisingEdge(dut.clk)
        dut.start_key_check.value = 0

        await wait_for_operation_done(dut)

        actual_key_valid = int(dut.key_valid.value)
        actual_ciphertext = int(dut.ciphertext.value)

        dut._log.info(
            f"Iteration {i}: Stimulus - candidate_e = {candidate}, totient = {totient_val}, "
            f"plaintext = {plaintext_val}, modulus = {modulus_val}"
        )
        dut._log.info(
            f"Iteration {i}: Expected - key_valid = {expected_key_valid}, ciphertext = {expected_ciphertext}"
        )
        dut._log.info(
            f"Iteration {i}: Actual - key_valid = {actual_key_valid}, ciphertext = {actual_ciphertext}"
        )

        assert actual_key_valid == expected_key_valid, (
            f"Stress Test Iteration {i}: key_valid mismatch. Candidate = {candidate}, "
            f"Totient = {totient_val}. Expected key_valid = {expected_key_valid}, got {actual_key_valid}."
        )
        assert actual_ciphertext == expected_ciphertext, (
            f"Stress Test Iteration {i}: ciphertext mismatch. Candidate = {candidate}, "
            f"Plaintext = {plaintext_val}, Modulus = {modulus_val}. Expected ciphertext = {expected_ciphertext}, "
            f"got {actual_ciphertext}."
        )
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    ##############
    # Test Case 4: Boundary Conditions
    # Apply maximum boundary values as determined by WIDTH.
    ##############
    expected_key_valid = 0
    expected_ciphertext = 0

    dut._log.info("Test Case 4: Boundary Conditions")
    dut._log.info(f"Stimulus: candidate_e, totient, plaintext, modulus = {max_val} (maximum value)")
    dut._log.info(f"Expected: key_valid = {expected_key_valid} and ciphertext = {expected_ciphertext}")
    dut.candidate_e.value     = max_val
    dut.totient.value         = max_val
    dut.plaintext.value       = max_val
    dut.modulus.value         = max_val
    dut.start_key_check.value = 1

    await RisingEdge(dut.clk)
    dut.start_key_check.value = 0

    await wait_for_operation_done(dut)

    actual_key_valid = int(dut.key_valid.value)
    actual_ciphertext = int(dut.ciphertext.value)
    dut._log.info(f"Actual: key_valid = {actual_key_valid}, ciphertext = {actual_ciphertext}")

    assert actual_key_valid == expected_key_valid, (
        f"Boundary Test: Expected key_valid = {expected_key_valid}, got {actual_key_valid}."
    )
    assert actual_ciphertext == expected_ciphertext, (
        f"Boundary Test: Expected ciphertext = {expected_ciphertext}, got {actual_ciphertext}."
    )

    dut._log.info("All tests passed successfully for the crypto accelerator.")
