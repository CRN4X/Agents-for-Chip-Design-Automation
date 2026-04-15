import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

def pack_vector(orders, width):
    """
    Pack a list of integers (orders[0] ... orders[7]) into a flat integer.
    The flat vector is constructed as {orders[7], orders[6], ..., orders[0]}
    so that orders[0] occupies the least-significant bits.
    """
    value = 0
    for order in orders[::-1]:
        value = (value << width) | (order & ((1 << width) - 1))
    return value

def scale_orders(orders, max_val):
    """
    Scale a list of order percentages (0-100) into the range [0, max_val].
    """
    return [int(val * max_val / 100) for val in orders]

@cocotb.test()
async def test_order_matching_engine(dut):
    """
    Cocotb testbench for order_matching_engine.
    This test applies several corner-case and random test vectors,
    verifies that the matching result (match_valid and matched_price)
    is correct, and checks that the overall latency from start to done is exactly 20 cycles.
    """
    # Create and start clock (10 ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Retrieve PRICE_WIDTH parameter from DUT (default to 16)
    try:
        price_width = int(dut.PRICE_WIDTH.value)
    except Exception as e:
        dut._log.warning("Unable to read PRICE_WIDTH parameter, defaulting to 16. Error: %s", e)
        price_width = 16

    max_val = (1 << price_width) - 1
    NUM_ELEMS = 8

    # Helper: Measure latency from start pulse to when done is asserted.
    async def measure_latency():
        cycle_count = 0
        while int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycle_count += 1
        return cycle_count

    # Define test cases.
    tests = []

    # Test 1: Matching scenario (bid >= ask)
    # Original percentages for bid: [40, 80, 20, 70, 60, 30, 10, 50]
    # and ask: [35, 15, 45, 55, 25, 65, 75, 78].
    tests.append({
        "description": "Matching scenario: valid match",
        "bid": scale_orders([40, 80, 20, 70, 60, 30, 10, 50], max_val),
        "ask": scale_orders([35, 15, 45, 55, 25, 65, 75, 78], max_val),
        "expected_match": True,
        "expected_price": int(15 * max_val / 100)  # 15% of max_val
    })

    # Test 2: No match scenario (bid < ask)
    tests.append({
        "description": "No match scenario: no match",
        "bid": scale_orders([10, 20, 30, 40, 50, 60, 70, 75], max_val),
        "ask": scale_orders([80, 90, 95, 85, 88, 82, 91, 87], max_val),
        "expected_match": False,
        "expected_price": 0
    })

    # Test 3: Extreme values at boundaries.
    tests.append({
        "description": "Extreme values: match at boundary",
        "bid": [0, 0, 0, 0, 0, 0, 0, max_val],
        "ask": [max_val] * NUM_ELEMS,
        "expected_match": True,
        "expected_price": max_val
    })

    # Test 4: Random stress tests (10 iterations)
    for t in range(10):
        bid_rand = [random.randint(0, max_val) for _ in range(NUM_ELEMS)]
        ask_rand = [random.randint(0, max_val) for _ in range(NUM_ELEMS)]
        best_bid = max(bid_rand)
        best_ask = min(ask_rand)
        expected_match = best_bid >= best_ask
        expected_price = best_ask if expected_match else 0
        tests.append({
            "description": f"Random stress test iteration {t+1}",
            "bid": bid_rand,
            "ask": ask_rand,
            "expected_match": expected_match,
            "expected_price": expected_price
        })

    # Iterate through each test case.
    for test in tests:
        dut._log.info("---------------------------------------------------")
        dut._log.info("Starting test: %s", test["description"])

        # Pack bid and ask orders.
        bid_flat = pack_vector(test["bid"], price_width)
        ask_flat = pack_vector(test["ask"], price_width)

        # Drive the inputs.
        dut.bid_orders.value = bid_flat
        dut.ask_orders.value = ask_flat

        # Apply a reset before starting the test.
        dut.rst.value = 1
        await RisingEdge(dut.clk)
        dut.rst.value = 0
        await RisingEdge(dut.clk)

        # Issue the start pulse.
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Measure latency.
        latency = await measure_latency()
        dut._log.info("Test '%s': Measured latency = %d cycles", test["description"], latency)
        assert latency == 21, f"Latency error in test '{test['description']}': expected 20 cycles, got {latency}"

        # Check DUT's latency_error signal.
        assert int(dut.latency_error.value) == 0, f"Latency error flag is asserted in test '{test['description']}'"

        # Retrieve matching outputs.
        match_valid = int(dut.match_valid.value)
        matched_price = int(dut.matched_price.value)

        # Compute expected matching result.
        expected_best_bid = max(test["bid"])
        expected_best_ask = min(test["ask"])
        if expected_best_bid >= expected_best_ask:
            exp_match_valid = 1
            exp_matched_price = expected_best_ask
        else:
            exp_match_valid = 0
            exp_matched_price = 0

        # Alternatively, use the test case provided expected values.
        exp_match_valid = 1 if test["expected_match"] else 0
        exp_matched_price = test["expected_price"]

        # Check matching result.
        assert match_valid == exp_match_valid, f"Test '{test['description']}' failed: Expected match_valid {exp_match_valid}, got {match_valid}"
        if match_valid:
            assert matched_price == exp_matched_price, f"Test '{test['description']}' failed: Expected matched_price {exp_matched_price}, got {matched_price}"

        dut._log.info("Test '%s' PASSED: Best bid = %d, Best ask = %d, Matched price = %d", 
                      test["description"], expected_best_bid, expected_best_ask, matched_price)

        # Wait a few cycles before the next test.
        await Timer(20, units="ns")

    dut._log.info("All tests passed.")
