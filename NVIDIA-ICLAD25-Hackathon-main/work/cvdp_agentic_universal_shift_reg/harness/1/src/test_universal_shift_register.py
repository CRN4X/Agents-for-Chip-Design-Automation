import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge,FallingEdge, Timer
import random

import harness_library as hrs_lb


@cocotb.test()
async def test_universal_shift_register(dut):

    N = int(dut.N.value)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    await hrs_lb.dut_init(dut)
    
    # Run individual tests
    await test_pipo(dut,N)
    await test_piso(dut,N)
    await test_siso(dut,N)
    await test_sipo(dut,N)
    await test_rotate_right(dut,N)
    await test_rotate_left(dut,N)
    await test_hold(dut,N)

    cocotb.log.info("=== Universal Shift Register Testbench Completed Successfully ===")

async def reset_register(dut):
    """Reset the DUT"""
    dut.rst.value = 1
    await FallingEdge(dut.clk)
    dut.serial_in.value = 0
    dut.parallel_in.value = 0
    await FallingEdge(dut.clk)
    dut.rst.value = 0
    cocotb.log.info("Reset completed.")

async def test_pipo(dut,N):
    """Test Parallel In - Parallel Out (PIPO)"""

        # Reset the DUT
    await reset_register(dut)
    await FallingEdge(dut.clk)
    
    parallel_data = random.randint(0, (1 << N) - 1)
    dut.mode_sel.value = 0b11  # PIPO mode
    dut.parallel_in.value = parallel_data
    expected_q = parallel_data
    
    await FallingEdge(dut.clk)
    
    actual_q = int (dut.q.value)
    assert actual_q == expected_q, f"PIPO Test Failed: Expected q={expected_q:08b}, Got q={actual_q:08b}"
    cocotb.log.info(f"PIPO - PASSED | Input: {parallel_data:08b} | Expected q={expected_q:08b} | Got q={actual_q:08b}")

async def test_piso(dut,N):
    """Test Parallel In - Serial Out (PISO)"""
    await reset_register(dut)
    await FallingEdge(dut.clk)

    # Generate data to be transmitted
    parallel_data = random.randint(0, (1 << N) - 1)

    # Load Parallel Data
    dut.mode_sel.value = 0b11  # Load Parallel Data
    dut.parallel_in.value = parallel_data

    cocotb.log.info(f"PISO - Loaded Data: {parallel_data:08b}")
    await FallingEdge(dut.clk)

    # Test Configuration
    dut.mode_sel.value = 0b01  # Shift Right mode
    dut.shift_dir.value = 0
    
    expected_q = parallel_data

    for _ in range(N):
        expected_serial_out = expected_q & 1  # LSB
        actual_serial_out = int (dut.serial_out.value)
        assert actual_serial_out == expected_serial_out, f"PISO Failed: Expected serial_out={expected_serial_out}, Got serial_out={actual_serial_out}"
        expected_q = expected_q // 2  # Shift right
        cocotb.log.info(f"PISO - PASSED | Expected serial_out={expected_serial_out} | Got serial_out={actual_serial_out}")
        await FallingEdge(dut.clk)

async def test_siso(dut,N):
    """Test Serial In - Serial Out (SISO)"""
    serial_input = 0
    await reset_register(dut)
    await FallingEdge(dut.clk)

    # Generate data to be transmitted
    serial_input = random.randint(0, 1)

    # Drive DUT signals
    dut.mode_sel.value = 0b01  # Shift Right mode
    dut.shift_dir.value = 0
    dut.serial_in.value = serial_input

    expected_q = 0
    for _ in range(N*2):
        expected_serial_out = expected_q & 1  # LSB
        actual_serial_out = int (dut.serial_out.value)
        assert actual_serial_out == expected_serial_out, f"SISO Failed: Expected serial_out={expected_serial_out}, Got serial_out={actual_serial_out}"
        expected_q = (serial_input << (N - 1)) | (expected_q >> 1)  # Shift right with new serial input
        cocotb.log.info(f"SISO - PASSED | Serial Input={serial_input} | Expected serial_out={expected_serial_out} | Got serial_out={actual_serial_out}")
        await FallingEdge(dut.clk)

async def test_sipo(dut, N):
    """Test Serial In - Parallel Out (SIPO)"""
    serial_input = 0
    await reset_register(dut)
    await FallingEdge(dut.clk)

    dut.mode_sel.value = 0b01  # Shift Right mode
    dut.shift_dir.value = 0
    expected_q = 0

    for _ in range(N):
        serial_input = random.randint(0, 1)  # Generate new serial input
        dut.serial_in.value = serial_input  # Set serial input before shift
        actual_q = dut.q.value.to_unsigned()  # Capture the DUT's q output
        assert actual_q == expected_q, f"SIPO Failed: Expected q={expected_q:0{N}b}, Got q={actual_q:0{N}b}"
        cocotb.log.info(f"SIPO - PASSED | Serial Input={serial_input} | Expected q={expected_q:0{N}b} | Got q={actual_q:0{N}b}")
        expected_q = (expected_q >> 1) | (serial_input << (N - 1))  # Corrected shift operation
        await FallingEdge(dut.clk)  # Wait for shift to complete

        
async def test_rotate_right(dut,N):
    """Test Rotate Right"""
    serial_input = 0
    await reset_register(dut)
    await FallingEdge(dut.clk)

    parallel_data = random.randint(0, (1 << N) - 1)
    dut.mode_sel.value = 0b11  # Load Parallel Data
    dut.parallel_in.value = parallel_data
    await FallingEdge(dut.clk)

    # Test Configuration
    dut.mode_sel.value = 0b10  # Rotate mode
    dut.shift_dir.value = 0  # Rotate Right
    expected_q = parallel_data

    for _ in range(N):
        actual_q = dut.q.value.to_unsigned()  # Convert to integer
        assert actual_q == expected_q, f"Rotate Right Failed: Expected q={expected_q:0{N}b}, Got q={actual_q:0{N}b}"
        cocotb.log.info(f"Rotate Right - PASSED | Expected q={expected_q:0{N}b} | Got q={actual_q:0{N}b}")
        expected_q = (expected_q >> 1) | ((expected_q & 1) << (N - 1))  # Right circular shift
        await FallingEdge(dut.clk)

async def test_rotate_left(dut,N):
    """Test Rotate Left"""
    serial_input = 0
    await reset_register(dut)
    await FallingEdge(dut.clk)

    # Generate Data
    parallel_data = random.randint(0, (1 << N) - 1)

    # Drive DUT Signals
    dut.mode_sel.value = 0b11  # Load Parallel Data
    dut.parallel_in.value = parallel_data
    await FallingEdge(dut.clk)
    
    # Test Configuration
    dut.mode_sel.value = 0b10  # Rotate mode
    dut.shift_dir.value = 1  # Rotate Left
    expected_q = parallel_data

    for _ in range(N):
        actual_q = dut.q.value.to_unsigned()  # Convert to integer
        assert actual_q == expected_q, f"Rotate Left Failed: Expected q={expected_q:08b}, Got q={actual_q:08b}"
        cocotb.log.info(f"Rotate Left - PASSED | Expected q={expected_q:08b} | Got q={actual_q:08b}")
        expected_q = ((expected_q << 1) | (expected_q >> (N - 1))) & ((1 << N) - 1)  # Rotate left
        await FallingEdge(dut.clk)

async def test_hold(dut,N):
    """Test Hold Mode"""
    await reset_register(dut)
    await FallingEdge(dut.clk)

    # Generate data to be transmitted
    parallel_data = random.randint(0, (1 << N) - 1)
    dut.mode_sel.value = 0b11  # Load Parallel Data
    dut.parallel_in.value = parallel_data
    await FallingEdge(dut.clk)
    
    # Drive DUT signals
    dut.mode_sel.value = 0b00  # Hold mode
    expected_q = parallel_data

    await FallingEdge(dut.clk)
    
    actual_q = int(dut.q.value)
    assert actual_q == expected_q, f"Hold Mode Failed: Expected q={expected_q:08b}, Got q={actual_q:08b}"
    cocotb.log.info(f"Hold - PASSED | Expected q={expected_q:08b} | Got q={actual_q:08b}")
