
module nbit_swizzling_tb();
parameter DATA_WIDTH = 40;

reg [DATA_WIDTH-1:0] data_in;
reg [1:0] sel;
wire [DATA_WIDTH-1:0] data_out;
wire [DATA_WIDTH-1:0] gray_out;

nbit_swizzling#(.DATA_WIDTH(DATA_WIDTH))
uut_nbit_sizling(
.data_in(data_in),
.sel(sel),
.data_out(data_out),
.gray_out(gray_out)
);

initial begin
repeat(10) begin
#10;
sel = 2'b00;
data_in = $urandom_range(20000,2451000);
$display( " HEX ::sel = %h, data_in = %h",sel,data_in);
#10
$display( " data_out = %h,gray_out = %h ",data_out,gray_out);
$display( "BIN ::sel = %b, data_out = %b, gray_out = %b", sel,data_out,gray_out);
$display("====================================================================================================================");
end
repeat(10) begin
#10;
sel = 2'b01;
data_in = $urandom_range(20000,2451000);
$display( " HEX ::sel = %h, data_in = %h",sel,data_in);
#10
$display( " data_out = %h,gray_out = %h ", data_out,gray_out);
$display( "BIN ::sel = %b, data_out = %b, gray_out = %b", sel, data_out,gray_out);
$display("====================================================================================================================");
end
repeat(10) begin
#10;
sel = 2'b10;
data_in = $urandom_range(20000,2451000);
$display( " HEX ::sel = %h, data_in = %h",sel,data_in);
#10
$display( " data_out = %h,gray_out = %h ", data_out,gray_out);
$display( "BIN ::sel = %b, data_out = %b, gray_out = %b", sel, data_out,gray_out);
$display("====================================================================================================================");
end
repeat(10) begin
#10;
sel = 2'b11;
data_in = $urandom_range(20000,2451000);
$display( " HEX ::sel = %h, data_in = %h",sel,data_in);
#10
$display( " data_out = %h,gray_out = %h", data_out,gray_out);
$display( "BIN ::sel = %b, data_out = %b, gray_out = %b", sel, data_out,gray_out);
$display("====================================================================================================================");
end 
end

initial begin
$dumpfile("dump.vcd");
$dumpvars(0,nbit_swizzling_tb);
end

endmodule 