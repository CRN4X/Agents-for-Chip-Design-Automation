import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

async def reset_dut(reset_n, duration_ns=10):
    reset_n.value = 0
    await Timer(duration_ns, units="ns")
    reset_n.value = 1
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")   

class ControlFSM:
   # State encoding (same as SystemVerilog FSM)
   CONTROL_CAPTURE = 0
   DATA_CAPTURE    = 1
   CALC_START      = 2
   CALC            = 3
   WAIT            = 4

   def __init__(self, nbw_cnt=8, nbw_wait=32):
        # Parameters
        self.NBW_CNT = nbw_cnt
        self.NBW_WAIT = nbw_wait

        # Inputs
        self.i_enable = 0
        self.i_subsampling = 0
        self.i_valid = 0
        self.i_calc_valid = 0
        self.i_calc_fail = 0
        self.i_wait = 0

        # Outputs
        self.o_subsampling = 0
        self.o_valid = 0
        self.o_start_calc = 0

        # Internal state
        self.state = self.CONTROL_CAPTURE
        self.next_state = self.CONTROL_CAPTURE
        self.cnt_ff = 0
        self.timecnt_ff = 0
        self.timecnt_ff0 = 0
        self.ctrl_en = 0
        self.subsampling_ff = 0
        self.timecnt_en = 0
        self.cnt_en = 0
        self.cnt_rstctrl = 0

   def tick(self, i_enable, i_subsampling, i_valid, i_calc_valid, i_calc_fail, i_wait):
        
        self.sequential()

        self.i_enable      = i_enable     
        self.i_subsampling = i_subsampling
        self.i_valid       = i_valid      
        self.i_calc_valid  = i_calc_valid 
        self.i_calc_fail   = i_calc_fail  
        self.i_wait        = i_wait       

        # Update state
        self.state = self.next_state

        # Next state logic
        if self.state == self.CONTROL_CAPTURE:
            self.next_state = self.DATA_CAPTURE if self.i_enable else self.CONTROL_CAPTURE
        elif self.state == self.DATA_CAPTURE:
            self.next_state = self.CALC_START if self.cnt_ff == 0 else self.DATA_CAPTURE
        elif self.state == self.CALC_START:
            self.next_state = self.CALC if self.cnt_ff == 0 else self.CALC_START
        elif self.state == self.CALC:
            if self.i_calc_fail:
                self.next_state = self.CONTROL_CAPTURE
            elif self.i_calc_valid:
                self.next_state = self.WAIT
            else:
                self.next_state = self.CALC
        elif self.state == self.WAIT:
            if not self.i_enable or self.timecnt_ff == 0:
                self.next_state = self.CONTROL_CAPTURE
            else:
                self.next_state = self.WAIT
        else:
            self.next_state = self.CONTROL_CAPTURE

        # Output logic based on current state
        if self.state == self.CONTROL_CAPTURE:
            self.o_start_calc = 0
            self.ctrl_en = self.i_enable
            self.cnt_rstctrl = 1
            self.cnt_en = 0
            self.timecnt_en = 0
        elif self.state == self.DATA_CAPTURE:
            self.o_start_calc = 0
            self.ctrl_en = 0
            self.cnt_rstctrl = 0
            self.cnt_en = self.i_valid
            self.timecnt_en = 0
        elif self.state == self.CALC_START:
            self.o_start_calc = 1
            self.ctrl_en = 0
            self.cnt_rstctrl = 0
            self.cnt_en = 1
            self.timecnt_en = 0
        elif self.state == self.CALC:
            self.o_start_calc = 0
            self.ctrl_en = 0
            self.cnt_rstctrl = 0
            self.cnt_en = 0
            self.timecnt_en = 0
        elif self.state == self.WAIT:
            self.o_start_calc = 0
            self.ctrl_en = 0
            self.cnt_rstctrl = 0
            self.cnt_en = 0
            self.timecnt_en = 1
        else:
            self.o_start_calc = 0
            self.ctrl_en = 0
            self.cnt_rstctrl = 0
            self.cnt_en = 0
            self.timecnt_en = 0

        self.o_valid = 1 if self.cnt_en and (self.state == self.DATA_CAPTURE) and (self.cnt_ff > 0) else 0

   def sequential(self):
        # Timeout counter logic
        if self.i_calc_valid and self.state == self.CALC:
            self.timecnt_ff = self.timecnt_ff0
        elif self.timecnt_en:
            self.timecnt_ff = max(0, self.timecnt_ff - 1)
            
        # General counter logic
        cnt_rstproc = (self.state == self.DATA_CAPTURE) and (self.cnt_ff == 0)
        if self.cnt_rstctrl:
            self.cnt_ff = 1 << (self.NBW_CNT - 1) if self.i_subsampling == 1 else 8
        elif cnt_rstproc:
            self.cnt_ff = (1 << 4) - 1  # NBW_CALCSTART = 4, so set to 0b1111
        elif self.cnt_en:
            self.cnt_ff = max(0, self.cnt_ff - 1)

        # Capture i_wait and i_subsampling during control
        if self.ctrl_en:
            self.timecnt_ff0 = self.i_wait
            self.subsampling_ff = self.i_subsampling
        # Assign outputs
        self.o_subsampling = self.subsampling_ff