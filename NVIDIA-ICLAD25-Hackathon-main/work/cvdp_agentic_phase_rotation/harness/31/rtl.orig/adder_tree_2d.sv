module adder_tree_2d #(
    parameter NBW_IN   = 'd8        ,
    parameter NS_IN    = 'd80       ,
    parameter N_LEVELS = 'd7        ,
    parameter REGS     = 8'b100010_0
) (
    input  logic                                clk               ,
    input  logic        [NBW_IN*NS_IN-1:0]      i_data,
    output logic signed [(NBW_IN+N_LEVELS)-1:0] o_data
);
    logic signed [NBW_IN-1:0] i_data_2d [NS_IN-1:0];

    always_comb begin
      for(int k = 0; k < NS_IN; k++) begin
         i_data_2d[k] = $signed(i_data[(k+1)*NBW_IN-1-:NBW_IN]);
      end
    end

    function automatic integer func_nadd (input integer level);
        integer i;
        integer nadd;
        begin
            nadd = $signed(NS_IN);
            for (i=0; i<level; i=i+1) begin
                nadd = (nadd+1)/2;
            end
            func_nadd = nadd;
        end
    endfunction

    genvar i,j;
    generate
        for (i=0; i<=N_LEVELS; i=i+1) begin : levels

            for (j=0; j<func_nadd(i); j=j+1 ) begin : nodes

                reg signed [i+NBW_IN-1:0] result;

                if (i == 0) begin : gen_initial

                    if (REGS[i]) begin: gen_init_reg
                        always_ff @ (posedge clk) begin : in_split_reg
                            begin
                                result <= $signed(i_data_2d[j]);
                            end
                        end
                    end else begin : gen_comb
                        always_comb begin : in_split_comb
                            result = $signed(i_data_2d[j]);
                        end
                    end

                end else if (2*j+1 == func_nadd(i-1)) begin : gen_others

                    if (REGS[i]) begin : gen_reg
                        always_ff @ (posedge clk) begin : odd_reg
                            begin
                                result <= levels[i-1].nodes[2*j+0].result;
                            end
                        end
                    end else begin : gen_comb
                        always_comb begin : odd 
                            result = levels[i-1].nodes[2*j+0].result;
                        end

                    end

                end else begin : gen_final

                    if (REGS[i]) begin : gen_end_ff
                        always_ff @(posedge clk) begin : add_reg
                            begin
                                result <= levels[i-1].nodes[2*j+0].result +
                                    levels[i-1].nodes[2*j+1].result;
                            end
                        end
                    end else begin : gen_end_comb
                        always_comb begin : add 
                            result = levels[i-1].nodes[2*j+0].result +
                                levels[i-1].nodes[2*j+1].result;
                        end
                    end

                end
            end
        end
    endgenerate

    assign o_data = levels[N_LEVELS].nodes[0].result;

endmodule