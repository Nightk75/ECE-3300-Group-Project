`timescale 1ns / 1ps

module sync_fifo #(
    parameter DEPTH = 16,
    parameter DWIDTH = 8
)(
    input clk,
    input rstn,              // active-low reset
    input wr_en,
    input rd_en,
    input [DWIDTH-1:0] din,
    output reg [DWIDTH-1:0] dout,
    output empty,
    output full
);

    reg [$clog2(DEPTH)-1:0] wptr;
    reg [$clog2(DEPTH)-1:0] rptr;
    reg [DWIDTH-1:0] fifo [0:DEPTH-1];

    always @(posedge clk) begin
        if (!rstn) begin
            wptr <= 0;
        end
        else if (wr_en && !full) begin
            fifo[wptr] <= din;
            wptr <= wptr + 1;
        end
    end

    always @(posedge clk) begin
        if (!rstn) begin
            rptr <= 0;
            dout <= 0;
        end
        else if (rd_en && !empty) begin
            dout <= fifo[rptr];
            rptr <= rptr + 1;
        end
    end

    assign empty = (wptr == rptr);
    assign full  = ((wptr + 1) == rptr);

endmodule