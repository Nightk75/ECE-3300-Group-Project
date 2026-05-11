`timescale 1ns / 1ps

// Master testbench for the VGA/UART/FIFO game design.

module top_master_tb;

    // ------------------------------------------------------------
    // Testbench constants
    // ------------------------------------------------------------
    localparam CLK_PERIOD_NS    = 10;  // 100 MHz
    localparam UART_CLKS_PER_BIT = 16; // Faster than hardware setting for simulation

    integer tests_run  = 0;
    integer tests_pass = 0;
    integer tests_fail = 0;
    integer i;

    // ------------------------------------------------------------
    // DUT: full top-level integration test
    // ------------------------------------------------------------
    reg clk_100MHz;
    reg reset;
    reg [11:0] color;
    reg UART_TXD_IN;

    wire hsync;
    wire vsync;
    wire [11:0] rgb;
    wire [15:0] led;
    wire [6:0] seg;
    wire [7:0] an;

    top dut (
        .clk_100MHz(clk_100MHz),
        .reset(reset),
        .color(color),
        .UART_TXD_IN(UART_TXD_IN),
        .hsync(hsync),
        .vsync(vsync),
        .rgb(rgb),
        .led(led),
        .seg(seg),
        .an(an)
    );

    // Override UART baud divisor to keep simulation short.
    defparam dut.uart_unit.CLKS_PER_BIT = UART_CLKS_PER_BIT;


    // Extra direct pixel_generation instance for fast functional tests
   
    reg pg_video_on;
    reg [9:0] pg_x, pg_y;
    reg [7:0] pg_rx_data;
    reg pg_rx_done;
    wire [11:0] pg_rgb;
    wire pg_collision;
    wire pg_win;

    pixel_generation pg_direct (
        .clk(clk_100MHz),
        .reset(reset),
        .video_on(pg_video_on),
        .x(pg_x),
        .y(pg_y),
        .sw_color(color),
        .rx_data(pg_rx_data),
        .rx_done(pg_rx_done),
        .rgb(pg_rgb),
        .collision(pg_collision),
        .win(pg_win)
    );


    // Clock generation
 
    initial begin
        clk_100MHz = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk_100MHz = ~clk_100MHz;
    end


    // Common checking task

    task check_equal;
        input [127:0] test_name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            tests_run = tests_run + 1;
            if (actual === expected) begin
                tests_pass = tests_pass + 1;
                $display("PASS: %0s actual=0x%0h expected=0x%0h", test_name, actual, expected);
            end else begin
                tests_fail = tests_fail + 1;
                $display("FAIL: %0s actual=0x%0h expected=0x%0h", test_name, actual, expected);
            end
        end
    endtask


    // Reset task

    task apply_reset;
        begin
            reset       = 1'b1;
            UART_TXD_IN = 1'b1;
            color       = 12'h0F0;
            pg_video_on = 1'b1;
            pg_x        = 10'd20;
            pg_y        = 10'd220;
            pg_rx_data  = 8'h00;
            pg_rx_done  = 1'b0;
            repeat (8) @(posedge clk_100MHz);
            reset = 1'b0;
            repeat (4) @(posedge clk_100MHz);
        end
    endtask


    // UART stimulus task: sends 1 start bit, 8 data bits LSB-first, 1 stop bit

    task uart_send_byte;
        input [7:0] data;
        begin
            UART_TXD_IN = 1'b1;
            repeat (UART_CLKS_PER_BIT) @(posedge clk_100MHz);

            UART_TXD_IN = 1'b0; // start bit
            repeat (UART_CLKS_PER_BIT) @(posedge clk_100MHz);

            for (i = 0; i < 8; i = i + 1) begin
                UART_TXD_IN = data[i];
                repeat (UART_CLKS_PER_BIT) @(posedge clk_100MHz);
            end

            UART_TXD_IN = 1'b1; // stop bit
            repeat (UART_CLKS_PER_BIT) @(posedge clk_100MHz);
            repeat (6) @(posedge clk_100MHz);
        end
    endtask


    // Pixel-generator direct movement task

    task pg_move;
        input [7:0] key;
        begin
            pg_rx_data = key;
            pg_rx_done = 1'b1;
            @(posedge clk_100MHz);
            pg_rx_done = 1'b0;
            @(posedge clk_100MHz);
        end
    endtask

    // Main test sequence

    initial begin
        $display("Starting master testbench...");
        apply_reset();

        // 1. Reset verification
        check_equal("direct pixel reset x", pg_direct.sq_x_reg, 32'd20);
        check_equal("direct pixel reset y", pg_direct.sq_y_reg, 32'd220);
        check_equal("top latched collision reset", dut.collision_latched, 32'd0);
        check_equal("top latched win reset", dut.win_latched, 32'd0);

        // 2. Movement verification using tasks and for loops
        // Move right three times: 20 -> 50
        for (i = 0; i < 3; i = i + 1) begin
            pg_move(8'h64); // 'd'
        end
        check_equal("move right loop", pg_direct.sq_x_reg, 32'd50);
        check_equal("y unchanged after right loop", pg_direct.sq_y_reg, 32'd220);

        // Move up two times: 220 -> 200
        for (i = 0; i < 2; i = i + 1) begin
            pg_move(8'h77); // 'w'
        end
        check_equal("move up loop", pg_direct.sq_y_reg, 32'd200);

        // Move left once and down once: x 50 -> 40, y 200 -> 210
        pg_move(8'h61); // 'a'
        pg_move(8'h73); // 's'
        check_equal("move left once", pg_direct.sq_x_reg, 32'd40);
        check_equal("move down once", pg_direct.sq_y_reg, 32'd210);

        // 3. Boundary verification: repeated left commands should not underflow
        for (i = 0; i < 20; i = i + 1) begin
            pg_move(8'h61); // 'a'
        end
        check_equal("left boundary clamp", pg_direct.sq_x_reg, 32'd0);

        // 4. Color/rendering verification
        pg_x = pg_direct.sq_x_reg + 1;
        pg_y = pg_direct.sq_y_reg + 1;
        #1;
        check_equal("frog renders selected color", pg_rgb, {20'd0, color});

        pg_video_on = 1'b0;
        #1;
        check_equal("blank outside video_on", pg_rgb, 32'h000);
        pg_video_on = 1'b1;

        // 5. Collision verification by forcing frog into car 1's rectangle
        force pg_direct.sq_x_reg = 10'd150;
        force pg_direct.sq_y_reg = 10'd0;
        pg_x = 10'd160;
        pg_y = 10'd10;
        #1;
        check_equal("collision detected", pg_collision, 32'd1);
        release pg_direct.sq_x_reg;
        release pg_direct.sq_y_reg;
        apply_reset();

        // 6. Win verification by forcing frog into trophy rectangle
        force pg_direct.sq_x_reg = 10'd600;
        force pg_direct.sq_y_reg = 10'd225;
        pg_x = 10'd605;
        pg_y = 10'd230;
        #1;
        check_equal("win detected", pg_win, 32'd1);
        release pg_direct.sq_x_reg;
        release pg_direct.sq_y_reg;
        apply_reset();

        // 7. UART/top-level integration verification
        // Send multiple characters using a loop.  This checks UART reception,
        // FIFO write/read, seven-seg value path, and LED byte display path.
        for (i = 0; i < 4; i = i + 1) begin
            uart_send_byte(8'h64); // 'd'
        end
        repeat (20) @(posedge clk_100MHz);
        check_equal("UART/FIFO/LED data path", led[8:1], 32'h64);
        check_equal("FIFO not full after normal typing", led[0], 32'd0);

        // 8. VGA sanity checks: x/y counters should advance and video_on path should exist
        repeat (20) @(posedge clk_100MHz);
        check_equal("VGA x counter nonzero after clocks", (dut.w_x != 0), 32'd1);

        // Final report
        $display("--------------------------------------------------");
        $display("Tests run : %0d", tests_run);
        $display("Tests pass: %0d", tests_pass);
        $display("Tests fail: %0d", tests_fail);
        $display("--------------------------------------------------");

        if (tests_fail == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TESTBENCH FAILED");
        end

        $finish;
    end

endmodule
