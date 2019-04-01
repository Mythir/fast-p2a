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

#include <parquet/arrow/reader.h>

#include <SWParquetReader.h>

#define PRIM_WIDTH 64

//Use standard Arrow library functions to read Arrow array from Parquet file
//Only works for Parquet version 1 style files.
std::shared_ptr<arrow::Array> readArray(std::string hw_input_file_path) {
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_THROW_NOT_OK(arrow::io::ReadableFile::Open(hw_input_file_path, arrow::default_memory_pool(), &infile));
  
  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));

  std::shared_ptr<arrow::Array> array;
  PARQUET_THROW_NOT_OK(reader->ReadColumn(0, &array));

  return array;
}

int main(int argc, char **argv) {
    int num_values;
    char* hw_input_file_path;
    char* reference_parquet_file_path;

    if (argc > 3) {
      hw_input_file_path = argv[1];
      reference_parquet_file_path = argv[2];
      num_values = (uint32_t) std::strtoul(argv[3], nullptr, 10);
    
    } else {
      std::cerr << "Usage: prim <parquet_hw_input_file_path> <reference_parquet_file_path> <num_values>" << std::endl;
      return 1;
    }

    ptoa::SWParquetReader reader(hw_input_file_path);

    std::shared_ptr<arrow::PrimitiveArray> array;

    if(reader.read_prim(PRIM_WIDTH, num_values, 4, &array) != ptoa::status::OK){
        return 1;
    }

    #if PRIM_WIDTH == 64
        auto result_array = std::static_pointer_cast<arrow::Int64Array>(array);
        auto correct_array = std::dynamic_pointer_cast<arrow::Int64Array>(readArray(std::string(reference_parquet_file_path)));
    #elif PRIM_WIDTH == 32
        auto result_array = std::static_pointer_cast<arrow::Int32Array>(array);
        auto correct_array = std::dynamic_pointer_cast<arrow::Int32Array>(readArray(std::string(reference_parquet_file_path)));
    #endif

    // Verify result
    int error_count = 0;

    for(int i=0; i<result_array->length(); i++) {
        if(result_array->Value(i) != correct_array->Value(i)) {
          error_count++;
          if(error_count<20) {
            std::cout<<i<<std::endl;
          }
        }
        if(i<20) {
          std::cout << result_array->Value(i) << " " << correct_array->Value(i) << std::endl;
        }

    }

    if(error_count == 0) {
      std::cout << "Test passed!" << std::endl;
    } else {
      std::cout << "Test failed. Found " << error_count << " errors in the output Arrow array" << std::endl;
    }
    

}