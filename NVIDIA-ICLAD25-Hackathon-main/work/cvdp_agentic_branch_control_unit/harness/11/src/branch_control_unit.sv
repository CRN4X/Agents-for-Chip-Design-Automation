module branch_control_unit(
    input  logic test_0,
    input  logic test_1,
    input  logic test_2,
    input  logic test_3,
    input  logic i_0,
    input  logic i_1,
    input  logic i_2,
    input  logic i_3,
    output logic o_0,
    output logic o_1,
    output logic o_2,
    output logic o_3
);

`ifdef BUG_0
    initial begin
        $display("BUG_0 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_0 is NOT ACTIVE");
    end
`endif

`ifdef BUG_1
    initial begin
        $display("BUG_1 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_1 is NOT ACTIVE");
    end
`endif

`ifdef BUG_2
    initial begin
        $display("BUG_2 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_2 is NOT ACTIVE");
    end
`endif

`ifdef BUG_3
    initial begin
        $display("BUG_3 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_3 is NOT ACTIVE");
    end
`endif

`ifdef BUG_4
    initial begin
        $display("BUG_4 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_4 is NOT ACTIVE");
    end
`endif

`ifdef BUG_5
    initial begin
        $display("BUG_5 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_5 is NOT ACTIVE");
    end
`endif

`ifdef BUG_6
    initial begin
        $display("BUG_6 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_6 is NOT ACTIVE");
    end
`endif

`ifdef BUG_7
    initial begin
        $display("BUG_7 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_7 is NOT ACTIVE");
    end
`endif

`ifdef BUG_8
    initial begin
        $display("BUG_8 is ACTIVE");
    end
`else
    initial begin
        $display("BUG_8 is NOT ACTIVE");
    end
`endif

always_comb begin 
    case({i_3, i_2, i_1, i_0})
        4'b0000: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_0
                    4'bxxxx: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                `else
                    4'bxxxx: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0001: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_1
                    4'bxxx0: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bxxx1: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                `else
                    4'bxxx0: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bxxx1: begin
                        o_3 = 1'b1;
                        o_2 = 1'b1;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0010: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_2
                    4'bxx0x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bxx1x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                `else
                    4'bxx0x: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bxx1x: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0011: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_3
                    4'bxx00: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bxx01: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bxx10: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bxx11: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `else
                    4'bxx00: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bxx01: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bxx10: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                    4'bxx11: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0100: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_4    
                    4'bx0xx: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx1xx: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                `else
                    4'bx0xx: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx1xx: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0101: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_5
                    4'bx0x0: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx0x1: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bx1x0: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bx1x1: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `else
                    4'bx0x0: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx0x1: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bx1x0: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bx1x1: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0110: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_6    
                    4'bx00x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx01x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bx10x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bx11x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `else
                    4'bx00x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bx01x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                    4'bx10x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                    4'bx11x: begin
                        o_3 = 1'b0;
                        o_2 = 1'b1;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `endif
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b0111: begin
            casex({test_3, test_2, test_1, test_0})
                `ifndef BUG_7
                    4'bx000: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b0;
                    end
                    4'bx001: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b0;
                        o_0 = 1'b1;
                    end
                    4'bx010: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bx011: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                `else
                    4'bx000: begin
                        o_3 = 1'b1;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                    4'bx001: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                    4'bx010: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b1;
                    end
                    4'bx011: begin
                        o_3 = 1'b0;
                        o_2 = 1'b0;
                        o_1 = 1'b1;
                        o_0 = 1'b0;
                    end
                `endif
                4'bx100: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'bx101: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'bx110: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'bx111: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1000: begin
            casex({test_3, test_2, test_1, test_0})
                4'b0xxx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b1xxx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1001: begin
            casex({test_3, test_2, test_1, test_0})
                4'b0xx0: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b0xx1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b1xx0: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b1xx1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1010: begin
            casex({test_3, test_2, test_1, test_0})
                4'b0x0x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b0x1x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b1x0x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b1x1x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1011: begin
            casex({test_3, test_2, test_1, test_0})
                4'b0x00: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b0x01: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b0x10: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b0x11: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b1x00: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b1x01: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b1x10: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b1x11: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1100: begin
            casex({test_3, test_2, test_1, test_0})
                4'b00xx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b01xx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b10xx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b11xx: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1101: begin
            casex({test_3, test_2, test_1, test_0})
                4'b00x0: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b00x1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b01x0: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b01x1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b10x0: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b10x1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b11x0: begin 
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b11x1: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1110: begin
            casex({test_3, test_2, test_1, test_0})
                4'b000x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b001x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b010x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b011x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b100x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b101x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b110x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b111x: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        4'b1111: begin
            casex({test_3, test_2, test_1, test_0})
                4'b0000: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b0001: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b0010: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b0011: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b0100: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b0101: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b0110: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b0111: begin
                    o_3 = 1'b0;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b1000: begin
                    o_3 = 1'b1;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b1001: begin
                    o_3 = 1'b1;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b1010: begin
                    o_3 = 1'b1;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b1011: begin
                    o_3 = 1'b1;
                    o_2 = 1'b0;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                4'b1100: begin
                    o_3 = 1'b1;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
                4'b1101: begin
                    o_3 = 1'b1;
                    o_2 = 1'b1;
                    o_1 = 1'b0;
                    o_0 = 1'b1;
                end
                4'b1110: begin
                    o_3 = 1'b1;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b0;
                end
                4'b1111: begin
                    o_3 = 1'b1;
                    o_2 = 1'b1;
                    o_1 = 1'b1;
                    o_0 = 1'b1;
                end
                default: begin
                    o_3 = 1'b0;
                    o_2 = 1'b0;
                    o_1 = 1'b0;
                    o_0 = 1'b0;
                end
            endcase
        end
        default: begin
            o_3 = 1'b0;
            o_2 = 1'b0;
            o_1 = 1'b0;
            o_0 = 1'b0;
        end
    endcase
end

endmodule

