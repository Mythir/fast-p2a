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

# Parameters
bus_data_width = 512
int_width_bits = 64
int_width_bytes = int_width_bits//8
ints_per_bus_word = bus_data_width//int_width_bits
min_page_size = 10
max_page_size = 300

page_amount = 50

page_sizes = [random.randint(min_page_size, max_page_size) for _ in range(page_amount)]

with open("PageNumValues_input.hex", "w") as f:
    for size in page_sizes:
        f.write(hex(size)[2:].zfill(8)+"\n")

with open("PageData_input.hex", "w") as f:
    counter = 0
    for size in page_sizes:
        for i in range(size):
            f.write(hex(counter)[2:].zfill(int_width_bytes*2))
            counter += 1
            if (i+1) % ints_per_bus_word == 0:
                f.write("\n")

        if size % ints_per_bus_word != 0:
            for j in range(ints_per_bus_word-(size % ints_per_bus_word)):
                f.write(hex(0)[2:].zfill(int_width_bytes*2))
            f.write("\n")
