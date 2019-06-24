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

module test_md();

   initial begin
      int exit_code;
      
      tb.power_up();

      tb.test_main(exit_code);
      
      #50ns;

      tb.power_down();
      
      $finish;
   end

endmodule // test_null
