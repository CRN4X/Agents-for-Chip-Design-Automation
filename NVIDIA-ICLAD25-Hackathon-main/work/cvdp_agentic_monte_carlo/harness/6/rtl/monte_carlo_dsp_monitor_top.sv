module monte_carlo_dsp_monitor_top #(
    parameter DATA_WIDTH = 16,                     
    parameter SEED_A = 16'hACE1,
    parameter SEED_B = 16'hBEEF
)(
    input  wire                   clk_a,
    input  wire                   clk_b,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0] data_in_a,
    input  wire                   valid_in_a,
    output wire [DATA_WIDTH-1:0] data_out_b,
    output wire                   valid_out_b,
    output wire [31:0]            cross_domain_transfer_count
);

    wire [DATA_WIDTH-1:0] lfsr_out_a, lfsr_out_b;
    wire [DATA_WIDTH-1:0] data_stage_a;
    wire                  valid_stage_a;
    wire [DATA_WIDTH-1:0] data_cross_b;
    wire                  valid_cross_b;

    // LFSR for clk_a
    lfsr_generator #(.WIDTH(DATA_WIDTH), .SEED(SEED_A)) u_lfsr_a (
        .clk(clk_a),
        .rst_n(rst_n),
        .lfsr(lfsr_out_a)
    );

    // LFSR for clk_b
    lfsr_generator #(.WIDTH(DATA_WIDTH), .SEED(SEED_B)) u_lfsr_b (
        .clk(clk_b),
        .rst_n(rst_n),
        .lfsr(lfsr_out_b)
    );

    // Input stage
    dsp_input_stage #(.DATA_WIDTH(DATA_WIDTH)) u_input_stage (
        .clk(clk_a),
        .rst_n(rst_n),
        .data_in(data_in_a),
        .valid_in(valid_in_a),
        .rand_mask(lfsr_out_a),
        .data_out(data_stage_a),
        .valid_out(valid_stage_a)
    );

    // Cross domain sync
    cross_domain_sync #(.DATA_WIDTH(DATA_WIDTH)) u_cross_sync (
        .clk_dst(clk_b),
        .rst_n(rst_n),
        .data_src(data_stage_a),
        .valid_src(valid_stage_a),
        .data_dst(data_cross_b),
        .valid_dst(valid_cross_b)
    );

    // Output stage
    dsp_output_stage #(.DATA_WIDTH(DATA_WIDTH)) u_output_stage (
        .clk(clk_b),
        .rst_n(rst_n),
        .data_in(data_cross_b),
        .valid_in(valid_cross_b),
        .rand_mask(lfsr_out_b),
        .data_out(data_out_b),
        .valid_out(valid_out_b),
        .transfer_count(cross_domain_transfer_count)
    );

endmodule