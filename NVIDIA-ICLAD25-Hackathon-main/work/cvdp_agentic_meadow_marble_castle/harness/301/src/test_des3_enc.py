import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import harness_library as hrs_lb
import random

def compare_values(dut, model, debug=0):
    dut_data   = dut.o_data.value.to_unsigned()
    model_data = model.read_data()

    if debug == 1:
        print("\nOUTPUTS")
        print(f"DUT o_data  = {hex(dut_data)} \nMODEL o_data  = {hex(model_data)}")
    
    assert dut_data == model_data,  f"[ERROR] DUT o_data does not match model o_data: {hex(dut_data)} != {hex(model_data)}"

@cocotb.test()
async def test_des3_enc(dut):
    """Test the des3_enc module with edge cases and random data."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())


    model = hrs_lb.des()

    resets = 4
    runs = 1000

    data_min = 0
    data_max = 2**64 - 1

    key_min  = 0
    key_max  = 2**192 - 1
    
    await hrs_lb.dut_init(dut)

    for i in range(resets):
        # Reset DUT
        # Set all inputs to 0
        dut.i_valid.value     = 0
        dut.i_data.value      = 0
        dut.i_key.value       = 0
        dut.rst_async_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_async_n.value = 1
        await RisingEdge(dut.clk)

        model.reset()

        compare_values(dut, model)

        # Latency check
        key   = random.randint(key_min , key_max )
        data  = random.randint(data_min, data_max)
        valid = 1

        await FallingEdge(dut.clk)
        dut.i_data.value  = data
        dut.i_key.value   = key
        dut.i_valid.value = valid

        model.des3_enc(data, key)
        await FallingEdge(dut.clk)
        latency_counter = 1
        dut.i_valid.value = 0

        while dut.o_valid.value == 0:
            latency_counter = latency_counter + 1
            await FallingEdge(dut.clk)
        
        assert latency_counter == 48, f"[ERROR] DUT latency must be 48 clock cycles"
        
        compare_values(dut, model)

        for j in range(runs):
            if (j+1)%500 == 0:
                print(f'\n------ Reset {i}, run {j+1} ------')

            key   = random.randint(key_min , key_max )
            data  = random.randint(data_min, data_max)
            valid = random.randint(0,1)

            await FallingEdge(dut.clk)

            dut.i_data.value  = data
            dut.i_key.value   = key
            dut.i_valid.value = valid
            if valid:
                model.des3_enc(data, key)

            if dut.o_valid.value == 1:
                compare_values(dut, model)
