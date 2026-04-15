import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import random

NUM_LANES = 4
DATA_WIDTH = 8

# Flatten a list of lane values into a single integer.
# Lane 0 occupies bits [DATA_WIDTH-1:0], lane 1 occupies [2*DATA_WIDTH-1:DATA_WIDTH], etc.
def flatten_lanes(lanes):
    out = 0
    for i, lane in enumerate(lanes):
        out |= (lane & ((1 << DATA_WIDTH) - 1)) << (i * DATA_WIDTH)
    return out

# Flatten a swizzle map into a single integer.
# For 4 lanes, each mapping is 2 bits. Lane 0 mapping is at bits [1:0], etc.
def flatten_map(mapping):
    bits = max((NUM_LANES - 1).bit_length(), 1)
    out = 0
    for i, m in enumerate(mapping):
        out |= (m & ((1 << bits) - 1)) << (i * bits)
    return out

# Extract lane values from a flat integer.
# The least significant DATA_WIDTH bits become lane 0, and so on.
def extract_lanes(flat):
    lanes = []
    for i in range(NUM_LANES):
        lane = (flat >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
        lanes.append(lane)
    return lanes

@cocotb.test()
async def test_basic(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    input_data = [1, 2, 3, 4]
    swizzle_map = [0, 1, 2, 3]  # Identity mapping
    dut.data_in.value = flatten_lanes(input_data)
    dut.swizzle_map_flat.value = flatten_map(swizzle_map)
    dut.bypass.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    out = extract_lanes(dut.data_out.value.integer)
    assert out == input_data, f"Basic swizzle failed: expected {input_data}, got {out}"

@cocotb.test()
async def test_random(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 1
    for _ in range(10):
        input_data = [random.randint(0, 255) for _ in range(NUM_LANES)]
        swizzle_map = random.sample(range(NUM_LANES), NUM_LANES)
        dut.data_in.value = flatten_lanes(input_data)
        dut.swizzle_map_flat.value = flatten_map(swizzle_map)
        dut.bypass.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        expected = [input_data[i] for i in swizzle_map]
        out = extract_lanes(dut.data_out.value.integer)
        assert out == expected, f"Random swizzle failed: expected {expected}, got {out}"

@cocotb.test()
async def test_edge_cases(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 1

    # Edge case: alternating 0 and max values with reverse mapping.
    input_data = [255, 0, 255, 0]
    swizzle_map = [3, 2, 1, 0]  # Reverse mapping
    dut.data_in.value = flatten_lanes(input_data)
    dut.swizzle_map_flat.value = flatten_map(swizzle_map)
    dut.bypass.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    expected = [input_data[i] for i in swizzle_map]
    out = extract_lanes(dut.data_out.value.integer)
    assert out == expected, f"Edge case swizzle failed: expected {expected}, got {out}"

    # Test bypass mode: when bypass is enabled, output should match input_data exactly.
    dut.bypass.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    out_bypass = extract_lanes(dut.data_out.value.integer)
    assert out_bypass == input_data, f"Bypass failed: expected {input_data}, got {out_bypass}"
