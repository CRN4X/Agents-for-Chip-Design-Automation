import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, Timer
import random
import time
import harness_library as hrs_lb

@cocotb.test()
async def test_axis_broadcast(dut):
    # Seed the random number generator with the current time or another unique value
    random.seed(time.time())
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 5, units='ns').start())
    
    await hrs_lb.dut_init(dut)
    
    


    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await FallingEdge(dut.clk)
    dut.rst_n.value = 0
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    assert dut.m_axis_tdata_1.value == 0, f"[ERROR] m_axis_tdata_1 value is : {dut.m_axis_tdata_1.value}"
    print(f'reset successful ')
    


    await FallingEdge(dut.clk)
    dut.s_axis_tdata.value = 0xA5
    dut.s_axis_tvalid.value = 1
    dut.m_axis_tready_1.value = 1
    dut.m_axis_tready_2.value = 1
    dut.m_axis_tready_3.value = 1
    await FallingEdge(dut.clk)
    dut.s_axis_tdata.value = 0x5A
    dut.s_axis_tvalid.value = 1
    dut.m_axis_tready_1.value = 0   ##one master is not ready so in next cycle previous data should be sent
    dut.m_axis_tready_2.value = 1
    dut.m_axis_tready_3.value = 1

    assert dut.m_axis_tdata_1.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_1.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_2.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_2.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_3.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_3.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    await FallingEdge(dut.clk)
    dut.s_axis_tdata.value = 0x5B
    dut.s_axis_tvalid.value = 1
    dut.m_axis_tready_1.value = 1
    dut.m_axis_tready_2.value = 1
    dut.m_axis_tready_3.value = 1
    print(f' previous data should be sent as one master is not ready')
    assert dut.m_axis_tdata_1.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_1.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_2.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_2.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_3.value == 0xA5, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_3.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"
    print(f' previous data received successfully')
    await FallingEdge(dut.clk)
    dut.s_axis_tdata.value = 0x5B
    dut.s_axis_tvalid.value = 1
    dut.m_axis_tready_1.value = 1
    dut.m_axis_tready_2.value = 1
    dut.m_axis_tready_3.value = 1

    assert dut.m_axis_tdata_1.value == 0x5A, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_1.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_2.value == 0x5A, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_2.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_3.value == 0x5A, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_3.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"
    print(f' received data should be from the cycle where master is not ready')
    await FallingEdge(dut.clk)

    assert dut.m_axis_tdata_1.value == 0x5B, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_1.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_2.value == 0x5B, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_2.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"

    assert dut.m_axis_tdata_3.value == 0x5B, f"[ERROR] m_axis_tdata value is : {dut.m_axis_tdata.value}"
    assert dut.m_axis_tvalid_3.value == 1, f"[ERROR] m_axis_tvalid value is : {dut.m_axis_tvalid.value}"
    
    



    
    print(f' tested successfully')
    