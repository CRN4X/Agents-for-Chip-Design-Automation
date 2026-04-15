import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def run_systolic_array_test(dut):
    """
    Cocotb test for the 2x2 systolic array.

    This test replicates the same sequence and test vectors
    demonstrated in the original Verilog testbench.
    """

    # ------------------------------------------------------------------------
    # Parameters
    # ------------------------------------------------------------------------
    CLK_PERIOD = 10  # ns (equivalent to 100 MHz)

    # ------------------------------------------------------------------------
    # Create and start the clock
    # ------------------------------------------------------------------------
    clock = Clock(dut.clk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())

    # ------------------------------------------------------------------------
    # Reset logic
    # ------------------------------------------------------------------------
    dut.reset.value        = 1
    dut.load_weights.value = 0
    dut.start.value        = 0
    dut.w00.value          = 0
    dut.w01.value          = 0
    dut.w10.value          = 0
    dut.w11.value          = 0
    dut.x0.value           = 0
    dut.x1.value           = 0

    # Hold reset high for a few cycles
    for _ in range(5):
        await RisingEdge(dut.clk)

    # Deassert reset
    dut.reset.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)

    # ------------------------------------------------------------------------
    # Define test vectors
    #
    # Each test is a dictionary holding:
    #   w00, w01, w10, w11, x0, x1, y0_exp, y1_exp
    # ------------------------------------------------------------------------
    tests = [
        # Test 0: Simple: All weights = 1, x0=2, x1=3 => y0=5, y1=5
        {"w00":1,  "w01":1,  "w10":1,  "w11":1,
         "x0":2,  "x1":3,
         "y0_exp":5,  "y1_exp":5},

        # Test 1: Normal case => w00=2,w01=3,w10=4,w11=5, x0=6,x1=7 => y0=40, y1=53
        {"w00":2,  "w01":3,  "w10":4,  "w11":5,
         "x0":6,  "x1":7,
         "y0_exp":40, "y1_exp":53},

        # Test 2: Zero weights => all wXX=0 => y0=0, y1=0
        {"w00":0,  "w01":0,  "w10":0,  "w11":0,
         "x0":10, "x1":20,
         "y0_exp":0,  "y1_exp":0},

        # Test 3: Zero inputs => x0=0, x1=0 => y0=0, y1=0
        {"w00":5,  "w01":4,  "w10":3,  "w11":2,
         "x0":0,  "x1":0,
         "y0_exp":0, "y1_exp":0},

        # Test 4: Maximum unsigned => 255*255 => truncated in 8 bits
        # Expect each partial product = 0xFF * 0xFF => 65025 => 0x01 LSB
        # The final sums in a 2x2 pipeline lead to y0=2, y1=2
        {"w00":255, "w01":255, "w10":255, "w11":255,
         "x0":255, "x1":255,
         "y0_exp":2,  "y1_exp":2},

        # Test 5: Mixed partial overflow
        # w00=100, w01=150, w10=200, w11=250, x0=8, x1=3
        # => y0= (8*100 + 3*200)=1400 => 1400 mod 256=120
        # => y1= (8*150 + 3*250)=1950 => 1950 mod 256=158
        {"w00":100, "w01":150, "w10":200, "w11":250,
         "x0":8,    "x1":3,
         "y0_exp":120, "y1_exp":158},

        # Test 6: Repeated zero case
        {"w00":0,  "w01":0,  "w10":0,  "w11":0,
         "x0":0,   "x1":0,
         "y0_exp":0,  "y1_exp":0},
    ]

    # ------------------------------------------------------------------------
    # Test execution loop
    # ------------------------------------------------------------------------
    for i, test_vec in enumerate(tests):

        # 1) Load the weights
        dut.w00.value = test_vec["w00"]
        dut.w01.value = test_vec["w01"]
        dut.w10.value = test_vec["w10"]
        dut.w11.value = test_vec["w11"]

        dut.load_weights.value = 1
        await RisingEdge(dut.clk)
        dut.load_weights.value = 0

        # 2) Apply inputs and start
        dut.x0.value = test_vec["x0"]
        dut.x1.value = test_vec["x1"]

        dut.start.value = 1

        # Wait until done is asserted
        while True:
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Additional cycle to let outputs settle
        await RisingEdge(dut.clk)

        # 3) Read outputs and compare
        y0_val = dut.y0.value.integer
        y1_val = dut.y1.value.integer
        y0_exp = test_vec["y0_exp"]
        y1_exp = test_vec["y1_exp"]

        if (y0_val == y0_exp) and (y1_val == y1_exp):
            dut._log.info(f"Test {i} PASSED. y0={y0_val}, y1={y1_val} (Expected {y0_exp}, {y1_exp})")
        else:
            dut._log.error(f"Test {i} FAILED. y0={y0_val}, y1={y1_val} (Expected {y0_exp}, {y1_exp})")

        # Deassert start and wait some cycles
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    dut._log.info("All tests completed successfully.")
