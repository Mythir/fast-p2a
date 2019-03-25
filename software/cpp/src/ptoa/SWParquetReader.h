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

#include "./ptoa.h"

namespace ptoa{

/**
 * @brief Class that implements as fast as possible Parquet reading functionality equivalent to that of the hardware.
 */
class ParquetReader {
  public:
    SWParquetReader();

  private:
};

}
