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

#pragma once

#include <stdlib.h>
#include <string.h>

#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/properties.h>
#include <parquet/types.h>

#include <ptoa.h>

namespace ptoa{

/**
 * Class that implements as fast as possible Parquet reading functionality equivalent to that of the hardware.
 */
class SWParquetReader {
  public:
    SWParquetReader(std::string file_path);
    ~SWParquetReader(){free(parquet_data);}
    status read_prim(int32_t prim_width, int64_t num_values, int32_t file_offset, uint8_t* arr_buf_ptr);
    status inspect_metadata(int32_t file_offset);
    status count_pages(int32_t file_offset);

  private:
  	status read_metadata(uint8_t* metadata, int32_t* uncompressed_size, int32_t* compressed_size, int32_t* num_values, int32_t* def_level_length, int32_t* rep_level_length, int32_t* metadata_size);

    int decode_varint32(uint8_t* input, int32_t* result, bool zigzag);

  	uint8_t* parquet_data;
  	size_t file_size;
};

}
