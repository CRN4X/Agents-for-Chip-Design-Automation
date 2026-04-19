module clock_estimator #(
    parameter int COUNT_WIDTH   = 32,
    parameter int CLK_DIV_WIDTH = 2
) (
    input  logic                   clk_sys,
    input  logic                   clk_test,
    input  logic                   rst_n,
    input  logic                   enable,
    input  logic [COUNT_WIDTH-1:0] count_ref,
    output logic [COUNT_WIDTH-1:0] o_clock_est,
    output logic                   o_irq
);

    logic [COUNT_WIDTH-1:0]               ref_counter;
    logic [COUNT_WIDTH-CLK_DIV_WIDTH-1:0] edge_counter;
    logic                                 counting;

    logic [CLK_DIV_WIDTH-1:0] clk_test_div;
    logic                     div_event_toggle;
    logic [2:0]               clk_test_cdc;
    logic                     tst_posedge;

    always_ff @(posedge clk_test or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_div     <= {CLK_DIV_WIDTH{1'b0}};
            div_event_toggle <= 1'b0;
        end else begin
            clk_test_div <= clk_test_div + {{(CLK_DIV_WIDTH-1){1'b0}}, 1'b1};
            if (clk_test_div == {1'b0, {(CLK_DIV_WIDTH-1){1'b1}}}) begin
                div_event_toggle <= ~div_event_toggle;
            end
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            clk_test_cdc <= 3'b000;
        end else begin
            clk_test_cdc <= {clk_test_cdc[1:0], div_event_toggle};
        end
    end

    always_comb begin
        tst_posedge = clk_test_cdc[2] ^ clk_test_cdc[1];
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            counting <= 1'b0;
        end else if (enable && !counting) begin
            counting <= 1'b1;
        end else if (counting && (ref_counter >= (count_ref - {{(COUNT_WIDTH-1){1'b0}}, 1'b1}))) begin
            counting <= 1'b0;
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            ref_counter <= {COUNT_WIDTH{1'b0}};
        end else if (counting) begin
            ref_counter <= ref_counter + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
        end else begin
            ref_counter <= {COUNT_WIDTH{1'b0}};
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            edge_counter <= {(COUNT_WIDTH-CLK_DIV_WIDTH){1'b0}};
        end else if (counting && tst_posedge) begin
            edge_counter <= edge_counter + {{(COUNT_WIDTH-CLK_DIV_WIDTH-1){1'b0}}, 1'b1};
        end else if (!counting) begin
            edge_counter <= {(COUNT_WIDTH-CLK_DIV_WIDTH){1'b0}};
        end
    end

    always_ff @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            o_clock_est <= {COUNT_WIDTH{1'b0}};
            o_irq       <= 1'b0;
        end else if (enable && !counting) begin
            o_clock_est <= {COUNT_WIDTH{1'b0}};
            o_irq       <= 1'b0;
        end else if (counting && (ref_counter >= (count_ref - {{(COUNT_WIDTH-1){1'b0}}, 1'b1}))) begin
            o_clock_est <= {edge_counter, {CLK_DIV_WIDTH{1'b0}}};
            o_irq       <= 1'b1;
        end else begin
            o_irq <= 1'b0;
        end
    end

endmodule
