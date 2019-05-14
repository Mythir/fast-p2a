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
#include <LemireBitUnpacking.h>
#include <ptoa.h>

namespace ptoa {


status SWParquetReader::read_prim_delta(int32_t prim_width, int64_t num_values, int32_t file_offset, std::shared_ptr<arrow::PrimitiveArray>* prim_array){
    return status::OK;

}

status SWParquetReader::read_prim_delta(int32_t prim_width, int64_t num_values, int32_t file_offset, std::shared_ptr<arrow::PrimitiveArray>* prim_array, std::shared_ptr<arrow::Buffer> arr_buffer){
    std::cout<< "Delta reading for pre allocated buffers not yet implemented"<<std::endl;
    return status::FAIL;
}

}