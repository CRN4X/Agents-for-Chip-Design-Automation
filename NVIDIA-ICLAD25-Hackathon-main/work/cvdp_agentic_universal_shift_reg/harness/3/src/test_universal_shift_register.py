import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

import harness_library as hrs_lb


def reverse_bits(value, n_bits=8):
    """
    Reverse the bit order of 'value' assuming it is 'n_bits' wide.
    """
    rev = 0
    for i in range(n_bits):
        rev <<= 1
        rev |= (value >> i) & 1
    return rev & ((1 << n_bits) - 1)


def update_expected_signals(expected_q,N): 
    # For Python, treat 'expected_q' as integer and find msb_out, lsb_out
    msb_out = (expected_q >> (N - 1)) & 1
    lsb_out = expected_q & 1
    # XOR of all bits for parity
    # Could do bin(expected_q).count('1') % 2, or ^ operator in a loop
    parity_out = 0
    tmp = expected_q
    for _ in range(N):
        parity_out ^= (tmp & 1)
        tmp >>= 1
    zero_flag = (expected_q == 0)

    return {
        "msb_out":       msb_out,
        "lsb_out":       lsb_out,
        "parity_out":    parity_out,
        "zero_flag":     zero_flag
    }


async def reset_register(dut):
    """
    Drive reset high for one clock cycle, then de-assert.
    Initialize signals to default values.
    """
    dut.rst.value        = 1
    dut.en.value         = 1  # Keep enable high (unless testing disabled mode)
    dut.op_sel.value     = 0
    dut.shift_dir.value  = 0
    dut.bitwise_op.value = 0
    dut.serial_in.value  = 0
    dut.parallel_in.value= 0

    # Wait for a rising edge
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    # Wait one more cycle for reset to settle
    await RisingEdge(dut.clk)
    dut._log.info("[RESET] DUT has been reset.")


async def check_outputs(dut, testname, expected_q, expected_overflow, 
                        expected_serial_out, extra_signals):
    """
    Compare DUT outputs to the provided expected values.
    extra_signals is the dictionary from update_expected_signals().
    Wait one rising edge so that the DUT outputs have updated.
    """
    await RisingEdge(dut.clk)

    # Convert to Python ints
    actual_q           = int(dut.q.value)
    actual_serial_out  = int(dut.serial_out.value)
    actual_overflow    = int(dut.overflow.value)
    actual_msb_out     = int(dut.msb_out.value)
    actual_lsb_out     = int(dut.lsb_out.value)
    actual_parity      = int(dut.parity_out.value)
    actual_zero_flag   = int(dut.zero_flag.value)

    # --- Q Check ---
    assert actual_q == expected_q, (
        f"{testname} [Q Mismatch]: Expected q={expected_q:08b}, got={actual_q:08b}"
    )
    dut._log.info(f"{testname} PASS: q={actual_q:08b}")

    # --- Overflow Check ---
    assert actual_overflow == expected_overflow, (
        f"{testname} [Overflow Mismatch]: Expected overflow={expected_overflow}, got={actual_overflow}"
    )
    dut._log.info(f"{testname} PASS: overflow={actual_overflow}")

    # --- Serial Out Check ---
    assert actual_serial_out == expected_serial_out, (
        f"{testname} [Serial Out Mismatch]: Expected serial_out={expected_serial_out}, got={actual_serial_out}"
    )
    dut._log.info(f"{testname} PASS: serial_out={actual_serial_out}")

    # --- MSB Check ---
    expected_msb_out = extra_signals["msb_out"]
    assert actual_msb_out == expected_msb_out, (
        f"{testname} [MSB Mismatch]: Expected msb_out={expected_msb_out}, got={actual_msb_out}"
    )
    dut._log.info(f"{testname} PASS: msb_out={actual_msb_out}")

    # --- LSB Check ---
    expected_lsb_out = extra_signals["lsb_out"]
    assert actual_lsb_out == expected_lsb_out, (
        f"{testname} [LSB Mismatch]: Expected lsb_out={expected_lsb_out}, got={actual_lsb_out}"
    )
    dut._log.info(f"{testname} PASS: lsb_out={actual_lsb_out}")

    # --- Parity Check ---
    expected_parity = extra_signals["parity_out"]
    assert actual_parity == expected_parity, (
        f"{testname} [Parity Mismatch]: Expected parity_out={expected_parity}, got={actual_parity}"
    )
    dut._log.info(f"{testname} PASS: parity_out={actual_parity}")

    # --- Zero Flag Check ---
    expected_zero_flag = extra_signals["zero_flag"]
    assert actual_zero_flag == expected_zero_flag, (
        f"{testname} [Zero Flag Mismatch]: Expected zero_flag={expected_zero_flag}, got={actual_zero_flag}"
    )
    dut._log.info(f"{testname} PASS: zero_flag={actual_zero_flag}")


################################################################################
# Main Test
################################################################################

@cocotb.test()
async def test_universal_shift_register(dut):
    """
    Cocotb-based test replicating the functionality of the original SV testbench.
    """
    N = int(dut.N.value)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    await hrs_lb.dut_init(dut)
    await RisingEdge(dut.clk)
    # Initially reset
    await reset_register(dut)

    dut._log.info("=========== Starting Expanded USR Cocotb Tests ===========")

    ############################################################################
    # TEST #1: HOLD (op_sel = 000)
    ############################################################################
    dut._log.info("--- TEST: HOLD (op_sel=000) ---")
    # 1) Load some random value
    rand_val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = rand_val
    dut.op_sel.value      = 0b011  # parallel load
    expected_q = rand_val
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow   = 0
    expected_serial_out = (expected_q & 1)

    await RisingEdge(dut.clk)
    # Check after load
    await check_outputs(dut, "HOLD(Load)", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)
                        
    await RisingEdge(dut.clk)
    # 2) Switch to HOLD mode
    dut.op_sel.value = 0b000
    # Let it run a few cycles
    for _ in range(3):
        # Q should not change
        await check_outputs(dut, "HOLD(NoChange)", expected_q,
                            expected_overflow,
                            expected_serial_out,
                            extra_signals)

    ############################################################################
    # TEST #2: SHIFT (Logical) (op_sel = 001)
    ############################################################################
    dut._log.info("--- TEST: SHIFT (Logical) (op_sel=001) ---")
    # SHIFT RIGHT Test
    await RisingEdge(dut.clk)
    await reset_register(dut)

    parallel_in = random.getrandbits(N)
    serial_in = random.randint(0, 1)

    dut.parallel_in.value = parallel_in
    dut.serial_in.value = serial_in
    dut.op_sel.value = 0b011  # Parallel load

    expected_q = parallel_in
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    extra_signals = update_expected_signals(expected_q, N)
    await RisingEdge(dut.clk)

    dut.shift_dir.value = 0  # shift right
    dut.op_sel.value = 0b001


    expected_overflow = expected_q & 1
    expected_q = (serial_in << (N - 1)) | (expected_q >> 1)
    expected_serial_out = expected_q & 1
    extra_signals = update_expected_signals(expected_q, N)
    await RisingEdge(dut.clk)
    await check_outputs(dut, "SHIFT_RIGHT", expected_q, expected_overflow, expected_serial_out,extra_signals)

    # SHIFT LEFT Test
    await reset_register(dut)
    await RisingEdge(dut.clk)

    parallel_in = random.getrandbits(N)
    serial_in = random.randint(0, 1)

    dut.parallel_in.value = parallel_in
    dut.serial_in.value = serial_in
    dut.op_sel.value = 0b011  # Parallel load

    expected_q = parallel_in
    expected_overflow = 0
    expected_serial_out = (expected_q >> (N - 1)) & 1
    extra_signals = update_expected_signals(expected_q, N)
    await RisingEdge(dut.clk)

    dut.shift_dir.value = 1  # shift left
    dut.op_sel.value = 0b001

    expected_overflow = (expected_q >> (N - 1)) & 1
    expected_q = ((expected_q << 1) | serial_in) & ((1 << N) - 1)
    expected_serial_out = (expected_q >> (N - 1)) & 1
    extra_signals = update_expected_signals(expected_q, N)
    await RisingEdge(dut.clk)
    await check_outputs(dut, "SHIFT_LEFT", expected_q, expected_overflow, expected_serial_out,extra_signals)

    ############################################################################
    # TEST #3: ROTATE (op_sel = 010)
    ############################################################################
    dut._log.info("--- TEST: ROTATE (op_sel=010) ---")
    await reset_register(dut)
    await RisingEdge(dut.clk)

    rand_val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = rand_val
    dut.op_sel.value = 0b011  # load
    expected_q = rand_val
    extra_signals = update_expected_signals(expected_q,N)

    await RisingEdge(dut.clk)
    # Rotate Right
    dut.shift_dir.value = 0
    dut.op_sel.value    = 0b010

        # The LSB is the "overflow," but it re-enters as the MSB
    overflow_bit = expected_q & 1
    expected_overflow = overflow_bit
    expected_q = (overflow_bit << (N-1)) | (expected_q >> 1)
    overflow_bit = expected_q & 1
    expected_serial_out = overflow_bit
    extra_signals = update_expected_signals(expected_q,N)

    await RisingEdge(dut.clk)
    await check_outputs(dut, f"ROTATE_RIGHT", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # Rotate Left
    await reset_register(dut)
    await RisingEdge(dut.clk)
    rand_val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = rand_val
    dut.op_sel.value = 0b011  # load
    expected_q = rand_val
    extra_signals = update_expected_signals(expected_q,N)
    
    await RisingEdge(dut.clk)
    dut.shift_dir.value = 1
    dut.op_sel.value    = 0b010
    overflow_bit = (expected_q >> (N-1)) & 1
    expected_overflow = overflow_bit
    expected_q = ((expected_q << 1) & ((1 << N) - 1)) | overflow_bit
    overflow_bit = (expected_q >> (N-1)) & 1
    expected_serial_out = overflow_bit
    extra_signals = update_expected_signals(expected_q,N)

    await RisingEdge(dut.clk)
    await check_outputs(dut, f"ROTATE_LEFT", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    ############################################################################
    # TEST #4: PARALLEL LOAD (op_sel = 011)
    ############################################################################
    dut._log.info("--- TEST: PARALLEL LOAD (op_sel=011) ---")
    await reset_register(dut)

    # Load #1
    val_list = [random.randint(0, (1 << N) - 1) for _ in range(2)]
    for idx, val in enumerate(val_list):
        dut.parallel_in.value = val
        dut.op_sel.value = 0b011
        await RisingEdge(dut.clk)
        expected_q = val
        extra_signals = update_expected_signals(expected_q,N)
        expected_overflow = 0
        # shift_dir is presumably 0 from reset, so serial_out=LSB of loaded
        expected_serial_out = val & 1
        await check_outputs(dut, f"PARALLEL_LOAD_{idx+1}", expected_q,
                            expected_overflow,
                            expected_serial_out,
                            extra_signals)

    ############################################################################
    # TEST #5: ARITHMETIC SHIFT (op_sel = 100)
    ############################################################################
    dut._log.info("--- TEST: ARITHMETIC SHIFT (op_sel=100) ---")
    await reset_register(dut)
    await RisingEdge(dut.clk)
    # SHIFT RIGHT (sign bit replicates)
    test_val = (1 << (N - 1)) | random.getrandbits(N - 1)
    dut.parallel_in.value = test_val
    dut.op_sel.value = 0b011  # load
    expected_q = test_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    dut.shift_dir.value = 0
    dut.op_sel.value    = 0b100
    lost_bit = expected_q & 1
    expected_overflow = lost_bit
    await RisingEdge(dut.clk)
    sign_bit = (expected_q >> (N-1)) & 1
    expected_q = (sign_bit << (N-1)) | (expected_q >> 1)
    extra_signals = update_expected_signals(expected_q,N)
    lost_bit = expected_q & 1
    expected_serial_out = lost_bit
    await check_outputs(dut, f"ARITH_SHIFT_RIGHT", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # SHIFT LEFT (like logical shift left)
    await reset_register(dut)
    await RisingEdge(dut.clk)
    test_val = (0 << (N - 1)) | random.getrandbits(N - 1)
    dut.parallel_in.value = test_val
    dut.op_sel.value = 0b011
    expected_q = test_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    dut.shift_dir.value = 1
    dut.op_sel.value    = 0b100
    lost_bit = (expected_q >> (N-1)) & 1
    expected_overflow = lost_bit
    await RisingEdge(dut.clk)
    expected_q = ((expected_q << 1) & ((1 << N) - 1))
    extra_signals = update_expected_signals(expected_q,N)
    lost_bit = (expected_q >> (N-1)) & 1
    expected_serial_out = lost_bit
    await check_outputs(dut, f"ARITH_SHIFT_LEFT", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    ############################################################################
    # TEST #6: BITWISE OPS (op_sel = 101)
    ############################################################################
    dut._log.info("--- TEST: BITWISE OPS (op_sel=101) ---")
    await reset_register(dut)

    # 1) AND
    base_val = 0xF
    dut.parallel_in.value = base_val
    dut.op_sel.value = 0b011  # load
    expected_q = base_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)
    dut.bitwise_op.value = 0b00  # AND
    dut.op_sel.value = 0b101
    await RisingEdge(dut.clk)
    # We do Q & parallel_in again. If your DUT is coded that way,
    # it may be Q & Q or Q & parallel_in, etc. 
    # In your original bench you used "expected_q & 8'hF0" 
    # Here let's assume the second operand is parallel_in again:
    expected_q = expected_q & base_val
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1  # shift_dir=0
    await check_outputs(dut, "BITWISE_AND", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # 2) OR
    await reset_register(dut)
    base_val = 0x5
    dut.parallel_in.value = base_val
    dut.op_sel.value = 0b011
    expected_q = base_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    dut.bitwise_op.value = 0b01  # OR
    dut.op_sel.value = 0b101
    await RisingEdge(dut.clk)
    expected_q = expected_q | base_val
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await check_outputs(dut, "BITWISE_OR", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # 3) XOR
    await reset_register(dut)
    base_val = 0xF
    dut.parallel_in.value = base_val
    dut.op_sel.value = 0b011
    expected_q = base_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    # We'll do Q ^ 0xFF
    dut.bitwise_op.value = 0b10  # XOR
    dut.op_sel.value = 0b101
    await RisingEdge(dut.clk)
    expected_q = expected_q ^ base_val
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await check_outputs(dut, "BITWISE_XOR", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # 4) XNOR
    await reset_register(dut)
    base_val = 0x0
    dut.parallel_in.value = base_val
    dut.op_sel.value = 0b011
    expected_q = base_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    dut.bitwise_op.value = 0b11  # XNOR
    dut.op_sel.value = 0b101
    await RisingEdge(dut.clk)
    expected_q = ~(expected_q ^ base_val) & ((1 << N) - 1)
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await check_outputs(dut, "BITWISE_XNOR", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    ############################################################################
    # TEST #7: REVERSE BITS (op_sel = 110)
    ############################################################################
    dut._log.info("--- TEST: REVERSE BITS (op_sel=110) ---")
    await reset_register(dut)
    await RisingEdge(dut.clk)
    test_val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = test_val
    dut.op_sel.value = 0b011
    expected_q = test_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)
    await check_outputs(dut, "BEFORE_REVERSE", expected_q,
                        0,  # overflow
                        (expected_q & 1),  # serial_out if shift_dir=0
                        extra_signals)
    await RisingEdge(dut.clk)

    # Reverse
    dut.op_sel.value = 0b110
    await RisingEdge(dut.clk)
    expected_q = reverse_bits(expected_q, N)
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await check_outputs(dut, "AFTER_REVERSE", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    ############################################################################
    # TEST #8: COMPLEMENT (op_sel = 111)
    ############################################################################
    dut._log.info("--- TEST: COMPLEMENT (op_sel=111) ---")
    await reset_register(dut)
    await RisingEdge(dut.clk)

    test_val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = test_val
    dut.op_sel.value = 0b011
    expected_q = test_val
    extra_signals = update_expected_signals(expected_q,N)
    await RisingEdge(dut.clk)

    dut.op_sel.value = 0b111
    await RisingEdge(dut.clk)
    expected_q = ~expected_q & ((1 << N) - 1)
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await check_outputs(dut, "COMPLEMENT", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    ############################################################################
    # TEST #9: ENABLE TEST (en=0)
    ############################################################################
    dut._log.info("--- TEST: ENABLE (en=0) ---")
    await reset_register(dut)
    val = random.randint(0, (1 << N) - 1)
    dut.parallel_in.value = val
    dut.op_sel.value = 0b011  # load
    expected_q = val
    extra_signals = update_expected_signals(expected_q,N)
    expected_overflow = 0
    expected_serial_out = expected_q & 1
    await RisingEdge(dut.clk)
    await check_outputs(dut, "ENABLE_BEFORE", expected_q,
                        expected_overflow,
                        expected_serial_out,
                        extra_signals)

    # Now disable and try SHIFT
    dut.en.value = 0
    dut.op_sel.value = 0b001  # SHIFT
    dut.shift_dir.value = 0
    dut.serial_in.value = 1
    # The register should NOT change
    # Wait some cycles
    for i in range(3):
        await RisingEdge(dut.clk)
        await check_outputs(dut, f"ENABLE_DISABLED_{i}", expected_q,
                            expected_overflow,
                            expected_serial_out,
                            extra_signals)

    dut._log.info("=========== ALL TESTS COMPLETED ===========")
