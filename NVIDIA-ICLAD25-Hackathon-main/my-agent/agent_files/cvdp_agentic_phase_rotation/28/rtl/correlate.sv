module correlate #(
   parameter  NS_DATA_IN        = 'd11,
   parameter  NBW_DATA_IN = 'd08,
   parameter  NBW_ADDER_TREE_IN = 3
)
(
 input  logic [NBW_DATA_IN*NS_DATA_IN-1 : 0]  i_data_i    ,
 input  logic [NBW_DATA_IN*NS_DATA_IN-1 : 0]  i_data_q    ,
 input  logic        [       NS_DATA_IN-1 : 0]  i_conj_seq_i,
 input  logic        [       NS_DATA_IN-1 : 0]  i_conj_seq_q,   
 output logic [NBW_ADDER_TREE_IN*NS_DATA_IN-1:0]o_sum_i,
 output logic [NBW_ADDER_TREE_IN*NS_DATA_IN-1:0]o_sum_q

);

wire signed  [      NBW_DATA_IN:0] add[NS_DATA_IN];
wire signed  [      NBW_DATA_IN:0] sub[NS_DATA_IN];

logic signed [NBW_ADDER_TREE_IN-1:0] sum_i[NS_DATA_IN];
logic signed [NBW_ADDER_TREE_IN-1:0] sum_q[NS_DATA_IN];

logic signed [NBW_DATA_IN-1:0]  i_data_i_2d [NS_DATA_IN-1:0]; 
logic signed [NBW_DATA_IN-1:0]  i_data_q_2d [NS_DATA_IN-1:0]; 

wire [NS_DATA_IN-1:0] signal_seq_i;
wire [NS_DATA_IN-1:0] signal_seq_q;

always_comb begin
    for (int i=0; i<NS_DATA_IN; i++) begin
        i_data_i_2d[i] = $signed(i_data_i[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
        i_data_q_2d[i] = $signed(i_data_q[(i+1)*NBW_DATA_IN-1-:NBW_DATA_IN]);
    end
end

generate
    for(genvar i = 0 ; i < NS_DATA_IN; i++) begin
        
        /*determinate the signal of the FAW symbs*/
        assign signal_seq_i[i] = i_conj_seq_i[i];
        assign signal_seq_q[i] = i_conj_seq_q[i];


        assign add[i] = i_data_i_2d[i] + i_data_q_2d[i];
        assign sub[i] = i_data_i_2d[i] - i_data_q_2d[i];
    
        always_comb begin
            case({signal_seq_i[i],signal_seq_q[i]})
                2'b00: begin
                            sum_i[i]  = sub[i];
                            sum_q[i]  = add[i];
                       end

                2'b01: begin
                            sum_i[i]  =  add[i];
                            sum_q[i]  = -sub[i];
                       end    

                2'b10: begin
                            sum_i[i]  = -add[i];
                            sum_q[i]  =  sub[i];
                       end    

                2'b11: begin
                            sum_i[i]  = -sub[i];
                            sum_q[i]  = -add[i];
                       end    
            endcase 
        end
    end    
endgenerate

always_comb begin
    for (int i=0; i<NS_DATA_IN; ++i) begin
        o_sum_i[(i+1)*NBW_ADDER_TREE_IN-1-:NBW_ADDER_TREE_IN] = sum_i[i];
        o_sum_q[(i+1)*NBW_ADDER_TREE_IN-1-:NBW_ADDER_TREE_IN] = sum_q[i];
    end
end
endmodule