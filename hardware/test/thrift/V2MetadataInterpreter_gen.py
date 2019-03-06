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

import random
import sys

class SimpleThriftWriter:
    def __init__(self, bus_data_width, input_file_path="V2MDI_input.hex",output_file_path="V2MDI_output.hex"):
        self.input_file = open(input_file_path, "w+")
        self.output_file = open(output_file_path, "w+")
        self.bus_data_width = bus_data_width

    def int_to_zigzag(self, n):
        return (n << 1) ^ (n >> 31)

    def encode_varint32(self, a):
        a = a & 0xFFFFFFFF
        next_a = a >> 7
    
        if next_a == 0:
            return bytearray([a & 0x7F])
        else:
            return bytearray([(a & 0x7f) | 0x80]) + self.encode_varint32(next_a)

    def random_hex_string(self, length):
        allowed_chars = list("0123456789abcdef")
        return "".join([random.choice(allowed_chars) for i in range(length)])


    def _generate_random_thrift(self, uncomp_size, comp_size, num_val, def_lvl, rep_lvl, include_is_compressed):
        metadata = ""

        # PageType (random number)
        metadata += "15" + self.random_hex_string(2)

        # Uncompressed Page Size
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(uncomp_size)))

        # Compressed Page Size
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(comp_size)))

        # DataPageHeaderV2
        metadata += "5c"

        # Num values
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(num_val)))

        # Num_nulls (random number)
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(random.randint(0,1000000000))))

        # Num rows (random number)
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(random.randint(0,1000000000))))

        # Encoding (random number)
        metadata += "15" + self.random_hex_string(2)

        # Def lvl byte length
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(def_lvl)))

        # Rep lvl byte length
        metadata += "15" + "".join('{:02x}'.format(x) for x in self.encode_varint32(self.int_to_zigzag(rep_lvl)))

        # Optional bool is_compressed
        if include_is_compressed:
            metadata += random.choice(["11", "12"])

        metadata += "0000"

        return metadata


    def write_random_thrift(self):
        uncomp_size = random.randint(0, 1000000000)
        comp_size = random.randint(0, 1000000000)
        num_val = random.randint(0, 1000000000)
        def_lvl = random.randint(0, 1000000000)
        rep_lvl = random.randint(0, 1000000000)
        is_compressed = random.choice(["True", "False"])

        # Write generated values to output file for checking the results of the metadata interpreter
        self.output_file.write(hex(uncomp_size)[2:].zfill(8) + " ")
        self.output_file.write(hex(comp_size)[2:].zfill(8) + " ")
        self.output_file.write(hex(num_val)[2:].zfill(8) + " ")
        self.output_file.write(hex(def_lvl)[2:].zfill(8) + " ")
        self.output_file.write(hex(rep_lvl)[2:].zfill(8) + " ")
        self.output_file.write("\n")

        metadata_string = self._generate_random_thrift(uncomp_size, comp_size, num_val, def_lvl, rep_lvl, is_compressed)

        while len(metadata_string) > 0:
            self.input_file.write(metadata_string[:bus_data_width//8*2].ljust(bus_data_width//8*2, "F"))
            self.input_file.write("\n")
            metadata_string = metadata_string[bus_data_width//8*2:]


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: V2MetadataInterpretergen.py [bus_data_width] [num_metadata_structs]")
        exit()

    bus_data_width = int(sys.argv[1])
    num_structs = int(sys.argv[2])

    writer = SimpleThriftWriter(bus_data_width)

    for i in range(num_structs):
        writer.write_random_thrift()