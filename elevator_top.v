
module elevator_top (
    input wire clk,
    input wire [3:0] sw,
    input wire [3:0] btn,
    output wire [7:0] led
);

    // Reset using SW0
    wire reset;
    assign reset = sw[0];

    // Button synchronization
    reg [3:0] btn_sync0;
    reg [3:0] btn_sync1;

    // Button debouncing
    reg [3:0] btn_stable;
    reg [3:0] btn_prev;

    localparam integer CLK_HZ = 100_000_000;
    localparam integer DB_COUNT_MAX = 2_000_000;
    localparam integer DB_WIDTH = 21;

    reg [DB_WIDTH-1:0] debounce_count [0:3];

    integer i;

    // Synchronize buttons to FPGA clock
    always @(posedge clk) begin
        if (reset) begin
            btn_sync0 <= 4'b0000;
            btn_sync1 <= 4'b0000;
        end
        else begin
            btn_sync0 <= btn;
            btn_sync1 <= btn_sync0;
        end
    end

    // Debounce all four buttons
    always @(posedge clk) begin
        if (reset) begin
            btn_stable <= 4'b0000;
            btn_prev <= 4'b0000;

            for (i = 0; i < 4; i = i + 1)
                debounce_count[i] <= 0;
        end
        else begin
            btn_prev <= btn_stable;

            for (i = 0; i < 4; i = i + 1) begin

                if (btn_sync1[i] == btn_stable[i]) begin
                    debounce_count[i] <= 0;
                end
                else if (debounce_count[i] >= DB_COUNT_MAX-1) begin
                    btn_stable[i] <= btn_sync1[i];
                    debounce_count[i] <= 0;
                end
                else begin
                    debounce_count[i] <=
                        debounce_count[i] + 1'b1;
                end

            end
        end
    end

    // Generate one-cycle floor request pulses
    wire [3:0] floor_req;

    assign floor_req = btn_stable & ~btn_prev;

    // Elevator controller outputs
    wire motor_up;
    wire motor_down;
    wire stop;
    wire door_open;
    wire busy;

    wire [1:0] current_floor;

    // Instantiate elevator controller
    elevator_controller #(
        .CLK_HZ(CLK_HZ)
    ) controller_inst (
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

    // Display status using LEDs
    assign led[1:0] = current_floor;
    assign led[2]   = motor_up;
    assign led[3]   = motor_down;
    assign led[4]   = door_open;
    assign led[5]   = busy;
    assign led[6]   = stop;
    assign led[7]   = 1'b0;

endmodule
