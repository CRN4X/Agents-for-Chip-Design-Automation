import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb
import random

def compare_values(dut, model, debug=0):
    dut_data  = dut.o_ciphertext.value.to_unsigned()

    model_data = model.data_out

    if debug == 1:
        print("\nOUTPUTS")
        print(f"DUT o_ciphertext  = {hex(dut_data)} \nMODEL o_ciphertext  = {hex(model_data)}")
    
    assert dut_data == model_data,  f"[ERROR] DUT o_ciphertext does not match model o_ciphertext: {hex(dut_data)} != {hex(model_data)}"

def set_inputs(dut, reset_counter, update_iv, update_mode, update_key, mode, iv, plaintext, key, start):
    dut.i_reset_counter.value = reset_counter
    dut.i_update_iv.value     = update_iv
    dut.i_update_mode.value   = update_mode
    dut.i_update_key.value    = update_key
    dut.i_mode.value          = mode
    dut.i_iv.value            = iv
    dut.i_plaintext.value     = plaintext
    dut.i_key.value           = key
    dut.i_start.value         = start

@cocotb.test()
async def test_aes_enc_top(dut):
    """Test the aes_enc_top module with edge cases and random data."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    model = hrs_lb.aes_encrypt()

    resets = 2
    runs = 2
    mode_runs = 200

    data_min = 0
    data_max = 2**128 - 1

    key_min = 0
    key_max = 2**256 - 1
    
    await hrs_lb.dut_init(dut)

    for i in range(resets):
        # Reset DUT
        # Set all inputs to 0
        set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        dut.rst_async_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_async_n.value  = 1
        await RisingEdge(dut.clk)

        model.reset()

        compare_values(dut, model)
        # After reset o_done must be 1
        dut_done = dut.o_done.value
        assert dut_done == 1,  f"[ERROR] After reset, DUT o_done must be 1. The harness received o_done = {dut_done}"

        for j in range(runs):
            print(f'\n------ Reset {i}, run {j} ------')

            print("ECB mode")
            mode      = 0
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.ECB(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)
            
            print("CBC mode")
            mode      = 1
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )
            
            model.iv  = iv

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.CBC(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)
            
            print("PCBC mode")
            mode      = 2
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )
            
            model.iv  = iv

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.PCBC(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)
            
            print("CFB mode")
            mode      = 3
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )
            
            model.iv  = iv

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.CFB(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)

            print("OFB mode")
            mode      = 4
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )
            
            model.iv  = iv

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.OFB(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)
            
            print("CTR mode")
            mode      = 5
            iv        = random.randint(data_min, data_max)
            plaintext = random.randint(data_min, data_max)
            key       = random.randint(key_min , key_max )
            
            model.iv      = iv
            model.counter = 0

            # Set Counter, IV and mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            await RisingEdge(dut.clk)
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, plaintext, key, 1)
                    model.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, plaintext, 0, 1)
                
                model.CTR(plaintext)
                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                compare_values(dut, model)
            