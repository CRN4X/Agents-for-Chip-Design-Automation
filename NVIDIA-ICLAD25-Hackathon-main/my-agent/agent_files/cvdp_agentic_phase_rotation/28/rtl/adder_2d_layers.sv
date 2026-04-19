module adder_2d_layers #(
    parameter NBW_IN   = 'd8        ,
    parameter NS_IN    = 'd80       ,
    parameter N_LEVELS = 'd7        ,
    parameter REGS     = 8'b100010_0,
    parameter NBW_ADDER_TREE_OUT = 8,
    parameter NBW_ENERGY = 5
) (
    input  logic                                clk    ,
    input  logic                               i_enable,
    input  logic [           NBW_IN*NS_IN-1:0] i_data_i,
    input  logic [           NBW_IN*NS_IN-1:0] i_data_q,
    output logic [(NBW_IN+N_LEVELS)-1:0] o_data_i,
    output logic [(NBW_IN+N_LEVELS)-1:0] o_data_q,
    output logic [NBW_IN-1:0] o_energy    
);

logic signed [NBW_ADDER_TREE_OUT-1:0] correlation_i_dff;
logic signed [NBW_ADDER_TREE_OUT-1:0] correlation_q_dff;

wire signed [2*NBW_ADDER_TREE_OUT-1:0] energy_i;
wire signed [2*NBW_ADDER_TREE_OUT-1:0] energy_q;
wire signed [2*NBW_ADDER_TREE_OUT:0] energy;

/*Sum all corelation_i components */
adder_tree_2d #(
    .NBW_IN  (NBW_IN  ),
    .NS_IN   (NS_IN   ),
    .N_LEVELS(N_LEVELS),
    .REGS    (REGS    ) 
) uu_sum_corr_i (
        .clk   (clk            ),
        .i_data(i_data_i       ),
        .o_data(o_data_i       )
);

/*Sum all corelation_q components */
adder_tree_2d #(
    .NBW_IN  (NBW_IN  ),
    .NS_IN   (NS_IN   ),
    .N_LEVELS(N_LEVELS),
    .REGS    (REGS    ) 
) uu_sum_corr_q (
        .clk   (clk            ),
        .i_data(i_data_q       ),
        .o_data(o_data_q       )
);

always_ff @(posedge clk) begin : proc_correlation_dff
  if(i_enable) begin
      correlation_i_dff <= o_data_i;
      correlation_q_dff <= o_data_q;
   end 
end

assign energy_i  = correlation_i_dff*correlation_i_dff;
assign energy_q  = correlation_q_dff*correlation_q_dff;
assign energy    = $unsigned(energy_i) + $unsigned(energy_q);
assign o_energy  = energy[2*NBW_ADDER_TREE_OUT-:NBW_ENERGY];


endmodule