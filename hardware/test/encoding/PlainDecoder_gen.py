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


def endian_swap(word):
    result = ""

    while word:
        result = word[:2] + result
        word = word[2:]

    return result


# Parameters
bus_data_width = 512
int_width_bits = 64
int_width_bytes = int_width_bits//8
ints_per_bus_word = bus_data_width//int_width_bits
min_page_size = 1
max_page_size = 300

page_amount = 100

page_sizes = [random.randint(min_page_size, max_page_size) for _ in range(page_amount)]

with open("PageNumValues_input.hex", "w") as f:
    for size in page_sizes:
        f.write(hex(size)[2:].zfill(8)+"\n")

with open("PageData_input.hex", "w") as f:
    counter = 0
    for size in page_sizes:
        bus_word = ""
        for i in range(size):
            bus_word = hex(counter)[2:].zfill(int_width_bytes*2) + bus_word
            counter += 1
            if (i+1) % ints_per_bus_word == 0:
                f.write(endian_swap(bus_word) + "\n")
                bus_word = ""

        if size % ints_per_bus_word != 0:
            for j in range(ints_per_bus_word-(size % ints_per_bus_word)):
                bus_word = hex(0)[2:].zfill(int_width_bytes*2) + bus_word
            f.write(endian_swap(bus_word) + "\n")

print("Generated testbench input files with the following parameters:")
print("bus_data_width = {bus_data_width} bits".format(bus_data_width=bus_data_width))
print("prim_width = {prim_width} bits".format(prim_width=int_width_bits))
print("total_num_values = {total_num_values}".format(total_num_values=sum(page_sizes)))
print("Please edit the Ingester testbench constants to reflect this.")