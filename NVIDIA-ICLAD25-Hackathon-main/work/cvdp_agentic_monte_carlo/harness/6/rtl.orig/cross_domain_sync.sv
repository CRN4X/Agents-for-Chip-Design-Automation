module cross_domain_sync #(  
    parameter DATA_WIDTH = 16
)(
    input  wire                   clk_dst,
    input  wire                   rst_n,
    input  wire [DATA_WIDTH-1:0] data_src,
    input  wire                   valid_src,

    output reg  [DATA_WIDTH-1:0] data_dst,
    output reg                   valid_dst
);

    reg [DATA_WIDTH-1:0] sync1_data, sync2_data;
    reg                  sync1_valid; 

    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            sync1_data  <= 0; sync2_data <= 0;
            sync1_valid <= 0;
        end else begin
            sync1_data  <= data_src;
            sync2_data  <= sync1_data;

            sync1_valid <= valid_src;
        end
    end

    always @(posedge clk_dst or negedge rst_n) begin
        if (!rst_n) begin
            data_dst  <= 0;
            valid_dst <= 0;
        end else begin
            data_dst  <= sync2_data;
            valid_dst <= sync1_valid;
        end
    end

endmodule