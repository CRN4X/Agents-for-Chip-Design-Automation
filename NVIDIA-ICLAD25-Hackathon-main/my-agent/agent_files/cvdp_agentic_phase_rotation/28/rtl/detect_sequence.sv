module detect_sequence #(
    parameter NBW_DATA_IN     = 8,
    parameter NS              = 64,
    parameter NBI_DATA_IN     = 6,
    parameter NBW_ENERGY      = 10,
    parameter NBW_PILOT_POS   = 6,
    parameter NBW_TH_PROC     = 10,
    parameter NS_PROC         = 23,
    parameter NS_PROC_OVERLAP = 22
) (
    input  logic                                        clk,
    input  logic                                        rst_async_n,
    input  logic                                        i_valid,
    input  logic                                        i_enable,
    input  logic                                        i_proc_pol,
    input  logic [NBW_PILOT_POS-1:0]                    i_proc_pos,
    input  logic [NBW_TH_PROC-1:0]                      i_static_threshold,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_i,
    input  logic [NBW_DATA_IN*(NS+NS_PROC_OVERLAP)-1:0] i_data_q,
    output logic [1:0]                                  o_proc_detected
);

localparam integer PIPE_DEPTH = 4;
localparam integer NS_DATA_IN = NS + NS_PROC_OVERLAP;

logic                            proc_enable;
logic [PIPE_DEPTH-1:0]           proc_enable_dff;
logic [1:0]                      proc_pol_dff;
logic [NBW_PILOT_POS-1:0]        proc_pos_delayed;
logic                            proc_detected;
logic                            proc_detected_dff;

logic signed [NBW_DATA_IN-1:0]   i_data_i_2d         [0:NS_DATA_IN-1];
logic signed [NBW_DATA_IN-1:0]   i_data_q_2d         [0:NS_DATA_IN-1];
logic signed [NBW_DATA_IN-1:0]   i_data_i_2d_delayed [0:NS_DATA_IN-1];
logic signed [NBW_DATA_IN-1:0]   i_data_q_2d_delayed [0:NS_DATA_IN-1];
logic [NBW_DATA_IN*NS_DATA_IN-1:0] i_data_i_dly_1d;
logic [NBW_DATA_IN*NS_DATA_IN-1:0] i_data_q_dly_1d;

logic signed [NBW_DATA_IN-1:0]   proc_buffer_i_dff   [0:NS_PROC-1];
logic signed [NBW_DATA_IN-1:0]   proc_buffer_q_dff   [0:NS_PROC-1];
logic signed [NBW_DATA_IN-1:0]   proc_buffer_i_cur   [0:NS_PROC-1];
logic signed [NBW_DATA_IN-1:0]   proc_buffer_q_cur   [0:NS_PROC-1];
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_i_dff_1d;
logic signed [NBW_DATA_IN*NS_PROC-1:0] proc_buffer_q_dff_1d;

logic [NS_PROC-1:0]              conj_proc_seq[0:1];
logic [NBW_ENERGY-1:0]           proc_calc_energy;

assign proc_enable = i_valid & i_enable;

always_comb begin
    for (int i = 0; i < NS_DATA_IN; i++) begin
        i_data_i_2d[i] = $signed(i_data_i[(i+1)*NBW_DATA_IN-1 -: NBW_DATA_IN]);
        i_data_q_2d[i] = $signed(i_data_q[(i+1)*NBW_DATA_IN-1 -: NBW_DATA_IN]);
    end
end

always_comb begin
    if (proc_pol_dff[0]) begin
        conj_proc_seq[0] = 23'b11010110101100100001110;
        conj_proc_seq[1] = 23'b10000101011110000101011;
    end else begin
        conj_proc_seq[0] = 23'b10101010111011101000000;
        conj_proc_seq[1] = 23'b11011001100011010001110;
    end
end

always_comb begin
    for (int i = 0; i < NS_PROC; i++) begin
        proc_buffer_i_dff[i] = $signed(i_data_i_dly_1d[(proc_pos_delayed + i)*NBW_DATA_IN +: NBW_DATA_IN]);
        proc_buffer_q_dff[i] = $signed(i_data_q_dly_1d[(proc_pos_delayed + i)*NBW_DATA_IN +: NBW_DATA_IN]);
    end
end

always_comb begin
    for (int i = 0; i < NS_PROC; i++) begin
        proc_buffer_i_dff_1d[(i+1)*NBW_DATA_IN-1 -: NBW_DATA_IN] = proc_buffer_i_dff[i];
        proc_buffer_q_dff_1d[(i+1)*NBW_DATA_IN-1 -: NBW_DATA_IN] = proc_buffer_q_dff[i];
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
        proc_enable_dff    <= '0;
        proc_pol_dff       <= '0;
        proc_pos_delayed   <= '0;
        proc_detected      <= 1'b0;
        proc_detected_dff  <= 1'b0;
        o_proc_detected    <= '0;

        for (int i = 0; i < NS_DATA_IN; i++) begin
            i_data_i_2d_delayed[i] <= '0;
            i_data_q_2d_delayed[i] <= '0;
        end
        i_data_i_dly_1d <= '0;
        i_data_q_dly_1d <= '0;

        for (int i = 0; i < NS_PROC; i++) begin
            proc_buffer_i_cur[i] <= '0;
            proc_buffer_q_cur[i] <= '0;
        end
    end else begin
        for (int i = PIPE_DEPTH-1; i > 0; i--) begin
            proc_enable_dff[i] <= proc_enable_dff[i-1];
        end
        proc_enable_dff[0] <= proc_enable;

        if (proc_enable) begin
            proc_pol_dff <= {1'b0, i_proc_pol};
        end

        if (proc_enable) begin
            proc_pos_delayed <= i_proc_pos;
            i_data_i_dly_1d  <= i_data_i;
            i_data_q_dly_1d  <= i_data_q;
            for (int i = 0; i < NS_DATA_IN; i++) begin
                i_data_i_2d_delayed[i] <= i_data_i_2d[i];
                i_data_q_2d_delayed[i] <= i_data_q_2d[i];
            end
        end

        proc_detected_dff <= proc_detected;
        if (proc_enable_dff[3]) begin
            proc_detected <= ((proc_calc_energy >= i_static_threshold) === 1'b1);
        end else begin
            proc_detected <= 1'b0;
        end

        o_proc_detected <= {1'b0, proc_detected_dff};
    end
end

cross_correlation #(
    .NS_DATA_IN (NS_PROC),
    .NBW_DATA_IN(NBW_DATA_IN),
    .NBI_DATA_IN(NBI_DATA_IN),
    .NBW_ENERGY (NBW_ENERGY)
) uu_cross_correlation (
    .clk         (clk),
    .i_enable    (proc_enable_dff[1]),
    .i_data_i    (proc_buffer_i_dff_1d),
    .i_data_q    (proc_buffer_q_dff_1d),
    .i_conj_seq_i(conj_proc_seq[0]),
    .i_conj_seq_q(conj_proc_seq[1]),
    .o_energy    (proc_calc_energy)
);

endmodule
