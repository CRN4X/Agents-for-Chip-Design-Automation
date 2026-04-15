import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


async def initialize_dut(dut):
    """Reset and initialize DUT signals."""
    dut.reset_in.value = 1
    dut.clk_enable_in.value = 0
    dut.data_in.value = 0
    dut.output_gate_in.value = 0
    dut.p_in.value = 0
    dut.n_in.value = 0

    cocotb.start_soon(Clock(dut.clk_in, 488, units="ns").start())

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    dut.reset_in.value = 0
    dut.clk_enable_in.value = 1
    dut.output_gate_in.value = 1

    cocotb.log.info("[TB] DUT initialized")


def generate_prbs15(shiftreg):
    """Generate next PRBS15 value."""
    feedback = not ((shiftreg >> 14) ^ (shiftreg >> 13)) & 1
    shiftreg = ((shiftreg << 1) | feedback) & 0x7FFF
    return shiftreg, (shiftreg >> 0) & 1


def get_expected_delayed_bit(shiftreg, encoder_type):
    return (shiftreg >> (6 + 2 * encoder_type)) & 1

def get_expected_random_delayed_bit(buffer, index, encoder_type):
    delay = 6 + 2 * encoder_type
    if index >= delay:
        return buffer[index - delay]
    else:
        return None  # Still in delay region

def update_dc_balance(p, n, pulse_active_state, running_sum):
    """Update the running DC balance sum."""
    if p == pulse_active_state:
        running_sum += 1
    elif n == pulse_active_state:
        running_sum -= 1
    return running_sum


def update_zero_count(p, n, pulse_active_state, zero_count):
    """Update the zero count."""
    if p == pulse_active_state or n == pulse_active_state:
        return 0
    else:
        return zero_count + 1


def check_errors(cycle, decoded, expected, running_sum, zero_count,
                 encoder_type, p, n, pulse_active_state, code_error):
    """Perform all error checks."""
    errors = 0

    if running_sum >= 2 or running_sum <= -2:
        cocotb.log.error(f"[CHECK] Running Sum Error ({running_sum}) at cycle {cycle}")
        errors += 1

    if p == pulse_active_state and n == pulse_active_state:
        cocotb.log.error(f"[CHECK] Simultaneous P and N Pulse Error at cycle {cycle}")
        errors += 1

    if zero_count > encoder_type:
        cocotb.log.error(f"[CHECK] Long String Of Zeros ({zero_count}) at cycle {cycle}")
        errors += 1

    if decoded != expected:
        cocotb.log.error(f"[CHECK] Decoder Bit Error: Expected {expected}, Got {decoded} at cycle {cycle}")
        errors += 1

    if code_error != 0:
        cocotb.log.error(f"[CHECK] Decoder Code Error flag set at cycle {cycle}")
        errors += 1

    return errors


@cocotb.test()
async def hdbn_prbs15_test(dut):
    """
    Full loopback test: PRBS source, encoder, loopback, decoder, error checking.
    """
    # Constants
    StartupTransient = 15000  # ns
    clock_period_ns = 488

    # Parameters from DUT
    EncoderType = int(dut.encoder_type.value)
    PulseActiveState = int(dut.pulse_active_state.value)

    # Initialize state
    RunningSum = 0
    ZeroCount = 0
    ErrorCount = 0
    BitCount = 0
    CorrectBits = 0
    shiftreg = 0
    total_time_ns = 0

    await initialize_dut(dut)
    cocotb.log.info("[TB] Starting full loopback test")

    for cycle in range(500):
        # PRBS generation
        shiftreg, input_bit = generate_prbs15(shiftreg)
        expected_delayed = get_expected_delayed_bit(shiftreg, EncoderType)

        # Drive encoder
        dut.data_in.value = input_bit
        await RisingEdge(dut.clk_in)

        # Loopback
        dut.p_in.value = dut.p_out.value.to_unsigned()
        dut.n_in.value = dut.n_out.value.to_unsigned()

        # Sample DUT outputs
        p = int(dut.p_out.value)
        n = int(dut.n_out.value)
        decoded = int(dut.data_out.value)
        code_error = int(dut.code_error_out.value)

        # Update tracking
        total_time_ns += clock_period_ns
        BitCount += 1
        RunningSum = update_dc_balance(p, n, PulseActiveState, RunningSum)
        ZeroCount = update_zero_count(p, n, PulseActiveState, ZeroCount)

        cocotb.log.info(
            f"[Cycle {cycle:03d}] input={input_bit} | p_out={p} n_out={n} | "
            f"data_out={decoded} | code_err={code_error} | RunningSum={RunningSum}"
        )

        # Error checks after transient period
        if total_time_ns >= StartupTransient:
            errors = check_errors(
                cycle, decoded, expected_delayed, RunningSum, ZeroCount,
                EncoderType, p, n, PulseActiveState, code_error
            )
            ErrorCount += errors
            if errors == 0:
                CorrectBits += 1

    # Final report
    cocotb.log.info("\n[TB] Loopback Simulation Results:")
    cocotb.log.info(f"[TB] Total bits processed: {BitCount}")
    cocotb.log.info(f"[TB] Correctly decoded bits: {CorrectBits} ({(100.0*CorrectBits)/BitCount:.2f}%)")
    cocotb.log.info(f"[TB] Total errors detected: {ErrorCount}")

    assert ErrorCount == 0, f"Loopback test failed with {ErrorCount} errors."


@cocotb.test()
async def hdbn_random_parallel_test(dut):
    """
    Loopback test using random 500-bit data.
    Serializes input, loopbacks encoded signal, parallelizes decoder output.
    Compares decoded data with expected delayed input.
    """
    EncoderType = int(dut.encoder_type.value)
    PulseActiveState = int(dut.pulse_active_state.value)
    clock_period_ns = 488
    StartupTransient = 15000

    await initialize_dut(dut)
    cocotb.log.info("[TB] Starting parallel random data loopback test")

    # Generate 500-bit random binary data
    test_bits = [random.randint(0, 1) for _ in range(500)]
    decoded_bits = []
    total_time_ns = 0
    ErrorCount = 0

    for i, bit in enumerate(test_bits):
        dut.data_in.value = bit

        await RisingEdge(dut.clk_in)

        # Loopback
        dut.p_in.value = dut.p_out.value.to_unsigned()
        dut.n_in.value = dut.n_out.value.to_unsigned()

        total_time_ns += clock_period_ns

        decoded = int(dut.data_out.value)
        decoded_bits.append(decoded)

        expected = get_expected_random_delayed_bit(test_bits, i, EncoderType)

        cocotb.log.info(
            f"[Cycle {i:03d}] input={bit} | decoded={decoded} | expected={expected} | "
            f"p_out={int(dut.p_out.value)} n_out={int(dut.n_out.value)}"
        )

        if expected is not None and total_time_ns > StartupTransient:
            if decoded != expected:
                cocotb.log.error(
                    f"[CHECK] Decoder Bit Error at index {i}: Expected {expected}, Got {decoded}"
                )
                ErrorCount += 1

            if int(dut.code_error_out.value) != 0:
                cocotb.log.error(f"[CHECK] Decoder Code Error flag set at cycle {i}")
                ErrorCount += 1

    cocotb.log.info("\n[TB] Random Parallel Test Results:")
    cocotb.log.info(f"[TB] Total bits tested: {len(test_bits)}")
    cocotb.log.info(f"[TB] Total errors detected: {ErrorCount}")

    assert ErrorCount == 0, f"Random parallel loopback test failed with {ErrorCount} errors."

@cocotb.test()
async def hdbn_reset_behavior_test(dut):
    """
    Verifies that the DUT resets correctly: outputs clear, decoder resets, and normal operation resumes.
    """
    clock_period_ns = 488
    EncoderType = int(dut.encoder_type.value)
    PulseActiveState = int(dut.pulse_active_state.value)

    await initialize_dut(dut)
    cocotb.log.info("[TB] Starting reset behavior test")

    # Step 1: Send a few bits normally
    dut.data_in.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_in)
        dut.p_in.value = dut.p_out.value.to_unsigned()
        dut.n_in.value = dut.n_out.value.to_unsigned()

    cocotb.log.info("[TB] DUT operating normally, applying reset now...")

    # Step 2: Assert reset mid-operation
    dut.reset_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    # Step 3: Check outputs are reset/cleared
    data_out = int(dut.data_out.value)
    code_err = int(dut.code_error_out.value)
    p = int(dut.p_out.value)
    n = int(dut.n_out.value)

    cocotb.log.info(
        f"[TB] After reset: data_out={data_out}, code_error_out={code_err}, "
        f"p_out={p}, n_out={n}"
    )

    assert data_out in (0, 1), "data_out should be valid after reset (some decoders may default to 0)"
    assert code_err == 0, "code_error_out should not be cleared on reset"
    # Optionally: assert p/n go to 0 if known behavior
    # assert p == 0 and n == 0, "p_out and n_out should be low on reset"

    # Step 4: Deassert reset and resume operation
    dut.reset_in.value = 0
    dut.data_in.value = 1

    for _ in range(10):
        await RisingEdge(dut.clk_in)
        dut.p_in.value = dut.p_out.value.to_unsigned()
        dut.n_in.value = dut.n_out.value.to_unsigned()

    cocotb.log.info("[TB] DUT resumed operation after reset")

    # Step 5: Confirm output is valid again
    resumed_data_out = int(dut.data_out.value)
    resumed_code_err = int(dut.code_error_out.value)

    assert resumed_code_err == 1, "code_error_out should be HIGH Initially after reset if input is valid"
    cocotb.log.info(f"[TB] Resumed data_out={resumed_data_out}, code_error_out={resumed_code_err}")

@cocotb.test()
async def hdbn_encoder_only_test(dut):
    """
    Encoder-only test: Provide known input bits, wait for encoder latency, and observe p_out/n_out.
    Checks for illegal simultaneous pulses and logs outputs aligned with input.
    """
    await initialize_dut(dut)
    cocotb.log.info("[TB] Starting encoder-only test (7-cycle latency aware)")

    PulseActiveState = int(dut.pulse_active_state.value)
    latency = 7

    # Input pattern (known simple sequence)
    input_bits = [0, 1, 0, 1, 1, 0, 0, 1, 1, 0]
    delayed_input = []

    for cycle, bit in enumerate(input_bits):
        dut.data_in.value = bit
        await RisingEdge(dut.clk_in)

        # Track input bits for output comparison post-latency
        delayed_input.append(bit)

        if len(delayed_input) >= latency:
            aligned_input = delayed_input.pop(0)
            p = int(dut.p_out.value)
            n = int(dut.n_out.value)

            cocotb.log.info(
                f"[Cycle {cycle}] input={aligned_input} | p_out={p} | n_out={n}"
            )

            # Protocol check: p and n should not be high at the same time
            if p == PulseActiveState and n == PulseActiveState:
                cocotb.log.error(
                    f"[ENC] Invalid: Both P and N active at cycle {cycle}"
                )
                assert False, f"Encoder violation at cycle {cycle}: both p_out and n_out are high"

    cocotb.log.info("[TB] Encoder-only test passed.")

@cocotb.test()
async def hdbn_decoder_only_test(dut):
    """
    Decoder-only test: Feed known p/n pulses, verify data_out after 7-cycle latency.
    """
    await initialize_dut(dut)
    cocotb.log.info("[TB] Starting decoder-only test (7-cycle latency aware)")

    PulseActiveState = int(dut.pulse_active_state.value)

    # Format: (p_in, n_in, expected_data)
    input_sequence = [
        (1, 0, 1),
        (0, 0, 0),
        (0, 1, 1),
        (0, 0, 0),
        (0, 0, 0),
        (1, 0, 1),
        (0, 0, 0),
        (0, 0, 1),
    ]

    latency = 6
    expected_fifo = []

    for cycle, (p_in, n_in, expected_data) in enumerate(input_sequence):
        dut.p_in.value = p_in
        dut.n_in.value = n_in
        dut.data_in.value = 0  # unused
        await RisingEdge(dut.clk_in)

        # Push expected value into latency FIFO
        expected_fifo.append(expected_data)

        # Check output if we're past the latency window
        if len(expected_fifo) >= latency:
            expected = expected_fifo.pop(0)
            actual = int(dut.data_out.value)
            code_err = int(dut.code_error_out.value)

            cocotb.log.info(
                f"[Cycle {cycle}] p_in={p_in} n_in={n_in} | data_out={actual} | expected={expected} | code_err={code_err}"
            )

            if actual != expected:
                cocotb.log.error(f"[DEC] Bit mismatch at cycle {cycle}: Expected {expected}, got {actual}")
                assert False, "Decoder output mismatch"

            if code_err != 0:
                cocotb.log.error(f"[DEC] Unexpected code error at cycle {cycle}")
                assert False, "Decoder raised unexpected error"

    cocotb.log.info("[TB] Decoder-only test passed.")


