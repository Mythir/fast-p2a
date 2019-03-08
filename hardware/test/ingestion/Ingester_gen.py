# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Ingester_gen.py can be used to generate input data for the Ingester VHDL testbench.

This script takes an input file and converts its binary data to:
1. test.srec: An SREC file that contains the entire contents of the input binary file starting at address 0.
2. test.hex1: A hex string file with on each line the expected output of the ingester for the given bus_data_width,
base_address and data_size input. Because both base_address and data_size do not have to be aligned the hex string file
will contain more data than data_size would suggest on first glance.
3. full.hex: The entire input_file as hex strings for script debugging purposes.
"""
import bincopy as bc

# Parameters
bus_data_width = 512  # In bits
base_address = 128  # In bytes
data_size = 1024  # In bytes
input_file = "../../../profiling/parquet-cpp/debug/strarray_nosnap_nodict.prq"

f = bc.BinFile()

f.add_binary_file(input_file)

with open("test.srec", "w") as output:
    output.write(f.as_srec())

with open("test.hex1", "w") as output:
    bin_data = "".join('{:02x}'.format(x) for x in f.as_binary())

    # Find aligned base and end adress so each line in test.hex will contain exactly 64 bytes
    aligned_base_address = base_address - (base_address % (bus_data_width//8))

    end_address = base_address + data_size - 1
    aligned_end_address = end_address + bus_data_width//8 - (end_address % (bus_data_width//8))
    print(aligned_end_address)

    if aligned_end_address*2 >= len(bin_data):
        print("Error: Input file too small.")
        exit()

    bin_data = bin_data[aligned_base_address*2:aligned_end_address*2]

    while len(bin_data) > 0:
        output.write(bin_data[:bus_data_width//8*2] + "\n")
        bin_data = bin_data[bus_data_width//8*2:]

with open("full.hex", "w") as output:
    bin_data = "".join('{:02x}'.format(x) for x in f.as_binary())

    while len(bin_data) > 0:
        output.write(bin_data[:bus_data_width//8*2] + "\n")
        bin_data = bin_data[bus_data_width//8*2:]

print("Generated testbench input files with the following parameters:")
print("bus_data_width = {bus_data_width} bits".format(bus_data_width=bus_data_width))
print("base_address = {base_address} bytes".format(base_address=base_address))
print("data_size = {data_size} bytes".format(data_size=data_size))
print("Please edit the Ingester testbench constants to reflect this.")
