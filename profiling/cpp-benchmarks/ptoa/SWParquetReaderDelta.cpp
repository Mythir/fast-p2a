// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <iostream>
#include <iomanip>
#include <fstream>
#include <cstring>
#include <algorithm>
#include <map>
#include <cassert>

#include <SWParquetReader.h>
#include <LemireBitUnpacking.h>
#include <ptoa.h>

namespace ptoa {


status SWParquetReader::read_prim_delta32(int64_t num_values, int32_t file_offset, std::shared_ptr<arrow::PrimitiveArray>* prim_array){
    const int32_t prim_width = 32;

    std::shared_ptr<arrow::Buffer> arr_buffer;
    arrow::AllocateBuffer(num_values*prim_width/8, &arr_buffer);

    read_prim_delta32(num_values, file_offset, prim_array, arr_buffer);

    return status::OK;
}

status SWParquetReader::read_string_delta_length(int64_t num_strings, int64_t num_chars, int32_t file_offset, std::shared_ptr<arrow::StringArray>* string_array){
    std::shared_ptr<arrow::Buffer> off_buffer;
    arrow::AllocateBuffer((num_strings+1)*sizeof(int32_t), &off_buffer);

    std::shared_ptr<arrow::Buffer> val_buffer;
    arrow::AllocateBuffer(num_chars, &val_buffer);

    read_string_delta_length(num_strings, file_offset, string_array, off_buffer, val_buffer);

    return status::OK;
}

status SWParquetReader::read_string_delta_length(int64_t num_strings, int32_t file_offset, std::shared_ptr<arrow::StringArray>* string_array, std::shared_ptr<arrow::Buffer> off_buffer, std::shared_ptr<arrow::Buffer> val_buffer){
    uint8_t* page_ptr = parquet_data;
    int32_t* off_buf_ptr = (int32_t*)off_buffer->mutable_data();
    int8_t* val_buf_ptr = (int8_t*)val_buffer->mutable_data();

    int32_t total_value_counter = 0;
    int32_t page_value_counter = 0;

    // Metadata reading variables
    int32_t uncompressed_size;
    int32_t compressed_size;
    int32_t page_num_values;
    int32_t def_level_length;
    int32_t rep_level_length;
    int32_t metadata_size;

    // Delta/block header reading variables
    int32_t page_values_to_read;
    uint8_t* block_ptr;
    int32_t min_delta;
    uint8_t* bitwidths = (uint8_t*)std::malloc(MINIBLOCKS_IN_BLOCK*sizeof(uint8_t));
    int32_t header_size;
    uint32_t* unpacked_deltas = (uint32_t*)std::malloc((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)*sizeof(uint32_t));

    //Keep track of amount of chars to read
    uint32_t chars_to_read;

    //Offset tracker
    uint32_t current_offset = 0;
    uint32_t prev_page_final_offset = 0;

    //Store most recently processed string length
    int32_t string_length;

    //Write first offset
    off_buf_ptr[0] = 0;
    off_buf_ptr++;

    page_ptr += file_offset;

    // Decode values from Parquet pages until max amount of values is reached
    while(total_value_counter < num_strings){
        page_value_counter = 0;

        // Read page metadata
        if(read_metadata(page_ptr, &uncompressed_size, &compressed_size, &page_num_values, &def_level_length, &rep_level_length, &metadata_size) != status::OK) {
            std::cerr << "[ERROR] Corrupted data in Parquet page headers" << std::endl;
            std::cerr << page_ptr-parquet_data << std::endl;
            return status::FAIL;
        }
        page_ptr += metadata_size;
        block_ptr = page_ptr;
        page_values_to_read = std::min(page_num_values, (int32_t)(num_strings-total_value_counter));

        // Read delta header
        read_delta_header32(block_ptr, &string_length, &header_size);
        block_ptr += header_size;

        // Insert first offset of page into the arrow offset buffer
        current_offset = string_length+current_offset;
        off_buf_ptr[page_value_counter] = current_offset;
        page_value_counter++;
        //chars_to_read = string_length;

        // Keep on looping through the blocks in the page until exactly page_values_to_read have been processed.
        while(page_value_counter < page_values_to_read){
            // Read block header
            read_block_header32(block_ptr, &min_delta, bitwidths, &header_size);
            block_ptr += header_size;
        
            for(int i=0; i<MINIBLOCKS_IN_BLOCK; i++){
                uint8_t current_bitwidth = bitwidths[i];
                fastunpack((uint*) block_ptr, unpacked_deltas, current_bitwidth);

                for(int j=0; j<(BLOCK_SIZE/MINIBLOCKS_IN_BLOCK); j++){
                    string_length = string_length + unpacked_deltas[j] + min_delta;
                    current_offset = string_length + current_offset;
                    off_buf_ptr[page_value_counter] = current_offset;
                    page_value_counter++;

                    // Nested loops termination condition, all values have been read
                    if(page_value_counter >= page_values_to_read){
                        // Set off_buf_ptr to where we start writing the next page
                        off_buf_ptr += page_value_counter;

                        //Advance block pointer to next block
                        page_value_counter += (BLOCK_SIZE/MINIBLOCKS_IN_BLOCK) - j - 1;
                        block_ptr += current_bitwidth*((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)/8);

                        for(int k=i+1; k<MINIBLOCKS_IN_BLOCK; k++){
                            // Check if there are more values/lengths in the page that we need to skip
                            if(page_value_counter>=page_num_values){
                                break;
                            }
                            block_ptr += bitwidths[k]*((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)/8);
                            page_value_counter += BLOCK_SIZE/MINIBLOCKS_IN_BLOCK;
                        }
                        goto end_of_lengths;
                    }
                }

                block_ptr += current_bitwidth*((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)/8);
            }
        }

        end_of_lengths:
        // If the last block processed was not the last block in the page we need to keep reading bitwidths to find the first character
        while(page_value_counter<page_num_values){
            read_block_header32(block_ptr, &min_delta, bitwidths, &header_size);
            block_ptr += header_size;

            for(int i=0; i<MINIBLOCKS_IN_BLOCK; i++){
                block_ptr += bitwidths[i]*((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)/8);
                page_value_counter += BLOCK_SIZE/MINIBLOCKS_IN_BLOCK;
                if(page_value_counter>=page_num_values){
                    break;
                }
            }
        }

        //Copy characters
        chars_to_read = current_offset-prev_page_final_offset;
        std::memcpy((void*) val_buf_ptr, (const void*) block_ptr, chars_to_read);
        val_buf_ptr += chars_to_read;
        prev_page_final_offset = current_offset;

        //Prepare for next page
        page_ptr += compressed_size;
        total_value_counter += page_num_values;
    }

    *string_array = std::make_shared<arrow::StringArray>(num_strings, off_buffer, val_buffer);

    free(bitwidths);
    free(unpacked_deltas);

    return status::OK;
}

status SWParquetReader::read_prim_delta32(int64_t num_values, int32_t file_offset, std::shared_ptr<arrow::PrimitiveArray>* prim_array, std::shared_ptr<arrow::Buffer> arr_buffer){
    uint8_t* page_ptr = parquet_data;
    int32_t* arr_buf_ptr = (int32_t*)arr_buffer->mutable_data();

    int32_t total_value_counter = 0;
    int32_t page_value_counter = 0;

    // Metadata reading variables
    int32_t uncompressed_size;
    int32_t compressed_size;
    int32_t page_num_values;
    int32_t def_level_length;
    int32_t rep_level_length;
    int32_t metadata_size;

    // Delta/block header reading variables
    int32_t page_values_to_read;
    uint8_t* block_ptr;
    int32_t first_value;
    int32_t min_delta;
    uint8_t* bitwidths = (uint8_t*)std::malloc(MINIBLOCKS_IN_BLOCK*sizeof(uint8_t));
    int32_t header_size;
    uint32_t* unpacked_deltas = (uint32_t*)std::malloc((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)*sizeof(uint32_t));

    page_ptr += file_offset;

    // Decode values from Parquet pages until max amount of values is reached
    while(total_value_counter < num_values){
        // Set arr_buf_ptr to where we start writing the current page
        arr_buf_ptr += page_value_counter;

        page_value_counter = 0;

        // Read page metadata
        if(read_metadata(page_ptr, &uncompressed_size, &compressed_size, &page_num_values, &def_level_length, &rep_level_length, &metadata_size) != status::OK) {
            std::cerr << "[ERROR] Corrupted data in Parquet page headers" << std::endl;
            std::cerr << page_ptr-parquet_data << std::endl;
            return status::FAIL;
        }
        page_ptr += metadata_size;
        block_ptr = page_ptr;
        page_values_to_read = std::min(page_num_values, (int32_t)(num_values-total_value_counter));

        // Read delta header
        read_delta_header32(block_ptr, &first_value, &header_size);
        block_ptr += header_size;

        // Insert first value of page into the arrow buffer
        arr_buf_ptr[page_value_counter] = first_value;
        page_value_counter++;

        // Keep on looping through the blocks in the page until exactly page_values_to_read have been processed.
        while(page_value_counter < page_values_to_read){
            // Read block header
            read_block_header32(block_ptr, &min_delta, bitwidths, &header_size);
            block_ptr += header_size;
        
            for(int i=0; i<MINIBLOCKS_IN_BLOCK; i++){
                uint8_t current_bitwidth = bitwidths[i];
                fastunpack((uint*) block_ptr, unpacked_deltas, current_bitwidth);

                for(int j=0; j<(BLOCK_SIZE/MINIBLOCKS_IN_BLOCK); j++){
                    arr_buf_ptr[page_value_counter] = unpacked_deltas[j] + min_delta + arr_buf_ptr[page_value_counter-1];
                    page_value_counter++;

                    // Nested loops termination condition
                    if(page_value_counter >= page_values_to_read){
                        // Not pretty, but very pragmatic
                        goto end_of_page;
                    }
                }

                block_ptr += current_bitwidth*((BLOCK_SIZE/MINIBLOCKS_IN_BLOCK)/8);
            }
        }

        end_of_page:
        page_ptr += compressed_size;
        total_value_counter += page_num_values;
    }

    *prim_array = std::make_shared<arrow::PrimitiveArray>(arrow::int32(), num_values, arr_buffer);

    free(bitwidths);
    free(unpacked_deltas);
    return status::OK;
}

status SWParquetReader::read_delta_header32(const uint8_t* header, int32_t* first_value, int32_t* header_size){
    const uint8_t* current_byte = header;

    //Skip block_size
    assert(BLOCK_SIZE == 128);
    current_byte += 2;

    //Skip miniblocks in block
    assert(MINIBLOCKS_IN_BLOCK == 4);
    current_byte += 1;

    //Total value count
    while((*current_byte & 0x80) != 0 ){
        current_byte++;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, first_value, true);

    *header_size = current_byte-header;

    return status::OK;
}

status SWParquetReader::read_block_header32(const uint8_t* header, int32_t* min_delta, uint8_t* bitwidths, int32_t* header_size){
    const uint8_t* current_byte = header;

    //Min_delta
    current_byte += decode_varint32(current_byte, min_delta, true);

    //Bit widths
    for(int i=0; i<MINIBLOCKS_IN_BLOCK; i++){
        bitwidths[i] = *current_byte;
        current_byte++;
    }

    *header_size = current_byte-header;

    return status::OK;

}

}