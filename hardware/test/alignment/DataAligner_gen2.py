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
Way cleaner version of the original DataAligner_gen.py, meant to provide files with input test data to the DataAligner
unit and files containing correct output data to check the functionality of DataAligner against.

DataAligner_out<consumer_index>.hex contains correctly aligned bus words that the DataAligner is expected to provide
to that consumer. After every block of these bus words a partial bus word appears that the consumer in the testbench can
use to signal the DataAligner that it should realign for the next consumer. Because this is represented in the
DataAligner_out<consumer_index>.hex files as a partial bus word it should not be used to verify the output of
DataAligner.

DataAligner_input.hex contains the corresponding input bus_words for the DataAligner.
"""

import random


# Generate string of given length containing only allowed_chars
def random_hex_string(length):
    allowed_chars = list("123456789ABCDEF")
    return "".join([random.choice(allowed_chars) for i in range(length)])


# Class containing the (correctly aligned) data for each consumer connected to DataAligner
class Consumer:
    def __init__(self, file_path, num_blocks, bus_word_width, min_words, max_words):
        bytes_in_bus_word = bus_word_width//8
        self.output_file = open(file_path, "w+")
        self.blocks = []

        # Write a random amount of randomly generated strings for each block
        for i in range(num_blocks):
            num_bus_words = random.randint(min_words, max_words)
            self.blocks.append([random_hex_string(bytes_in_bus_word*2) for i in range(num_bus_words)])

        # Every block gets a final (partial) bus_word of random length with that random length encoded as
        # a null byte followed by the length as an int32. An amount of null bytes follows to fill up to the
        # randomly generated length.
        for block in self.blocks:
            last_word_num_bytes = random.randint(5, bytes_in_bus_word)
            block.append("00"+hex(last_word_num_bytes)[2:].zfill(8)+"00"*(last_word_num_bytes-5))

    def concatenate_block_data(self, block_index):
        return "".join(self.blocks[block_index])

    def export_expected_output(self):
        for block in self.blocks:
            for bus_word in block:
                self.output_file.write(bus_word+"\n")


# Parameters
bus_data_width = 512
num_consumers = 5
data_blocks_per_consumer = 20
min_words_per_block = 0
max_words_per_block = 20
init_misalignment = random.randint(0, bus_data_width//8-1)

bytes_in_bus_word = bus_data_width//8

consumers = []

# Create consumers
for i in range(num_consumers):
    consumers.append(Consumer("DataAligner_out{index}.hex".format(index=i), data_blocks_per_consumer, bus_data_width, min_words_per_block, max_words_per_block))

for consumer in consumers:
    consumer.export_expected_output()

ordered_data = []

for i in range(data_blocks_per_consumer):
    for consumer in consumers:
        ordered_data.append(consumer.concatenate_block_data(i))

init_filler_data = "11"*init_misalignment
print("The initial misalignment in bytes is {init_misalignment}.".format(init_misalignment=init_misalignment))
full_concatenated_data = init_filler_data + "".join(ordered_data)

DA_input_file = open("DataAligner_input.hex", "w+")

data_size = len(full_concatenated_data)/2-init_misalignment
while len(full_concatenated_data) >= bytes_in_bus_word*2:
    DA_input_file.write(full_concatenated_data[:bytes_in_bus_word*2]+"\n")
    full_concatenated_data = full_concatenated_data[bytes_in_bus_word*2:]

# Add filler
DA_input_file.write(full_concatenated_data + "1"*(bytes_in_bus_word*2-len(full_concatenated_data)) + "\n")
print("The data size in bytes is {data_size}.".format(data_size=data_size))
print("Please change the proper constant in the DataAligner_tb file to reflect this.")

