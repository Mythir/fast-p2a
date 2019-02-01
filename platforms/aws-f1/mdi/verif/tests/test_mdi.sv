// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

/*
 * Testbench for the ptoa metadata interpreter
 *
 * Based on example testbenches in the Fletcher repository
 */

// Register offsets & some default values:
`define REG_STATUS          1
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000005

`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_RETURN_HI       3
`define REG_RETURN_LO       2

`define REG_OFF_ADDR_HI     7
`define REG_OFF_ADDR_LO     6

// Registers for first and last (exclusive) row index
`define REG_FIRST_IDX       4
`define REG_LAST_IDX        5

// Registers for reading MetadataInterpreter data output
`define REG_NUM_VALUES      8
`define REG_COMP_SIZE       9
`define REG_UNCOMP_SIZE     10

`define NUM_REGISTERS       11

// Offset buffer address for fpga memory (must be 4k aligned)
`define OFF_ADDR_HI         32'h00000000
`define OFF_ADDR_LO         32'h00001000
// Offset buffer address in host memory
`define HOST_ADDR           64'h0000000000000120

module test_mdi();

  import tb_type_defines_pkg::*;

  // Number of bytes to copy to cl buffer
  parameter num_buf_bytes = 100;


  int read_data;

  //File loading
  int file_descriptor = 0;
  string file_path = "int64array_nosnap_nodict.prq";
  byte file_data[0:num_buf_bytes];
  int bytes_read = 0;

initial begin

  logic[63:0] host_buffer_address;
  logic[63:0] cl_buffer_address;

  // Power up the testbench
  tb.power_up(.clk_recipe_a(ClockRecipe::A1),
              .clk_recipe_b(ClockRecipe::B0),
              .clk_recipe_c(ClockRecipe::C0));

  tb.nsec_delay(1000);

  tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));

  // Allow memory to initialize
  tb.nsec_delay(27000);

  for (int i=0; i<`NUM_REGISTERS; i++) begin
    tb.peek_bar1(.addr(i*4), .data(read_data));
    $display("[DEBUG] : Register %d: %H", i, read_data);
  end

  $display("[%t] : Initializing buffers", $realtime);

  host_buffer_address = `HOST_ADDR;
  cl_buffer_address = {`OFF_ADDR_HI, `OFF_ADDR_LO};

  // Queue the data movement
  tb.que_buffer_to_cl(
    .chan(0),
    .src_addr(host_buffer_address),
    .cl_addr(cl_buffer_address),
    .len(num_buf_bytes)
  );

  // Load file
  file_descriptor=$fopen(file_path, "rb");

  // Only proceed if fopen succeeded
  if (file_descriptor) begin
    bytes_read = $fread(file_data, file_descriptor);

    if(bytes_read == 100) begin
      for(int c = 0; c < num_buf_bytes; c++) begin
        tb.hm_put_byte(.addr(host_buffer_address + c), .d(file_data[c]));
        $display("[DEBUG] : Writing %H to host memory", file_data[c]);
      end


    end else begin
      $display("Failed to read enough bytes from opened file.\n");
      $finish;
    end

  end else begin
    $display("Could not open test file.\n");
    $finish;
  end

end // initial begin

endmodule // test_mdi
