import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import random
import math

async def initialize_ram(dut):
    """Initialize the RAM with inverse lookup values."""
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
    h_out = int(dut.hsv_channel_h.value)
    s_out = int(dut.hsv_channel_s.value)
    v_out = int(dut.hsv_channel_v.value)
    
    hsl_h_out = int(dut.hsl_channel_h.value)
    hsl_s_out = int(dut.hsl_channel_s.value)
    hsl_l_out = int(dut.hsl_channel_l.value)
    
    c_out = int(dut.cmyk_channel_c.value)
    m_out = int(dut.cmyk_channel_m.value)
    y_out = int(dut.cmyk_channel_y.value)
    k_out = int(dut.cmyk_channel_k.value)

    return c_out, m_out, y_out, k_out, h_out, s_out, v_out, hsl_h_out, hsl_s_out, hsl_l_out


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
    c_out, m_out, y_out, k_out, h_out, s_out, v_out, hsl_h_out, hsl_s_out, hsl_l_out = await apply_rgb_input(dut, r, g, b)

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


def rgb_to_hsl_python(r, g, b):
    r_, g_, b_ = r / 255.0, g / 255.0, b / 255.0
    max_c = max(r_, g_, b_)
    min_c = min(r_, g_, b_)
    delta = max_c - min_c

    # Compute Hue
    if delta == 0:
        h = 0
    elif max_c == r_:
        h = (60 * ((g_ - b_) / delta)) % 360
    elif max_c == g_:
        h = (60 * ((b_ - r_) / delta) + 120) % 360
    else:
        h = (60 * ((r_ - g_) / delta) + 240) % 360

    # Compute Lightness
    l = (max_c + min_c) / 2

    # Compute Saturation
    if delta == 0:
        s = 0
    else:
        s = delta / (1 - abs(2 * l - 1))

    h_fx10_2 = int(h * 4 + 0.5)
    s_fx1_12 = int(s * 4096 + 0.5)
    l_fx0_8 = int(l * 255 + 0.5)

    return h_fx10_2, s_fx1_12, l_fx0_8


async def compare_rgb_to_hsl(dut, r, g, b):
    c_out, m_out, y_out, k_out, h_out, s_out, v_out, hsl_h_out, hsl_s_out, hsl_l_out = await apply_rgb_input(dut, r, g, b)

    h_ref, s_ref, l_ref = rgb_to_hsl_python(r, g, b)

    dut_h_deg = hsl_h_out / 4
    dut_s_pct = (hsl_s_out / 4096) * 100
    dut_l_pct = (hsl_l_out / 255) * 100

    ref_h_deg = h_ref / 4
    ref_s_pct = (s_ref / 4096) * 100
    ref_l_pct = (l_ref / 255) * 100

    print(f"Input RGB: ({r:3}, {g:3}, {b:3}) → "
          f"DUT HSL: ({dut_h_deg:7.2f}°, {dut_s_pct:6.2f}%, {dut_l_pct:6.2f}%) | "
          f"Ref HSL: ({ref_h_deg:7.2f}°, {ref_s_pct:6.2f}%, {ref_l_pct:6.2f}%)")

    assert abs(dut_h_deg - ref_h_deg) <= 0.25, f"Hue mismatch: DUT={dut_h_deg}°, REF={ref_h_deg}°"
    assert abs(dut_s_pct - ref_s_pct) <= 0.25, f"Sat mismatch: DUT={dut_s_pct}%, REF={ref_s_pct}%"
    assert abs(dut_l_pct - ref_l_pct) <= 0.5, f"Lightness mismatch: DUT={dut_l_pct}%, REF={ref_l_pct}%"

def rgb_to_cmyk_python(r, g, b):
    r_, g_, b_ = r / 255.0, g / 255.0, b / 255.0
    k = 1.0 - max(r_, g_, b_)

    if k == 1.0:
        c = m = y = 0.0
    else:
        c = (1 - r_ - k) / (1 - k)
        m = (1 - g_ - k) / (1 - k)
        y = (1 - b_ - k) / (1 - k)

    # Fixed-point formats:
    # C, M, Y: fx8.8 scaled to 255 range then left shifted by 8
    # K: fx0.8 scaled directly to 0–255

    c_fx8_8 = int(c * 255 * 256 + 0.5)
    m_fx8_8 = int(m * 255 * 256 + 0.5)
    y_fx8_8 = int(y * 255 * 256 + 0.5)
    k_fx0_8 = int(k * 255 + 0.5)

    return c_fx8_8, m_fx8_8, y_fx8_8, k_fx0_8


async def compare_rgb_to_cmyk(dut, r, g, b):
    # Assume apply_rgb_input returns CMYK output channels in fixed-point
    c_out, m_out, y_out, k_out, h_out, s_out, v_out, hsl_h_out, hsl_s_out, hsl_l_out = await apply_rgb_input(dut, r, g, b)
    c_ref, m_ref, y_ref, k_ref = rgb_to_cmyk_python(r, g, b)

    # Convert DUT fixed-point outputs to percentages
    dut_c_pct = (c_out / (256 * 255)) * 100
    dut_m_pct = (m_out / (256 * 255)) * 100
    dut_y_pct = (y_out / (256 * 255)) * 100
    dut_k_pct = (k_out / 255) * 100

    ref_c_pct = (c_ref / (256 * 255)) * 100
    ref_m_pct = (m_ref / (256 * 255)) * 100
    ref_y_pct = (y_ref / (256 * 255)) * 100
    ref_k_pct = (k_ref / 255) * 100

    print(f"Input RGB: ({r:3}, {g:3}, {b:3}) → "
          f"DUT CMYK: ({dut_c_pct:6.2f}%, {dut_m_pct:6.2f}%, {dut_y_pct:6.2f}%, {dut_k_pct:6.2f}%) | "
          f"Ref CMYK: ({ref_c_pct:6.2f}%, {ref_m_pct:6.2f}%, {ref_y_pct:6.2f}%, {ref_k_pct:6.2f}%)")

    tolerance = 0.25
    assert abs(dut_c_pct - ref_c_pct) <= tolerance, f"Cyan mismatch: DUT={dut_c_pct}%, REF={ref_c_pct}%"
    assert abs(dut_m_pct - ref_m_pct) <= tolerance, f"Magenta mismatch: DUT={dut_m_pct}%, REF={ref_m_pct}%"
    assert abs(dut_y_pct - ref_y_pct) <= tolerance, f"Yellow mismatch: DUT={dut_y_pct}%, REF={ref_y_pct}%"
    assert abs(dut_k_pct - ref_k_pct) <= tolerance, f"Black mismatch: DUT={dut_k_pct}%, REF={ref_k_pct}%"

@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_predefined(dut):
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
        await compare_rgb_to_hsl(dut, r, g, b)
        await compare_rgb_to_cmyk(dut, r, g, b)


@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_random(dut):
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
        await compare_rgb_to_hsl(dut, random_r, random_g, random_b)
        await compare_rgb_to_cmyk(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_random_r_max(dut):
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
        await compare_rgb_to_hsl(dut, random_r, random_g, random_b)
        await compare_rgb_to_cmyk(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_random_g_max(dut):
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
        await compare_rgb_to_hsl(dut, random_r, random_g, random_b)
        await compare_rgb_to_cmyk(dut, random_r, random_g, random_b)


@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_random_b_max(dut):
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
        await compare_rgb_to_hsl(dut, random_r, random_g, random_b)
        await compare_rgb_to_cmyk(dut, random_r, random_g, random_b)

@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_max_min_same(dut):
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
        await compare_rgb_to_hsl(dut, r, g, b)
        await compare_rgb_to_cmyk(dut, r, g, b)

@cocotb.test()
async def test_reset_outputs_zero(dut):
    """Verify that outputs are 0 after reset."""
    await initialize_dut(dut)  # Ensure RAM is initialized and reset is applied

    # Check outputs after reset
    h_out = int(dut.hsv_channel_h.value)
    s_out = int(dut.hsv_channel_s.value)
    v_out = int(dut.hsv_channel_v.value)
    hsl_h_out = int(dut.hsl_channel_h.value)
    hsl_s_out = int(dut.hsl_channel_s.value)
    hsl_l_out = int(dut.hsl_channel_l.value)
        
    c_out = int(dut.cmyk_channel_c.value)
    m_out = int(dut.cmyk_channel_m.value)
    y_out = int(dut.cmyk_channel_y.value)
    k_out = int(dut.cmyk_channel_k.value)

    # Print results
    print(f"After reset: HSV_H = {h_out}, HSV_S = {s_out}, HSV_V = {v_out} HSL_H = {hsl_h_out}, HSL_S = {hsl_s_out}, HSL_L = {hsl_l_out}")

    # Assert outputs are 0
    assert h_out == 0, f"Expected HSV_H = 0 after reset, got {h_out}"
    assert s_out == 0, f"Expected HSV_S = 0 after reset, got {s_out}"
    assert v_out == 0, f"Expected HSV_V = 0 after reset, got {v_out}"
    assert hsl_h_out == 0, f"Expected HSL_H = 0 after reset, got {hsl_h_out}"
    assert hsl_s_out == 0, f"Expected HSL_S = 0 after reset, got {hsl_s_out}"
    assert hsl_l_out == 0, f"Expected HSL_L = 0 after reset, got {hsl_l_out}"
    
    assert c_out == 0, f"Expected CMYK_C = 0 after reset, got {c_out}"
    assert m_out == 0, f"Expected CMYK_M = 0 after reset, got {m_out}"
    assert y_out == 0, f"Expected CMYK_Y = 0 after reset, got {y_out}"
    assert k_out == 0, f"Expected CMYK_K = 0 after reset, got {k_out}"

@cocotb.test()
async def test_rgb_to_hsv_hsl_cmyk_color_table(dut):
    await initialize_dut(dut)

    # RGB to HSL color table test cases
    color_table_cases = [
        (0, 0, 0),         # Black
        (255, 255, 255),   # White
        (255, 0, 0),       # Red
        (0, 255, 0),       # Lime
        (0, 0, 255),       # Blue
        (255, 255, 0),     # Yellow
        (0, 255, 255),     # Cyan
        (255, 0, 255),     # Magenta
        (191, 191, 191),   # Silver
        (128, 128, 128),   # Gray
        (128, 0, 0),       # Maroon
        (128, 128, 0),     # Olive
        (0, 128, 0),       # Green
        (128, 0, 128),     # Purple
        (0, 128, 128),     # Teal
        (0, 0, 128),       # Navy
    ]

    for r, g, b in color_table_cases:
        await compare_rgb_to_hsv(dut, r, g, b)
        await compare_rgb_to_hsl(dut, r, g, b)
        await compare_rgb_to_cmyk(dut, r, g, b)

