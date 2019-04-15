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

    // instantiate Seyedali's implementation
    // wire                          aes_busy;
    wire [DATA_WIDTH-1:0]         result;
    // reg                           aes_busy_prev;
    // reg                           valid_out;
    wire                          valid_out;






   // localparam NUM_CYCLES = 5;
   // reg [NUM_CYCLES-1:0]           valid_r;

   // always @(posedge clk_lookup) begin
   //    if (rst) begin
   //       valid_r <= 0;
   //    end
   //    else begin
   //       valid_r[0] <= valid_in;
   //       valid_r[NUM_CYCLES-1:1] <= valid_r[NUM_CYCLES-2:0];
   //       end
   // end
   // assign valid_out = valid_r[NUM_CYCLES-1];

    aes_encrypt @MODULE_NAME@_aes_inst (
       .datain    (data),
       .key       (key),
       .clk       (clk_lookup),
       .reset     (rst),
       .in_valid  (valid_in),
       .dataout   (result),
       .valid_out (valid_out)
    );

    // always @(posedge clk_lookup) begin
    //     if (rst) begin
    //         aes_busy_prev <= 0;
    //         valid_out     <= 0;
    //     end
    //     else begin
    //         // we're done when we were busy in the previous cycle but are not busy now
    //         if (aes_busy_prev && !aes_busy) begin
    //             valid_out <= 1;
    //         end
    //         // needed... not sure why, but needed...
    //         if (aes_busy) begin
    //             valid_out <= 0;
    //         end
    //         aes_busy_prev <= aes_busy;
    //     end
    // end
    assign tuple_out_@EXTERN_NAME@_output_VALID = valid_out;
    assign tuple_out_@EXTERN_NAME@_output_DATA  = result;

endmodule
