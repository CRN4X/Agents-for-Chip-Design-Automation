import cocotb
from cocotb.triggers import Timer
import random

# A reference model in Python replicating the ALU logic for verification.
# This model returns an integer in the 32-bit signed range.
def alu_model(opcode, op1, op2, op3):
    # Wrap values to 32-bit signed
    op1 = to_32bit_signed(op1)
    op2 = to_32bit_signed(op2)
    op3 = to_32bit_signed(op3)
    
    if opcode == 0:   # ADD
        res = op1 + op2 + op3
    elif opcode == 1: # SUB
        res = op1 - op2 - op3
    elif opcode == 2: # MUL
        res = op1 * op2 * op3
    elif opcode == 3: # DIV
        # Simple guard against division by zero
        if op2 == 0 or op3 == 0:
            res = 0
        else:
            tmp = (op1 / op2) / op3
            res = int(tmp)
    elif opcode == 4: # AND
        res = op1 & op2 & op3
    elif opcode == 5: # OR
        res = op1 | op2 | op3
    elif opcode == 6: # XOR
        res = op1 ^ op2 ^ op3
    else:             # default
        res = 0

    # Wrap final result back to 32-bit signed
    return to_32bit_signed(res)

# Helper: convert a Python integer into 32-bit signed range
def to_32bit_signed(val):
    val &= 0xFFFFFFFF
    # Interpret highest bit as sign
    if val & 0x80000000:
        return val - 0x100000000
    return val

# A reusable checker that drives the DUT inputs, waits, and compares the DUT output.
async def alu_check(dut, opcode, op1, op2, op3):
    # Assign inputs
    dut.opcode.value = opcode
    dut.operand1.value = op1
    dut.operand2.value = op2
    dut.operand3.value = op3

    # Wait a little for combinational propagation (no clock in this design)
    await Timer(1, units="ns")
    dut._log.info(f"TEST Definition: opcode={opcode} op1={op1} op2={op2} op3={op3}")
    
    # Read DUT output as signed
    got = dut.result.value.signed_integer
    # Calculate expected result via reference model
    expected = alu_model(opcode, op1, op2, op3)
    
    # Log the test vector and results
    dut._log.info(f"TEST Result    : got={got}, expected={expected}")
    
    # Check result
    assert got == expected, (
        f"ERROR for opcode={opcode}, operands=({op1},{op2},{op3}): "
        f"Expected {expected}, got {got}"
    )


@cocotb.test()
async def test_basic(dut):
    """Basic ALU test: small fixed vectors covering each opcode."""
    dut._log.info("===== BASIC TEST START =====")
    
    test_vectors = [
        (0, 10, 20, 30),  # ADD  => 10 + 20 + 30
        (1, 11, 21, 31),  # SUB  => 11 - 21 - 31
        (2, 12, 22, 32),  # MUL  => 12 * 22 * 32
        (3, 13, 23, 33),  # DIV  => 13 / 23 / 33
        (4, 14, 24, 34),  # AND
        (5, 15, 25, 35),  # OR
        (6, 16, 26, 36),  # XOR
        (7, 17, 27, 37)   # default => 0
    ]
    
    for (opcode, op1, op2, op3) in test_vectors:
        await alu_check(dut, opcode, op1, op2, op3)
    
    dut._log.info("===== BASIC TEST END =====")


@cocotb.test()
async def test_random(dut):
    """Random ALU test: random opcodes and operands."""
    dut._log.info("===== RANDOM TEST START =====")
    
    random_tests = 20  # number of random tests to run
    for _ in range(random_tests):
        opcode = random.randint(0, 7)

        # If case of divisions, ensure to not divide by 0
        if (opcode == 3):
            op1 = random.randint(-1000, 1000)
            op2 = random.randint(-1000, 1000)
            op3 = random.randint(-1000, 1000)

            while (op2 == 0):
                op2 = random.randint(-1000, 1000)

            while (op3 == 0):
                op3 = random.randint(-1000, 1000)
                
        else:
            op1 = random.randint(-1000, 1000)
            op2 = random.randint(-1000, 1000)
            op3 = random.randint(-1000, 1000)
        
        await alu_check(dut, opcode, op1, op2, op3)
    
    dut._log.info("===== RANDOM TEST END =====")


@cocotb.test()
async def test_edgecases(dut):
    """Edge case ALU test: extremes (min/max int), zero, etc."""
    dut._log.info("===== EDGE CASE TEST START =====")
    
    # 32-bit signed extremes
    min_32 = -2**31
    max_32 =  2**31 - 1
    
    edge_vectors = [
        (0, 0, 0, 0),          # add with zeros
        (0, max_32, 0, 0),     # add with max
        (1, 0, max_32, 0),     # subtract with max
        (2, min_32, 1, 1),     # multiply min boundary
        (3, max_32, max_32, 1),# large division
        (4, min_32, max_32, 0),# bitwise AND extremes
        (5, min_32, max_32, 0),# bitwise OR extremes
        (6, min_32, max_32, 0) # bitwise XOR extremes
    ]
    
    for (opcode, op1, op2, op3) in edge_vectors:
        await alu_check(dut, opcode, op1, op2, op3)
    
    dut._log.info("===== EDGE CASE TEST END =====")
