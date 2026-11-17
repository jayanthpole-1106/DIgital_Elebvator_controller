`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.11.2026 16:23:54
// Design Name: 
// Module Name: elevator_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module elevator_controller #(
    parameter integer CLK_HZ = 100_000_000
)(
    input wire clk,
    input wire reset,
    input wire [3:0] floor_req,

    output reg motor_up,
    output reg motor_down,
    output reg stop,
    output reg door_open,
    output reg [1:0] current_floor,
    output wire busy
);

    // FSM state encoding
    localparam IDLE      = 3'b000;
    localparam MOVE_UP   = 3'b001;
    localparam MOVE_DOWN = 3'b010;
    localparam DOOR_OPEN = 3'b011;

    reg [2:0] state;
    reg [1:0] target_floor;

    // Pending floor requests
    reg [3:0] pending_requests;

    wire [3:0] requests_now =
        pending_requests | floor_req;

    // Clock divider
    reg [31:0] divider;
    wire tick = (divider == CLK_HZ - 1);

    // Door timer
    reg [1:0] door_counter;

    // Select the lowest-numbered pending floor
    function [1:0] first_req;
        input [3:0] req;
        begin
            casez (req)
                4'b???1: first_req = 2'd0;
                4'b??1?: first_req = 2'd1;
                4'b?1??: first_req = 2'd2;
                4'b1???: first_req = 2'd3;
                default: first_req = 2'd0;
            endcase
        end
    endfunction

    wire [1:0] selected_floor = first_req(requests_now);
    wire [3:0] selected_mask = 4'b0001 << selected_floor;

    assign busy = (state != IDLE);

    // Clock divider
    always @(posedge clk) begin
        if (reset)
            divider <= 0;
        else if (tick)
            divider <= 0;
        else
            divider <= divider + 1'b1;
    end

    // Main elevator FSM
    always @(posedge clk) begin
        if (reset) begin
            state            <= IDLE;
            current_floor    <= 2'd0;
            target_floor     <= 2'd0;
            pending_requests <= 4'b0000;
            door_counter     <= 0;
        end
        else begin

            pending_requests <= requests_now;

            case (state)

                IDLE: begin
                    if (|requests_now) begin

                        target_floor <= selected_floor;

                        pending_requests <=
                            requests_now & ~selected_mask;

                        if (selected_floor == current_floor) begin
                            state <= DOOR_OPEN;
                            door_counter <= 0;
                        end
                        else if (selected_floor > current_floor) begin
                            state <= MOVE_UP;
                        end
                        else begin
                            state <= MOVE_DOWN;
                        end
                    end
                end

                MOVE_UP: begin
                    if (tick) begin
                        if (current_floor + 1'b1 >= target_floor) begin
                            current_floor <= target_floor;
                            state <= DOOR_OPEN;
                            door_counter <= 0;

                            pending_requests <=
                                (pending_requests | floor_req)
                                & ~(4'b0001 << target_floor);
                        end
                        else begin
                            current_floor <= current_floor + 1'b1;
                        end
                    end
                end

                MOVE_DOWN: begin
                    if (tick) begin
                        if (current_floor - 1'b1 <= target_floor) begin
                            current_floor <= target_floor;
                            state <= DOOR_OPEN;
                            door_counter <= 0;

                            pending_requests <=
                                (pending_requests | floor_req)
                                & ~(4'b0001 << target_floor);
                        end
                        else begin
                            current_floor <= current_floor - 1'b1;
                        end
                    end
                end

                DOOR_OPEN: begin
                    if (tick) begin
                        if (door_counter == 2) begin
                            state <= IDLE;
                            door_counter <= 0;
                        end
                        else begin
                            door_counter <= door_counter + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

    // Output control logic
    always @(*) begin
        motor_up   = 0;
        motor_down = 0;
        stop       = 0;
        door_open  = 0;

        case (state)

            IDLE: begin
                stop = 1;
            end

            MOVE_UP: begin
                motor_up = 1;
            end

            MOVE_DOWN: begin
                motor_down = 1;
            end

            DOOR_OPEN: begin
                stop = 1;
                door_open = 1;
            end

            default: begin
                stop = 1;
            end

        endcase
    end

endmodule

