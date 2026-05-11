`timescale 1ns / 1ps

module pixel_generation(
    input clk,                               
    input reset,                             
    input video_on,                          
    input [9:0] x, y,                        
    input [11:0] sw_color,
    input [7:0] rx_data,     
    input rx_done,        
    input btnU,
    input btnD,
    input btnL,
    input btnR,   
    output reg [11:0] rgb,  
    output collision,
    output win
    );
    
    parameter X_MAX = 639;                  
    parameter Y_MAX = 479;                  
    parameter BG_RGB = 12'h2BF;             
    parameter SQUARE_SIZE = 40;             // Reduced size for better gameplay
    
    // ASCII/Movement Constants
    localparam STEP = 10; 
    
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0;
    
    // --- Frog Registers ---
    reg [9:0] sq_x_reg, sq_y_reg;
    wire [9:0] sq_x_l, sq_x_r, sq_y_t, sq_y_b;
    
    // Previous button states for edge detection
    reg btnU_prev, btnD_prev, btnL_prev, btnR_prev;
    
    // One-clock pulse when button is newly pressed
    wire btnU_press = btnU && !btnU_prev;
    wire btnD_press = btnD && !btnD_prev;
    wire btnL_press = btnL && !btnL_prev;
    wire btnR_press = btnR && !btnR_prev;
    
    // --- Car Parameters and Registers ---
    localparam CAR_WIDTH = 40;
    localparam CAR_HEIGHT = 80;
    localparam CAR_SPEED = 3;
    
    // Lane X positions
    localparam LANE1_X = 150;
    localparam LANE2_X = 300;
    localparam LANE3_X = 450;

    reg [9:0] car1_y, car2_y, car3_y;
    
    parameter TROPHY_RGB = 12'hFF0;         // Yellow (RRRRGGGGBBBB)
    localparam TROPHY_SIZE = 30;
    localparam TROPHY_X = 600;              // Right side of screen
    localparam TROPHY_Y = 225;              // Centered vertically (Y_MAX/2 approx)

    // --- Car Movement Logic (Vertical) ---
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            car1_y <= 0;
            car2_y <= Y_MAX + CAR_HEIGHT;
            car3_y <= 0;
        end
        else if(refresh_tick) begin
            // Car 1: Top to Bottom
            if(car1_y >= Y_MAX + CAR_HEIGHT) car1_y <= 0;
            else car1_y <= car1_y + CAR_SPEED;
            
            // Car 2: Bottom to Top
            if(car2_y <= 0) car2_y <= Y_MAX;
            else car2_y <= car2_y - (CAR_SPEED + 1);
            
            // Car 3: Top to Bottom
            if(car3_y >= Y_MAX+ CAR_HEIGHT) car3_y <= 0;
            else car3_y <= car3_y + CAR_SPEED;
        end
    end
    
    wire sq_on;
    assign sq_on = (sq_x_l <= x) && (x <= sq_x_r) && (sq_y_t <= y) && (y <= sq_y_b);

    // --- Collision Detection for 3 Cars ---
    wire car1_on, car2_on, car3_on;
    assign car1_on = (x >= LANE1_X) && (x <= LANE1_X + CAR_WIDTH) && (y >= car1_y) && (y <= car1_y + CAR_HEIGHT);
    assign car2_on = (x >= LANE2_X) && (x <= LANE2_X + CAR_WIDTH) && (y >= car2_y) && (y <= car2_y + CAR_HEIGHT);
    assign car3_on = (x >= LANE3_X) && (x <= LANE3_X + CAR_WIDTH) && (y >= car3_y) && (y <= car3_y + CAR_HEIGHT);

    assign collision = (sq_on && (car1_on || car2_on || car3_on));
    
    // --- Trophy Rendering Logic ---
    wire trophy_on;
    assign trophy_on = (x >= TROPHY_X) && (x <= TROPHY_X + TROPHY_SIZE) &&
                       (y >= TROPHY_Y) && (y <= TROPHY_Y + TROPHY_SIZE);

    // --- Win Detection ---
    assign win = (sq_on && trophy_on);

    // Store previous button values to detect new button presses
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btnU_prev <= 1'b0;
            btnD_prev <= 1'b0;
            btnL_prev <= 1'b0;
            btnR_prev <= 1'b0;
        end
        else begin
            btnU_prev <= btnU;
            btnD_prev <= btnD;
            btnL_prev <= btnL;
            btnR_prev <= btnR;
        end
    end
    
        // --- Frog Movement & Reset Logic ---
    // Movement control:
    // Frog can be moved using UART (WASD) or push buttons
    // btnU = up, btnD = down, btnL = left, btnR = right
    // Reset occurs on:
    // 1. Manual reset
    // 2. Collision (lose)
    // 3. Trophy reached (win)
    
    always @(posedge clk or posedge reset) begin
    if (reset || collision || win) begin 
        sq_x_reg <= 20;
        sq_y_reg <= 220;
    end
    else begin

        // UART movement (one step per keypress)
        if (rx_done) begin
            case (rx_data)
                8'h77, 8'h57: if (sq_y_reg >= STEP) 
                    sq_y_reg <= sq_y_reg - STEP;   // W

                8'h73, 8'h53: if (sq_y_reg <= Y_MAX - SQUARE_SIZE - STEP) 
                    sq_y_reg <= sq_y_reg + STEP;   // S

                8'h61, 8'h41: if (sq_x_reg >= STEP) 
                    sq_x_reg <= sq_x_reg - STEP;   // A

                8'h64, 8'h44: if (sq_x_reg <= X_MAX - SQUARE_SIZE - STEP) 
                    sq_x_reg <= sq_x_reg + STEP;   // D
            endcase
        end

        // Button movement (one step per button press)
        else if (btnU_press && sq_y_reg >= STEP)
            sq_y_reg <= sq_y_reg - STEP;
        
        else if (btnD_press && sq_y_reg <= Y_MAX - SQUARE_SIZE - STEP)
            sq_y_reg <= sq_y_reg + STEP;
        
        else if (btnL_press && sq_x_reg >= STEP)
            sq_x_reg <= sq_x_reg - STEP;
        
        else if (btnR_press && sq_x_reg <= X_MAX - SQUARE_SIZE - STEP)
            sq_x_reg <= sq_x_reg + STEP;
        
    end
end

    assign sq_x_l = sq_x_reg;
    assign sq_y_t = sq_y_reg;
    assign sq_x_r = sq_x_l + SQUARE_SIZE - 1;
    assign sq_y_b = sq_y_t + SQUARE_SIZE - 1;
    

    // --- Updated RGB Output ---
    always @* begin
        if(~video_on)
            rgb = 12'h000;
        else if(sq_on)
            rgb = sw_color;        // Frog
        else if(trophy_on)
            rgb = TROPHY_RGB;      // Yellow Trophy
        else if(car1_on || car2_on || car3_on)
            rgb = 12'hF00;        //  Cars
        else
            rgb = BG_RGB;         // Background
    end
    
endmodule
