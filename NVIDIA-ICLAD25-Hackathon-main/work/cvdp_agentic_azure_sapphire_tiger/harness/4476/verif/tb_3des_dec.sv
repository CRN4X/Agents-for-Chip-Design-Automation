module tb;

parameter NBW_DATA = 'd64;
parameter NBW_KEY  = 'd192;

logic              clk;
logic              rst_async_n;
logic              i_start;
logic [1:NBW_DATA] i_data;
logic [1:NBW_KEY ] i_key;
logic              o_done;
logic [1:NBW_DATA] o_data;

des3_dec #(
    .NBW_DATA(NBW_DATA),
    .NBW_KEY (NBW_KEY )
) uu_des3_dec (
    .clk        (clk        ),
    .rst_async_n(rst_async_n),
    .i_start    (i_start    ),
    .i_data     (i_data     ),
    .i_key      (i_key      ),
    .o_done     (o_done     ),
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
    i_start = 1;

    @(negedge clk);
    i_start = 0;

    @(posedge o_done);
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
    i_start = 1;

    @(negedge clk); // This next i_data must be ignored by the RTL
    i_data  = 64'h123456789ABCDEF0;

    @(negedge clk); // This next i_data and i_key must be ignored by the RTL
    i_data  = 64'h1234123412341234;
    i_key   = 192'hABCDABCDABCDABCD8765432187654321B1FECAFEBEBAB1FE;

    @(negedge clk);
    i_start = 0;

    @(posedge o_done);
    
    // The ignored data/key can not change the output data, nor the o_done
    for(int i = 0; i < 3; i++) begin // Using 3 to test the data output for the first value, and validating that the changes in i_data and i_key while the RTL is not done won't affect o_data
        @(negedge clk);
        if(o_done != 1) begin
            $display("FAIL! o_done should be asserted here.");
        end
        
        if(o_data != 64'h32966b20b88edf53) begin
            $display("FAIL!");
            $display("Expected %h, got %h", 64'h32966b20b88edf53, o_data);
        end else begin
            $display("PASS!");
        end
    end
    
endtask

initial begin
    clk = 0;
    i_start = 0;
    rst_async_n = 1;
    #1;
    rst_async_n = 0;
    #2;
    rst_async_n = 1;
    @(negedge clk);

    $display("\nSingle Tests");
    Single_test(192'h0123456789abcdeffedcba9876543210abcdef9876543210, 64'h0123456789ABCDEF, 64'h29d92f40554ab5dc);
    Single_test(192'h0123456789abcdeffedcba9876543210abcdef9876543210, 64'hFEDCBA9876543210, 64'hf27a8ffec7e6be1e);
    Single_test(192'hBEBACAFE12345678B1FECAFE876543219898898974744747, 64'hFEDCBA9876543210, 64'h64ff5c5ace7f03ba);
    Single_test(192'hBEBACAFE12345678B1FECAFE876543219898898974744747, 64'hB1FECAFEBEBAB1FE, 64'hc78f7a5f19428db8);

    $display("\nBurst Test");
    Burst_test();

    @(negedge clk);
    @(negedge clk);

    $finish();
end

endmodule