`timescale 1ns/1ps

module tb_design;
    reg  [3:0] A;
    reg  [3:0] B;
    wire [3:0] SUM;
    wire       COUT;

    adder4 dut (
        .A(A),
        .B(B),
        .SUM(SUM),
        .COUT(COUT)
    );

    task check;
        input [3:0] a_in;
        input [3:0] b_in;
        reg   [4:0] expected;
        begin
            A = a_in;
            B = b_in;
            #1;
            expected = a_in + b_in;
            if ({COUT, SUM} !== expected) begin
                $display("FAIL: A=%0d B=%0d got COUT=%0b SUM=%0d expected=%0d", a_in, b_in, COUT, SUM, expected);
                $finish;
            end
        end
    endtask

    integer i;
    integer j;

    initial begin
        A = 0;
        B = 0;
        #1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                check(i[3:0], j[3:0]);
            end
        end

        $display("PASS: all vectors");
        $finish;
    end
endmodule
