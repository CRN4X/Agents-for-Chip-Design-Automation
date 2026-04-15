module tb;

parameter NBW_DATA = 'd64;
parameter NBW_KEY  = 'd64;

logic              clk;
logic              rst_async_n;
logic              i_valid;
logic [1:NBW_DATA] i_data;
logic [1:NBW_KEY ] i_key;
logic              o_valid;
logic [1:NBW_DATA] o_data;

des_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_KEY )
) uu_des_dec (
    .clk        (clk        ),
    .rst_async_n(rst_async_n),
    .i_valid    (i_valid    ),
    .i_data     (i_data     ),
    .i_key      (i_key      ),
    .o_valid    (o_valid    ),
    .o_data     (o_data     )
);

initial begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb);
end

always #5 clk = ~clk;

task Single_test(logic [1:NBW_KEY] key, logic [1:NBW_DATA] data, logic [1:NBW_DATA] expected);
    i_key   = key;
    i_data  = data;
    i_valid = 1;

    @(negedge clk);
    i_valid = 0;

    @(posedge o_valid);
    @(negedge clk);
    if(o_data != expected) begin
        $display("FAIL!");
        $display("Expected %h, got %h", expected, o_data);
    end else begin
        $display("PASS!");
    end
endtask

task Burst_test();
    i_key   = 64'hB1FECAFEBEBAB1FE;
    i_data  = 64'h6B85F162427F0DC8;
    i_valid = 1;

    @(negedge clk);
    i_data  = 64'hB02273A3AD757BDA;

    @(negedge clk);
    i_data  = 64'h87C952860A802C4B;
    i_key   = 64'hABCDABCDABCDABCD;

    @(negedge clk);
    i_valid = 0;

    @(posedge o_valid);
    @(negedge clk);
    if(o_data != 64'h4321432143214321) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h4321432143214321, o_data);
    end else begin
        $display("PASS!");
    end

    @(negedge clk);
    if(o_valid != 1) begin
        $display("FAIL! o_valid should be asserted here.");
    end
    if(o_data != 64'h123456789ABCDEF0) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h123456789ABCDEF0, o_data);
    end else begin
        $display("PASS!");
    end

    @(negedge clk);
    if(o_valid != 1) begin
        $display("FAIL! o_valid should be asserted here.");
    end
    if(o_data != 64'h1234123412341234) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h1234123412341234, o_data);
    end else begin
        $display("PASS!");
    end
    
endtask

initial begin
    clk = 0;
    i_valid = 0;
    rst_async_n = 1;
    #1;
    rst_async_n = 0;
    #2;
    rst_async_n = 1;
    @(negedge clk);

    $display("\nSingle Tests");
    Single_test(64'h0123456789ABCDEF, 64'h56CC09E7CFDC4CEF, 64'h0123456789ABCDEF);
    Single_test(64'h0123456789ABCDEF, 64'h12C626AF058B433B, 64'hFEDCBA9876543210);
    Single_test(64'hBEBACAFE12345678, 64'h00D97727C293BFAC, 64'hFEDCBA9876543210);
    Single_test(64'hBEBACAFE12345678, 64'h31F3FE80E9457BED, 64'hB1FECAFEBEBAB1FE);

    $display("\nBurst Test");
    Burst_test();

    @(negedge clk);
    @(negedge clk);

    $finish();
end

endmodule