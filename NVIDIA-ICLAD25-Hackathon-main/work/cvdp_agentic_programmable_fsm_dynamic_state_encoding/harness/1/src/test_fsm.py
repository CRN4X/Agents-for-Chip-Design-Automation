import cocotb
from cocotb.triggers import Timer

async def clock_gen(dut):
    """Simple clock generator: toggles every 5 ns (10 ns period)."""
    while True:
        dut.clk.value = 0
        await Timer(5, units="ns")
        dut.clk.value = 1
        await Timer(5, units="ns")

@cocotb.test()
async def fsm_test(dut):
    """Cocotb testbench for dynamic FSM with assertions mimicking the provided SV testbench."""
    # Start the clock generator.
    cocotb.start_soon(clock_gen(dut))
    
    # Initialize configuration maps.
    # The state map packs 8 entries (state0..state7) of 8 bits each.
    # For example: state0 = 0x10, state1 = 0x20, ..., state7 = 0x80.
    dut.config_state_map_flat.value = 0x8070605040302010

    # For the transition map: 16 entries (8 bits each) for state 0.
    # Rightmost (element0): input_signal==0 => 0.
    # Element4 is set to 8 (invalid, to trigger error) and the rest are 0.
    # This 128-bit constant is represented in hexadecimal.
    dut.config_transition_map_flat.value = int("00000000000000000000000800000000", 16)
    
    # Apply reset: drive reset high for 12 ns, then low.
    dut.reset.value = 1
    dut.input_signal.value = 0
    await Timer(12, units="ns")
    dut.reset.value = 0
    await Timer(10, units="ns")
    
    # Test with input_signal = 1.
    dut.input_signal.value = 1
    await Timer(10, units="ns")
    dut._log.info(
        f"Test 1: encoded_state = {dut.encoded_state.value.to_unsigned():02x}, "
        f"dynamic_encoded_state = {dut.dynamic_encoded_state.value.to_unsigned():02x}, "
        f"error_flag = {dut.error_flag.value.to_unsigned()}, "
        f"operation_result = {dut.operation_result.value.to_unsigned()}"
    )
    # Assertions for Test 1.
    assert dut.encoded_state.value.to_unsigned() == 0x10, \
        f"Test 1: Expected encoded_state 0x10, got {dut.encoded_state.value.to_unsigned():02x}"
    assert dut.dynamic_encoded_state.value.to_unsigned() == 0x11, \
        f"Test 1: Expected dynamic_encoded_state 0x11, got {dut.dynamic_encoded_state.value.to_unsigned():02x}"
    assert dut.error_flag.value.to_unsigned() == 0, \
        f"Test 1: Expected error_flag 0, got {dut.error_flag.value.to_unsigned()}"
    assert dut.operation_result.value.to_unsigned() == 17, \
        f"Test 1: Expected operation_result 17, got {dut.operation_result.value.to_unsigned()}"
    
    # Test with input_signal = 2.
    dut.input_signal.value = 2
    await Timer(10, units="ns")
    dut._log.info(
        f"Test 2: encoded_state = {dut.encoded_state.value.to_unsigned():02x}, "
        f"dynamic_encoded_state = {dut.dynamic_encoded_state.value.to_unsigned():02x}, "
        f"error_flag = {dut.error_flag.value.to_unsigned()}, "
        f"operation_result = {dut.operation_result.value.to_unsigned()}"
    )
    # Assertions for Test 2.
    assert dut.encoded_state.value.to_unsigned() == 0x10, \
        f"Test 2: Expected encoded_state 0x10, got {dut.encoded_state.value.to_unsigned():02x}"
    assert dut.dynamic_encoded_state.value.to_unsigned() == 0x12, \
        f"Test 2: Expected dynamic_encoded_state 0x12, got {dut.dynamic_encoded_state.value.to_unsigned():02x}"
    assert dut.error_flag.value.to_unsigned() == 0, \
        f"Test 2: Expected error_flag 0, got {dut.error_flag.value.to_unsigned()}"
    assert dut.operation_result.value.to_unsigned() == 18, \
        f"Test 2: Expected operation_result 18, got {dut.operation_result.value.to_unsigned()}"
    
    # Test with input_signal = 3.
    dut.input_signal.value = 3
    await Timer(10, units="ns")
    dut._log.info(
        f"Test 3: encoded_state = {dut.encoded_state.value.to_unsigned():02x}, "
        f"dynamic_encoded_state = {dut.dynamic_encoded_state.value.to_unsigned():02x}, "
        f"error_flag = {dut.error_flag.value.to_unsigned()}, "
        f"operation_result = {dut.operation_result.value.to_unsigned()}"
    )
    # Assertions for Test 3.
    assert dut.encoded_state.value.to_unsigned() == 0x10, \
        f"Test 3: Expected encoded_state 0x10, got {dut.encoded_state.value.to_unsigned():02x}"
    assert dut.dynamic_encoded_state.value.to_unsigned() == 0x13, \
        f"Test 3: Expected dynamic_encoded_state 0x13, got {dut.dynamic_encoded_state.value.to_unsigned():02x}"
    assert dut.error_flag.value.to_unsigned() == 0, \
        f"Test 3: Expected error_flag 0, got {dut.error_flag.value.to_unsigned()}"
    assert dut.operation_result.value.to_unsigned() == 19, \
        f"Test 3: Expected operation_result 19, got {dut.operation_result.value.to_unsigned()}"
    
    # Test error condition with input_signal = 4.
    dut.input_signal.value = 4
    await Timer(10, units="ns")
    dut._log.info(
        f"Test 4 (error): encoded_state = {dut.encoded_state.value.to_unsigned():02x}, "
        f"dynamic_encoded_state = {dut.dynamic_encoded_state.value.to_unsigned():02x}, "
        f"error_flag = {dut.error_flag.value.to_unsigned()}, "
        f"operation_result = {dut.operation_result.value.to_unsigned()}"
    )
    # Assertions for Test 4.
    assert dut.encoded_state.value.to_unsigned() == 0x10, \
        f"Test 4: Expected encoded_state 0x10, got {dut.encoded_state.value.to_unsigned():02x}"
    assert dut.dynamic_encoded_state.value.to_unsigned() == 0x14, \
        f"Test 4: Expected dynamic_encoded_state 0x14, got {dut.dynamic_encoded_state.value.to_unsigned():02x}"
    assert dut.error_flag.value.to_unsigned() == 1, \
        f"Test 4: Expected error_flag 1, got {dut.error_flag.value.to_unsigned()}"
    assert dut.operation_result.value.to_unsigned() == 20, \
        f"Test 4: Expected operation_result 20, got {dut.operation_result.value.to_unsigned()}"
    
    # Return to a valid input: input_signal = 0.
    dut.input_signal.value = 0
    await Timer(10, units="ns")
    dut._log.info(
        f"Test 5: encoded_state = {dut.encoded_state.value.to_unsigned():02x}, "
        f"dynamic_encoded_state = {dut.dynamic_encoded_state.value.to_unsigned():02x}, "
        f"error_flag = {dut.error_flag.value.to_unsigned()}, "
        f"operation_result = {dut.operation_result.value.to_unsigned()}"
    )
    # Assertions for Test 5.
    assert dut.encoded_state.value.to_unsigned() == 0x10, \
        f"Test 5: Expected encoded_state 0x10, got {dut.encoded_state.value.to_unsigned():02x}"
    assert dut.dynamic_encoded_state.value.to_unsigned() == 0x10, \
        f"Test 5: Expected dynamic_encoded_state 0x10, got {dut.dynamic_encoded_state.value.to_unsigned():02x}"
    assert dut.error_flag.value.to_unsigned() == 0, \
        f"Test 5: Expected error_flag 0, got {dut.error_flag.value.to_unsigned()}"
    assert dut.operation_result.value.to_unsigned() == 16, \
        f"Test 5: Expected operation_result 16, got {dut.operation_result.value.to_unsigned()}"

