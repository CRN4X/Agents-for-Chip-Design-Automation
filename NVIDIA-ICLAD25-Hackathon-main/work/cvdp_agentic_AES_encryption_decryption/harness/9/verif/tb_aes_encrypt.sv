module tb_aes_encrypt;

localparam NBW_KEY  = 'd256;
localparam NBW_DATA = 'd128;

logic                clk;
logic                rst_async_n;
logic                i_update_key;
logic [NBW_KEY-1:0]  i_key;
logic                i_start;
logic [NBW_DATA-1:0] i_data;
logic                o_done;
logic [NBW_DATA-1:0] o_data;

aes_encrypt #(
    .NBW_KEY(NBW_KEY),
    .NBW_DATA(NBW_DATA)
) uu_aes_encrypt (
    .clk(clk),
    .rst_async_n(rst_async_n),
    .i_update_key(i_update_key),
    .i_key(i_key),
    .i_start(i_start),
    .i_data(i_data),
    .o_done(o_done),
    .o_data(o_data)
);

task Simple_test(logic update_key);
    @(negedge clk);
    i_key  = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    i_data = 128'h00112233445566778899aabbccddeeff;
    i_update_key = update_key;
    i_start = 1;

    @(negedge clk);
    i_start = 0;
    i_update_key = 0;
    i_key = 0;

    @(posedge o_done);
    @(negedge clk);

    if(o_data == 128'h8ea2b7ca516745bfeafc49904b496089) begin
        $display("PASS");
    end else begin
        $display("FAIL");
        $display("Expected output: %h", 128'h8ea2b7ca516745bfeafc49904b496089);
        $display("Observed output: %h", o_data);
    end
endtask

initial begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb_aes_encrypt);
end

always #5 clk = ~clk;

initial begin
    clk = 0;
    i_start = 0;
    rst_async_n = 1;
    #1;
    rst_async_n = 0;
    #2;
    rst_async_n = 1;
    @(negedge clk);

    // Tasks go here
    Simple_test(1'b1);
    Simple_test(1'b0);

    @(negedge clk);
    @(negedge clk);

    $finish();
end

endmodule