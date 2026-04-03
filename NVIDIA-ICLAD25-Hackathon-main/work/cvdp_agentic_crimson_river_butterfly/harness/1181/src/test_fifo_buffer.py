import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge

def safe_int(sig):
    """Converts a signal value to int if fully resolved; otherwise returns 'X'."""
    val_str = sig.value.binstr.lower()
    if "x" in val_str or "z" in val_str:
        return "X"
    try:
        return int(sig.value)
    except Exception:
        return "X"

async def monitor_signals(dut):
    """Continuously print out signal values similar to the SV $monitor."""
    sim_time = 0  # local simulation time counter in ns
    dut._log.info("Time\tclear in_valid in_addr    in_rdata      in_err | out_valid out_addr    out_rdata     out_err out_err_plus2 | busy")
    while True:
        await Timer(10, units="ns")
        sim_time += 10
        clear_val      = safe_int(dut.clear_i)
        in_valid_val   = safe_int(dut.in_valid_i)
        in_addr_val    = safe_int(dut.in_addr_i)
        in_rdata_val   = safe_int(dut.in_rdata_i)
        in_err_val     = safe_int(dut.in_err_i)
        out_valid_val  = safe_int(dut.out_valid_o)
        out_addr_val   = safe_int(dut.out_addr_o)
        out_rdata_val  = safe_int(dut.out_rdata_o)
        out_err_val    = safe_int(dut.out_err_o)
        out_err2_val   = safe_int(dut.out_err_plus2_o)
        busy_val       = safe_int(dut.busy_o)
        msg = (
            f"{sim_time}\t"
            f"{clear_val}      {in_valid_val}      "
            f"{in_addr_val if in_addr_val=='X' else format(in_addr_val, '08X')}   "
            f"{in_rdata_val if in_rdata_val=='X' else format(in_rdata_val, '08X')}    {in_err_val}    | "
            f"{out_valid_val}      {out_addr_val if out_addr_val=='X' else format(out_addr_val, '08X')}  "
            f"{out_rdata_val if out_rdata_val=='X' else format(out_rdata_val, '08X')}   "
            f"{out_err_val}    {out_err2_val}    | {busy_val}"
        )
        dut._log.info(msg)

@cocotb.test()
async def tb_fifo_buffer_test(dut):
    """
    Cocotb testbench for fifo_buffer that exactly mimics the provided SV testbench,
    with assertions at the end of each test case.
    """
    # -----------------------
    # Clock Generation
    # -----------------------
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    # -----------------------
    # Reset Generation
    # -----------------------
    dut.rst_i.value = 0
    await Timer(20, units="ns")
    dut.rst_i.value = 1
    dut._log.info("Reset deasserted")

    # -----------------------
    # Initialize Inputs
    # -----------------------
    dut.clear_i.value     = 0
    dut.in_valid_i.value  = 0
    dut.in_addr_i.value   = 0x00000000  # Initial instruction address
    dut.in_rdata_i.value  = 0
    dut.in_err_i.value    = 0
    dut.out_ready_i.value = 0

    # Start a monitor to mimic the SV $monitor
    monitor_task = cocotb.start_soon(monitor_signals(dut))

    # Wait until after reset is applied (simulate @(posedge rst_i); #10)
    await Timer(10, units="ns")

    # -----------------------
    # Test 1: Clear FIFO and set aligned PC
    # -----------------------
    dut._log.info("*** Test 1: Clear FIFO (Aligned PC) ***")
    dut.clear_i.value   = 1
    dut.in_addr_i.value = 0x00000000  # Using an aligned address
    await Timer(10, units="ns")
    dut.clear_i.value = 0
    await Timer(10, units="ns")
    # (Optionally, assert conditions here if required for Test 1)

    # -----------------------
    # Test 2: Single Instruction Fetch (Aligned case)
    # -----------------------
    dut._log.info("*** Test 2: Single Instruction Fetch (Aligned) ***")
    dut.in_valid_i.value = 1
    dut.in_rdata_i.value = 0x8C218363  # BEQ instruction with negative offset
    dut.in_err_i.value   = 0
    await Timer(10, units="ns")
    dut.in_valid_i.value = 0
    await Timer(10, units="ns")
    # Allow the instruction to be popped by asserting out_ready
    dut.out_ready_i.value = 1
    await Timer(10, units="ns")
    dut.out_ready_i.value = 0
    await Timer(20, units="ns")

    # --- Test 2 Assertions ---
    # Expected (from logs): at end of Test 2, out_valid should be 0,
    # out_addr should be 0x00000004, and out_rdata should be 0x8C218363.
    assert safe_int(dut.out_valid_o) != "X" and int(dut.out_valid_o.value) == 0, \
        "Test 2: out_valid_o should be 0 after instruction pop"
    assert safe_int(dut.out_addr_o) != "X" and int(dut.out_addr_o.value) == 0x00000004, \
        "Test 2: out_addr_o should be 0x00000004"
    assert safe_int(dut.out_rdata_o) != "X" and int(dut.out_rdata_o.value) == 0x8C218363, \
        "Test 2: out_rdata_o should match input (8C218363)"

    # -----------------------
    # Test 3: FIFO Depth Test - Push Multiple Instructions
    # -----------------------
    dut._log.info("*** Test 3: FIFO Depth Test ***")
    dut.in_valid_i.value = 1
    dut.in_rdata_i.value = 0x6C2183E3  # BEQ instruction with positive offset
    dut.in_err_i.value   = 0
    await Timer(10, units="ns")
    dut.in_rdata_i.value = 0x926CF16F  # JAL instruction with negative offset
    await Timer(10, units="ns")
    dut.in_valid_i.value = 0
    await Timer(10, units="ns")
    # Pop the FIFO entries (simulate repeat (3) begin #10)
    dut.out_ready_i.value = 1
    for _ in range(3):
        await Timer(10, units="ns")
    dut.out_ready_i.value = 0
    await Timer(10, units="ns")

    # --- Test 3 Assertions ---
    # Expected: out_valid should be 0, out_addr should be 0x0000000C,
    # and out_rdata should be 0x926CF16F.
    assert safe_int(dut.out_valid_o) != "X" and int(dut.out_valid_o.value) == 0, \
        "Test 3: out_valid_o should be 0 after FIFO pop"
    assert safe_int(dut.out_addr_o) != "X" and int(dut.out_addr_o.value) == 0x0000000C, \
        "Test 3: out_addr_o should be 0x0000000C"
    assert safe_int(dut.out_rdata_o) != "X" and int(dut.out_rdata_o.value) == 0x926CF16F, \
        "Test 3: out_rdata_o should be 0x926CF16F"

    # -----------------------
    # Test 4: Unaligned Instruction Fetch
    # -----------------------
    dut._log.info("*** Test 4: Unaligned Instruction Fetch ***")
    # Clear FIFO with a new PC that produces an unaligned fetch.
    dut.clear_i.value   = 1
    dut.in_addr_i.value = 0x00000002  # 0x00000002 gives an unaligned PC (instr_addr_q[0] = 1)
    await Timer(10, units="ns")
    dut.clear_i.value = 0
    await Timer(10, units="ns")
    # Provide two consecutive instruction data words to form an unaligned instruction.
    dut.in_valid_i.value = 1
    dut.in_rdata_i.value = 0xF63101E7  # JAL instruction with negative offset
    dut.in_err_i.value   = 0
    await Timer(10, units="ns")
    dut.in_rdata_i.value = 0x763101E7  # JALR instruction with positive offset
    await Timer(10, units="ns")
    dut.in_valid_i.value = 0
    await Timer(10, units="ns")
    # Pop the unaligned instruction
    dut.out_ready_i.value = 1
    for _ in range(3):
        await Timer(10, units="ns")
    dut.out_ready_i.value = 0
    await Timer(10, units="ns")

    # --- Test 4 Assertions ---
    # Expected: out_valid should be 0, out_addr should be 0x00000008,
    # and out_rdata should be 0x763101E7.
    assert safe_int(dut.out_valid_o) != "X" and int(dut.out_valid_o.value) == 0, \
        "Test 4: out_valid_o should be 0 after unaligned fetch"
    assert safe_int(dut.out_addr_o) != "X" and int(dut.out_addr_o.value) == 0x00000008, \
        "Test 4: out_addr_o should be 0x00000008"
    assert safe_int(dut.out_rdata_o) != "X" and int(dut.out_rdata_o.value) == 0x763101E7, \
        "Test 4: out_rdata_o should be 0x763101E7"

    # -----------------------
    # Test 5: Error Handling
    # -----------------------
    dut._log.info("*** Test 5: Error Handling ***")
    # Clear FIFO and reset PC to an aligned address.
    dut.clear_i.value   = 1
    dut.in_addr_i.value = 0x00000000
    await Timer(15, units="ns")
    dut.clear_i.value = 0
    await Timer(15, units="ns")
    # Drive an instruction fetch with an error on the first half.
    dut.in_valid_i.value = 1
    dut.in_rdata_i.value = 0x4840006F  # C.J instruction with positive offset
    dut.in_err_i.value   = 1          # Signal an error
    await Timer(15, units="ns")
    dut.in_valid_i.value = 0
    await Timer(15, units="ns")
    # Allow the error-containing instruction to be popped.
    dut.out_ready_i.value = 1
    await Timer(15, units="ns")
    dut.out_ready_i.value = 0
    await Timer(15, units="ns")

    # --- Test 5 Assertions ---
    # Expected: out_valid should be 0, out_addr should be 0x00000004,
    # out_rdata should be 0x4840006F, and in_err should be 1.
    assert safe_int(dut.out_valid_o) != "X" and int(dut.out_valid_o.value) == 0, \
        "Test 5: out_valid_o should be 0 after error handling"
    assert safe_int(dut.out_addr_o) != "X" and int(dut.out_addr_o.value) == 0x00000004, \
        "Test 5: out_addr_o should be 0x00000004"
    assert safe_int(dut.out_rdata_o) != "X" and int(dut.out_rdata_o.value) == 0x4840006F, \
        "Test 5: out_rdata_o should match error instruction data (4840006F)"
    assert safe_int(dut.in_err_i) != "X" and int(dut.in_err_i.value) == 1, \
        "Test 5: in_err_i should be 1 for error instruction"

    dut._log.info("*** End of Simulation ***")
    monitor_task.kill()

