import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles, Timer
import harness_library as hrs_lb
import random
import time
from cocotb.triggers import with_timeout
import cocotb.simulator


cocotb.simulator.dump_enabled = True

#----------------------------------------------------------------------------
# Utility Task
#----------------------------------------------------------------------------
async def populate_coeff_ram(dut, coeff_list):
    """
    Populate all coefficient RAMs
    """
    await Timer(1, units='ns')
    tap_count = int(dut.poly_branches[0].u_poly_filter.TAPS.value)
    phase_count = int(dut.M.value)
    total_coeffs = tap_count * phase_count
    dut._log.info(f"Populating coefficient RAMs (decimator): tap_count = {tap_count}, phase_count = {phase_count}, total_coeffs = {total_coeffs}")

    assert len(coeff_list) == total_coeffs, (
        f"Coefficient list length {len(coeff_list)} does not match expected {total_coeffs}"
    )

    for p in range(phase_count):
        for j in range(tap_count):
            addr = p * tap_count + j
            coeff_value = coeff_list[addr]
            try:
                dut.poly_branches[p].u_poly_filter.coeff_fetch[j].u_coeff_ram.mem[addr].value = coeff_value
                dut._log.info(f"Set coefficient for phase {p}, tap {j} (addr {addr}) to {coeff_value}")
            except Exception as e:
                dut._log.error(f"Failed to set coefficient for phase {p}, tap {j} (addr {addr}): {e}")
    await Timer(1, units='ns')

# Test 1: One Sample Decimation

@cocotb.test()
async def test_one_sample_decimation(dut):
    """
    Test that after feeding M input samples, one decimated output is generated.
    """
    # Start clock.
    cocotb.start_soon(Clock(dut.clk, 5, units="ns").start())
    await hrs_lb.dut_init(dut)

    # Apply reset.
    dut.arst_n.value = 0
    await Timer(50, units="ns")
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Starting test_one_sample_decimation")

    # For decimation with M=2, TAPS=2, total coefficients = 4.
    coeffs = [1, 2, 3, 4]
    await populate_coeff_ram(dut, coeffs)

    # Apply two input samples.
    X1 = 10
    X2 = 20

    # First sample
    await RisingEdge(dut.clk)
    dut.in_sample.value = X1
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)

    # Second sample
    dut.in_sample.value = X2
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)

    # Capture decimated output.
    outputs = []
    timeout_cycles = 50
    cycle = 0
    while len(outputs) < 1 and cycle < timeout_cycles:
        await RisingEdge(dut.clk)
        if int(dut.out_valid.value) == 1:
            outputs.append(int(dut.out_sample.value))
            dut._log.info(f"Captured decimated output: {int(dut.out_sample.value)}")
        cycle += 1

    expected = [50]
    assert outputs == expected, f"test_one_sample_decimation failed: expected {expected}, got {outputs}"
    dut._log.info("test_one_sample_decimation passed.")



# Test 2: Back-to-Back Samples Decimation
@cocotb.test()
async def test_back_to_back_samples_decimation(dut):
    """
    Test that two back-to-back decimation events produce consecutive outputs.
    """
    cocotb.start_soon(Clock(dut.clk, 5, units="ns").start())
    await hrs_lb.dut_init(dut)

    dut._log.info("Starting test_back_to_back_samples_decimation")
    coeffs = [1, 2, 3, 4]
    await populate_coeff_ram(dut, coeffs)

    # Apply reset.
    dut.arst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    # First decimation event: feed X1 and X2.
    X1 = 10
    X2 = 20

    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)
    dut.in_sample.value = X1
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)
    dut.in_sample.value = X2
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    outputs1 = []
    timeout_cycles = 50
    cycle = 0
    while len(outputs1) < 1 and cycle < timeout_cycles:
        await RisingEdge(dut.clk)
        if int(dut.out_valid.value) == 1:
            outputs1.append(int(dut.out_sample.value))
            dut._log.info(f"Captured first decimated output: {int(dut.out_sample.value)}")
        cycle += 1

    expected1 = [50]

    # Second decimation feed X3 and X4.
    X3 = 30
    X4 = 40

    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)
    dut.in_sample.value = X3
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    while not int(dut.in_ready.value):
        await RisingEdge(dut.clk)
    dut.in_sample.value = X4
    dut.in_valid.value = 1
    await RisingEdge(dut.clk)
    dut.in_valid.value = 0

    outputs2 = []
    cycle = 0
    while len(outputs2) < 1 and cycle < timeout_cycles:
        await RisingEdge(dut.clk)
        if int(dut.out_valid.value) == 1:
            outputs2.append(int(dut.out_sample.value))
            dut._log.info(f"Captured second decimated output: {int(dut.out_sample.value)}")
        cycle += 1

    expected2 = [210]

    assert outputs1 == expected1, f"First decimation event failed: expected {expected1}, got {outputs1}"
    assert outputs2 == expected2, f"Second decimation event failed: expected {expected2}, got {outputs2}"
    dut._log.info("test_back_to_back_samples_decimation passed.")



# Test 3: Edge Cases Decimation
@cocotb.test()
async def test_edge_cases_decimation(dut):
    """
    Test decimation with edge-case inputs.
    """
    cocotb.start_soon(Clock(dut.clk, 5, units="ns").start())
    await hrs_lb.dut_init(dut)

    dut._log.info("Starting test_edge_cases_decimation")
    coeffs = [1, 2, 3, 4]
    await populate_coeff_ram(dut, coeffs)

    # Apply reset.
    dut.arst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    # Edge case 1
    X = 0
    for _ in range(2):
        while not int(dut.in_ready.value):
            await RisingEdge(dut.clk)
        dut.in_sample.value = X
        dut.in_valid.value = 1
        await RisingEdge(dut.clk)
        dut.in_valid.value = 0

    outputs = []
    timeout_cycles = 50
    cycle = 0
    while len(outputs) < 1 and cycle < timeout_cycles:
        await RisingEdge(dut.clk)
        if int(dut.out_valid.value) == 1:
            outputs.append(int(dut.out_sample.value))
            dut._log.info(f"Captured output for 0 input: {int(dut.out_sample.value)}")
        cycle += 1

    expected = [0]
    assert outputs == expected, f"Edge-case (0) failed: expected {expected}, got {outputs}"

    # Edge case 2
    X = 32767
    for _ in range(2):
        while not int(dut.in_ready.value):
            await RisingEdge(dut.clk)
        dut.in_sample.value = X
        dut.in_valid.value = 1
        await RisingEdge(dut.clk)
        dut.in_valid.value = 0

    outputs = []
    cycle = 0
    while len(outputs) < 1 and cycle < timeout_cycles:
        await RisingEdge(dut.clk)
        if int(dut.out_valid.value) == 1:
            outputs.append(int(dut.out_sample.value))
            dut._log.info(f"Captured output for 32767 input: {int(dut.out_sample.value)}")
        cycle += 1

    expected = [131068]
    assert outputs == expected, f"Edge-case (32767) failed: expected {expected}, got {outputs}"
    dut._log.info("test_edge_cases_decimation passed.")


@cocotb.test()
async def test_random_samples_decimation(dut):
    """
    Test decimation with random input samples.
    """
    cocotb.start_soon(Clock(dut.clk, 5, units="ns").start())
    await hrs_lb.dut_init(dut)
    dut._log.info("Starting test_random_samples_decimation (decimator)")

    # Apply reset.
    dut.arst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.arst_n.value = 1
    await RisingEdge(dut.clk)

    # Read parameters.
    tap_count = int(dut.poly_branches[0].u_poly_filter.TAPS.value)
    M_val     = int(dut.M.value)
    total_taps = M_val * tap_count
    dut._log.info(f"Detected parameters: M = {M_val}, TAPS = {tap_count}, TOTAL_TAPS = {total_taps}")

    coeffs = [i + 1 for i in range(total_taps)]
    await populate_coeff_ram(dut, coeffs)

    num_samples = 10
    random.seed(12345)
    random_inputs = [random.randint(0, 100) for _ in range(num_samples)]
    dut._log.info(f"Random input samples: {random_inputs}")

    shift_reg = [0] * total_taps
    all_expected = []
    captured_outputs = []

    for k, sample in enumerate(random_inputs):
        shift_reg = [sample] + shift_reg[:-1]
        
        await RisingEdge(dut.clk)
        while not int(dut.in_ready.value):
            await RisingEdge(dut.clk)
        dut.in_sample.value = sample
        dut.in_valid.value  = 1
        await RisingEdge(dut.clk)
        dut.in_valid.value  = 0
        await RisingEdge(dut.clk)

        if ((k + 1) % M_val) == 0:
            branch0 = shift_reg[0] * coeffs[0] + shift_reg[2] * coeffs[1]
            branch1 = shift_reg[1] * coeffs[2] + shift_reg[3] * coeffs[3]
            expected_val = branch0 + branch1
            all_expected.append(expected_val)
            dut._log.info(f"After sample index {k} (sample={sample}), modeled shift_reg = {shift_reg}, "
                          f"expected decimated output = {expected_val}")

            # Capture the produced decimated output.
            captured = []
            timeout_cycles = 50
            cycle = 0
            while len(captured) < 1 and cycle < timeout_cycles:
                await RisingEdge(dut.clk)
                if int(dut.out_valid.value) == 1:
                    captured.append(int(dut.out_sample.value))
                    dut._log.info(f"Captured decimated output after sample index {k}: {int(dut.out_sample.value)}")
                cycle += 1
            assert len(captured) >= 1, f"Timeout waiting for decimated output after sample index {k}"
            captured_outputs.append(captured[0])
            assert captured[0] == expected_val, \
                f"Decimation failed at sample index {k}: expected {expected_val}, got {captured[0]}"

    dut._log.info(f"test_random_samples_decimation passed. Expected outputs: {all_expected}, "
                  f"Captured outputs: {captured_outputs}")
