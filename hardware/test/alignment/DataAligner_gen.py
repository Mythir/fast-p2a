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

# This scripts generates input data with corresponding expected output data to test the DataAligner.
# It roughly does the following steps:
#
# 1: Generates a list of random length and data hex strings for each consumer
# 2.1: Write a list of <bus_data_width> wide segments of this data to the expected output file of each consumer
# 2.2: Concatenate this data and divide it in <bus_data_width> wide segments. This will be the unaligned input data
#
# Every time there is not enough (randomized) data left to write an entire bus word to the expected output file
# instead a bus word will be written that encodes the length of this remaining data as a null_byte followed by
# the length as an int32 followed by null_bytes to fill up to the remaining data length. This will allow the consumers
# to report back to the DataAligner how it should adjust its alignment to correctly align for the next consumer.

import random


def random_string(min_length, max_length):
    allowed_chars = list("123456789ABCDEF")
    length = random.randint(min_length, max_length-1)
    # 2 hex per byte so length should always be even
    if length % 2 == 1:
        length += 1
    return "".join([random.choice(allowed_chars) for i in range(length)])


# Parameters
bus_data_width = 512  # Should be more than 5*8 bits to fit the the encoded last_word
num_consumers = 3
data_blocks_per_consumer = 4
max_hex_per_block = 1000
min_hex_per_block = 10  # Should be 10 or more

bytes_in_data_word = bus_data_width//8

# Open all relevant files
input_file = open("DataAligner_input.hex", "w+")
output_files = []

for i in range(num_consumers):
    output_files.append(open("DataAligner_out{index}.hex".format(index=i), "w+"))

# Initial misalignment in bytes
misalignment = random.randint(0, bytes_in_data_word-1)

# Generate random data
data = [[random_string(min_hex_per_block*2, max_hex_per_block*2) \
        for j in range(data_blocks_per_consumer)] \
        for i in range(num_consumers)]

# Insert some filler data into the input_file to account for the initial misalignment
input_file.write("11"*misalignment)

# Write to the input and output_check files
for i in range(data_blocks_per_consumer):
    for j in range(num_consumers):
        word = data[j][i]

        # If there is enough data left to fill an entire bus_word, go for it
        while len(word) >= bytes_in_data_word*2:
            output_files[j].write(word[:bytes_in_data_word*2] + "\n")

            input_file.write(word[:(bytes_in_data_word-misalignment)*2])
            input_file.write("\n")
            input_file.write(word[(bytes_in_data_word-misalignment)*2:bytes_in_data_word*2])
            word = word[bytes_in_data_word*2:]

        # Remaining data should have a length larger than 5 bytes to encode a last_word signal byte and an int32
        # If this is not the case determine a random new length larger than 5 bytes
        if len(word)<10:
            word = "00"*random.randint(5, 63)

        # Signal last word of a consumer
        last_word = "00"
        # Write length of data in that word that is meant for this consumer
        last_word += hex(len(word))[2:].zfill(8)
        # Fill with zeros up to length of data in the word that is still meant for this consumer
        last_word += "0"*(len(word)-10)
        # Write some data meant for the next consumer
        # Note: For the very last bus word it will write some data from the first one again
        if j == num_consumers-1:
            last_word += data[0][(i+1) % data_blocks_per_consumer][:bytes_in_data_word*2-len(word)]
        else:
            last_word += data[j+1][i][:bytes_in_data_word*2-len(word)]

        output_files[j].write(last_word)
        output_files[j].write("\n")

        input_file.write(last_word[:(bytes_in_data_word-misalignment)*2])

        if len(last_word)+misalignment*2>bytes_in_data_word*2:
            input_file.write("\n")
            input_file.write(last_word[(bytes_in_data_word-misalignment)*2:])

        misalignment = (misalignment + len(last_word)//2) % 64

# The last consumer expects to see some data from the first one again (really just filler)
input_file.write(data[0][0][:(bytes_in_data_word-misalignment)*2])