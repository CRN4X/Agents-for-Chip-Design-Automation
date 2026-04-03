import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import harness_library as hrs_lb
import random

def compare_values(dut, model, debug=0):
    dut_data  = dut.o_data.value.to_unsigned()

    model_data = model.data_out

    if debug == 1:
        print("\nOUTPUTS")
        print(f"DUT o_data  = {hex(dut_data)} \nMODEL o_data  = {hex(model_data)}")
    
    assert dut_data == model_data,  f"[ERROR] DUT o_data does not match model o_data: {hex(dut_data)} != {hex(model_data)}"

def set_inputs(dut, reset_counter, update_iv, update_mode, update_key, mode, iv, data, key, start, encrypt, update_padding, padding_mode, padding_bytes):
    dut.i_reset_counter.value       = reset_counter
    dut.i_update_iv.value           = update_iv
    dut.i_update_mode.value         = update_mode
    dut.i_update_key.value          = update_key
    dut.i_mode.value                = mode
    dut.i_iv.value                  = iv
    dut.i_data.value                = data
    dut.i_key.value                 = key
    dut.i_start.value               = start
    dut.i_encrypt.value             = encrypt
    dut.i_update_padding_mode.value = update_padding
    dut.i_padding_mode.value        = padding_mode
    dut.i_padding_bytes.value       = padding_bytes

@cocotb.test()
async def test_padding_top(dut):
    """Test the padding_top module with edge cases and random data."""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    W3C_BYTE = dut.W3C_BYTE.value.to_unsigned()

    model_enc = hrs_lb.aes_encrypt()
    model_dec = hrs_lb.aes_decrypt()

    resets = 2
    runs = 2
    mode_runs = 200

    data_min = 0
    data_max = 2**128 - 1

    key_min = 0
    key_max = 2**256 - 1

    padd_min = 0
    padd_max = 15

    mode_min = 0
    mode_max = 5
    
    await hrs_lb.dut_init(dut)

    for i in range(resets):
        # Reset DUT
        # Set all inputs to 0
        set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        dut.rst_async_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_async_n.value  = 1
        await RisingEdge(dut.clk)

        model_enc.reset()
        model_dec.reset()

        compare_values(dut, model_enc)
        compare_values(dut, model_dec)
        # After reset o_done must be 1
        dut_done = dut.o_done.value
        assert dut_done == 1,  f"[ERROR] After reset, DUT o_done must be 1. The harness received o_done = {dut_done}"

        for j in range(runs):
            print(f'\n------ Reset {i}, run {j} ------')

            print("Padding PKCS")
            encrypt = random.randint(0,1)
            padding = random.randint(padd_min, padd_max)
            mode    = random.randint(mode_min, mode_max)
            iv      = random.randint(data_min, data_max)
            data    = random.randint(data_min, data_max)
            key     = random.randint(key_min , key_max )

            # Set Counter, IV, mode and padding mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0, encrypt, 1, 0, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
            await RisingEdge(dut.clk)
            model_enc.counter = 0
            model_dec.counter = 0
            model_enc.iv      = iv
            model_dec.iv      = iv
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, data, key, 1, encrypt, 0, 0, padding)
                    model_enc.update_key(key)
                    model_dec.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, data, 0, 1, encrypt, 0, 0, padding)
                
                model_enc.MODE(hrs_lb.PKCS(data, padding), mode)
                model_dec.MODE(hrs_lb.PKCS(data, padding), mode)

                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                if encrypt == 1:
                    compare_values(dut, model_enc)
                else:
                    compare_values(dut, model_dec)


            print("Padding OneAndZeroes")
            encrypt = random.randint(0,1)
            padding = random.randint(padd_min, padd_max)
            mode    = random.randint(mode_min, mode_max)
            iv      = random.randint(data_min, data_max)
            data    = random.randint(data_min, data_max)
            key     = random.randint(key_min , key_max )

            # Set Counter, IV, mode and padding mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0, encrypt, 1, 1, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
            await RisingEdge(dut.clk)
            model_enc.counter = 0
            model_dec.counter = 0
            model_enc.iv      = iv
            model_dec.iv      = iv
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, data, key, 1, encrypt, 0, 0, padding)
                    model_enc.update_key(key)
                    model_dec.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, data, 0, 1, encrypt, 0, 0, padding)
                
                model_enc.MODE(hrs_lb.OneAndZeroes(data, padding), mode)
                model_dec.MODE(hrs_lb.OneAndZeroes(data, padding), mode)

                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                if encrypt == 1:
                    compare_values(dut, model_enc)
                else:
                    compare_values(dut, model_dec)
            

            print("Padding ANSIX923")
            encrypt = random.randint(0,1)
            padding = random.randint(padd_min, padd_max)
            mode    = random.randint(mode_min, mode_max)
            iv      = random.randint(data_min, data_max)
            data    = random.randint(data_min, data_max)
            key     = random.randint(key_min , key_max )

            # Set Counter, IV, mode and padding mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0, encrypt, 1, 2, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
            await RisingEdge(dut.clk)
            model_enc.counter = 0
            model_dec.counter = 0
            model_enc.iv      = iv
            model_dec.iv      = iv
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, data, key, 1, encrypt, 0, 0, padding)
                    model_enc.update_key(key)
                    model_dec.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, data, 0, 1, encrypt, 0, 0, padding)
                
                model_enc.MODE(hrs_lb.ANSIX923(data, padding), mode)
                model_dec.MODE(hrs_lb.ANSIX923(data, padding), mode)

                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                if encrypt == 1:
                    compare_values(dut, model_enc)
                else:
                    compare_values(dut, model_dec)

            print("Padding W3C")
            encrypt = random.randint(0,1)
            padding = random.randint(padd_min, padd_max)
            mode    = random.randint(mode_min, mode_max)
            iv      = random.randint(data_min, data_max)
            data    = random.randint(data_min, data_max)
            key     = random.randint(key_min , key_max )

            # Set Counter, IV, mode and padding mode
            set_inputs(dut, 1, 1, 1, 0, mode, iv, 0, 0, 0, encrypt, 1, 3, 0)
            await RisingEdge(dut.clk)
            set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
            await RisingEdge(dut.clk)
            model_enc.counter = 0
            model_dec.counter = 0
            model_enc.iv      = iv
            model_dec.iv      = iv
            
            for k in range(mode_runs):
                # Set key in first run
                if k == 0:
                    set_inputs(dut, 0, 0, 0, 1, 0, 0, data, key, 1, encrypt, 0, 0, padding)
                    model_enc.update_key(key)
                    model_dec.update_key(key)
                else:
                    set_inputs(dut, 0, 0, 0, 0, 0, 0, data, 0, 1, encrypt, 0, 0, padding)

                model_enc.MODE(hrs_lb.W3C(data, padding, W3C_BYTE), mode)
                model_dec.MODE(hrs_lb.W3C(data, padding, W3C_BYTE), mode)

                await RisingEdge(dut.clk)
                set_inputs(dut, 0, 0, 0, 0, 0, 0, 0, 0, 0, encrypt, 0, 0, 0)
                await RisingEdge(dut.clk)
                while dut.o_done.value == 0:
                    await RisingEdge(dut.clk)
                
                if encrypt == 1:
                    compare_values(dut, model_enc)
                else:
                    compare_values(dut, model_dec)