
import cocotb
from cocotb.triggers import Timer
import random
import os

@cocotb.test()
async def test_binary_to_gray(dut):
    """Test Binary to Gray Code Conversion"""

    WIDTH = int(dut.WIDTH.value)

    def binary_to_gray(binary):
        return binary ^ (binary >> 1)

   
    predefined_cases = [i for i in range(2 ** WIDTH)]  

   
    dut._log.info(f"Running predefined test cases with WIDTH={WIDTH}")
    for binary in predefined_cases:
        dut.binary_in.value = binary
        await Timer(10, units="ns")  
        gray = binary_to_gray(binary)
        dut_gray = int(dut.gray_out.value) 
        cocotb.log.info(f"Pushed Binary: {binary:0{WIDTH}b}, Expected Gray: {gray:0{WIDTH}b}, DUT Gray: {dut_gray:0{WIDTH}b}")
        assert dut_gray == gray, \
            f"Predefined Test Failed: Binary={binary:0{WIDTH}b}, Expected Gray={gray:0{WIDTH}b}, Got={dut_gray:0{WIDTH}b}"


    dut._log.info("--- Printing Random Values ---")


    for _ in range(16):
        binary = random.randint(0, (1 << WIDTH) - 1) 
        dut.binary_in.value = binary
        await Timer(10, units="ns") 
        gray = binary_to_gray(binary)
        dut_gray = int(dut.gray_out.value) 
        cocotb.log.info(f"Pushed Binary: {binary:0{WIDTH}b}, Expected Gray: {gray:0{WIDTH}b}, DUT Gray: {dut_gray:0{WIDTH}b}")
        assert dut_gray == gray, \
            f"Random Test Failed: Binary={binary:0{WIDTH}b}, Expected Gray={gray:0{WIDTH}b}, Got={dut_gray:0{WIDTH}b}"