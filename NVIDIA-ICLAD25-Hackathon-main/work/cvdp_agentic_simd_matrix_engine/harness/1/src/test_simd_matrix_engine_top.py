import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random

N = 8
DATA_WIDTH = 16

def flatten_matrix(matrix):
    flat = 0
    for i in reversed(range(N)):
        for j in reversed(range(N)):
            flat = (flat << DATA_WIDTH) | (matrix[i][j] & ((1 << DATA_WIDTH) - 1))
    return flat

def unflatten_matrix(bitvector):
    matrix = [[0 for _ in range(N)] for _ in range(N)]
    for i in range(N):
        for j in range(N):
            idx = i * N + j
            matrix[i][j] = (bitvector >> (idx * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
    return matrix

def compute_expected(A, B, op_sel):
    result = [[0 for _ in range(N)] for _ in range(N)]
    for i in range(N):
        for j in range(N):
            a, b = A[i][j], B[i][j]
            if op_sel == 0:
                result[i][j] = (a + b) & 0xFFFF
            elif op_sel == 1:
                result[i][j] = (a - b) & 0xFFFF
            elif op_sel == 2:
                result[i][j] = (a * b) & 0xFFFF
    return result

def display_matrix(title, mat, dut):
    dut._log.info(f"\n{title}")
    for row in mat:
        dut._log.info("[" + ", ".join(f"{val:5d}" for val in row) + "]")

@cocotb.test()
async def test_simd_matrix_engine(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst.value = 1
    dut.start.value = 0
    dut.op_select.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0

    # Random test data
    A = [[random.randint(0, 255) for _ in range(N)] for _ in range(N)]
    B = [[random.randint(0, 255) for _ in range(N)] for _ in range(N)]
    op_sel = random.choice([0, 1, 2])

    dut._log.info(f"\n Testing Operation: {['ADD', 'SUB', 'MUL'][op_sel]}")
    display_matrix("Matrix A:", A, dut)
    display_matrix("Matrix B:", B, dut)

    # Drive inputs
    dut.mat_a_flat.value = flatten_matrix(A)
    dut.mat_b_flat.value = flatten_matrix(B)
    dut.op_select.value = op_sel

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 1000
    while dut.done.value == 0 and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    assert timeout > 0, " Timeout waiting for DUT to complete"

    # Read output
    binstr = str(dut.mat_result_flat.value).lower().replace('x', '0')
    result_flat = int(binstr, 2)
    result_matrix = unflatten_matrix(result_flat)
    expected_matrix = compute_expected(A, B, op_sel)

    display_matrix("DUT Result Matrix:", result_matrix, dut)
    display_matrix("Expected Matrix   :", expected_matrix, dut)

    # Compare
    errors = 0
    for i in range(N):
        for j in range(N):
            if result_matrix[i][j] != expected_matrix[i][j]:
                dut._log.error(f" Mismatch at ({i},{j}): DUT={result_matrix[i][j]}, Expected={expected_matrix[i][j]}")
                errors += 1

    assert errors == 0, f"Test failed with {errors} mismatches."
    dut._log.info(" Test passed.")
