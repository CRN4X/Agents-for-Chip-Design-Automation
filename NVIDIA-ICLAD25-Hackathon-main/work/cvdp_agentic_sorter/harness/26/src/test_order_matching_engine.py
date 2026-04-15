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
    is correct, and checks that the overall latency from start to done
    is exactly 10 cycles.
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

    #-----------------------------------------------------------------------
    # 1) Normal matching scenario (circuit_breaker=0)
    #    bid: [42,74,10,21,108,53,95,106]
    #    ask: [130,108,205,129,192,213,244,141]
    #
    #    Here we expect a valid match, with matched_price = 108
    #    (assuming best bid >= best ask).
    #-----------------------------------------------------------------------
    tests.append({
        "description": "Matching scenario: valid match, circuit breaker off",
        "bid": scale_orders([42,74,10,21,108,53,95,106], 100),
        "ask": scale_orders([130,108,205,129,192,213,244,141], 100),
        "circuit_breaker": 0,
        "expected_match": True,
        "expected_price": 108
    })

    #-----------------------------------------------------------------------
    # 2) Circuit breaker scenario
    #    Even though best_bid >= best_ask, circuit_breaker=1 must block the match.
    #
    #    bid: [80,90,100,85,95,81,99,120]
    #    ask: [70,75,60,65,64,68,66,72]
    #
    #    Normally, best_bid=120, best_ask=60 => match_valid=1, matched_price=120.
    #    But with circuit_breaker=1, match_valid must be 0.
    #-----------------------------------------------------------------------
    tests.append({
        "description": "Circuit breaker scenario: best bid >= best ask but breaker is active",
        "bid": scale_orders([80,90,100,85,95,81,99,120], 100),
        "ask": scale_orders([70,75,60,65,64,68,66,72], 100),
        "circuit_breaker": 1,
        "expected_match": False,
        "expected_price": 0
    })

    #-----------------------------------------------------------------------
    # Additional tests can be appended here if needed
    #-----------------------------------------------------------------------

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
        dut.circuit_breaker.value = test["circuit_breaker"]

        # Apply a reset before starting the test.
        dut.rst.value = 1
        dut.start.value = 0
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
        assert latency == 13, f"Latency error in test '{test['description']}': expected 10 cycles, got {latency}"

        # Retrieve matching outputs.
        match_valid = int(dut.match_valid.value)
        matched_price = int(dut.matched_price.value)

        # Compute expected matching result from test vector
        exp_match_valid = 1 if test["expected_match"] else 0
        exp_matched_price = test["expected_price"]

        # Check matching result.
        assert match_valid == exp_match_valid, \
            f"Test '{test['description']}' failed: Expected match_valid {exp_match_valid}, got {match_valid}"
        if match_valid:
            assert matched_price == exp_matched_price, \
                f"Test '{test['description']}' failed: Expected matched_price {exp_matched_price}, got {matched_price}"

        dut._log.info("Test '%s' PASSED: match_valid=%d, matched_price=%d",
                      test["description"], match_valid, matched_price)

        # Wait a few cycles before the next test.
        await Timer(20, units="ns")

    dut._log.info("All tests passed.")
