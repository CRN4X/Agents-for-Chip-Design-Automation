module cross_correlation #(
   parameter  NS_DATA_IN  = 5,
   parameter  NBW_DATA_IN = 2,
   parameter  NBI_DATA_IN = 1,
   parameter  NBW_ENERGY  = 5
)
( 
 input  logic                                clk         ,
 input  logic                                i_enable    , 
 input  logic [NBW_DATA_IN*NS_DATA_IN-1 : 0] i_data_i    ,
 input  logic [NBW_DATA_IN*NS_DATA_IN-1 : 0] i_data_q    ,
 input  logic [NS_DATA_IN-1:0]               i_conj_seq_i,
 input  logic [NS_DATA_IN-1:0]               i_conj_seq_q,
 output logic [NBW_ENERGY-1:0]               o_energy  
);
localparam N_ADDER_LEVELS= $clog2(NS_DATA_IN);
localparam N_REG_LEVELS  = 8'b00000000;

localparam NBW_ADDER_TREE_IN  = NBW_DATA_IN + 2;
localparam NBI_ADDER_TREE_IN  = NBI_DATA_IN + 2;

localparam NBW_ADDER_TREE_OUT = NBW_ADDER_TREE_IN  + N_ADDER_LEVELS;
localparam NBI_ADDER_TREE_OUT = NBI_ADDER_TREE_IN  + N_ADDER_LEVELS;
localparam NBF_ADDER_TREE_OUT = NBW_ADDER_TREE_OUT - NBI_ADDER_TREE_OUT;

logic [NBW_ADDER_TREE_IN*NS_DATA_IN-1:0] sum_i_1d;
logic [NBW_ADDER_TREE_IN*NS_DATA_IN-1:0] sum_q_1d;

/*Correlation result for i and q data component*/
wire signed [NBW_ADDER_TREE_OUT-1:0] correlation_i;
wire signed [NBW_ADDER_TREE_OUT-1:0] correlation_q;

correlate #(
    .NS_DATA_IN       (NS_DATA_IN       ),
    .NBW_DATA_IN      (NBW_DATA_IN      ),
    .NBW_ADDER_TREE_IN(NBW_ADDER_TREE_IN)
) uu_correlate(
    .i_data_i    (i_data_i    ),
    .i_data_q    (i_data_q    ),
    .i_conj_seq_i(i_conj_seq_i),
    .i_conj_seq_q(i_conj_seq_q),   
    .o_sum_i     (sum_i_1d    ),
    .o_sum_q     (sum_q_1d    )
);

adder_2d_layers  #(
    .NBW_IN            (NBW_ADDER_TREE_IN ),
    .NS_IN             (NS_DATA_IN        ),
    .N_LEVELS          (N_ADDER_LEVELS    ),
    .REGS              (N_REG_LEVELS      ),
    .NBW_ADDER_TREE_OUT(NBW_ADDER_TREE_OUT),
    .NBW_ENERGY        (NBW_ENERGY        )
) uu_adder_2d_layers (
        .clk     (clk            ),
        .i_enable(i_enable       ),
        .i_data_i(sum_i_1d       ),
        .i_data_q(sum_q_1d       ),
        .o_data_i(correlation_i  ),
        .o_data_q(correlation_q  ),
        .o_energy(o_energy)            
);

endmodule