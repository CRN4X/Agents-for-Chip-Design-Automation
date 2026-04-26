`timescale 1ns/1ns

module detect_sequence #(
    parameter NS              = 'd64,
    parameter NBW_PILOT_POS   = 'd06,
    parameter NBW_DATA_IN     = 'd08,
    parameter NBI_DATA_IN     = 'd02,
    parameter NBW_TH_UNLOCK   = 'd03,
    parameter NBW_ENERGY      = 'd10,
    parameter NS_PROC         = 'd23,
    parameter NS_PROC_OVERLAP = NS_PROC - 1
)(
    input  logic                                        clk                       ,
    input  logic                                        rst_async_n               ,
    input  logic                                        i_valid                   ,
    input  logic                                        i_enable                  ,
    input  logic                                        i_proc_pol                ,
    input  logic [NBW_PILOT_POS-1:0]                    i_proc_pos                ,
    input  logic [NBW_TH_UNLOCK-1:0]                    i_static_unlock_threshold ,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_i                  ,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_q                  ,
    output logic                                        o_proc_detected           ,
    output logic                                        o_locked
);

localparam PROC_CORR_ADDER_LEVELS = $clog2(NS_PROC);
localparam PROC_CORR_REG_LEVELS   = 8'b00000000;
localparam PIPE_DEPTH             = 4;
localparam ST_DETECT_TS           = 1'b0;
localparam ST_DETECT_FAW          = 1'b1;
localparam N_TS_CYCLES            = 58;
localparam CNT_W                  = $clog2(N_TS_CYCLES + 1);

logic [NS_PROC-1:0] conj_proc_h[2];
logic [NS_PROC-1:0] conj_proc_v[2];
logic [NS_PROC-1:0] conj_proc_seq[2];

assign conj_proc_h[1] = 23'b11011001100011010001110;
assign conj_proc_v[1] = 23'b10000101011110000101011;
assign conj_proc_h[0] = 23'b10101010111011101000000;
assign conj_proc_v[0] = 23'b11010110101100100001110;

logic signed [NBW_DATA_IN-1:0] i_data_i_2d[(NS+NS_PROC_OVERLAP)];
logic signed [NBW_DATA_IN-1:0] i_data_q_2d[(NS+NS_PROC_OVERLAP)];
logic signed [NBW_DATA_IN-1:0] i_data_i_2d_delayed[(NS+NS_PROC_OVERLAP)];
logic signed [NBW_DATA_IN-1:0] i_data_q_2d_delayed[(NS+NS_PROC_OVERLAP)];

logic [NBW_PILOT_POS-1:0] i_proc_pos_delayed;

logic [PIPE_DEPTH-1:0] proc_enable_dff;
logic                  proc_enable;
logic                  proc_detected;
logic                  proc_detected_dff;
logic [1:0]            proc_pol_dff;

logic signed [NBW_DATA_IN-1:0]       proc_buffer_i_dff[NS_PROC];
logic signed [NBW_DATA_IN-1:0]       proc_buffer_q_dff[NS_PROC];
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_i_dff_1d;
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_q_dff_1d;
logic [NBW_ENERGY-1:0]               proc_calc_energy;

logic [1:0] mode;
logic [1:0] mode_nx;
logic [1:0] mode_nx_comb;
logic [1:0] w_aware_mode;

logic       curr_state;
logic       nxt_state;
logic       nxt_state_comb;
logic [CNT_W-1:0] ts_count_dff;
logic [CNT_W-1:0] nxt_ts_count;
logic [CNT_W-1:0] nxt_ts_count_comb;
logic [CNT_W-1:0] ts_undetected_count_dff;
logic [CNT_W-1:0] nxt_ts_undetected_count;
logic [CNT_W-1:0] nxt_ts_undetected_count_comb;
logic             o_locked_raw;
logic             o_locked_raw_comb;

always_comb begin
    for (int i = 0; i < (NS + NS_PROC_OVERLAP); i++) begin
        i_data_i_2d[i] = $signed(i_data_i[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
        i_data_q_2d[i] = $signed(i_data_q[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
    end
end

assign proc_enable = i_valid & i_enable;

always_ff @(posedge clk or negedge rst_async_n) begin : proc_proc_enable_dff
    if (!rst_async_n)
        proc_enable_dff <= '0;
    else begin
        proc_enable_dff[0] <= proc_enable;
        for (int i = 1; i < PIPE_DEPTH; i++) begin
            proc_enable_dff[i] <= proc_enable_dff[i-1];
        end
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin : proc_buffers
    if (!rst_async_n) begin
        i_proc_pos_delayed <= '0;
        for (int i = 0; i < (NS + NS_PROC_OVERLAP); i++) begin
            i_data_i_2d_delayed[i] <= '0;
            i_data_q_2d_delayed[i] <= '0;
        end
        for (int i = 0; i < NS_PROC; i++) begin
            proc_buffer_i_dff[i] <= '0;
            proc_buffer_q_dff[i] <= '0;
        end
    end else begin
        if (proc_enable) begin
            i_proc_pos_delayed <= i_proc_pos;
            for (int i = 0; i < (NS + NS_PROC_OVERLAP); i++) begin
                i_data_i_2d_delayed[i] <= i_data_i_2d[i];
                i_data_q_2d_delayed[i] <= i_data_q_2d[i];
            end
            for (int i = 0; i < NS_PROC; i++) begin
                proc_buffer_i_dff[i] <= i_data_i_2d[i_proc_pos + i];
                proc_buffer_q_dff[i] <= i_data_q_2d[i_proc_pos + i];
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin : proc_proc_pol_dff
    if (!rst_async_n) begin
        proc_pol_dff  <= 2'b00;
    end else if (proc_enable) begin
        proc_pol_dff <= {1'b0, i_proc_pol};
    end
end

always_comb begin
    if (proc_pol_dff[0]) begin
        conj_proc_seq[0] = conj_proc_v[0];
        conj_proc_seq[1] = conj_proc_v[1];
    end else begin
        conj_proc_seq[0] = conj_proc_h[0];
        conj_proc_seq[1] = conj_proc_h[1];
    end
end

always_comb begin
    for (int i = 0; i < NS_PROC; ++i) begin
        proc_buffer_i_dff_1d[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN] = proc_buffer_i_dff[i];
        proc_buffer_q_dff_1d[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN] = proc_buffer_q_dff[i];
    end
end

cross_correlation #(
    .NS_DATA_IN  (NS_PROC    ),
    .NBW_DATA_IN (NBW_DATA_IN),
    .NBI_DATA_IN (NBI_DATA_IN),
    .NBW_ENERGY  (NBW_ENERGY )
) uu_cross_correlation(
    .clk         (clk                 ),
    .rst_async_n (rst_async_n         ),
    .i_enable    (proc_enable_dff[1]  ),
    .i_mode      (mode                ),
    .i_data_i    (proc_buffer_i_dff_1d),
    .i_data_q    (proc_buffer_q_dff_1d),
    .i_conj_seq_i(conj_proc_seq[0]    ),
    .i_conj_seq_q(conj_proc_seq[1]    ),
    .o_energy    (proc_calc_energy    ),
    .o_aware_mode(w_aware_mode        )
);

assign proc_detected = proc_enable_dff[3];

always_ff @(posedge clk or negedge rst_async_n) begin : proc_proc_detected_dff
    if (!rst_async_n)
        proc_detected_dff <= 1'b0;
    else
        proc_detected_dff <= proc_detected;
end

assign o_proc_detected = proc_detected_dff;

always_comb begin
    if (curr_state == ST_DETECT_TS) begin
        nxt_ts_count_comb = '0;
    end else begin
        if (i_valid) begin
            if (ts_count_dff == (N_TS_CYCLES - 1))
                nxt_ts_count_comb = '0;
            else
                nxt_ts_count_comb = ts_count_dff + 1'b1;
        end else begin
            nxt_ts_count_comb = ts_count_dff;
        end
    end
end

always_comb begin
    if (curr_state == ST_DETECT_TS) begin
        nxt_ts_undetected_count_comb = '0;
    end else begin
        if (ts_count_dff == (N_TS_CYCLES - 1)) begin
            if (o_proc_detected)
                nxt_ts_undetected_count_comb = '0;
            else
                nxt_ts_undetected_count_comb = ts_undetected_count_dff + 1'b1;
        end else begin
            nxt_ts_undetected_count_comb = ts_undetected_count_dff;
        end
    end
end

always_comb begin
    nxt_state_comb   = curr_state;
    mode_nx_comb     = mode_nx;
    o_locked_raw_comb = o_locked_raw;

    if (curr_state == ST_DETECT_TS) begin
        mode_nx_comb = 2'd0;
        if (o_proc_detected && (w_aware_mode[0] == 1'b1))
            nxt_state_comb = ST_DETECT_FAW;
        else
            nxt_state_comb = ST_DETECT_TS;
    end else begin
        if ((ts_count_dff == (N_TS_CYCLES - 1)) &&
            !o_proc_detected &&
            (ts_undetected_count_dff == i_static_unlock_threshold)) begin
            nxt_state_comb    = ST_DETECT_TS;
            mode_nx_comb      = 2'd0;
            o_locked_raw_comb = o_locked_raw;
        end else if (o_proc_detected) begin
            nxt_state_comb    = ST_DETECT_FAW;
            mode_nx_comb      = 2'd0;
            o_locked_raw_comb = 1'b1;
        end else begin
            nxt_state_comb    = ST_DETECT_TS;
            mode_nx_comb      = ts_undetected_count_dff[1:0];
            o_locked_raw_comb = o_locked_raw;
        end
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin : proc_fsm_regs
    if (!rst_async_n) begin
        curr_state               <= ST_DETECT_TS;
        nxt_state                <= ST_DETECT_TS;
        ts_count_dff             <= '0;
        nxt_ts_count             <= '0;
        ts_undetected_count_dff  <= '0;
        nxt_ts_undetected_count  <= '0;
        mode                     <= 2'd0;
        mode_nx                  <= 2'd0;
        o_locked_raw             <= 1'b0;
        o_locked                 <= 1'b0;
    end else begin
        curr_state              <= nxt_state;
        nxt_state               <= nxt_state_comb;
        ts_count_dff            <= nxt_ts_count;
        nxt_ts_count            <= nxt_ts_count_comb;
        ts_undetected_count_dff <= nxt_ts_undetected_count;
        nxt_ts_undetected_count <= nxt_ts_undetected_count_comb;
        mode                    <= mode_nx;
        mode_nx                 <= mode_nx_comb;
        o_locked                <= o_locked_raw;
        o_locked_raw            <= o_locked_raw_comb;
    end
end

endmodule
