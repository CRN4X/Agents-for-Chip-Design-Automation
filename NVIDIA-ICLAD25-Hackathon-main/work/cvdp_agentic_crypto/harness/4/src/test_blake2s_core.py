
import cocotb
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.triggers import FallingEdge
import harness_library as hrs_lb
import os


@cocotb.test()
async def test_assert_reset_result(dut):
    if os.getenv("SELECTION") != 'reset':
        return

    cocotb.log.setLevel("DEBUG")
    cocotb.log.info("Starting test_assert_ready_after_reset...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    cocotb.log.info("All tests passed.")

@cocotb.test()
async def test_get_ready_after_init(dut):
    if os.getenv("SELECTION") != 'init_ready':
        return

    cocotb.log.setLevel("DEBUG")
    cocotb.log.info("Starting test_get_ready_after_init...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    await hrs_lb.ready_after_init(dut)

    await FallingEdge(dut.clk)

    cocotb.log.info("All tests passed.")

@cocotb.test()
async def test_finish_operation_asserts(dut):
    if os.getenv("SELECTION") != 'finish':
        return

    """Main test function to call all tests."""
    cocotb.log.setLevel("DEBUG")
    cocotb.log.info("Starting test_finish_operation_asserts...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    # Empty message test (Test Case 0):
    empty_expected_digest = int('69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9', 16)
    empty_block_bin = BinaryValue(0, 512, False)
    empty_block_len_bin = BinaryValue(0, 7, False)
    empty_expected_digest_bin = BinaryValue(empty_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, empty_block_len_bin, empty_block_bin, empty_expected_digest_bin)

    # Test Case 1:
    # tb_block = 512'h00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f;
    # tb_blocklen = 7'h40;
    # dut.digest == 256'h56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e
    tc1_block = int('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f', 16)
    tc1_block_len = int('40', 16)
    tc1_expected_digest = int('56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e', 16)
    tc1_block_bin = BinaryValue(tc1_block, 512, False)
    tc1_block_len_bin = BinaryValue(tc1_block_len, 7, False)
    tc1_expected_digest_bin = BinaryValue(tc1_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, tc1_block_len_bin, tc1_block_bin, tc1_expected_digest_bin)

    # # Test Case 2:
    # # tb_block = 512'h00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f;
    # # tb_blocklen = 7'h40;
    # # tb_block = {8'h40, {63{8'h00}}};
    # # tb_blocklen = 7'h01;
    # tc2_block0 = int('00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f'.replace('_',''), 16)
    # tc2_block0_len = int('40', 16)
    # tc2_block1 = int('40' + (63 * '00'), 16)
    # tc2_block1_len = 1
    # tc2_expected_digest = int('1b53ee94aaf34e4b159d48de352c7f0661d0a40edff95a0b1639b4090e974472', 16)
    # tc2_block_bin = [
    #     BinaryValue(tc2_block0, 512, False),
    #     BinaryValue(tc2_block1, 512, False)
    # ]
    # tc2_block_len_bin = [
    #     BinaryValue(tc2_block0_len, 7, False),
    #     BinaryValue(tc2_block1_len, 7, False)
    # ]
    # tc2_expected_digest_bin = BinaryValue(tc2_expected_digest, 256, False)
    # await hrs_lb.multiple_block_message_test(dut, tc2_block_len_bin, tc2_block_bin, tc2_expected_digest_bin)

    # Test Case 3:
    # tb_block = {32'h61626300, {15{32'h0}}};
    # tb_blocklen = 7'h03;
    # tb_digest == 256'h508c5e8c327c14e2_e1a72ba34eeb452f_37458b209ed63a29_4d999b4c86675982
    tc3_block = int('61626300' + (15 * 8 * '0'), 16)
    tc3_block_len = int('03', 16)
    tc3_expected_digest = int('508c5e8c327c14e2_e1a72ba34eeb452f_37458b209ed63a29_4d999b4c86675982'.replace('_', ''), 16)
    tc3_block_bin = BinaryValue(tc3_block, 512, False)
    tc3_block_len_bin = BinaryValue(tc3_block_len, 7, False)
    tc3_expected_digest_bin = BinaryValue(tc3_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, tc3_block_len_bin, tc3_block_bin, tc3_expected_digest_bin)

    cocotb.log.info("All tests passed.")


@cocotb.test()
async def test_update_operation_asserts(dut):
    if os.getenv("SELECTION") != 'update':
        return

    """Main test function to call all tests."""
    cocotb.log.setLevel("DEBUG")
    cocotb.log.info("Starting test_dut...")

    await hrs_lb.dut_init(dut)
    await cocotb.start(Clock(dut.clk, hrs_lb.CLK_PERIOD, units=hrs_lb.CLK_TIME_UNIT).start(start_high=False))

    await hrs_lb.init_sim(dut)
    await hrs_lb.reset_dut(dut)

    # Empty message test (Test Case 0):
    empty_expected_digest = int('69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9', 16)
    empty_block_bin = BinaryValue(0, 512, False)
    empty_block_len_bin = BinaryValue(0, 7, False)
    empty_expected_digest_bin = BinaryValue(empty_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, empty_block_len_bin, empty_block_bin, empty_expected_digest_bin)

    # Test Case 1:
    # tb_block = 512'h00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f;
    # tb_blocklen = 7'h40;
    # dut.digest == 256'h56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e
    tc1_block = int('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f', 16)
    tc1_block_len = int('40', 16)
    tc1_expected_digest = int('56f34e8b96557e90c1f24b52d0c89d51086acf1b00f634cf1dde9233b8eaaa3e', 16)
    tc1_block_bin = BinaryValue(tc1_block, 512, False)
    tc1_block_len_bin = BinaryValue(tc1_block_len, 7, False)
    tc1_expected_digest_bin = BinaryValue(tc1_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, tc1_block_len_bin, tc1_block_bin, tc1_expected_digest_bin)

    # Test Case 2:
    # tb_block = 512'h00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f;
    # tb_blocklen = 7'h40;
    # tb_block = {8'h40, {63{8'h00}}};
    # tb_blocklen = 7'h01;
    tc2_block0 = int('00010203_04050607_08090a0b_0c0d0e0f_10111213_14151617_18191a1b_1c1d1e1f_20212223_24252627_28292a2b_2c2d2e2f_30313233_34353637_38393a3b_3c3d3e3f'.replace('_',''), 16)
    tc2_block0_len = int('40', 16)
    tc2_block1 = int('40' + (63 * '00'), 16)
    tc2_block1_len = 1
    tc2_expected_digest = int('1b53ee94aaf34e4b159d48de352c7f0661d0a40edff95a0b1639b4090e974472', 16)
    tc2_block_bin = [
        BinaryValue(tc2_block0, 512, False),
        BinaryValue(tc2_block1, 512, False)
    ]
    tc2_block_len_bin = [
        BinaryValue(tc2_block0_len, 7, False),
        BinaryValue(tc2_block1_len, 7, False)
    ]
    tc2_expected_digest_bin = BinaryValue(tc2_expected_digest, 256, False)
    await hrs_lb.multiple_block_message_test(dut, tc2_block_len_bin, tc2_block_bin, tc2_expected_digest_bin)

    # Test Case 3:
    # tb_block = {32'h61626300, {15{32'h0}}};
    # tb_blocklen = 7'h03;
    # tb_digest == 256'h508c5e8c327c14e2_e1a72ba34eeb452f_37458b209ed63a29_4d999b4c86675982
    tc3_block = int('61626300' + (15 * 8 * '0'), 16)
    tc3_block_len = int('03', 16)
    tc3_expected_digest = int('508c5e8c327c14e2_e1a72ba34eeb452f_37458b209ed63a29_4d999b4c86675982'.replace('_', ''), 16)
    tc3_block_bin = BinaryValue(tc3_block, 512, False)
    tc3_block_len_bin = BinaryValue(tc3_block_len, 7, False)
    tc3_expected_digest_bin = BinaryValue(tc3_expected_digest, 256, False)
    await hrs_lb.one_block_message_test(dut, tc3_block_len_bin, tc3_block_bin, tc3_expected_digest_bin)

    cocotb.log.info("All tests passed.")
