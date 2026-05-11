`timescale 1ns / 1ps

module top(
    input clk_100MHz,       // from Basys 3
    input reset,            // btnC on Basys 3
    input [11:0] color,
    input UART_TXD_IN,
    input btnU,
    input btnD,
    input btnL,
    input btnR,
    output hsync,           // VGA port on Basys 3
    output vsync,           // VGA port on Basys 3
    output [11:0] rgb,       // to DAC, 3 bits to VGA port on Basys 3
    output [15:0] led,
    output [6:0] seg,
    output [7:0] an 
    );
    
    wire w_video_on, w_p_tick;
    wire [9:0] w_x, w_y;
    reg [11:0] rgb_reg;
    wire[11:0] rgb_next;
    wire w_rx_dv;
    wire [7:0] w_rx_byte;
    wire [7:0] w_fifo_dout;
    wire w_fifo_empty;
    wire w_fifo_full;
    wire w_fifo_rd_en;
    wire w_fifo_data_valid;
    wire w_collision;
    wire w_win;
    
    vga_controller vc(.clk_100MHz(clk_100MHz), .reset(reset), .video_on(w_video_on), .hsync(hsync), 
                      .vsync(vsync), .p_tick(w_p_tick), .x(w_x), .y(w_y));
    pixel_generation pg(
        .clk(clk_100MHz), 
        .reset(reset), 
        .video_on(w_video_on), 
        .x(w_x), 
        .y(w_y), 
        .sw_color(color),
        .rx_data(w_fifo_dout),
        .rx_done(w_fifo_data_valid),
        .rgb(rgb_next),
        .collision(w_collision),
        .win(w_win),
        .btnU(btnU),
        .btnD(btnD),
        .btnL(btnL),
        .btnR(btnR)
    );
    
    // Instantiate UART Receiver
    uart_rx #(.CLKS_PER_BIT(10417)) uart_unit ( // Set for 9600 baud
        .i_Clock(clk_100MHz),
        .i_Rx_Serial(UART_TXD_IN),
        .o_Rx_DV(w_rx_dv),
        .o_Rx_Byte(w_rx_byte)
    );
    
    sync_fifo #(.DEPTH(16), .DWIDTH(8)) uart_fifo (
    .clk(clk_100MHz),
    .rstn(~reset),
    .wr_en(w_rx_dv && !w_fifo_full),
    .din(w_rx_byte),
    .rd_en(w_fifo_rd_en),
    .dout(w_fifo_dout),
    .empty(w_fifo_empty),
    .full(w_fifo_full)
    );
    
    reg fifo_rd_en_reg;
    reg fifo_data_valid_reg;
    
    always @(posedge clk_100MHz or posedge reset) begin
        if (reset) begin
            fifo_rd_en_reg <= 1'b0;
            fifo_data_valid_reg <= 1'b0;
        end
        else begin
            fifo_rd_en_reg <= !w_fifo_empty;
            fifo_data_valid_reg <= fifo_rd_en_reg;
        end
    end
    
    assign w_fifo_rd_en = fifo_rd_en_reg;
    assign w_fifo_data_valid = fifo_data_valid_reg;
        
    seven_seg_driver seg_unit(
    .clk(clk_100MHz),
    .value(w_fifo_dout),
    .seg(seg),
    .an(an)
    );
    
    always @(posedge clk_100MHz)
        if(w_p_tick)
            rgb_reg <= rgb_next;
            
    assign rgb = rgb_reg;
    assign led[0] = w_fifo_full; // turns on if FIFO is full
    assign led[8:1] = w_fifo_dout; // Displays received UART ASCII value (hex) as binary on LEDs
    assign led[15:11] = 0; //unused currently
    
    reg collision_latched;
    reg win_latched;

   always @(posedge clk_100MHz or posedge reset) begin
    if (reset) begin
        collision_latched <= 1'b0;
        win_latched <= 1'b0;
    end
    else if (w_collision) begin
        collision_latched <= 1'b1;
        win_latched <= 1'b0;
    end
    else if (w_win) begin
        win_latched <= 1'b1;
        collision_latched <= 1'b0;
    end
end

    assign led[9] = collision_latched;
    assign led[10] = win_latched;
    
endmodule
