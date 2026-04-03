module tb;

parameter NBW_DATA = 'd64;
parameter NBW_KEY  = 'd192;

logic                clk;
logic                rst_async_n;
logic                i_valid;
logic [1:NBW_DATA] i_data;
logic [1:NBW_KEY ] i_key;
logic                o_valid;
logic [1:NBW_DATA] o_data;

des3_enc #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_KEY )
) uu_des3_enc (
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
    i_key   = 192'hB1FECAFEBEBAB1FEABCDABCDABCDABCD8765432187654321;
    i_data  = 64'h4321432143214321;
    i_valid = 1;

    @(negedge clk);
    i_data  = 64'h123456789ABCDEF0;

    @(negedge clk);
    i_data  = 64'h1234123412341234;
    i_key   = 192'hABCDABCDABCDABCD8765432187654321B1FECAFEBEBAB1FE;

    @(negedge clk);
    i_valid = 0;

    @(posedge o_valid);
    @(negedge clk);
    if(o_data != 64'h2749c9efcaed543a) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h2749c9efcaed543a, o_data);
    end else begin
        $display("PASS!");
    end

    @(negedge clk);
    if(o_valid != 1) begin
        $display("FAIL! o_valid should be asserted here.");
    end
    if(o_data != 64'h984d23ecef8df5fd) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h984d23ecef8df5fd, o_data);
    end else begin
        $display("PASS!");
    end

    @(negedge clk);
    if(o_valid != 1) begin
        $display("FAIL! o_valid should be asserted here.");
    end
    if(o_data != 64'h972161012599c927) begin
        $display("FAIL!");
        $display("Expected %h, got %h", 64'h972161012599c927, o_data);
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
    Single_test(192'h0123456789abcdeffedcba9876543210abcdef9876543210, 64'h0123456789ABCDEF, 64'ha4688b153da3f95b);
    Single_test(192'h0123456789abcdeffedcba9876543210abcdef9876543210, 64'hFEDCBA9876543210, 64'h7b9325d305515107);
    Single_test(192'hBEBACAFE12345678B1FECAFE876543219898898974744747, 64'hFEDCBA9876543210, 64'h71f4eedd55b0f964);
    Single_test(192'hBEBACAFE12345678B1FECAFE876543219898898974744747, 64'hB1FECAFEBEBAB1FE, 64'h2038ea8568d3f771);

    $display("\nBurst Test");
    Burst_test();

    @(negedge clk);
    @(negedge clk);

    $finish();
end

endmodule