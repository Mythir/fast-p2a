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

#include <SWParquetReader.h>
#include <ptoa.h>

namespace ptoa {

// Load Parquet file into memory
SWParquetReader::SWParquetReader(std::string file_path) {
    std::ifstream parquet_file(file_path, std::ios::binary);
    
    parquet_file.seekg(0, parquet_file.end);
    file_size = parquet_file.tellg();
    parquet_file.seekg(0, parquet_file.beg);

    parquet_data = (uint8_t*) malloc(file_size);
    parquet_file.read((char*) parquet_data, file_size);

    parquet_file.close();

}

// Read a number (set by num_values) of either 32 or 64 bit integers (set by prim_width) into prim_array.
// File_offset is the byte offset in the Parquet file where the first in a contiguous list of Parquet pages is located.
status SWParquetReader::read_prim(int32_t prim_width, int64_t num_values, int32_t file_offset, uint8_t* arr_buffer) {
    uint8_t* page_ptr = parquet_data;
    uint8_t* arr_buf_ptr = arr_buffer;

    int64_t total_value_counter = 0;

    // Metadata reading variables
    int32_t uncompressed_size;
    int32_t compressed_size;
    int32_t page_num_values;
    int32_t def_level_length;
    int32_t rep_level_length;
    int32_t metadata_size;

    page_ptr += file_offset;

    // Copy values from Parquet pages until max amount of values is reached
    while(total_value_counter < num_values){
        if(read_metadata(page_ptr, &uncompressed_size, &compressed_size, &page_num_values, &def_level_length, &rep_level_length, &metadata_size) != status::OK) {
            std::cerr << "[ERROR] Corrupted data in Parquet page headers" << std::endl;
            std::cerr << page_ptr-parquet_data << std::endl;
            return status::FAIL;
        }

        page_ptr += metadata_size;
    
        std::memcpy((void*) arr_buf_ptr, (const void*) page_ptr, std::min((int64_t) compressed_size, (num_values-total_value_counter)*prim_width/8));
    
        page_ptr += compressed_size;
        arr_buf_ptr += compressed_size;
        total_value_counter += page_num_values;


    }

    return status::OK;

}

// Count pages and provide information about their sizes starting with the page at file_offset
status SWParquetReader::count_pages(int32_t file_offset) {
    uint8_t* page_ptr = parquet_data;

    // Metadata reading variables
    int32_t uncompressed_size;
    int32_t compressed_size;
    int32_t page_num_values;
    int32_t def_level_length;
    int32_t rep_level_length;
    int32_t metadata_size;

    page_ptr += file_offset;

    int32_t page_ctr = 0;
    std::map<int32_t, int32_t> size_map;
    std::map<int32_t, int32_t> value_map;

    // Read Parquet pages until either the end of the file is reached or a non PageHeader Thrift structure.
    while((uint64_t)(page_ptr-parquet_data) < file_size){
        if(read_metadata(page_ptr, &uncompressed_size, &compressed_size, &page_num_values, &def_level_length, &rep_level_length, &metadata_size) != status::OK) {
            break;
        }

        page_ptr += metadata_size;    
        page_ptr += compressed_size;

        page_ctr++;
        auto size_it = size_map.find(compressed_size);
        if(size_it != size_map.end()) {
            size_it->second++;
        } else {
            size_map.insert(std::make_pair(compressed_size, 1));
        }

        auto value_it = value_map.find(page_num_values);
        if(value_it != value_map.end()) {
            value_it->second++;
        } else {
            value_map.insert(std::make_pair(page_num_values, 1));
        }


    }

    std::cout << "Counted " << page_ctr << " pages" << std::endl;
    std::cout << "Page sizes: " << std::endl;
    for(auto it = size_map.begin(); it != size_map.end(); it++){
        std::cout << "    Size " << it->first << ": " << it->second <<std::endl;
    }

    std::cout << "Number of values per page: " << std::endl;
    for(auto it = value_map.begin(); it != value_map.end(); it++){
        std::cout << "    " << it->first << ": " << it->second <<std::endl;
    }
    std::cout << std::endl;

    return status::OK;

}

// Decodes variable length integer pointed to by input and stores it in decoded_int. Returns length of variable length integer in bytes.
int SWParquetReader::decode_varint32(uint8_t* input, int32_t* decoded_int, bool zigzag) {
    int32_t result = 0;
    int i;

    for (i = 0; i < 5; i++) {
        result |= (input[i] & 127) << (7 * i);

        if(!(input[i] & 128)) {
            break;
        }
    }

    if(zigzag) {
        result = ((result >> 1) & 0x7FFFFFFF) ^ (-(result & 1));
    }

    *decoded_int = result;

    return i+1;
}

status SWParquetReader::inspect_metadata(int32_t file_offset) {
    // Metadata reading variables
    int32_t uncompressed_size;
    int32_t compressed_size;
    int32_t page_num_values;
    int32_t def_level_length;
    int32_t rep_level_length;
    int32_t metadata_size;

    if(read_metadata(parquet_data + file_offset, &uncompressed_size, &compressed_size, &page_num_values, &def_level_length, &rep_level_length, &metadata_size) != status::OK) {
        std::cerr << "[ERROR] Page header at file offset " << file_offset << " corrupted or missing." << std::endl;
        return status::FAIL;
    }

    std::cout << "Page header fields at file offset " << file_offset << ":" << std::endl;
    std::cout << "    Uncompressed size: " << uncompressed_size << std::endl;
    std::cout << "    Compressed size: " << compressed_size << std::endl;
    std::cout << "    Page num values: " << page_num_values << std::endl;
    std::cout << "    Def level length: " << def_level_length << std::endl;
    std::cout << "    rep_level_length: " << rep_level_length << std::endl;
    std::cout << "    metadata_size: " << metadata_size << std::endl;
    std::cout << std::endl;
    
    return status::OK;
}

// Read all relevant fields from the Parquet page header pointed to by uint8_t* metadata.
status SWParquetReader::read_metadata(uint8_t* metadata, int32_t* uncompressed_size, int32_t* compressed_size, int32_t* num_values, 
                                      int32_t* def_level_length, int32_t* rep_level_length, int32_t* metadata_size) {

    uint8_t* current_byte = metadata;

    // PageType
    if(*current_byte != 0x15){
        //std::cerr<<"PageType error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    while((*current_byte & 0x80) != 0 ){
        current_byte++;
    }

    current_byte++;

    //Uncompressed page size
    if(*current_byte != 0x15){
        //std::cerr<<"uncompressed_size error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, uncompressed_size, true);

    //Compressed page size
    if(*current_byte != 0x15){
        //std::cerr<<"compressed_size error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, compressed_size, true);

    //CRC
    int data_page_v2_field_header = 0x5c;

    if(*current_byte == 0x15){
        current_byte++;

        while((*current_byte & 0x80) != 0 ){
           current_byte++;
        };

        current_byte++;
        data_page_v2_field_header = 0x4c;
    }

    //DataPageHeaderV2
    if(*current_byte != data_page_v2_field_header){
        //std::cerr<<"datapagev2 error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    //Num values
    if(*current_byte != 0x15){
        //std::cerr<<"numval error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, num_values, true);

    //Num nulls
    if(*current_byte != 0x15){
        //std::cerr<<"num_null error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    while((*current_byte & 0x80) != 0 ){
        current_byte++;
    }

    current_byte++;

    //Num rows
    if(*current_byte != 0x15){
        //std::cerr<<"numrow error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    while((*current_byte & 0x80) != 0 ){
        current_byte++;
    }

    current_byte++;

    //Encoding
    if(*current_byte != 0x15){
        //std::cerr<<"enc error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    while((*current_byte & 0x80) != 0 ){
        current_byte++;
    }

    current_byte++;

    //Def level byte length
    if(*current_byte != 0x15){
        //std::cerr<<"def_level_length error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, def_level_length, true);

    //rep level byte length
    if(*current_byte != 0x15){
        //std::cerr<<"rep_level_length error"<<std::endl;
        return status::FAIL;
    }

    current_byte++;

    current_byte += decode_varint32(current_byte, rep_level_length, true);

    //is_compressed
    if((*current_byte == 0x11) || (*current_byte == 0x12)) {
        current_byte++;
    }

    //Skip stop bytes
    current_byte += 2;

    *metadata_size = current_byte - metadata;


    return status::OK;

}

}