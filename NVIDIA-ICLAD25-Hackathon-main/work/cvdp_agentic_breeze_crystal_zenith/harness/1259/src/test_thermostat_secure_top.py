import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.clock import Clock

async def reset_dut(dut):
    """Reset the DUT"""

    dut.i_temp_feedback.value =0
    dut.i_fan_on.value =0
    dut.i_fault.value =0
    dut.i_clr.value =0
    dut.i_clk.value =0
    dut.i_rst.value =0
    dut.i_addr.value =0
    dut.i_data_in.value =0
    dut.i_read_write_enable.value =0
    dut.i_capture_pulse.value =0

    await FallingEdge(dut.i_clk)
    dut.i_rst.value = 1
    await RisingEdge(dut.i_clk)


def assert_equal(actual, expected, msg=""):
    """Custom assertion with message."""
    assert actual == expected, f"{msg}: Expected {expected}, but got {actual}"

@cocotb.test()
async def test_thermostat_secure_top(dut):
    """Testbench for thermostat FSM Verilog module."""

    # Setup clock: 10 ns period (100 MHz)
    clock = Clock(dut.i_clk, 10, units="ns")
    cocotb.start_soon(Clock(dut.i_capture_pulse, 20, units='ns').start())  # timeperiod= 20ns
    cocotb.start_soon(clock.start())
    await Timer(1, units="ns")
    # Reset the DUT
    await reset_dut(dut)

    # Check initial state after reset
    assert_equal(dut.o_state.value, 0b011, "FSM should initialize to AMBIENT state")
    assert_equal(dut.o_heater_full.value, 0, "Heater full output should be 0 after reset")
    assert_equal(dut.o_aircon_full.value, 0, "Aircon full output should be 0 after reset")
    assert_equal(dut.o_fan.value, 0, "Fan output should be 0 after reset")

    # Enable the thermostat and test state transitions
    await FallingEdge(dut.i_capture_pulse)  #stage one unlock
    dut.i_addr.value =0
    dut.i_data_in.value =171
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #stage two unlock
    dut.i_addr.value =1
    dut.i_data_in.value =205
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #unlocked
    dut.i_addr.value =2
    dut.i_data_in.value =0
    dut.i_read_write_enable.value =1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    # Test heating states
    dut.i_temp_feedback.value = 0b100000  # i_full_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b010, "FSM should transition to HEAT_FULL")
    assert_equal(dut.o_heater_full.value, 1, "Heater full output should be 1 in HEAT_FULL")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b010000  # i_medium_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b001, "FSM should transition to HEAT_MED")
    assert_equal(dut.o_heater_medium.value, 1, "Heater medium output should be 1 in HEAT_MED")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b001000  # i_low_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b000, "FSM should transition to HEAT_LOW")
    assert_equal(dut.o_heater_low.value, 1, "Heater low output should be 1 in HEAT_LOW")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    # Test cooling states
    dut.i_temp_feedback.value = 0b000001  # i_full_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b110, "FSM should transition to COOL_FULL")
    assert_equal(dut.o_aircon_full.value, 1, "Aircon full output should be 1 in COOL_FULL")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b000010  # i_medium_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b101, "FSM should transition to COOL_MED")
    assert_equal(dut.o_aircon_medium.value, 1, "Aircon medium output should be 1 in COOL_MED")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b000100  # i_low_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b100, "FSM should transition to COOL_LOW")
    assert_equal(dut.o_aircon_low.value, 1, "Aircon low output should be 1 in COOL_LOW")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    # Test ambient state
    dut.i_temp_feedback.value = 0b000000  # No temperature feedback
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b011, "FSM should transition to AMBIENT")
    assert_equal(dut.o_fan.value, 0, "Fan output should be 0 in AMBIENT")

    # Test fault handling
    dut.i_fault.value = 1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b011, "FSM should remain in AMBIENT during fault")
    assert_equal(dut.o_heater_full.value, 0, "All outputs should be 0 during fault")
    assert_equal(dut.o_aircon_full.value, 0, "All outputs should be 0 during fault")
    assert_equal(dut.o_fan.value, 0, "All outputs should be 0 during fault")

    # Clear fault
    dut.i_fault.value = 0
    dut.i_clr.value = 1
    await RisingEdge(dut.i_clk)
    dut.i_clr.value = 0
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b011, "FSM should transition back to AMBIENT after fault is cleared")

    ##wrong data write in address. 
    await FallingEdge(dut.i_capture_pulse)
    dut.i_addr.value =0
    dut.i_data_in.value =170
    dut.i_read_write_enable.value =0
    #locked,
    await FallingEdge(dut.i_capture_pulse)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    assert_equal(dut.o_state.value, 0b011, "FSM should remain in AMBIENT when disabled")
    assert_equal(dut.o_heater_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_aircon_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_fan.value, 0, "All outputs should be 0 when disabled")
    

    await reset_dut(dut)

    # Test disable functionality
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b011, "FSM should remain in AMBIENT when disabled")
    assert_equal(dut.o_heater_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_aircon_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_fan.value, 0, "All outputs should be 0 when disabled")

    dut.i_addr.value =0
    dut.i_data_in.value =170
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #in correct stage two unlock
    dut.i_addr.value =1
    dut.i_data_in.value =200
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #locked,

    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b011, "FSM should remain in AMBIENT when disabled")
    assert_equal(dut.o_heater_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_aircon_full.value, 0, "All outputs should be 0 when disabled")
    assert_equal(dut.o_fan.value, 0, "All outputs should be 0 when disabled")

    # Re-enable and verify transitions again
    # Enable the thermostat and test state transitions
    await FallingEdge(dut.i_capture_pulse)  #stage one unlock
    dut.i_addr.value =0
    dut.i_data_in.value =171
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #stage two unlock
    dut.i_addr.value =1
    dut.i_data_in.value =205
    dut.i_read_write_enable.value =0
    await FallingEdge(dut.i_capture_pulse) #unlocked
    dut.i_addr.value =2
    dut.i_data_in.value =0
    dut.i_read_write_enable.value =1
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)

    
    dut.i_temp_feedback.value = 0b100000  # i_full_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b010, "FSM should transition to HEAT_FULL after re-enabling")
    assert_equal(dut.o_heater_full.value, 1, "Heater full output should be 1 after re-enabling")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    # Test priority when multiple hot inputs are set
    dut.i_temp_feedback.value = 0b000101  # i_full_hot and i_low_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b110, "FSM should prioritize COOL_FULL when multiple hot inputs are set")
    assert_equal(dut.o_aircon_full.value, 1, "Aircon full output should be 1 in COOL_FULL")
    assert_equal(dut.o_aircon_low.value, 0, "Aircon low output should be 0 when COOL_FULL is prioritized")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b000110  # i_medium_hot and i_low_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b101, "FSM should prioritize COOL_MED when multiple hot inputs are set")
    assert_equal(dut.o_aircon_medium.value, 1, "Aircon medium output should be 1 in COOL_MED")
    assert_equal(dut.o_aircon_low.value, 0, "Aircon low output should be 0 when COOL_MED is prioritized")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b000111  # i_full_hot, i_medium_hot, and i_low_hot
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b110, "FSM should prioritize COOL_FULL over other hot inputs")
    assert_equal(dut.o_aircon_full.value, 1, "Aircon full output should be 1 in COOL_FULL")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    # Test priority when multiple cold inputs are set
    dut.i_temp_feedback.value = 0b101000  # i_full_cold and i_low_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b010, "FSM should prioritize HEAT_FULL when multiple cold inputs are set")
    assert_equal(dut.o_heater_full.value, 1, "Heater full output should be 1 in HEAT_FULL")
    assert_equal(dut.o_heater_low.value, 0, "Heater low output should be 0 when HEAT_FULL is prioritized")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b011000  # i_medium_cold and i_low_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b001, "FSM should prioritize HEAT_MED when multiple cold inputs are set")
    assert_equal(dut.o_heater_medium.value, 1, "Heater medium output should be 1 in HEAT_MED")
    assert_equal(dut.o_heater_low.value, 0, "Heater low output should be 0 when HEAT_MED is prioritized")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")

    dut.i_temp_feedback.value = 0b111000  # i_full_cold, i_medium_cold, and i_low_cold
    await RisingEdge(dut.i_clk)
    await RisingEdge(dut.i_clk)
    await Timer(1, units="ns")
    assert_equal(dut.o_state.value, 0b010, "FSM should prioritize HEAT_FULL over other cold inputs")
    assert_equal(dut.o_heater_full.value, 1, "Heater full output should be 1 in HEAT_FULL")
    assert_equal(dut.o_fan.value, 1, "Fan output should be 1")
