`timescale 1ns / 1ps

module pixel_generation(
    input clk,                              // 100MHz from Basys 3
    input reset,                            // btnC
    input video_on,                         // from VGA controller
    input [9:0] x, y,                       // from VGA controller
    input [11:0] sw_color,
    input [7:0] rx_data,     // From UART
    input rx_done,           // High for 1 cycle when char received
    output reg [11:0] rgb                   // to DAC, to VGA controller
    );
    
    parameter X_MAX = 639;                  // right border of display area
    parameter Y_MAX = 479;                  // bottom border of display area
    //parameter SQ_RGB = 12'h0FF;             // red & green = yellow for square
    parameter BG_RGB = 12'hF00;             // blue background
    parameter SQUARE_SIZE = 64;             // width of square sides in pixels
    parameter SQUARE_VELOCITY_POS = 2;      // set position change value for positive direction
    parameter SQUARE_VELOCITY_NEG = -2;     // set position change value for negative direction  
    
    // ASCII Constants
    localparam char_w = 8'h77;
    localparam char_a = 8'h61;
    localparam char_s = 8'h73;
    localparam char_d = 8'h64;
    localparam STEP   = 10; // Pixels to move per keypress
    
    // create a 60Hz refresh tick at the start of vsync 
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0;
    
    // square boundaries and position
    wire [9:0] sq_x_l, sq_x_r;              // square left and right boundary
    wire [9:0] sq_y_t, sq_y_b;              // square top and bottom boundary
    
    reg [9:0] sq_x_reg, sq_y_reg;           // regs to track left, top position
    wire [9:0] sq_x_next, sq_y_next;        // buffer wires
    
    reg [9:0] x_delta_reg, y_delta_reg;     // track square speed
    reg [9:0] x_delta_next, y_delta_next;   // buffer regs    
    
    // register control
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            sq_x_reg <= 100; 
            sq_y_reg <= 100;
        end
        else if(rx_done) begin
            case(rx_data)
                8'h77, 8'h57: if(sq_y_reg >= STEP) sq_y_reg <= sq_y_reg - STEP;
                8'h73, 8'h53: if(sq_y_reg <= Y_MAX - SQUARE_SIZE - STEP) sq_y_reg <= sq_y_reg + STEP;
                8'h61, 8'h41: if(sq_x_reg >= STEP) sq_x_reg <= sq_x_reg - STEP;
                8'h64, 8'h44: if(sq_x_reg <= X_MAX - SQUARE_SIZE - STEP) sq_x_reg <= sq_x_reg + STEP;
            endcase
        end
    end

    assign sq_x_l = sq_x_reg;
    assign sq_y_t = sq_y_reg;
    assign sq_x_r = sq_x_l + SQUARE_SIZE - 1;
    assign sq_y_b = sq_y_t + SQUARE_SIZE - 1;
    
    // square status signal
    wire sq_on;
    assign sq_on = (sq_x_l <= x) && (x <= sq_x_r) &&
                   (sq_y_t <= y) && (y <= sq_y_b);
    
    
    // RGB control
    always @*
        if(~video_on)
            rgb = 12'h000;          // black(no value) outside display area
        else
            if(sq_on)
                rgb = sw_color;       // yellow square
            else
                rgb = BG_RGB;       // blue background
    
endmodule
