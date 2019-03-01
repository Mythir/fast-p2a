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

#include "./parquetwriter.h"

#include <iostream>

namespace ptoa {

ParquetWriter::ParquetWriter(){
  builder = std::make_shared<parquet::WriterProperties::Builder>();

  //Default settings
  builder->dictionary_pagesize_limit(1000000000);
  builder->disable_dictionary();
  builder->memory_pool(arrow::default_memory_pool());
  builder->version(parquet::ParquetVersion::PARQUET_2_0);
  builder->encoding(parquet::Encoding::PLAIN);
  builder->compression(parquet::Compression::UNCOMPRESSED);
  builder->disable_statistics();
  chunk_size = 1000000;
}

void ParquetWriter::enable_dictionary(){
  builder->enable_dictionary();
}

void ParquetWriter::disable_dictionary(){
  builder->disable_dictionary();
}

status ParquetWriter::write(std::shared_ptr<arrow::Table> table, std::string file_path){
  std::shared_ptr<arrow::io::FileOutputStream> outfile;
  PARQUET_THROW_NOT_OK(
        arrow::io::FileOutputStream::Open(file_path, &outfile));

  std::shared_ptr<parquet::WriterProperties> props = builder->build();

  PARQUET_THROW_NOT_OK(
      parquet::arrow::WriteTable(*table, arrow::default_memory_pool(), outfile, chunk_size, props));

  return ptoa::status::OK;
}

}