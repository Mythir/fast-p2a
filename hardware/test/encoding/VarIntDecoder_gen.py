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
Script for generating a ROM contain integers encoded as VarInt's. Before every VarInt a null byte is inserted.
The very last byte is also a null byte.
"""
# Some numbers to encode
numbers = [0, 30, 100, 127, 128, 201857, -50, 18887, -80000]

def encode_varint32(a):
    a = a & 0xFFFFFFFF
    next_a = a >> 7

    if next_a == 0:
        return bytearray([a & 0x7F])
    else:
        return bytearray([(a & 0x7f) | 0x80]) + encode_varint32(next_a)


def encode_varint64(a):
    a = a & 0xFFFFFFFFFFFFFFFF
    next_a = a >> 7

    if next_a == 0:
        return bytearray([a & 0x7F])
    else:
        return bytearray([(a & 0x7f) | 0x80]) + encode_varint64(next_a)


# Encode the numbers and separate them with a null byte
encoded = bytearray([0])
total_size = 1
# Start_locations stores where we need to write comments later to indicate the start of a number
start_locations = []
for number in numbers:
    encoded_number = encode_varint32(number)
    start_locations.append(total_size - 1)
    total_size += len(encoded_number) + 1
    encoded = encoded + encoded_number + bytearray([0])

file = open("VarInt_ROM.vhd", "w+")
file.write("type mem is array (0 to {encoded_len}) of std_logic_vector(7 downto 0);\n".format(encoded_len=len(encoded)-1))
file.write("constant VarInt_ROM : mem := (\n")

numbers_counter = 0
for i, byte in enumerate(encoded):
    if i != 0:
        file.write(",\n")

    if i in start_locations:
        file.write("  {index} => x\"{byte_hex}\", -- {number}".format(index=i, byte_hex=hex(byte)[2:].zfill(2), number=numbers[numbers_counter]))
        numbers_counter += 1
    else:
        file.write("  {index} => x\"{byte_hex}\"". format(index=i, byte_hex=hex(byte)[2:].zfill(2)))

file.write("\n);")
