/*
 * File: @MODULE_NAME@.v
 * Author: Kamila Souckova
 *
 * Auto-generated file.
 *
 * Single-block AES-128-ECB, wrapper only (bring your own AES core)
 */


`timescale 1 ps / 1 ps

module @MODULE_NAME@
#(
    parameter KEY_WIDTH    = 128,
    parameter DATA_WIDTH   = 128,
    parameter INPUT_WIDTH  = DATA_WIDTH+KEY_WIDTH+1,
    parameter RESULT_WIDTH = DATA_WIDTH
)
(
    // Data Path I/O
    input                           clk_lookup,
    input                           rst,
    input                           tuple_in_@EXTERN_NAME@_input_VALID,
    input   [INPUT_WIDTH-1:0]       tuple_in_@EXTERN_NAME@_input_DATA,
    output                          tuple_out_@EXTERN_NAME@_output_VALID,
    output  [RESULT_WIDTH-1:0]      tuple_out_@EXTERN_NAME@_output_DATA
);


/* Tuple format for input:
        [INPUT_WIDTH-1             : INPUT_WIDTH-1            ] : statefulValid_in
        [DATA_WIDTH+KEY_WIDTH-1    : KEY_WIDTH                ] : data
        [KEY_WIDTH-1               : 0                        ] : key
*/

    // convert the input data to readable wires
    wire                          valid_in = tuple_in_@EXTERN_NAME@_input_VALID;
    wire                          statefulValid_in = tuple_in_@EXTERN_NAME@_input_DATA[INPUT_WIDTH-1];
    wire [DATA_WIDTH-1:0]         data     = tuple_in_@EXTERN_NAME@_input_DATA[KEY_WIDTH+DATA_WIDTH-1:KEY_WIDTH];
    wire [KEY_WIDTH-1:0]          key      = tuple_in_@EXTERN_NAME@_input_DATA[KEY_WIDTH-1:0];

    // registers to hold statefulness
    reg                           valid_r;
    reg  [DATA_WIDTH-1:0]         result_r;

    // TODO replace the following with AES instantiation

    // drive the registers
    always @(posedge clk_lookup)
    begin
        if (rst) begin
            valid_r  <= 1'd0;
            result_r <= 'd0;

        end else begin
            valid_r  <= valid_in;
            result_r <= data - key; // for testing
        end
    end

    // Read the result from the register
    wire [DATA_WIDTH-1:0] result_out = result_r;

    // Truncate the output
    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_r;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = {result_out[RESULT_WIDTH-1:0]};

endmodule
