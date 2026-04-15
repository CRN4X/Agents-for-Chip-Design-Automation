import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import csv
import os

DATA_WIDTH = 16
NUM_SAMPLES = 500

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.data_in_a.value = 0
    dut.valid_in_a.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await Timer(50, units="ns")

@cocotb.test()
async def monte_carlo_simulation(dut):
    """Monte Carlo Test with display logging and CSV tracing"""

    # Start clocks
    cocotb.start_soon(Clock(dut.clk_a, 7, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_b, 13, units="ns").start())

    # Reset DUT
    await reset_dut(dut)

    transfer_count_start = dut.cross_domain_transfer_count.value.to_unsigned()

    # CSV setup
    log_filename = "monte_carlo_log.csv"
    if os.path.exists(log_filename):
        os.remove(log_filename)

    with open(log_filename, mode='w', newline='') as logfile:
        writer = csv.writer(logfile)
        writer.writerow(["cycle", "data_in_a", "valid_in_a", "data_out_b", "valid_out_b"])

        for i in range(NUM_SAMPLES):
            await RisingEdge(dut.clk_a)

            # Generate stimulus
            send_valid = random.random() < 0.7
            input_data = random.getrandbits(DATA_WIDTH) if send_valid else 0

            dut.data_in_a.value = input_data
            dut.valid_in_a.value = int(send_valid)

            await Timer(random.randint(1, 5), units="ns")

            # Sample output on clk_b
            await RisingEdge(dut.clk_b)
            output_valid = int(dut.valid_out_b.value)
            output_data = dut.data_out_b.value.to_unsigned() if output_valid else 0

            # Log stimulus and response to CSV
            writer.writerow([
                i,
                f"0x{input_data:04X}" if send_valid else "",
                int(send_valid),
                f"0x{output_data:04X}" if output_valid else "",
                output_valid
            ])

            # Display stimulus vector
            dut._log.info(
                f"[Cycle {i}] "
                f"IN: valid={int(send_valid)} data=0x{input_data:04X} | "
                f"OUT: valid={output_valid} data={'0x%04X' % output_data if output_valid else '--'}"
            )

        # Drain pipeline
        for i in range(50):
            await RisingEdge(dut.clk_b)
            output_valid = int(dut.valid_out_b.value)
            output_data = dut.data_out_b.value.to_unsigned() if output_valid else 0

            writer.writerow([
                NUM_SAMPLES + i,
                "",
                "",
                f"0x{output_data:04X}" if output_valid else "",
                output_valid
            ])

            if output_valid:
                dut._log.info(
                    f"[Drain {NUM_SAMPLES + i}] "
                    f"OUT: valid={output_valid} data=0x{output_data:04X}"
                )

    # Final stats
    transfer_count_end = dut.cross_domain_transfer_count.value.to_unsigned()
    total_transfers = transfer_count_end - transfer_count_start

    dut._log.info(" Monte Carlo Simulation Complete")
    dut._log.info(f"Stimuli logged to: {log_filename}")
    dut._log.info(f"Total input attempts: {NUM_SAMPLES}")
    dut._log.info(f"Total successful domain transfers: {total_transfers}")

    assert total_transfers > 0, " No data transferred — check logic or reset"
    assert total_transfers <= NUM_SAMPLES, " Transfers exceed input attempts — possible sync bug"
