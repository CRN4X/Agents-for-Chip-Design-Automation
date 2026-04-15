import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb
import random

def compare_values(dut, model, debug=0):
    dut_data  = dut.o_data.value.to_unsigned()

    model_data = model.data

    if debug == 1:
        print("\nOUTPUTS")
        print(f"DUT o_data  = {hex(dut_data)} \nMODEL o_data  = {hex(model_data)}")
    
    assert dut_data == model_data,  f"[ERROR] DUT o_data does not match model o_data: {hex(dut_data)} != {hex(model_data)}"

@cocotb.test()
async def test_aes128_encrypt(dut):
    """Test the aes128_encrypt module with edge cases and random data."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    model = hrs_lb.aes128_encrypt()

    resets = 4
    runs = 1000

    data_min = 0
    data_max = 2**128 - 1
    
    await hrs_lb.dut_init(dut)

    for i in range(resets):
        # Reset DUT
        # Set all inputs to 0
        dut.i_start.value      = 0
        dut.i_update_key.value = 0
        dut.i_key.value        = 0
        dut.i_data.value       = 0
        dut.rst_async_n.value  = 0
        await RisingEdge(dut.clk)
        dut.rst_async_n.value  = 1
        await RisingEdge(dut.clk)

        model.reset()

        compare_values(dut, model)

        for j in range(runs):
            key = random.randint(data_min, data_max)
            data = random.randint(data_min, data_max)
            if j == 0:
                update_key = 1
            else:
                update_key = random.randint(0,1)

            dut.i_update_key.value = update_key
            dut.i_key.value        = key
            dut.i_data.value       = data
            dut.i_start.value      = 1

            if update_key:
                model.update_key(key)
            
            model.update(data)

            await RisingEdge(dut.clk)
            dut.i_start.value = 0
            dut.i_key.value   = 0
            dut.i_update_key.value = 0
            dut.i_data.value       = 0
            await RisingEdge(dut.clk)
            while dut.o_done.value == 0:
                await RisingEdge(dut.clk)

            compare_values(dut, model)
