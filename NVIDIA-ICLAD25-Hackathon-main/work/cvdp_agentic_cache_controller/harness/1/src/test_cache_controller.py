import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_cache_controller(dut):
  clock = Clock(dut.clk, 10, units="ns")
  cocotb.start_soon(clock.start())

  dut.reset.value = 1
  await RisingEdge(dut.clk)
  dut.reset.value = 0

  # Test case 1: Read miss
  dut.address.value = 0x01
  dut.read.value = 1
  dut.mem_read_data.value = 0xDEADBEEF
  dut.mem_ready.value = 1
  await RisingEdge(dut.clk)
  dut.read.value = 0
  await Timer(20, units="ns")
  assert dut.read_data.value == 0xDEADBEEF, "Failed for read miss"

  # Test case 2: Write hit
  dut.address.value = 0x01
  dut.write.value = 1
  dut.write_data.value = 0xCAFEBABE
  await RisingEdge(dut.clk)
  dut.write.value = 0
  await Timer(20, units="ns")
  assert dut.hit.value == 1, "Failed for write hit"

  # Test case 3: Read hit
  dut.address.value = 0x01
  dut.read.value = 1
  await RisingEdge(dut.clk)
  dut.read.value = 0
  await Timer(20, units="ns")
  assert dut.read_data.value == 0xCAFEBABE, "Failed for read hit"

  cocotb.log.info("Cache controller tests passed!")