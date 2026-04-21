module phase_lut #(
    parameter int NBW_IN    = 6,
    parameter int NBI_IN    = 1,
    parameter int NBW_PHASE = 9,
    parameter int NBI_PHASE = 1
) (
    input  logic                           clk,
    input  logic                           rst_async_n,
    input  logic signed [NBW_IN-1:0]       i_data_i,
    input  logic signed [NBW_IN-1:0]       i_data_q,
    output logic signed [NBW_PHASE-1:0]    o_phase
);

localparam int NBF_IN     = NBW_IN - NBI_IN;
localparam int NBF_PHASE  = NBW_PHASE - NBI_PHASE;
localparam int LUT_SIDE   = (1 << NBF_IN) + 1;
localparam int FULL_SCALE = (1 << NBF_PHASE);

logic [NBF_IN:0] abs_i_now;
logic [NBF_IN:0] abs_q_now;
logic [NBF_IN:0] abs_i_s0;
logic [NBF_IN:0] abs_q_s0;
logic            sign_i_s0;
logic            sign_q_s0;
logic [1:0]      init_pipe;
logic signed [NBW_PHASE-1:0] phase_next;
logic signed [NBW_PHASE-1:0] lut_val;

integer lut_quant;
real    theta;
logic signed [NBW_IN-1:0] abs_i_tmp;
logic signed [NBW_IN-1:0] abs_q_tmp;

always_comb begin
    abs_i_tmp = i_data_i[NBW_IN-1] ? -i_data_i : i_data_i;
    abs_q_tmp = i_data_q[NBW_IN-1] ? -i_data_q : i_data_q;
    if (abs_i_tmp > (LUT_SIDE - 1)) begin
        abs_i_now = LUT_SIDE - 1;
    end else begin
        abs_i_now = abs_i_tmp[NBF_IN:0];
    end
    if (abs_q_tmp > (LUT_SIDE - 1)) begin
        abs_q_now = LUT_SIDE - 1;
    end else begin
        abs_q_now = abs_q_tmp[NBF_IN:0];
    end
end

always_comb begin
    if ((abs_i_s0 == '0) && (abs_q_s0 == '0)) begin
        lut_quant = 0;
    end else begin
        theta = $atan2(abs_q_s0, abs_i_s0);
        lut_quant = $rtoi((theta * FULL_SCALE) / 3.14159265358979323846);
    end
    lut_val = lut_quant[NBW_PHASE-1:0];

    if (!init_pipe[1]) begin
        phase_next = '0;
    end else if ((abs_i_s0 == '0) && (abs_q_s0 == '0)) begin
        phase_next = '0;
    end else if (!sign_i_s0 && !sign_q_s0) begin
        phase_next = lut_val;
    end else if (!sign_i_s0 && sign_q_s0) begin
        phase_next = -lut_val;
    end else if (sign_i_s0 && !sign_q_s0) begin
        phase_next = FULL_SCALE - lut_val;
    end else begin
        phase_next = lut_val - FULL_SCALE;
    end
end

always_ff @(posedge clk or negedge rst_async_n) begin
    if (rst_async_n !== 1'b1) begin
        abs_i_s0  <= '0;
        abs_q_s0  <= '0;
        sign_i_s0 <= 1'b0;
        sign_q_s0 <= 1'b0;
        init_pipe <= 2'b00;
        o_phase   <= '0;
    end else begin
        abs_i_s0  <= abs_i_now;
        abs_q_s0  <= abs_q_now;
        sign_i_s0 <= i_data_i[NBW_IN-1];
        sign_q_s0 <= i_data_q[NBW_IN-1];
        init_pipe <= {init_pipe[0], 1'b1};
        o_phase   <= phase_next;
    end
end

initial begin
    abs_i_s0  = '0;
    abs_q_s0  = '0;
    sign_i_s0 = 1'b0;
    sign_q_s0 = 1'b0;
    init_pipe = 2'b00;
    o_phase   = '0;
end

endmodule
