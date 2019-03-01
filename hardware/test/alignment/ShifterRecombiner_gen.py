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
# The amount of bus words with a certain misalignment may never be less than 2
bytes_in_bus_word = 64
misalignments = [(5, 4), (11, 63), (6, 0), (2, 30), (4, 0), (3, 55), (3, 0)]

# Determine contents of ROMs
misaligned_bus_words = []
aligned_bus_words = []
alignment_rom_values = []
alignment_rom_values2 = []

current_nibble = 0
for misalignment in misalignments:
    for i in range(misalignment[0]):
        next_nibble = (current_nibble + 1) % 10
        misaligned_string = str(current_nibble)*misalignment[1]*2 + str(next_nibble)*(bytes_in_bus_word-misalignment[1])*2
        aligned_string = str(next_nibble)*bytes_in_bus_word*2
        current_nibble = next_nibble
        misaligned_bus_words.append(misaligned_string)
        # Last misaligned bus word contains the start of a bus word that can not be aligned because its end part is missing
        # Therefore, we only add the "aligned" version of this last bus word to the list of expected bus words if it completely present in the misaligned one, i.e. when misalignment=0
        if i != misalignment[0]-1 or aligned_string == misaligned_string:
        	aligned_bus_words.append(aligned_string)
        	alignment_rom_values2.append(misalignment[1])
        alignment_rom_values.append(misalignment[1])

# Generate rom containing misaligned bus words
file = open("ShifterRecombiner_ROM.vhd", "w+")
file.write("-- Misaligned input of the ShifterRecombiner\n")
file.write("type mem1 is array (0 to {rom_size}) of std_logic_vector(511 downto 0);\n".format(rom_size=len(misaligned_bus_words)-1))
file.write("constant MisalignedBusWord_ROM : mem1 := (\n")

numbers_counter = 0
for i, bw in enumerate(misaligned_bus_words):
    if i != 0:
        file.write(",\n")

    file.write("  {index} => x\"{bus_word}\"". format(index=i, bus_word=bw))

file.write("\n);")

file.write("\n\n")

# Generate rom containing degrees of misalignment
file.write("--Alignment of all bus words in MisalignedBusWord_ROM\n")
file.write("type mem2 is array (0 to {rom_size}) of integer;\n".format(rom_size=len(misaligned_bus_words)-1))
file.write("constant Alignment_ROM : mem2 := (\n")

numbers_counter = 0
for i, alignment in enumerate(alignment_rom_values):
    if i != 0:
        file.write(",\n")

    file.write("  {index} => {alignment_value}". format(index=i, alignment_value=alignment))

file.write("\n);")

file.write("\n\n")

# Generate rom containing aligned bus words (for checking results)
file.write("--List of aligned bus words we expect the ShifterRecombiner to produce\n")
file.write("type mem3 is array (0 to {rom_size}) of std_logic_vector(511 downto 0);\n".format(rom_size=len(aligned_bus_words)-1))
file.write("constant AlignedBusWord_ROM : mem3 := (\n")

numbers_counter = 0
for i, bw in enumerate(aligned_bus_words):
    if i != 0:
        file.write(",\n")

    file.write("  {index} => x\"{bus_word}\"". format(index=i, bus_word=bw))

file.write("\n);")

file.write("\n\n")

# Generate rom containing degrees of misalignment
file.write("--Original alignment of all bus words in AlignedBusWord_ROM\n")
file.write("type mem4 is array (0 to {rom_size}) of integer;\n".format(rom_size=len(alignment_rom_values2)-1))
file.write("constant Alignment2_ROM : mem4 := (\n")

numbers_counter = 0
for i, alignment in enumerate(alignment_rom_values2):
    if i != 0:
        file.write(",\n")

    file.write("  {index} => {alignment_value}". format(index=i, alignment_value=alignment))

file.write("\n);")

file.write("\n\n")