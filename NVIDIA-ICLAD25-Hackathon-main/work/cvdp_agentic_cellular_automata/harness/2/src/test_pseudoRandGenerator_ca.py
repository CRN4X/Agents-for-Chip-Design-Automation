import cocotb
from cocotb.triggers import RisingEdge, Timer

async def clock_gen(clock):
    while True:
        clock.value = 0
        await Timer(5, units="ns")
        clock.value = 1
        await Timer(5, units="ns")

@cocotb.test()
async def run_test(dut):
    # Start the clock generator
    cocotb.start_soon(clock_gen(dut.clock))

    # Initialize signals using .value assignment
    dut.reset.value = 1
    dut.CA_seed.value = 0x1        # Initial seed value
    dut.rule_sel.value = 2         # 0 corresponds to Rule 30 (use 1 for Rule 110)
    await Timer(12, units="ns")    # Hold reset for a few ns
    dut.reset.value = 0

    # Wait for one rising edge after reset is deasserted
    await RisingEdge(dut.clock)

    # Assertion for reset behavior: Verify that CA_out equals CA_seed immediately after reset.
    seed_val = int(dut.CA_seed.value.to_unsigned())
    ca_out_val = int(dut.CA_out.value.to_unsigned())
    assert ca_out_val == seed_val, f"After reset, CA_out ({ca_out_val}) does not equal seed ({seed_val})."

    # Create an array to record the first seen cycle for each possible 16-bit state.
    # There are 2^16 = 65,536 possible states; initialize all entries to -1.
    first_seen = [-1] * 65536
    cycle_count = 0
    repetition_found = False

    # Run for exactly 65,536 cycles.
    for _ in range(65536):
        await RisingEdge(dut.clock)
        cycle_count += 1

        # Read the current value as an unsigned number
        cur_val = int(dut.CA_out.value.to_unsigned())

        # Range check: Ensure CA_out is within the valid 16-bit range.
        assert 0 <= cur_val < 65536, f"Cycle {cycle_count}: CA_out value {cur_val} is out of range [0, 65535]."

        if first_seen[cur_val] == -1:
            first_seen[cur_val] = cycle_count
        else:
            dut._log.info(
                "Cycle {}: Value {} repeated; first seen at cycle {}".format(
                    cycle_count, cur_val, first_seen[cur_val]
                )
            )
            repetition_found = True

    # Assertion to verify that the simulation ran for exactly 65,536 cycles.
    assert cycle_count == 65536, f"Cycle count is {cycle_count} instead of 65536."

    # Assertion to verify that at least one repetition was detected.
    assert repetition_found, "No repetition was detected within 65,536 cycles."

    dut._log.info("Completed 65,536 cycles of simulation.")

