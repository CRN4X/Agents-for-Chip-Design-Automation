import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from collections import deque

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

class EventArray:
    def __init__(self, NS_ROWS=4, NS_COLS=4, NBW_STR=8, NS_EVT=8):
        self.NS_ROWS = NS_ROWS
        self.NS_COLS = NS_COLS
        self.NBW_STR = NBW_STR
        self.NS_EVT  = NS_EVT
        self.reset()

    def reset(self):
        self.reg_bank = [[[0 for _ in range(self.NS_EVT)]
                          for _ in range(self.NS_COLS)]
                         for _ in range(self.NS_ROWS)]
        self.o_data = 0

    def event_update(self, i_event, i_en_overflow):
        total_bits = self.NS_ROWS * self.NS_COLS * self.NS_EVT
        bin_event = bin(i_event)[2:].zfill(total_bits)  # MSB-first

        MAX_VAL = (1 << self.NBW_STR) - 1

        byte_index = 0
        for row in range(self.NS_ROWS):
            for col in range(self.NS_COLS):
                # Calculate flat index for this (row, col)
                flat_index = row * self.NS_COLS + col
                overflow_en = (i_en_overflow >> (flat_index)) & 1

                for evt in range(self.NS_EVT):
                    bit_index = byte_index * self.NS_EVT + evt
                    if bin_event[bit_index] == '1':
                        current_val = self.reg_bank[row][col][self.NS_EVT - 1 - evt]
                        if overflow_en:
                            self.reg_bank[row][col][self.NS_EVT - 1 - evt] = (current_val + 1) & MAX_VAL
                        else:
                            if current_val < MAX_VAL:
                                self.reg_bank[row][col][self.NS_EVT - 1 - evt] += 1
                byte_index += 1


    def read_data(self, bypass, r_addr, col_sel, i_data):
        # Convert i_data to array of NBW_STR slices (MSB to LSB)
        array_i_data = []
        mask = (1 << self.NBW_STR) - 1
        for i in range(self.NS_COLS):
            shift = self.NBW_STR * (self.NS_COLS - 1 - i)
            array_i_data.append((i_data >> shift) & mask)

        selected_row = None

        # Priority decoder tree: walk MSB → LSB, match original behavior
        for row in range(self.NS_ROWS):
            bit = (bypass >> (self.NS_ROWS - 1 - row)) & 1
            if bit == 0:
                selected_row = self.NS_ROWS - 1 - row
                break

        # All bypass bits = 1 → use i_data
        if selected_row is None:
            out_row = array_i_data
        else:
            out_row = [self.reg_bank[selected_row][i][r_addr] for i in range(self.NS_COLS)]

        self.o_data = out_row[col_sel]
