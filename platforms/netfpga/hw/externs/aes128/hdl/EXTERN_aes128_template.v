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
        [DATA_WIDTH+KEY_WIDTH-1    : DATA_WIDTH               ] : key
        [DATA_WIDTH-1              : 0                        ] : data
*/

    // convert the input data
    wire                          valid_in = tuple_in_@EXTERN_NAME@_input_VALID;
    wire                          statefulValid_in = tuple_in_@EXTERN_NAME@_input_DATA[INPUT_WIDTH-1];
    wire [KEY_WIDTH-1:0]          key      = tuple_in_@EXTERN_NAME@_input_DATA[KEY_WIDTH+DATA_WIDTH-1:DATA_WIDTH];
    wire [DATA_WIDTH-1:0]         data     = tuple_in_@EXTERN_NAME@_input_DATA[KEY_WIDTH-1:0];

    wire [DATA_WIDTH-1:0]         result;
    wire                          valid_out;

    AES @MODULE_NAME@_aes_inst (
       .clk        (clk_lookup),
       .rst        (rst),
       .dvalid_in  (valid_in),
       .plaintext  (data),
       .key        (key),
       .dvalid_out (valid_out),
       .ciphertext (result)
    );

    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = result;

endmodule
