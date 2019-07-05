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
#include <timer.h>

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
    int iterations;
    bool verify_output;
    ptoa::encoding enc;

    Timer t;

    if (argc > 6) {
      hw_input_file_path = argv[1];
      reference_parquet_file_path = argv[2];
      num_values = (uint32_t) std::strtoul(argv[3], nullptr, 10);
      iterations = (uint32_t) std::strtoul(argv[4], nullptr, 10);
      if(argv[5][0] == 'y') {
        verify_output = true;
      } else if (argv[5][0] == 'n') {
        verify_output = false;
      } else {
        std::cerr << "Invalid argument. Option \"verify\" should be \"y\" or \"n\"" << std::endl;
        return 1;
      }
      if(argv[6][0] == 'y') {
        enc = ptoa::encoding::DELTA;
      } else if (argv[6][0] == 'n') {
        enc = ptoa::encoding::PLAIN;
      } else {
        std::cerr << "Invalid argument. Option \"delta_encoded\" should be \"y\" or \"n\"" << std::endl;
        return 1;
      }
    } else {
      std::cerr << "Usage: prim parquet_hw_input_file_path reference_parquet_file_path num_values iterations verify(y or n) delta_encoded(y or n)" << std::endl;
      return 1;
    }

    ptoa::SWParquetReader reader(hw_input_file_path);
    //reader.inspect_metadata(4);
    reader.count_pages(4);

    std::shared_ptr<arrow::PrimitiveArray> array;
    std::shared_ptr<arrow::Buffer> arr_buffer;

    // Only relevant for the benchmark with pre-allocated (and memset) buffer
    arrow::AllocateBuffer(num_values*(PRIM_WIDTH/8), &arr_buffer);
    std::memset((void*)(arr_buffer->mutable_data()), 0, num_values*(PRIM_WIDTH/8));
    
    for(int i=0; i<iterations; i++){
        t.start();
        // Reading the Parquet file. The interesting bit.
        if(reader.read_prim(PRIM_WIDTH, num_values, 4, &array, arr_buffer, enc) != ptoa::status::OK){
            return 1;
        }
        t.stop();
        t.record();
    }

    std::cout << "Read " << num_values << " values" << std::endl;
    std::cout << "Average time in seconds (pre-allocated): " << t.average() << std::endl;

    t.clear_history();

    for(int i=0; i<iterations; i++){
        t.start();
        // Reading the Parquet file. The interesting bit.
        if(reader.read_prim(PRIM_WIDTH, num_values, 4, &array, enc) != ptoa::status::OK){
            return 1;
        }
        t.stop();
        t.record();
    }

    std::cout << "Read " << num_values << " values" << std::endl;
    std::cout << "Average time in seconds (not pre-allocated): " << t.average() << std::endl;

    if(verify_output) {
        #if PRIM_WIDTH == 64
            auto result_array = std::static_pointer_cast<arrow::Int64Array>(array);
            auto correct_array = std::dynamic_pointer_cast<arrow::Int64Array>(readArray(std::string(reference_parquet_file_path)));
        #elif PRIM_WIDTH == 32
            auto result_array = std::static_pointer_cast<arrow::Int32Array>(array);
            auto correct_array = std::dynamic_pointer_cast<arrow::Int32Array>(readArray(std::string(reference_parquet_file_path)));
        #endif
    
        // Verify result
        int error_count = 0;
    
        for(int i=0; i<num_values; i++) {
            if(result_array->Value(i) != correct_array->Value(i)) {
              error_count++;
              if(error_count<20) {
                std::cout<<i<<": "<< result_array->Value(i) <<" "<< correct_array->Value(i)<<std::endl;
              }
            }
        }
    
        if(error_count == 0) {
          std::cout << "Test passed!" << std::endl;
        } else {
          std::cout << "Test failed. Found " << error_count << " errors in the output Arrow array" << std::endl;
        }
    }
    
    

}
