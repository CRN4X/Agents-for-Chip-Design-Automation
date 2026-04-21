`timescale 1ns/1ps

module clock_estimator #(
    parameter int COUNT_WIDTH   = 32,
    parameter int CLK_DIV_WIDTH = 3
) (
    input  logic                   clk_sys,
    input  logic                   clk_test,
    input  logic                   rst_n,
    input  logic                   enable,
    input  logic [COUNT_WIDTH-1:0] count_ref,
    output logic [COUNT_WIDTH-1:0] o_clock_est,
    output logic                   o_irq
);

    localparam int EDGE_WIDTH = COUNT_WIDTH - CLK_DIV_WIDTH;

    logic [COUNT_WIDTH-1:0] ref_counter;
    logic [EDGE_WIDTH-1:0]  edge_counter;
    logic                   counting;

    logic [CLK_DIV_WIDTH-1:0] clk_test_div;
    logic                     clk_test_div_msb;
    logic [2:0]               clk_test_cdc;
    logic                     tst_posedge;
    logic [EDGE_WIDTH-1:0]    edge_counter_next;

    assign clk_test_div_msb = clk_test_div[CLK_DIV_WIDTH-1];
    assign tst_posedge      = (clk_test_cdc[2:1] == 2'b01);
    assign edge_counter_next = edge_counter + {{(EDGE_WIDTH-1){1'b0}}, tst_posedge};

    // Divide high-frequency test clock in its own domain.
    always_ff @(posedge clk_test or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_div <= {CLK_DIV_WIDTH{1'b0}};
        end else begin
            clk_test_div <= clk_test_div + {{(CLK_DIV_WIDTH-1){1'b0}}, 1'b1};
        end
    end

    // Synchronize divided clock into clk_sys domain.
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_cdc <= 3'b000;
        end else begin
            clk_test_cdc <= {clk_test_cdc[1:0], clk_test_div_msb};
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            ref_counter  <= {COUNT_WIDTH{1'b0}};
            edge_counter <= {EDGE_WIDTH{1'b0}};
            counting     <= 1'b0;
            o_clock_est  <= {COUNT_WIDTH{1'b0}};
            o_irq        <= 1'b0;
        end else begin
            o_irq <= 1'b0;

            if (enable && !counting) begin
                counting     <= 1'b1;
                ref_counter  <= {COUNT_WIDTH{1'b0}};
                edge_counter <= {EDGE_WIDTH{1'b0}};
                o_clock_est  <= {COUNT_WIDTH{1'b0}};
            end else if (counting) begin
                ref_counter  <= ref_counter + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                edge_counter <= edge_counter_next;

                if (ref_counter == (count_ref - {{(COUNT_WIDTH-1){1'b0}}, 1'b1})) begin
                    counting    <= 1'b0;
                    o_clock_est <= {edge_counter_next, {CLK_DIV_WIDTH{1'b0}}};
                    o_irq       <= 1'b1;
                end
            end
        end
    end

endmodule
