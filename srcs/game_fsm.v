`timescale 1ns / 1ps

module game_fsm(
    input clk,
    input reset,
    input start,
    input collision,
    input win,
    output reg [1:0] state
);

    localparam IDLE = 2'b00;
    localparam PLAY = 2'b01;
    localparam HIT  = 2'b10;
    localparam WON  = 2'b11;

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else begin
            case (state)
                IDLE: begin
                    if (start)
                        state <= PLAY;
                end

                PLAY: begin
                    if (collision)
                        state <= HIT;
                    else if (win)
                        state <= WON;
                end

                HIT: begin
                    if (start)
                        state <= PLAY;
                end
                
                WON: begin
                    if (start)
                        state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule