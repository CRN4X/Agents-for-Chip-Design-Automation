`timescale 1ns/1ns

module control_fsm #(
    parameter int NBW_WAIT = 32
) (
    input  logic               clk,
    input  logic               rst_async_n,
    input  logic               i_enable,
    input  logic               i_subsampling,
    output logic [1:0]         o_subsampling,
    input  logic               i_valid,
    output logic [1:0]         o_valid,
    input  logic               i_calc_valid,
    input  logic               i_calc_fail,
    input  logic [NBW_WAIT-1:0] i_wait,
    output logic [1:0]         o_start_calc
);

    localparam int NBW_CNT = 8;
    localparam int NBW_CALCSTART = 4;

    localparam logic [2:0] PROC_CONTROL_CAPTURE_ST = 3'd0;
    localparam logic [2:0] PROC_DATA_CAPTURE_ST    = 3'd1;
    localparam logic [2:0] PROC_CALC_START_ST      = 3'd2;
    localparam logic [2:0] PROC_CALC_ST            = 3'd3;
    localparam logic [2:0] PROC_WAIT_ST            = 3'd4;

    logic [2:0] state_ff, next_state;
    logic [NBW_CNT-1:0] cnt_ff;
    logic [NBW_WAIT-1:0] timecnt_ff;
    logic [NBW_WAIT-1:0] timecnt_ff0;
    logic subsampling_ff;

    logic ctrl_en;
    logic timecnt_en;
    logic cnt_en;
    logic cnt_rstproc;
    logic [1:0] cnt_rstctrl;

    always_comb begin
        next_state = state_ff;

        unique case (state_ff)
            PROC_CONTROL_CAPTURE_ST: begin
                if (i_enable) begin
                    next_state = PROC_DATA_CAPTURE_ST;
                end
            end
            PROC_DATA_CAPTURE_ST: begin
                if (cnt_ff == '0) begin
                    next_state = PROC_CALC_START_ST;
                end
            end
            PROC_CALC_START_ST: begin
                if (cnt_ff == '0) begin
                    next_state = PROC_CALC_ST;
                end
            end
            PROC_CALC_ST: begin
                if (i_calc_fail) begin
                    next_state = PROC_CONTROL_CAPTURE_ST;
                end else if (i_calc_valid) begin
                    next_state = PROC_WAIT_ST;
                end
            end
            PROC_WAIT_ST: begin
                if ((!i_enable) || (timecnt_ff == '0)) begin
                    next_state = PROC_CONTROL_CAPTURE_ST;
                end
            end
            default: begin
                next_state = PROC_CONTROL_CAPTURE_ST;
            end
        endcase
    end

    always_comb begin
        o_start_calc = 1'b0;
        ctrl_en = 1'b0;
        cnt_rstctrl = 1'b0;
        cnt_en = 1'b0;
        timecnt_en = 1'b0;

        unique case (state_ff)
            PROC_CONTROL_CAPTURE_ST: begin
                ctrl_en = i_enable;
                cnt_rstctrl = 1'b1;
            end
            PROC_DATA_CAPTURE_ST: begin
                cnt_en = i_valid;
            end
            PROC_CALC_START_ST: begin
                o_start_calc = 1'b1;
                cnt_en = 1'b1;
            end
            PROC_WAIT_ST: begin
                timecnt_en = 1'b1;
            end
            default: begin
            end
        endcase
    end

    assign o_valid = cnt_en && (state_ff == PROC_DATA_CAPTURE_ST) && (cnt_ff > '0);
    assign cnt_rstproc = (state_ff == PROC_DATA_CAPTURE_ST) && (cnt_ff == '0);
    assign o_subsampling = subsampling_ff;

    always_ff @(posedge clk or negedge rst_async_n) begin
        if (!rst_async_n) begin
            state_ff <= PROC_CONTROL_CAPTURE_ST;
            cnt_ff <= '0;
            timecnt_ff <= '0;
            timecnt_ff0 <= '0;
            subsampling_ff <= 1'b0;
        end else begin
            state_ff <= next_state;

            if (i_calc_valid && (state_ff == PROC_CALC_ST)) begin
                timecnt_ff <= timecnt_ff0;
            end else if (timecnt_en) begin
                timecnt_ff <= timecnt_ff - {{(NBW_WAIT-1){1'b0}}, 1'b1};
            end

            if (cnt_rstctrl) begin
                if (i_subsampling == 1'b1) begin
                    cnt_ff <= 1 << (NBW_CNT - 1);
                end else begin
                    cnt_ff <= 8;
                end
            end else if (cnt_rstproc) begin
                cnt_ff <= (1 << NBW_CALCSTART) - 1;
            end else if (cnt_en) begin
                cnt_ff <= cnt_ff - 1'b1;
            end

            if (ctrl_en) begin
                timecnt_ff0 <= i_wait;
                subsampling_ff <= i_subsampling;
            end
        end
    end

endmodule
