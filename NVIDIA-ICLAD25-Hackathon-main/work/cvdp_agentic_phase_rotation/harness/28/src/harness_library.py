import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
import random
import math

async def dut_init(dut):
    # iterate all the input signals and initialize with 0
    for signal in dut:
        if signal._type == "GPI_NET":
            signal.value = 0

# Reset the DUT (design under test)
async def reset_dut(reset_n, duration_ns=10):
    reset_n.value = 0
    await Timer(duration_ns, units="ns")
    reset_n.value = 1
    await Timer(duration_ns, units='ns')
    reset_n._log.debug("Reset complete")   

def check_instances(dut):
    assert hasattr(dut, 'uu_cross_correlation'), "Module cross_correlation does not exist"
    assert hasattr(dut.uu_cross_correlation, 'uu_adder_2d_layers'), "Module adder_2d_layers does not exist"
    assert hasattr(dut.uu_cross_correlation, 'uu_correlate'), "Module correlate does not exist"
    assert hasattr(dut.uu_cross_correlation.uu_adder_2d_layers, 'uu_sum_corr_i'), "Module uu_sum_corr_i does not exist"
    assert hasattr(dut.uu_cross_correlation.uu_adder_2d_layers, 'uu_sum_corr_q'), "Module uu_sum_corr_q does not exist"    

class detect_sequence:
    def __init__(self, ns = 64, nbw_pilot_pos = 6, nbw_data_symb = 8, nbw_th_proc = 8, nbw_energy = 10, ns_proc = 23, ns_proc_overlap = 22):
        self.ns = ns
        self.nbw_pilot_pos = nbw_pilot_pos
        self.nbw_data_symb = nbw_data_symb
        self.nbw_th_proc = nbw_th_proc
        self.nbw_energy = nbw_energy
        self.ns_proc_overlap = ns_proc_overlap
        self.ns_proc = ns_proc
        self.pipe_depth = 4
        self.proc_enable_dff = self.pipe_depth * [0]
        self.proc_buffer_i_dff = self.ns_proc * [0]
        self.proc_buffer_q_dff = self.ns_proc * [0]
        self.i_data_i_2d_delayed = (self.ns + self.ns_proc_overlap) * [0]
        self.i_data_q_2d_delayed = (self.ns + self.ns_proc_overlap) * [0]
        self.i_proc_pos_delayed = 0
        self.proc_buffer_i_dff_delayed_2 = self.ns_proc * [0]
        self.proc_buffer_q_dff_delayed_2 = self.ns_proc * [0]                
        self.proc_detected = 0
        self.proc_detected_dff = 0
        self.proc_pol_dff = 0
        self.proc_pol_dff_delayed = 0
        self.conj_proc_h_1 = 0b11011001100011010001110
        self.conj_proc_v_1 = 0b10000101011110000101011
        self.conj_proc_h_0 = 0b10101010111011101000000
        self.conj_proc_v_0 = 0b11010110101100100001110        
        self.conj_proc_0 = 0 
        self.conj_proc_1 = 0

        N_ADDER_LEVELS = math.ceil(math.log2(self.ns_proc))
        NBW_ADDER_TREE_IN = self.nbw_data_symb + 2
        NBW_ADDER_TREE_OUT = NBW_ADDER_TREE_IN + N_ADDER_LEVELS

        self.proc_processor = FawSymbolProcessor(
            ns_data_in=self.ns_proc,
            nbw_adder_tree_out=NBW_ADDER_TREE_OUT,
            nbw_energy=nbw_energy
        )

    def insert_data_and_process(self, i_valid, i_enable, i_proc_pol, i_proc_pos, i_static_threshold, i_data_i_2d, i_data_q_2d):
        print(f"using function insert_data_and_process")
        self.proc_enable = i_valid & i_enable
        for i in reversed(range(self.pipe_depth-1)):
            self.proc_enable_dff[i+1] = self.proc_enable_dff[i]
        self.proc_enable_dff[0] = self.proc_enable

        self.proc_buffer_i_dff_delayed = self.proc_buffer_i_dff
        self.proc_buffer_q_dff_delayed = self.proc_buffer_q_dff
        self.proc_pol_dff_delayed = self.proc_pol_dff

        for i in range(self.ns_proc):
            self.proc_buffer_i_dff[i] = self.i_data_i_2d_delayed[self.i_proc_pos_delayed+i]
            self.proc_buffer_q_dff[i] = self.i_data_q_2d_delayed[self.i_proc_pos_delayed+i]
        if self.proc_enable:
            self.proc_pol_dff = i_proc_pol
            self.i_proc_pos_delayed = i_proc_pos
            self.i_data_i_2d_delayed = i_data_i_2d
            self.i_data_q_2d_delayed = i_data_q_2d


        if self.proc_pol_dff_delayed:
            self.conj_proc_0 = self.conj_proc_v_0
            self.conj_proc_1 = self.conj_proc_v_1
        else:
            self.conj_proc_0 = self.conj_proc_h_0
            self.conj_proc_1 = self.conj_proc_h_1  

        sum_i, sum_q = self.proc_processor.process(
            i_enable=self.proc_enable_dff[1],
            i_conj_seq_i_int=self.conj_proc_0,
            i_conj_seq_q_int=self.conj_proc_1,
            i_data_i_2d=self.proc_buffer_i_dff_delayed,
            i_data_q_2d=self.proc_buffer_q_dff_delayed
        )

        self.proc_detected_dff = self.proc_detected
        if self.proc_processor.o_energy_delayed >= i_static_threshold:
            self.proc_detected = 1  & self.proc_enable_dff[3]
        else:
            self.proc_detected = 0                

class FawSymbolProcessor:
    def __init__(self, ns_data_in, nbw_adder_tree_out, nbw_energy):
        self.ns_data_in = ns_data_in
        self.nbw_adder_tree_out = nbw_adder_tree_out
        self.nbw_energy = nbw_energy
        self.energy_i_delayed = 0 
        self.energy_q_delayed = 0 
        self.energy_delayed   = 0 
        self.o_energy_delayed = 0
        self.energy_i = 0 
        self.energy_q = 0 
        self.energy   = 0 
        self.o_energy = 0
        self.model_sum_all_i = 0
        self.model_sum_all_q = 0

    def _int_to_bit_list(self, value):
        return [(value >> i) & 1 for i in range(self.ns_data_in)]
    
    def process(self, i_enable, i_conj_seq_i_int, i_conj_seq_q_int, i_data_i_2d, i_data_q_2d):
        i_enable_0 = i_enable & 1
        #i_enable_1 = (i_enable >> 1) & 1

        i_conj_seq_i = self._int_to_bit_list(i_conj_seq_i_int)
        i_conj_seq_q = self._int_to_bit_list(i_conj_seq_q_int)

        assert len(i_data_i_2d) == self.ns_data_in
        assert len(i_data_q_2d) == self.ns_data_in
        sum_i = []
        sum_q = []

        for i in range(self.ns_data_in):
            signal_seq_i = i_conj_seq_i[i]
            signal_seq_q = i_conj_seq_q[i]

            add = i_data_i_2d[i] + i_data_q_2d[i]
            sub = i_data_i_2d[i] - i_data_q_2d[i]

            selector = (signal_seq_i << 1) | signal_seq_q
            if selector == 0b00:
                sum_i.append(sub)
                sum_q.append(add)
            elif selector == 0b01:
                sum_i.append(add)
                sum_q.append(-sub)
            elif selector == 0b10:
                sum_i.append(-add)
                sum_q.append(sub)
            elif selector == 0b11:
                sum_i.append(-sub)
                sum_q.append(-add)
            else:
                raise ValueError(f"Invalid selector: {selector}")

        self.model_sum_all_i = sum(sum_i)        
        self.model_sum_all_q = sum(sum_q)        

        self.energy_i_delayed = self.energy_i
        self.energy_q_delayed = self.energy_q
        self.energy_delayed   = self.energy
        self.o_energy_delayed = self.o_energy  

        if i_enable_0:
            self.energy_i = self.model_sum_all_i*self.model_sum_all_i
            self.energy_q = self.model_sum_all_q*self.model_sum_all_q
            self.energy   = self.energy_i + self.energy_q
            self.o_energy = (self.energy >> int((2*self.nbw_adder_tree_out+1-self.nbw_energy))) & (2**self.nbw_energy-1)
            #print(f"self.nbw_adder_tree_out:{self.nbw_adder_tree_out}, self.energy:{self.energy}")
                
        return sum_i, sum_q
