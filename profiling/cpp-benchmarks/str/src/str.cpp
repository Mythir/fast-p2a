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
    int num_strings;
    char* hw_input_file_path;
    char* reference_parquet_file_path;
    int iterations;
    bool verify_output;

    Timer t;

    if (argc > 5) {
      hw_input_file_path = argv[1];
      reference_parquet_file_path = argv[2];
      num_strings = (uint32_t) std::strtoul(argv[3], nullptr, 10);
      iterations = (uint32_t) std::strtoul(argv[4], nullptr, 10);
      if(argv[5][0] == 'y') {
        verify_output = true;
      } else if (argv[5][0] == 'n') {
        verify_output = false;
      } else {
        std::cerr << "Invalid argument. Option \"verify\" should be \"y\" or \"n\"" << std::endl;
        return 1;
      }
    } else {
      std::cerr << "Usage: str parquet_hw_input_file_path reference_parquet_file_path num_strings iterations verify(y or n)" << std::endl;
      return 1;
    }

    ptoa::SWParquetReader reader(hw_input_file_path);
    //reader.inspect_metadata(4);
    reader.count_pages(4);

    // Read correct array from reference file
    auto correct_array = std::dynamic_pointer_cast<arrow::StringArray>(readArray(std::string(reference_parquet_file_path)));

    // Get total amount of characters from string array for buffer allocation
    int num_chars = correct_array->value_offset(num_strings);

    std::shared_ptr<arrow::StringArray> result_array;
    std::shared_ptr<arrow::Buffer> off_buffer;
    std::shared_ptr<arrow::Buffer> val_buffer;

    // Only relevant for the benchmark with pre-allocated (and memset) buffer
    arrow::AllocateBuffer((num_strings+1)*sizeof(int32_t), &off_buffer);
    std::memset((void*)(off_buffer->mutable_data()), 0, (num_strings+1)*sizeof(int32_t));
    arrow::AllocateBuffer(num_chars, &val_buffer);
    std::memset((void*)(val_buffer->mutable_data()), 0, num_chars);
    
    for(int i=0; i<iterations; i++){
        t.start();
        // Reading the Parquet file. The interesting bit.
        if(reader.read_string(num_strings, 4, &result_array, off_buffer, val_buffer, ptoa::encoding::DELTA_LENGTH) != ptoa::status::OK){
            return 1;
        }
        t.stop();
        t.record();
    }

    std::cout << "Read " << num_strings << " strings" << std::endl;
    std::cout << "Average time in seconds (pre-allocated): " << t.average() << std::endl;

    t.clear_history();

    for(int i=0; i<iterations; i++){
        t.start();
        // Reading the Parquet file. The interesting bit.
        if(reader.read_string(num_strings, num_chars, 4, &result_array, ptoa::encoding::DELTA_LENGTH) != ptoa::status::OK){
            return 1;
        }
        t.stop();
        t.record();
    }

    std::cout << "Read " << num_strings << " strings" << std::endl;
    std::cout << "Average time in seconds (not pre-allocated): " << t.average() << std::endl;

    if(verify_output) {
        //std::cout<<"Num chars: "<<num_chars<<std::endl;
        //std::cout<<"Correct capacity: "<<correct_array->value_data()->capacity()<<" Result capacity: "<<correct_array->value_data()->capacity()<<std::endl;
    
        // Verify result
        int error_count = 0;
    
        for(int i=0; i<num_strings; i++) {
            if(result_array->GetString(i).compare(correct_array->GetString(i)) != 0) {
              error_count++;
              if(error_count<20) {
                std::cout<<i<<" "<<result_array->GetString(i)<<" -> "<<correct_array->GetString(i)<<std::endl;
              }
            }
        }

        if(result_array->length() != num_strings){
          error_count++;
        }
    
        if(error_count == 0) {
          std::cout << "Test passed!" << std::endl;
        } else {
          std::cout << "Test failed. Found " << error_count << " errors in the output Arrow array" << std::endl;
        }
    }
    
    

}
