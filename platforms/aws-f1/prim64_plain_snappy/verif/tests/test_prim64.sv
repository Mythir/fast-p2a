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
 * Testbench for 64 bit primitive ParquetReader
 *
 * Based on example testbenches in the Fletcher repository
 */

// Register offsets & some default values:
`define REG_STATUS          1
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000004

`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_NUM_VAL         2
`define REG_PAGE_ADDR0      3
`define REG_PAGE_ADDR1      4
`define REG_MAX_SIZE0       5
`define REG_MAX_SIZE1       6
`define REG_VAL_ADDR0       7
`define REG_VAL_ADDR1       8

`define NUM_REGISTERS       9

`define NUM_VAL             10000

// Testbench assumes max_size to be smaller than 2^32
`define MAX_SIZE            59442

// Base address for Parquet file in fpga memory (must be 4k aligned)
`define CL_PAGE_ADDR_HI     32'h00000000
`define CL_PAGE_ADDR_LO     32'h00001000

// Pointer to arrow buffer in fpga memory
`define CL_VAL_BUF_HI       32'h00000000
`define CL_VAL_BUF_LO       32'h00020000

// Base address for pages in host memory
`define HOST_PAGE_ADDR      64'h0000000000001000

// Pointer to arrow buffer in host memory
`define HOST_VAL_BUF        64'h0000000000020000

`define PRIM_WIDTH          64


module test_prim64();

  import tb_type_defines_pkg::*;

  // Number of bytes to copy to cl buffer
  parameter num_page_bytes = `MAX_SIZE;


  int read_data;

  //Error checking
  int         error_count;
  int         timeout_count;
  int         fail;
  logic [3:0] status;

  //Input file
  int file_descriptor = 0;
  string file_path = "hw_snappy_1000ps_int64.parquet";//"int64array_nosnap_nodict.prq";
  byte file_data[0:num_page_bytes-1];
  int bytes_read = 0;

  //Ouput file
  int out_file_descriptor = 0;
  string out_file_path = "int64array_hw.bin";
  byte read_arrow_byte;

initial begin

  /*************************************************************
  * Initilialization
  *************************************************************/

  logic[63:0] host_parquet_address;
  logic[63:0] cl_parquet_address;
  logic[63:0] host_arrow_address;
  logic[63:0] cl_arrow_address;

  $display("[%t] : Initializing memory", $realtime);

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

  host_parquet_address = `HOST_PAGE_ADDR;
  cl_parquet_address = {`CL_PAGE_ADDR_HI, `CL_PAGE_ADDR_LO};
  host_arrow_address = `HOST_VAL_BUF;
  cl_arrow_address = {`CL_VAL_BUF_HI, `CL_VAL_BUF_LO};

  /*************************************************************
  * Queue data movements
  *************************************************************/
  tb.que_buffer_to_cl(
    .chan(0),
    .src_addr(host_parquet_address),
    .cl_addr(cl_parquet_address),
    .len(num_page_bytes)
  );

  tb.que_cl_to_buffer(
    .chan(0),
    .dst_addr(host_arrow_address),
    .cl_addr(cl_arrow_address),
    .len(`PRIM_WIDTH/8*`NUM_VAL)
  );


  /*************************************************************
  * Load contents of input Parquet file into host memory
  *************************************************************/
  file_descriptor=$fopen(file_path, "rb");

  // Only proceed if fopen succeeded
  if (file_descriptor) begin
    $display("[DEBUG] : Loading Parquet file %s into host memory.", file_path);
    bytes_read = $fread(file_data, file_descriptor);

    if(bytes_read == num_page_bytes) begin
      $display("[DEBUG] : First 40 bytes get displayed for debugging purposes.");
      for(int c = 0; c < num_page_bytes; c++) begin
        tb.hm_put_byte(.addr(host_parquet_address + c), .d(file_data[c]));
        if(c<40) begin
          $display("[DEBUG] : Writing %H to host memory", file_data[c]);
        end
      end

    end else begin
      $display("[ERROR] : Failed to read proper amount of bytes from opened file. Read %d instead of %d.\n", bytes_read, num_page_bytes);
      $finish;
    end

  end else begin
    $display("[ERROR] : Could not open test file.\n");
    $finish;
  end

  /*************************************************************
  * Transfer Parquet pages from host to CL
  *************************************************************/

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

  /*************************************************************
  * Initialize and start UserCore
  *************************************************************/

  $display("[%t] : Initializing UserCore ", $realtime);

  // Put the units in reset:
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));

  // Pointer to Parquet data on CL memory (+4 to skip the PAR1 magic number!)
  tb.poke_bar1(.addr(4*`REG_PAGE_ADDR0), .data(`CL_PAGE_ADDR_LO+4));
  tb.poke_bar1(.addr(4*`REG_PAGE_ADDR1), .data(`CL_PAGE_ADDR_HI));
  // Max amount of data to read (assumed to be smaller than 2^32 in this testbench)
  tb.poke_bar1(.addr(4*`REG_MAX_SIZE0), .data(0));
  tb.poke_bar1(.addr(4*`REG_MAX_SIZE1), .data(`MAX_SIZE));
  // Number of values to read
  tb.poke_bar1(.addr(4*`REG_NUM_VAL), .data(`NUM_VAL));
  // Pointer to Arrow buffer
  tb.poke_bar1(.addr(4*`REG_VAL_ADDR0), .data(`CL_VAL_BUF_LO));
  tb.poke_bar1(.addr(4*`REG_VAL_ADDR1), .data(`CL_VAL_BUF_HI));

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
  while((read_data & `STATUS_DONE) !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);

  tb.nsec_delay(12000);

  /*************************************************************
  * Transfer Arrow buffer from CL to host
  *************************************************************/

  $display("[%t] : Transfering buffers from CL to Host", $realtime);
    
    // Start transfers of data from CL DDR to host
  tb.start_que_to_buffer(.chan(0));

  // Wait for dma transfers to complete,
  // increase the timeout if you have to transfer a lot of data
  timeout_count = 0;
  do begin
    status[0] = tb.is_dma_to_buffer_done(.chan(0));
    #10ns;
    timeout_count++;
  end while ((status != 4'hf) && (timeout_count < 6000));

  if (timeout_count >= 6000) begin
    $display(
      "[%t] : *** ERROR *** Timeout waiting for dma transfers from cl",
      $realtime
    );
    error_count++;
  end

  tb.nsec_delay(12000);

  /*************************************************************
  * Write values in Arrow column to file
  *************************************************************/
  out_file_descriptor=$fopen(out_file_path, "wb");

  // Only proceed if fopen succeeded
  if (out_file_descriptor) begin
    $display("[DEBUG] : Writing CL output to %s.", out_file_path);
    $display("[DEBUG] : First 40 bytes get displayed for debugging purposes.");
    for(int c = 0; c < `PRIM_WIDTH/8*`NUM_VAL; c++) begin
      read_arrow_byte = tb.hm_get_byte(.addr(host_arrow_address + c));
      $fwrite(out_file_descriptor, "%c", read_arrow_byte);
      if(c<40) begin
        $display("[DEBUG] : Writing %H to output verification file", read_arrow_byte);
      end
    end

  end else begin
    $display("[ERROR] : Failed to create/open output verification file.\n");
    $finish;
  end

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

  tb.nsec_delay(12000);

  $finish;


end // initial begin

endmodule // test_prim64
