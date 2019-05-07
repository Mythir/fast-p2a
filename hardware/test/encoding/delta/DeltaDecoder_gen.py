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

import bincopy as bc

# Parameters
bus_data_width = 512  # In bits
header_length = 33 # How many bytes to skip in the input file
input_file = "../../../../profiling/gen-input/hw_int32array_delta.parquet"

f = bc.BinFile()

f.add_binary_file(input_file)

with open("dd_tb_in.hex1", "w") as output:
    bin_data = "".join('{:02x}'.format(x) for x in f.as_binary())
    bin_data = bin_data[header_length*2:]

    while len(bin_data) > 0:
        output.write(bin_data[:bus_data_width//8*2] + "\n")
        bin_data = bin_data[bus_data_width//8*2:]

print("Generated testbench input files with the following parameters:")
print("bus_data_width = {bus_data_width} bits".format(bus_data_width=bus_data_width))
print("Please edit the DeltaDecoder testbench constants to reflect this.")