import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

# Function to calculate the expected output based on the given RC5 encryption algorithm
def expected_rc5_enc_16bit(plaintext):
    s = [0xAB, 0x29, 0x6E, 0xC1]  # S-box values
    p_tmp = plaintext

    # Step 1: Initial addition stage
    p_tmp_msb = (p_tmp >> 8) & 0xFF
    p_tmp_lsb = p_tmp & 0xFF

    p_tmp_msb = (p_tmp_msb + s[0]) % 0x100
    p_tmp_lsb = (p_tmp_lsb + s[1]) % 0x100

    # Step 2: Computation of MSB 8-bits
    tmp_msb = p_tmp_msb ^ p_tmp_lsb
    rotated_msb = ((tmp_msb << (p_tmp_lsb % 8)) | (tmp_msb >> (8 - (p_tmp_lsb % 8)))) & 0xFF
    p_tmp_msb = (rotated_msb + s[2]) % 0x100

    # Step 3: Computation of LSB 8-bits
    tmp_lsb = p_tmp_lsb ^ p_tmp_msb
    rotated_lsb = ((tmp_lsb << (p_tmp_msb % 8)) | (tmp_lsb >> (8 - (p_tmp_msb % 8)))) & 0xFF
    p_tmp_lsb = (rotated_lsb + s[3]) % 0x100

    # Combine MSB and LSB to form the 16-bit ciphertext
    ciphertext = (p_tmp_msb << 8) | p_tmp_lsb
    return ciphertext

@cocotb.test()
async def test_rc5_enc_16bit(dut):
    """Test the rc5_enc_16bit encryption module"""

    # Generate clock
    cocotb.start_soon(Clock(dut.clock, 10, units="ns").start())

    # Define a few test plaintext values
    test_values = [0x1234, 0xABCD, 0x0000, 0xFFFF, 0xA5A5, 0x2222, 0x3333, 0x4444, 0x5555, 0xFFFF]
    
    

    for plaintext in test_values:
        # Reset the design
        dut.reset.value = 0
        dut.enc_start.value = 0
        dut.p.value = plaintext  # Assign the plaintext value while reset is active
        await RisingEdge(dut.clock)

        # Release reset
        dut.reset.value = 1
        await RisingEdge(dut.clock)

        # Start encryption
        dut.enc_start.value = 1

        # Wait for the encryption to complete
        while dut.enc_done.value == 0:
            await RisingEdge(dut.clock)

        # Check the output with the expected result
        encrypted = dut.c.value.integer
        expected_encrypted = expected_rc5_enc_16bit(plaintext)

        dut._log.info(f"Plaintext: 0x{plaintext}, Ciphertext: 0x{encrypted}, Expected: 0x{expected_encrypted}")
       
        # Compare the actual output with the expected result
        assert encrypted == expected_encrypted, f"Expected 0x{expected_encrypted}, but got 0x{encrypted}"

        # Reset the start signal for the next operation
        dut.enc_start.value = 0
        await RisingEdge(dut.clock)  # Ensure the enc_start is de-asserted before the next test
