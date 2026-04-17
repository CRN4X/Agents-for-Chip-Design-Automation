import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.rst_in.value = 1
    dut.enc_valid_in.value = 0
    dut.enc_data_in.value = 0
    dut.dec_valid_in.value = 0
    dut.dec_data_in.value = 0
    
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0
    print("DUT initialized.")

async def check_encoding(dut, input_data, N):
    """Check if the Manchester encoder outputs the correct encoded data."""
    expected_output = 0
    for i in range(N):
        bit = (input_data >> i) & 1
        expected_output |= ((bit << (2 * i + 1)) | ((~bit & 1) << (2 * i)))
    
    await RisingEdge(dut.clk_in)  # Wait for output to stabilize
    print(f"Checking Encoding: Input={bin(input_data)}, Expected={bin(expected_output)}, Got={bin(dut.enc_data_out.value.integer)}")
    assert dut.enc_data_out.value.integer == expected_output, "Encoding mismatch."
    assert dut.enc_valid_out.value == 1, "Encoder valid signal is not asserted."

async def check_decoding(dut, encoded_data, original_data):
    """Check if the Manchester decoder correctly recovers the original data."""
    await RisingEdge(dut.clk_in)  # Wait for output to stabilize
    print(f"Checking Decoding: Encoded={bin(encoded_data)}, Expected={bin(original_data)}, Got={bin(dut.dec_data_out.value.integer)}")
    assert dut.dec_data_out.value.integer == original_data, "Decoding mismatch."
    assert dut.dec_valid_out.value == 1, "Decoder valid signal is not asserted."

@cocotb.test()
async def test_all_zeros_ones(dut):
    """Test encoding and decoding with all 0s and all 1s inputs."""
    await initialize_dut(dut)
    N = int(dut.N.value)
    
    test_cases = [(0, "All 0s"), ((1 << N) - 1, "All 1s")]
    
    for input_data, description in test_cases:
        print(f"Running test: {description}")
        dut.enc_data_in.value = input_data
        dut.enc_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_encoding(dut, input_data, N)
        
        encoded_data = dut.enc_data_out.value.integer
        dut.dec_data_in.value = encoded_data
        dut.dec_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_decoding(dut, encoded_data, input_data)
        print(f"{description} test passed.")

@cocotb.test()
async def test_encoding(dut):
    """Test encoding by driving random values and comparing with expected encoded values."""
    await initialize_dut(dut)
    N = int(dut.N.value)
    
    for _ in range(10):
        input_data = random.randint(0, (1 << N) - 1)
        dut.enc_data_in.value = input_data
        dut.enc_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_encoding(dut, input_data, N)

@cocotb.test()
async def test_decoding(dut):
    """Test decoding by driving random decoder inputs and comparing decoder output."""
    await initialize_dut(dut)
    N = int(dut.N.value)
    
    for _ in range(10):
        input_data = random.randint(0, (1 << N) - 1)
        expected_encoded_data = 0
        for i in range(N):
            bit = (input_data >> i) & 1
            expected_encoded_data |= ((bit << (2 * i + 1)) | ((~bit & 1) << (2 * i)))
        
        dut.dec_data_in.value = expected_encoded_data
        dut.dec_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_decoding(dut, expected_encoded_data, input_data)

@cocotb.test()
async def test_encoding_decoding_together(dut):
    """Drive both encoder and decoder inputs at the same time and compare outputs."""
    await initialize_dut(dut)
    N = int(dut.N.value)
    
    for _ in range(10):
        input_data = random.randint(0, (1 << N) - 1)
        dut.enc_data_in.value = input_data
        dut.enc_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_encoding(dut, input_data, N)
        
        encoded_data = dut.enc_data_out.value.integer
        dut.dec_data_in.value = encoded_data
        dut.dec_valid_in.value = 1
        
        await RisingEdge(dut.clk_in)
        await check_decoding(dut, encoded_data, input_data)

@cocotb.test()
async def test_reset(dut):
    """Test reset behavior of encoder and decoder."""
    await initialize_dut(dut)
    N = int(dut.N.value)
    
    input_data = random.randint(0, (1 << N) - 1)
    dut.enc_data_in.value = input_data
    dut.enc_valid_in.value = 1
    await RisingEdge(dut.clk_in)
    
    # Assert reset
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    
    print("Checking Reset: Encoder Output should be 0.")
    assert dut.enc_data_out.value.integer == 0, "Encoder output is not reset to 0."
    assert dut.enc_valid_out.value == 0, "Encoder valid signal is not reset."
    print("Checking Reset: Decoder Output should be 0.")
    assert dut.dec_data_out.value.integer == 0, "Decoder output is not reset to 0."
    assert dut.dec_valid_out.value == 0, "Decoder valid signal is not reset."
    
    # Deassert reset
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    print("Reset test completed.")

