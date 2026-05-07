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
    
    // --- Add these Registers inside pixel_generation ---
reg [9:0] car_x_reg;           // X position of the "car"
localparam CAR_Y = 250;        // Fixed Y lane for the car
localparam CAR_WIDTH = 80;
localparam CAR_HEIGHT = 40;
localparam CAR_SPEED = 2;      // How many pixels it moves per frame

// --- Car Movement Logic ---
always @(posedge clk or posedge reset) begin
    if(reset) begin
        car_x_reg <= 0;
    end
    else if(refresh_tick) begin // Move once per screen refresh (60Hz)
        if(car_x_reg >= X_MAX)
            car_x_reg <= 0;     // Wrap around
        else
            car_x_reg <= car_x_reg + CAR_SPEED;
    end
end

// --- Collision Detection ---
wire collision;
assign collision = (sq_x_r >= car_x_reg) && (sq_x_l <= car_x_reg + CAR_WIDTH) &&
                   (sq_y_b >= CAR_Y) && (sq_y_t <= CAR_Y + CAR_HEIGHT);

// --- Modify your Square movement to handle Reset on Collision ---
    always @(posedge clk or posedge reset) begin
        if(reset || collision) begin // Reset frog to start if hit
            sq_x_reg <= 320;        // Start middle-bottom
            sq_y_reg <= 400;
        end
        else if(rx_done) begin
            case(rx_data)
                8'h77, 8'h57: if(sq_y_reg >= STEP) sq_y_reg <= sq_y_reg - STEP; // W
                8'h73, 8'h53: if(sq_y_reg <= Y_MAX - SQUARE_SIZE - STEP) sq_y_reg <= sq_y_reg + STEP; // S
                8'h61, 8'h41: if(sq_x_reg >= STEP) sq_x_reg <= sq_x_reg - STEP; // A
                8'h64, 8'h44: if(sq_x_reg <= X_MAX - SQUARE_SIZE - STEP) sq_x_reg <= sq_x_reg + STEP; // D
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
    wire car_on;
assign car_on = (x >= car_x_reg) && (x <= car_x_reg + CAR_WIDTH) &&
                (y >= CAR_Y) && (y <= CAR_Y + CAR_HEIGHT);

    always @* begin
        if(~video_on)
            rgb = 12'h000;
        else if(sq_on)
            rgb = sw_color;        // Your "Frog"
        else if(car_on)
            rgb = 12'h00F;        // The "Car" (Red in 12-bit RRRRGGGGBBBB)
        else
            rgb = BG_RGB;         // Background
    end
    
endmodule
