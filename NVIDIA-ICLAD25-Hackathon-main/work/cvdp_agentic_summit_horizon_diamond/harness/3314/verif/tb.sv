module tb;

localparam NS_ROWS = 'd4;
localparam NS_COLS = 'd4;
localparam NBW_COL = 'd2;
localparam NBW_STR = 'd8;
localparam NS_EVT  = 'd8;
localparam NBW_EVT = 'd3;

logic                                clk;
logic                                rst_async_n;
logic [NBW_COL-1:0]                  i_col_sel;
logic [NS_ROWS*NS_COLS-1:0]          i_en_overflow;
logic [(NS_ROWS*NS_COLS*NS_EVT)-1:0] i_event;
logic [(NS_ROWS*NBW_STR)-1:0]        i_data;
logic [NS_ROWS-1:0]                  i_bypass;
logic [NBW_EVT-1:0]                  i_raddr;
logic [NBW_STR-1:0]                  o_data;

event_array #(
    .NS_ROWS(NS_ROWS),
    .NS_COLS(NS_COLS),
    .NBW_COL(NBW_COL),
    .NBW_STR(NBW_STR),
    .NS_EVT(NS_EVT),
    .NBW_EVT(NBW_EVT)
) uu_event_array (
    .clk          (clk          ),
    .rst_async_n  (rst_async_n  ),
    .i_col_sel    (i_col_sel    ),
    .i_en_overflow(i_en_overflow),
    .i_event      (i_event      ),
    .i_data       (i_data       ),
    .i_bypass     (i_bypass     ),
    .i_raddr      (i_raddr      ),
    .o_data       (o_data       )
);

initial begin
    $dumpfile("test.vcd");
    $dumpvars(0,tb);
end

task SimpleTest(int line_to_read, int col_to_read, int r_addr);
    $display("---------------");
    $display("Running test reading row %2d, column %2d, address %2d", line_to_read, col_to_read, r_addr);
    @(negedge clk);
    i_en_overflow = 0;
    i_bypass = {NS_ROWS{1'b1}};
    i_bypass[line_to_read] = 1'b0;
    i_raddr = r_addr;
    i_col_sel = col_to_read;
    i_event = 0;

    for(int i = 1; i <= NS_ROWS*NS_COLS*NS_EVT; i++) begin
        for(int j = 0; j < i; j++) begin
            i_event[NS_ROWS*NS_COLS*NS_EVT-i] = 1'b1;
            @(negedge clk);
        end
        i_event = 0;
    end

    @(negedge clk);

    if((NS_EVT - r_addr + line_to_read*NS_COLS*NS_EVT + col_to_read*NS_EVT) > 2**NBW_STR - 1) begin
        if(o_data != 2**NBW_STR - 1) begin
            $display("FAIL! Received o_data = %2d, when it should have been %2d", o_data, 2**NBW_STR - 1);
        end else begin
            $display("PASS! Received o_data = %2d", o_data);
        end
    end else begin
        if(o_data != (NS_EVT - r_addr + line_to_read*NS_COLS*NS_EVT + col_to_read*NS_EVT)) begin
            $display("FAIL! Received o_data = %d, when it should have been %2d", o_data, (NS_EVT - r_addr + line_to_read*NS_COLS*NS_EVT + col_to_read*NS_EVT));
        end else begin
            $display("PASS! Received o_data = %d", o_data);
        end
    end
endtask

task Reset();
    i_col_sel     = 0;
    i_en_overflow = 0;
    i_event       = 0;
    i_data        = 0;
    i_bypass      = 0;
    i_raddr       = 0;
    rst_async_n = 1;
    #1;
    rst_async_n = 0;
    #2;
    rst_async_n = 1;
    @(negedge clk);
endtask

task TestOverflow(logic overflow);
    $display("---------------");
    $display("Testing overflow in row 0, column 0, address 0");
    @(negedge clk);
    i_en_overflow = overflow;
    i_bypass = {NS_ROWS{1'b1}};
    i_bypass[0] = 1'b0;
    i_raddr = 0;
    i_col_sel = 0;
    i_event = 0;

    for(int i = 0; i <= 2**NBW_STR; i++) begin
        i_event[NS_ROWS*NS_COLS*NS_EVT-NS_EVT] = 1'b1;
        @(negedge clk);
    end
    i_event = 0;

    @(negedge clk);

    if(overflow == 0) begin
        if(o_data != 2**NBW_STR - 1) begin
            $display("FAIL! Received o_data = %2d, when it should have been %2d", o_data, 2**NBW_STR - 1);
        end else begin
            $display("PASS! Received o_data = %2d", o_data);
        end
    end else begin
        if(o_data != 1) begin
            $display("FAIL! Received o_data = %2d, when it should have been %2d", o_data, 1);
        end else begin
            $display("PASS! Received o_data = %2d", o_data);
        end
    end
endtask

always #5 clk = ~clk;

int value;

initial begin
    clk = 0;
    value = 1;
    Reset();

    $display("----------------------");
    $display("This testbench writes:");
    for(int row = 0; row < NS_ROWS; row++) begin
        for(int col = 0; col < NS_COLS; col++) begin
            for(int addr = NS_EVT-1; addr >= 0; addr--) begin
                $display("%2d in row %2d, col %2d, address %2d", value, row, col, addr);
                value++;
            end
        end
    end

    $display("----------------------");
    $display("Note that, if any of those values are bigger than %2d, it will saturate when i_en_overflow = 0, and wrap around when i_en_overflow = 1.", 2**NBW_STR - 1);
    $display("----------------------");

    // Tasks go here
    SimpleTest(0, 0, 0);
    Reset();
    SimpleTest(1, 0, 0);
    Reset();
    SimpleTest(0, 1, 0);
    Reset();
    SimpleTest(0, 0, 1);
    Reset();
    SimpleTest(2, 1, 0);
    Reset();
    SimpleTest(1, 2, 2);
    Reset();
    SimpleTest(1, 2, 7);
    Reset();
    TestOverflow(1'b0);
    Reset();
    TestOverflow(1'b1);
    Reset();

    @(negedge clk);
    @(negedge clk);

    $finish();
end

endmodule