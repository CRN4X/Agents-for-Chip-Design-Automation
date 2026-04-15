import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb
import random

def compare_values(dut, model, debug=0):
    dut_data  = dut.o_data.value.to_unsigned()

    model_data = model.o_data

    if debug == 1:
        print("\nOUTPUTS")
        print(f"DUT o_data  = {hex(dut_data)} \nMODEL o_data  = {hex(model_data)}")
    
    assert dut_data == model_data,  f"[ERROR] DUT o_data does not match model o_data: {hex(dut_data)} != {hex(model_data)}"

def row_to_bypass(row, ns_rows):
    if row < 0 or row >= ns_rows:
        raise ValueError("Invalid row index")

    # Full set of 1s: (1 << ns_rows) - 1
    # Clear the bit at (ns_rows - row - 1)
    return ((1 << ns_rows) - 1) ^ (1 << (ns_rows - row - 1))

@cocotb.test()
async def test_event_array(dut):
    """Test the event_array module with edge cases and random data."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Retrieve parameters from the DUT
    NS_ROWS = dut.NS_ROWS.value.to_unsigned()
    NS_COLS = dut.NS_COLS.value.to_unsigned()
    NBW_STR = dut.NBW_STR.value.to_unsigned()
    NS_EVT  = dut.NS_EVT.value.to_unsigned()

    model = hrs_lb.EventArray(NS_ROWS, NS_COLS, NBW_STR, NS_EVT)

    resets = 4
    runs = 2**(NBW_STR+1) # Run it 2 times the 2**NBW_STR so it's very likely that there will be an overflow and no overflow

    event_min = 0
    event_max = 2**(NS_ROWS*NS_COLS*NS_EVT) - 1

    data_min = 0
    data_max = 2**(NS_COLS*NBW_STR) - 1

    overflow_min = 0
    overflow_max = 2**(NS_ROWS*NS_COLS) - 1
    
    await hrs_lb.dut_init(dut)

    for i in range(resets):
        dut._log.info(f"Starting {i+1} test...")
        # Reset DUT
        # Set all inputs to 0
        dut.i_col_sel.value     = 0
        dut.i_en_overflow.value = 0
        dut.i_event.value       = 0
        dut.i_data.value        = 0
        dut.i_bypass.value      = 0
        dut.i_raddr.value       = 0
        dut.rst_async_n.value   = 0
        await RisingEdge(dut.clk)
        dut.rst_async_n.value = 1
        await RisingEdge(dut.clk)

        model.reset()

        compare_values(dut, model)

        en_overflow = random.randint(overflow_min, overflow_max)
        for j in range(runs):
            event = random.randint(event_min, event_max)

            dut.i_en_overflow.value = en_overflow
            dut.i_event.value       = event
            model.event_update(event, en_overflow)

            await RisingEdge(dut.clk)
        
        dut.i_event.value = 0
        # Compare all values
        # First compare the full bypass
        data = random.randint(data_min, data_max)
        dut._log.info(f"Loop for columns bypass...")
        for col in range(NS_COLS):
            for addr in range(NS_EVT):
                bypass = (1 << NS_ROWS) - 1
                model.read_data(bypass, addr, col, data)
                dut.i_col_sel.value     = col
                dut.i_data.value        = data
                dut.i_bypass.value      = bypass
                dut.i_raddr.value       = addr
                await RisingEdge(dut.clk)
                compare_values(dut, model)

        dut._log.info(f"Loop for columns complete...")
        for col in range(NS_COLS):
            for row in range(NS_ROWS):
                for addr in range(NS_EVT):
                    bypass = row_to_bypass(row, NS_ROWS)
                    model.read_data(bypass, addr, col, data)
                    dut.i_col_sel.value     = col
                    dut.i_data.value        = data
                    dut.i_bypass.value      = bypass
                    dut.i_raddr.value       = addr
                    await RisingEdge(dut.clk)
                    compare_values(dut, model)
