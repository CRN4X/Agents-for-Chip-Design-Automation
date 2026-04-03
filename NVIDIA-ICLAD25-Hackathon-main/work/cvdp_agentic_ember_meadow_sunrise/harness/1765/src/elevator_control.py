import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge


FLOOR = cocotb.plusargs.get("N")

# Helper function to reset DUT
async def reset_dut(dut, duration_ns):
    dut.reset.value = 1
    await Timer(duration_ns, units="ns")
    dut.reset.value = 0
    await RisingEdge(dut.clk)

# Helper function to trigger a floor request
async def request_floor(dut, floor):
    #current_requests = int(dut.call_requests.value)  # Convert LogicArray to integer
    dut.call_requests.value =  (1 << floor)  # Perform bitwise OR
    await RisingEdge(dut.clk)
    dut.call_requests.value =  0

# Helper function to clear call requests
async def clear_requests(dut):
    dut.call_requests.value = 0
    await RisingEdge(dut.clk)


#Helper function to wait for door close
async def wait_door_close(dut):
    # Wait until the door closes
    dut._log.info("Waiting for the door to close")
    while dut.door_open.value == 1:
        await RisingEdge(dut.clk)

# Helper: Check direction LEDs during motion
async def check_direction_leds(dut, expected_direction):
    if expected_direction == "up":
        assert dut.up_led.value == 1, "up_led not active while moving up"
        assert dut.down_led.value == 0, "down_led should not be active while moving up"
    elif expected_direction == "down":
        assert dut.up_led.value == 0, "up_led should not be active while moving down"
        assert dut.down_led.value == 1, "down_led not active while moving down"

# Test case 1: Single floor request
async def test_case_1(dut):
    """Test case 1: Single floor request"""

    # Request floor 3 and check if the elevator reaches it
    dut._log.info("Requesting floor 3")
    await request_floor(dut, 3)

    #print("A Current Floor", dut.current_floor.value)

    # Wait and check if the elevator reaches floor 3
    while dut.current_floor.value != 3:
        await RisingEdge(dut.clk)
        #print("Current Floor", dut.current_floor.value)
    await RisingEdge(dut.clk)
    await Timer(30, units="ns")
    
    assert dut.door_open.value == 1, "Door did not open at requested floor"


    dut._log.info("Elevator reached floor 3 successfully")

    await wait_door_close(dut)

    dut._log.info("Door closed successfully after reaching floor")

# Test case 2: Multiple floor requests
async def test_case_2(dut):
    """Test case 2: Multiple floor requests"""

    FLOOR_SIZE = int(FLOOR)

    if(FLOOR_SIZE == 5):
        dut._log.info("Requesting floor 2,4")
        floor_list = [2,4]
        # Request floors 2, 4, and 6
        await request_floor(dut, 2)
        await request_floor(dut, 4)
    else:
        dut._log.info("Requesting floor 2,4,6")
        floor_list = [2,4,6]
        # Request floors 2, 4, and 6
        await request_floor(dut, 2)
        await request_floor(dut, 4)
        await request_floor(dut, 6)

    # Check if the elevator serves requests in sequence
    for expected_floor in floor_list:
        while dut.current_floor.value != expected_floor:
            await RisingEdge(dut.clk)
        #print("FLOOR",dut.current_floor.value)
        await Timer(30, units="ns")
        assert dut.door_open.value == 1, f"Door did not open at floor {expected_floor}"
        await Timer(10, units="ns")  # Simulate door open delay
        dut._log.info(f"Elevator reached floor {expected_floor}")
        await wait_door_close(dut)
        dut._log.info("Door closed successfully after reaching floor")

    dut._log.info("Elevator served multiple requests successfully")

# Test case 3: Emergency stop
async def test_case_3(dut):
    """Test case 3: Emergency stop"""

    # Request floor 5 and activate emergency stop midway
    dut._log.info("Requesting floor 4")
    await request_floor(dut, 4)
    await Timer(30, units="ns")  # Wait for some time during movement

    dut._log.info("Activating emergency stop")
    dut.emergency_stop.value = 1
    await RisingEdge(dut.clk)
    await Timer(30, units="ns")  # Wait for some time during movement
    assert dut.system_status.value == 3, "Elevator did not enter emergency halt state"
    dut._log.info("Elevator entered emergency halt state")

    # Deactivate emergency stop and check if elevator resumes operation
    dut.emergency_stop.value = 0
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")  # Wait for some time during movement    
    assert dut.system_status.value == 0, "Elevator did not return to idle after emergency stop"
    dut._log.info("Emergency stop cleared, elevator resumed operation")

# Test case 4: Reset during operation
async def test_case_4(dut):
    """Test case 4: Reset during operation"""

    # Request floor 4
    await request_floor(dut, 4)
    await Timer(20, units="ns")

    # Apply reset and check if elevator goes to idle
    dut._log.info("Applying reset during operation")
    await reset_dut(dut, 20)
    assert dut.current_floor.value == 0, "Elevator did not reset to ground floor"
    assert dut.system_status.value == 0, "Elevator did not return to idle after reset"
    dut._log.info("Reset applied successfully, elevator returned to idle")

# Test case 5: Overload handling
async def test_case_5(dut):
    """Test case 5: Elevator overload"""

    # Request a floor
    await request_floor(dut, 4)
    await Timer(20, units="ns")

    # Activate overload
    dut._log.info("Activating overload")
    dut.overload.value = 1

    await Timer(100, units="ns")

    # Ensure door is open, system is not moving, and overload LED is active
    assert dut.door_open.value == 1, "Door should be open during overload"
    assert dut.overload_led.value == 1, "Overload LED should be active during overload"
    assert dut.system_status.value != 1 and dut.system_status.value != 2, "Elevator should not be moving under overload"

    dut._log.info("Overload active: door open and elevator stationary")

    # Clear overload and wait for elevator to resume
    dut.overload.value = 0
    await Timer(50, units="ns")
    dut._log.info("Overload cleared")

    while dut.current_floor.value != 4:
        await RisingEdge(dut.clk)
        await check_direction_leds(dut, "up")

    await Timer(30, units="ns")
    assert dut.door_open.value == 1, "Door did not open after overload cleared"
    dut._log.info("Elevator reached requested floor after overload")
    await wait_door_close(dut)

    dut._log.info("Requesting floor 2 (downward motion)")
    await request_floor(dut, 2)
    await Timer(10, units="ns")

    await Timer(50, units="ns")

    while dut.current_floor.value != 2:
        await RisingEdge(dut.clk)
        await check_direction_leds(dut, "down")

    await Timer(30, units="ns")
    assert dut.door_open.value == 1, "Door did not open at floor 2"
    dut._log.info("Elevator resumed and reached floor 2 after overload")
    await wait_door_close(dut)


@cocotb.test()
async def test_elevator_control_system(dut):
    """Main test function for elevator control system"""

    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())

    # Initialize all signals to known values
    dut.reset.value = 0
    dut.call_requests.value = 0
    dut.emergency_stop.value = 0
    dut.overload.value = 0

    FLOOR_SIZE = int(FLOOR) - 1
    print("System FLOOR Size: 0 to", FLOOR_SIZE)

    ## Apply reset
    await reset_dut(dut, 30)

    ## Run test cases
    await test_case_1(dut)
    await Timer(20, units="ns")  # Wait before next test

    await test_case_2(dut)
    await Timer(20, units="ns")

    ## Apply reset
    await reset_dut(dut, 30)

    await test_case_3(dut)
    await Timer(20, units="ns")

    await test_case_4(dut)
    await Timer(20, units="ns")

    ## Apply reset
    await reset_dut(dut, 30)
    await test_case_5(dut)
