import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random
import math

async def initialize_ram(dut):
    """Initialize the RAM (dual_port_ram) with inverse lookup values."""
    dut.we.value = 1  # Enable write mode

    for i in range(256):  # Populate only 256 values as in your SV testbench
        dut.wdata.value = compute_fx0_24(i)
        dut.waddr.value = i
        await RisingEdge(dut.clk)  # Wait for one clock cycle

    dut.we.value = 0  # Disable write mode
    dut.waddr.value = 0


def compute_fx0_24(n):
    """Compute the fixed-point (fx0.24) representation of 1/n."""
    if n == 0:
        return 0
    inverse = 1.0 / n
    return int(inverse * (2 ** 24))


async def initialize_dut(dut):
    """Initialize the DUT, including RAM initialization before testing."""
    dut.rst.value = 1
    dut.valid_in.value = 0
    dut.r_component.value = 0
    dut.g_component.value = 0
    dut.b_component.value = 0
    dut.we.value = 1
    dut.waddr.value = 0
    dut.wdata.value = 0

    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize RAM before applying any test cases
    await initialize_ram(dut)

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0


async def apply_rgb_input(dut, r, g, b):
    """Apply an RGB input to the DUT and wait for the HSV output."""
    dut.r_component.value = r
    dut.g_component.value = g
    dut.b_component.value = b
    dut.valid_in.value = 1

    await RisingEdge(dut.clk)
    dut.valid_in.value = 0  # Deassert valid

    # Wait for valid_out to be asserted
    while dut.valid_out.value == 0:
        await RisingEdge(dut.clk)

    # Capture the output
    h_out = int(dut.h_component.value)
    s_out = int(dut.s_component.value)
    v_out = int(dut.v_component.value)

    return h_out, s_out, v_out


def rgb_to_hsv_python(r, g, b):
    """Compute HSV values in Python to match RTL bit precision."""
    r_prime, g_prime, b_prime = r / 255.0, g / 255.0, b / 255.0
    c_max = max(r_prime, g_prime, b_prime)
    c_min = min(r_prime, g_prime, b_prime)
    delta = c_max - c_min

    # Compute Hue
    if delta == 0:
        h = 0
    elif c_max == r_prime:
        h = (60 * ((g_prime - b_prime) / delta)) % 360
    elif c_max == g_prime:
        h = (60 * ((b_prime - r_prime) / delta) + 120) % 360
    elif c_max == b_prime:
        h = (60 * ((r_prime - g_prime) / delta) + 240) % 360

    # Apply correct rounding to match RTL
    h_fx10_2 = int(h * 4 + 0.5)  # Convert degrees to fx10.2

    # Compute Saturation
    s_fx1_12 = round((delta / c_max) * 4096) if c_max != 0 else 0  # Convert percentage to fx1.12

    # Compute Value (Direct assignment matches RTL)
    v_fx0_12 = int(c_max * 255)  # Directly use Cmax (matches RTL behavior)

    return h_fx10_2, s_fx1_12, v_fx0_12

async def compare_rgb_to_hsv(dut, r, g, b):
    """
    Shared function to apply RGB input, compute reference values, and compare DUT outputs.
    """
    # Get DUT output
    h_out, s_out, v_out = await apply_rgb_input(dut, r, g, b)

    # Convert to degrees and percentages
    dut_h_deg = h_out / 4
    dut_s_pct = (s_out / 4096) * 100
    dut_v_pct = (v_out / 255) * 100  # Normalize V to 100%

    # Get reference output
    h_ref, s_ref, v_ref = rgb_to_hsv_python(r, g, b)

    # Convert reference values for comparison
    ref_h_deg = h_ref / 4
    ref_s_pct = (s_ref / 4096) * 100
    ref_v_pct = (v_ref / 255) * 100

    print(f"Input RGB: ({r:3}, {g:3}, {b:3}) → "
          f"DUT HSV: ({dut_h_deg:7.2f}°, {dut_s_pct:6.2f}%, {dut_v_pct:6.2f}%) | "
          f"Ref HSV: ({ref_h_deg:7.2f}°, {ref_s_pct:6.2f}%, {ref_v_pct:6.2f}%)")

    # Assert correctness
    assert abs(dut_h_deg - ref_h_deg) <= 0.25, f"Mismatch in H: Expected {ref_h_deg:.2f}°, got {dut_h_deg:.2f}°"
    assert abs(dut_s_pct - ref_s_pct) <= 0.25, f"Mismatch in S: Expected {ref_s_pct:.2f}%, got {dut_s_pct:.2f}%"
    assert abs(dut_v_pct - ref_v_pct) <= 0.25, f"Mismatch in V: Expected {ref_v_pct:.2f}%, got {dut_v_pct:.2f}%"

@cocotb.test()
async def test_rgb_to_hsv(dut):
    """Test predefined RGB inputs and compare HSV outputs with expected values."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Predefined test cases
    test_cases = [
        (193, 226, 60),   # Normal color
        (255, 0, 0),      # Red
        (0, 255, 0),      # Green
        (0, 0, 255),      # Blue
        (255, 255, 0),    # Yellow
        (0, 255, 255),    # Cyan
        (255, 0, 255),    # Magenta
        (128, 128, 128),  # Mid Gray
        (255, 255, 255),  # White
        (0, 0, 0),        # Black
        (212, 90, 17),    # Random color
        (10, 10, 10),     # Almost black
        (245, 245, 245),  # Almost white
        (50, 100, 200),   # Random blue shade
        (200, 50, 100),   # Random red shade
        (100, 200, 50),   # Random green shade
        (1, 1, 1),        # Edge case: near black
        (254, 254, 254),  # Edge case: near white
    ]

    for r, g, b in test_cases:
        await compare_rgb_to_hsv(dut, r, g, b)


@cocotb.test()
async def test_rgb_to_hsv_random(dut):
    """Test random RGB inputs and compare HSV outputs with expected values."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Number of random test cases to generate
    num_random_tests = 50

    for _ in range(num_random_tests):
        # Generate random RGB values
        random_r = random.randint(0, 255)
        random_g = random.randint(0, 255)
        random_b = random.randint(0, 255)

        # Compare DUT output with reference
        await compare_rgb_to_hsv(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_random_r_max(dut):
    """Test random RGB inputs where R is the maximum value."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Number of random test cases to generate
    num_random_tests = 50

    for _ in range(num_random_tests):
        # Generate random RGB values where R is the maximum
        random_r = random.randint(1, 255)  # Ensure R is high
        random_g = random.randint(0, random_r - 1)  # G < R
        random_b = random.randint(0, random_r - 1)  # B < R

        # Compare DUT output with reference
        await compare_rgb_to_hsv(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_random_g_max(dut):
    """Test random RGB inputs where G is the maximum value."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Number of random test cases to generate
    num_random_tests = 50

    for _ in range(num_random_tests):
        # Generate random RGB values where G is the maximum
        random_g = random.randint(1, 255)  # Ensure G is high
        random_r = random.randint(0, random_g - 1)  # R < G
        random_b = random.randint(0, random_g - 1)  # B < G

        # Compare DUT output with reference
        await compare_rgb_to_hsv(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_random_b_max(dut):
    """Test random RGB inputs where B is the maximum value."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Number of random test cases to generate
    num_random_tests = 50

    for _ in range(num_random_tests):
        # Generate random RGB values where B is the maximum
        random_b = random.randint(1, 255)  # Ensure B is high
        random_r = random.randint(0, random_b - 1)  # R < B
        random_g = random.randint(0, random_b - 1)  # G < B

        # Compare DUT output with reference
        await compare_rgb_to_hsv(dut, random_r, random_g, random_b)

@cocotb.test()
async def test_rgb_to_hsv_max_min_same(dut):
    """Test RGB inputs where max and min values are the same (grayscale colors)."""
    await initialize_dut(dut)  # Ensure RAM is initialized

    # Number of random test cases to generate
    num_random_tests = 50

    for _ in range(num_random_tests):
        # Generate a random grayscale value (R = G = B)
        grayscale_value = random.randint(0, 255)

        # Use the same value for R, G, and B
        r, g, b = grayscale_value, grayscale_value, grayscale_value

        # Compare DUT output with reference
        await compare_rgb_to_hsv(dut, r, g, b)

@cocotb.test()
async def test_reset_outputs_zero(dut):
    """Verify that outputs are 0 after reset."""
    await initialize_dut(dut)  # Ensure RAM is initialized and reset is applied

    # Check outputs after reset
    h_out = int(dut.h_component.value)
    s_out = int(dut.s_component.value)
    v_out = int(dut.v_component.value)

    # Print results
    print(f"After reset: H = {h_out}, S = {s_out}, V = {v_out}")

    # Assert outputs are 0
    assert h_out == 0, f"Expected H = 0 after reset, got {h_out}"
    assert s_out == 0, f"Expected S = 0 after reset, got {s_out}"
    assert v_out == 0, f"Expected V = 0 after reset, got {v_out}"


