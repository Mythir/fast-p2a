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
Script for generating a ROM contain un aligned 512 bit data words.
"""

# Misalignment tuples: (amount of bus words with this misalignment, misalignment in bytes)
bytes_in_bus_word = 64
misalignments = [(10, 2), (5, 17)]

rom_strings = []
current_nibble = 0
for misalignment in misalignments:
    for i in range(misalignment[0]):
        next_nibble = (current_nibble + 1) % 10
        new_string = str(current_nibble)*misalignment[1]*2 + str(next_nibble)*(bytes_in_bus_word-misalignment[1])*2
        next_nibble = current_nibble
        rom_strings.append(new_string)

file = open("ShifterRecombiner_ROM.vhd", "w+")
file.write("type mem is array (0 to {rom_size}) of std_logic_vector(511 downto 0);\n".format(encoded_len=len(rom_strings)-1))
file.write("constant ShifterRecombiner_ROM : mem := (\n")

numbers_counter = 0
for i, bw in enumerate(rom_strings):
    if i != 0:
        file.write(",\n")

    file.write("  {index} => x\"{bus_word}\"". format(index=i, bus_word=bw))

file.write("\n);")