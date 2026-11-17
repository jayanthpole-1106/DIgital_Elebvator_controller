
`timescale 1ns / 1ps

module elevator_tb;

    // ==========================================
    // 1. TESTBENCH SIGNALS
    // ==========================================

    reg clk;
    reg reset;
    reg [3:0] floor_req;

    wire motor_up;
    wire motor_down;
    wire stop;
    wire door_open;
    wire [1:0] current_floor;
    wire busy;


    // ==========================================
    // 2. INSTANTIATE ELEVATOR CONTROLLER
    // ==========================================

    elevator_controller #(
        .CLK_HZ(4)
    ) uut (
        .clk(clk),
        .reset(reset),
        .floor_req(floor_req),

        .motor_up(motor_up),
        .motor_down(motor_down),
        .stop(stop),
        .door_open(door_open),
        .current_floor(current_floor),
        .busy(busy)
    );


    // ==========================================
    // 3. CLOCK GENERATION
    // ==========================================

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // ==========================================
    // 4. FLOOR REQUEST TASK
    // ==========================================

    task request_floor;
        input [3:0] request;

        begin
            @(negedge clk);
            floor_req = request;

            @(negedge clk);
            floor_req = 4'b0000;
        end
    endtask


    // ==========================================
    // 5. CHECK DESTINATION FLOOR
    // ==========================================

    task check_floor;
        input [1:0] expected_floor;

        integer timeout;

        begin
            timeout = 0;

            // Wait for door to open
            while (!door_open && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (!door_open)
                $fatal(1,
                    "FAIL: Door did not open!");

            // Verify current floor
            if (current_floor !== expected_floor)
                $fatal(1,
                    "FAIL: Expected Floor %0d, Reached Floor %0d",
                    expected_floor + 1,
                    current_floor + 1);

            $display(
                "PASS: Reached Floor %0d",
                current_floor + 1
            );

            // Wait for door to close
            repeat (15) @(negedge clk);

            if (door_open !== 1'b0)
                $fatal(1,
                    "FAIL: Door did not close!");

            // Do not check busy here.
            // Another pending request may start.

        end
    endtask


    // ==========================================
    // 6. WAIT FOR COMPLETE IDLE
    // ==========================================

    task check_idle;

        integer timeout;

        begin
            timeout = 0;

            while ((busy || door_open) && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (busy !== 1'b0)
                $fatal(1,
                    "FAIL: Elevator did not return to IDLE!");

            if (door_open !== 1'b0)
                $fatal(1,
                    "FAIL: Door is still open!");

            $display("PASS: Elevator returned to IDLE");
        end

    endtask


    // ==========================================
    // 7. SAFETY CONDITION MONITORING
    // ==========================================

    always @(posedge clk) begin

        if (!reset) begin

            // UP and DOWN cannot operate together
            if (motor_up && motor_down)
                $fatal(1,
                    "FAIL: UP and DOWN active together!");

            // Door cannot open during movement
            if (door_open && (motor_up || motor_down))
                $fatal(1,
                    "FAIL: Door opened during movement!");

            // Check FSM output consistency
            case (uut.state)

                // IDLE
                3'b000: begin
                    if (motor_up || motor_down || door_open)
                        $fatal(1,
                            "FAIL: Invalid IDLE outputs!");
                end

                // MOVE_UP
                3'b001: begin
                    if (!motor_up || motor_down || door_open)
                        $fatal(1,
                            "FAIL: Invalid MOVE_UP outputs!");
                end

                // MOVE_DOWN
                3'b010: begin
                    if (!motor_down || motor_up || door_open)
                        $fatal(1,
                            "FAIL: Invalid MOVE_DOWN outputs!");
                end

                // DOOR_OPEN
                3'b011: begin
                    if (!door_open || motor_up || motor_down)
                        $fatal(1,
                            "FAIL: Invalid DOOR_OPEN outputs!");
                end

                default: begin
                    $fatal(1,
                        "FAIL: Invalid FSM state!");
                end

            endcase

        end

    end


    // ==========================================
    // 8. MAIN TEST SEQUENCE
    // ==========================================

    initial begin

        reset = 1'b1;
        floor_req = 4'b0000;

        $display("------------------------------------");
        $display("ELEVATOR CONTROLLER TEST STARTED");
        $display("------------------------------------");


        // INITIAL RESET
        repeat (3) @(negedge clk);
        reset = 1'b0;


        // ======================================
        // TEST 1: FLOOR 1 TO FLOOR 4
        // ======================================

        $display("TEST 1: Floor 1 to Floor 4");

        request_floor(4'b1000);

        check_floor(2'b11);


        // ======================================
        // TEST 2: FLOOR 4 TO FLOOR 2
        // ======================================

        $display("TEST 2: Floor 4 to Floor 2");

        request_floor(4'b0010);

        check_floor(2'b01);


        // ======================================
        // TEST 3: REQUEST CURRENT FLOOR
        // ======================================

        $display("TEST 3: Request current floor");

        request_floor(4'b0010);

        check_floor(2'b01);


        // ======================================
        // TEST 4: MULTIPLE FLOOR REQUESTS
        // ======================================

        $display("TEST 4: Multiple floor requests");

        // Request Floor 1 and Floor 4 together
        request_floor(4'b1001);

        // First serve Floor 1
        check_floor(2'b00);

        // Then serve pending Floor 4
        check_floor(2'b11);


        // ======================================
        // TEST 5: VERIFY FINAL IDLE STATE
        // ======================================

        $display("TEST 5: Final IDLE verification");

        check_idle();


        // ======================================
        // 9. FINAL RESULT
        // ======================================

        $display("------------------------------------");
        $display("ALL ELEVATOR TESTS PASSED!");
        $display("ALL SAFETY CHECKS PASSED!");
        $display("------------------------------------");

        $finish;

    end

endmodule
