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
  parameter num_buf_bytes = 1000;


  int read_data;

  //Error checking
  int         error_count;
  int         timeout_count;
  int         fail;
  logic [3:0] status;

  //File loading
  int file_descriptor = 0;
  string file_path = "int64array_nosnap_nodict.prq";
  byte file_data[0:num_buf_bytes-1];
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

    if(bytes_read == num_buf_bytes) begin
      $display("[DEBUG] : First 20 bytes get displayed for debugging purposes.");
      for(int c = 0; c < num_buf_bytes; c++) begin
        tb.hm_put_byte(.addr(host_buffer_address + c), .d(file_data[c]));
        if(c<20) begin
          $display("[DEBUG] : Writing %H to host memory", file_data[c]);
        end
      end

    end else begin
      $display("[ERROR] : Failed to read proper amount of bytes from opened file. Read %d instead of %d.\n", bytes_read, num_buf_bytes);
      $finish;
    end

  end else begin
    $display("[ERROR] : Could not open test file.\n");
    $finish;
  end

  $display("[%t] : Starting host to CL DMA transfers ", $realtime);

  // Start transfers of data to CL DDR
  tb.start_que_to_cl(.chan(0));

  timeout_count = 0;
  do begin
    status[0] = tb.is_dma_to_cl_done(.chan(0));
    #10ns;
    timeout_count++;
  end while ((status != 4'hf) && (timeout_count < 4000));

  if (timeout_count >= 4000) begin
    $display("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
    error_count++;
  end

  tb.nsec_delay(1000);

  $display("[%t] : Initializing UserCore ", $realtime);

  // Put the units in reset:
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));

  // Initialize buffer addressess:
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_LO), .data(`OFF_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_HI), .data(`OFF_ADDR_HI));

  $display("[%t] : Starting UserCore", $realtime);

  // Start UserCore, taking units out of reset
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));

  // Poll status at an interval of 1000 nsec
  // For the real thing, you should probably increase this to put 
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(1000);
      tb.peek_bar1(.addr(4*`REG_STATUS), .data(read_data));
      $display("[%t] : UserCore status: %H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);

  //Get the custom return register values
  tb.peek_bar1(.addr(4*`REG_UNCOMP_SIZE), .data(read_data));
  $display("[%t] : Return register uncomp size: %d", $realtime, read_data);
  tb.peek_bar1(.addr(4*`REG_COMP_SIZE), .data(read_data));
  $display("[%t] : Return register comp size: %d", $realtime, read_data);
  tb.peek_bar1(.addr(4*`REG_NUM_VALUES), .data(read_data));
  $display("[%t] : Return register num values: %d", $realtime, read_data);

  // Report pass/fail status
  $display("[%t] : Checking total error count...", $realtime);
  if (error_count > 0) begin
    fail = 1;
  end
  $display("[%t] : Detected %3d errors during this test", $realtime, error_count);

  if (fail || (tb.chk_prot_err_stat())) begin
    $display("[%t] : *** TEST FAILED ***", $realtime);
  end else begin
    $display("[%t] : *** TEST PASSED ***", $realtime);
  end

  $finish;


end // initial begin

endmodule // test_mdi
