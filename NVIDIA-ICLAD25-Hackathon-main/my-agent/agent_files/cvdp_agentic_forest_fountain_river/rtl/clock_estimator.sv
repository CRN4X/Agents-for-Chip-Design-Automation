module clock_estimator #(
    parameter int COUNT_WIDTH   = 32,
    parameter int CLK_DIV_WIDTH = 3
) (
    input  logic                     clk_sys,
    input  logic                     clk_test,
    input  logic                     rst_n,
    input  logic                     enable,
    input  logic [COUNT_WIDTH-1:0]   count_ref,
    output logic [COUNT_WIDTH-1:0]   o_clock_est,
    output logic                     o_irq
);

    localparam int EDGE_WIDTH = COUNT_WIDTH - CLK_DIV_WIDTH;

    logic [COUNT_WIDTH-1:0] ref_counter;
    logic [EDGE_WIDTH-1:0]  edge_counter;
    logic [CLK_DIV_WIDTH-1:0] clk_test_div;
    logic [2:0]             clk_test_cdc;
    logic                   counting;
    logic                   tst_posedge;
    logic                   done_now;
    logic [EDGE_WIDTH-1:0]  edge_counter_latched;

    // Divide test clock in its own domain to avoid missing high-frequency edges.
    always_ff @(posedge clk_test or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_div <= {CLK_DIV_WIDTH{1'b0}};
        end else begin
            clk_test_div <= clk_test_div + {{(CLK_DIV_WIDTH-1){1'b0}}, 1'b1};
        end
    end

    // Synchronize divided test clock into system clock domain.
    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_cdc <= 3'b000;
        end else begin
            clk_test_cdc <= {clk_test_cdc[1:0], clk_test_div[CLK_DIV_WIDTH-1]};
        end
    end

    assign tst_posedge = (clk_test_cdc[2:1] == 2'b01);
    assign done_now    = counting && (ref_counter == (count_ref - {{(COUNT_WIDTH-1){1'b0}}, 1'b1}));

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            counting    <= 1'b0;
            ref_counter <= {COUNT_WIDTH{1'b0}};
            edge_counter <= {EDGE_WIDTH{1'b0}};
            o_clock_est <= {COUNT_WIDTH{1'b0}};
            o_irq       <= 1'b0;
        end else begin
            o_irq <= 1'b0;

            if (enable && !counting) begin
                counting     <= 1'b1;
                ref_counter  <= {COUNT_WIDTH{1'b0}};
                edge_counter <= {EDGE_WIDTH{1'b0}};
                o_clock_est  <= {COUNT_WIDTH{1'b0}};
            end else if (counting) begin
                // Count reference cycles.
                ref_counter <= ref_counter + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};

                // Count synchronized divided-clock rising edges.
                if (tst_posedge) begin
                    edge_counter <= edge_counter + {{(EDGE_WIDTH-1){1'b0}}, 1'b1};
                end

                if (done_now) begin
                    counting <= 1'b0;

                    // Include any edge detected on the completion cycle, then rescale.
                    edge_counter_latched = edge_counter;
                    if (tst_posedge) begin
                        edge_counter_latched = edge_counter + {{(EDGE_WIDTH-1){1'b0}}, 1'b1};
                    end
                    o_clock_est <= {edge_counter_latched, {CLK_DIV_WIDTH{1'b0}}};
                    o_irq <= 1'b1;
                    ref_counter <= {COUNT_WIDTH{1'b0}};
                    edge_counter <= {EDGE_WIDTH{1'b0}};
                end
            end
        end
    end

endmodule
