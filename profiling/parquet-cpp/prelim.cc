// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements. See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership. The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

/*
 * Author: Lars van Leeuwen
 * Code for benchmarking the performance of Arrow's Parquet function
 * Lots of the code here is based on example code provided in the Parquet GitHub repo (https://github.com/apache/parquet-cpp/)
 */

#include <stdlib.h>
#include <cstdlib>
#include <iomanip>
#include <ctime>

#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>
#include <parquet/exception.h>
#include <parquet/properties.h>
#include <parquet/file_reader.h>
#include <parquet/types.h>
#include <string.h>

//Struct for timing code
#include "../utils/timer.h"

// #0 Build dummy data to pass around
// To have some input data, we first create an Arrow Table that holds
// some data.
std::shared_ptr<arrow::Table> generate_table(int num_values) {
  arrow::Int64Builder i64builder;
  for(int i=0; i<num_values; i++){
    int number = rand();
    PARQUET_THROW_NOT_OK(i64builder.Append(number));
  }
  std::shared_ptr<arrow::Array> i64array;
  PARQUET_THROW_NOT_OK(i64builder.Finish(&i64array));

  std::shared_ptr<arrow::Schema> schema = arrow::schema(
      {arrow::field("int", arrow::int64(), true)});

  return arrow::Table::Make(schema, {i64array});
}

// #1 Write out the data as a Parquet file
void write_parquet_file(const arrow::Table& table, std::string filename, int chunk_size, bool compression, bool dictionary) {
  std::shared_ptr<arrow::io::FileOutputStream> outfile;
  PARQUET_THROW_NOT_OK(
      arrow::io::FileOutputStream::Open(filename, &outfile));
  // The last argument to the function call is the size of the RowGroup in
  // the parquet file. Normally you would choose this to be rather large but
  // for the example, we use a small value to have multiple RowGroups.
  
  //Adjust compression type
  auto builder = std::make_shared<parquet::WriterProperties::Builder>();

  if(compression){
    builder->compression(parquet::Compression::SNAPPY);
  }
  else{
    builder->compression(parquet::Compression::UNCOMPRESSED);
  }

  if(dictionary){
    //builder->enable_dictionary();
  }
  else{
    builder->disable_dictionary();
  }


  PARQUET_THROW_NOT_OK(
      parquet::arrow::WriteTable(table, arrow::default_memory_pool(), outfile, chunk_size, builder->build()));
}

std::shared_ptr<arrow::Table> read_whole_file(std::string file_path){
  //Code for the actual reading
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_THROW_NOT_OK(arrow::io::ReadableFile::Open(
      file_path, arrow::default_memory_pool(), &infile));

  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(
      parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));
  std::shared_ptr<arrow::Table> table;
  PARQUET_THROW_NOT_OK(reader->ReadTable(&table));

  return table;
}

/*
void parquet_to_arrow_benchmark(std::string file_path, int iterations) {
  std::vector<clock_t> times;
  std::shared_ptr<arrow::Table> table;
  clock_t starttime;
  clock_t stoptime;
  int average;
  int total = 0;

  std::cout << "Reading " << file_path<< std::endl;

  for(int i=0; i<iterations; i++){
    starttime = std::clock();
    table = read_whole_file(file_path);
    stoptime = std::clock();
    times.push_back(stoptime-starttime);
  }

  for(int i=0; i<times.size(); i++){
    total += times[i];
  }
  average = total/times.size();
  std::cout<<"Total time: "<<total<<std::endl;
  std::cout << "Loaded " << table->num_rows() << " rows in " << table->num_columns()
            << " columns. Average time for " << iterations << " iterations: " << average << std::endl;
}
*/

void parquet_to_arrow_benchmark(std::string file_path, int iterations) {
  std::shared_ptr<arrow::Table> table;
  Timer t;

  std::cout << "Reading " << file_path<< std::endl;

  for(int i=0; i<iterations; i++){
    t.start();
    table = read_whole_file(file_path);
    t.stop();
    t.record();
  }
  std::cout<<"Total time: "<<t.total()<<std::endl;
  std::cout << "Loaded " << table->num_rows() << " rows in " << table->num_columns()
            << " columns. Average time for " << iterations << " iterations: " << t.average() << std::endl;

  t.clear_history();
}

void examine_metadata(std::string file_path) {
  std::shared_ptr<parquet::FileMetaData> md;
  std::unique_ptr<parquet::ParquetFileReader> file;
  std::unique_ptr<parquet::RowGroupMetaData> rmd;
  std::unique_ptr<parquet::ColumnChunkMetaData> ccmd;

  file = parquet::ParquetFileReader::OpenFile(file_path);

  md=file->metadata();
  std::cout<<md->size()<<" "<<md->num_columns()<<" "<<md->num_rows()<<std::endl;

  rmd = md->RowGroup(0);
  ccmd = rmd->ColumnChunk(0);

  std::cout<<"Amount of rowgroups: "<<md->num_row_groups()<<std::endl;

  for(auto &enc : ccmd->encodings()){
    std::cout<<enc<<std::endl;
  }

  std::cout<<"compression(): "<<ccmd->compression()<<std::endl;
  std::cout<<"total_compressed_size: "<<ccmd->total_compressed_size()<<std::endl;
  std::cout<<"total_uncompressed_size: "<<ccmd->total_uncompressed_size()<<std::endl;
  std::cout<<"data_page_offset: "<<ccmd->data_page_offset()<<std::endl;
  std::cout<<"dictionary_page_offset: "<<ccmd->dictionary_page_offset()<<std::endl;


  std::shared_ptr<parquet::RowGroupReader> rg = file->RowGroup(0);
  std::shared_ptr<parquet::PageReader> pr = rg->GetColumnPageReader(0);
  std::shared_ptr<parquet::Page> page;

  do{
    page = pr->NextPage();
    std::cout<<"Page type: "<<page->type()<<std::endl;
  }while(page->type() != 0);

  
  std::cout<<"num_values: "<<std::static_pointer_cast<parquet::DataPage>(page)->num_values()<<" size: "<<page->size()<<" encoding: "<<std::static_pointer_cast<parquet::DataPage>(page)->encoding()<<std::endl;
  for(int i=0; i<40;i++){
    std::cout<<i<<" data uint8: "<<std::hex<<std::setfill('0')<<std::setw(2)<<static_cast<unsigned int>(page->data()[i])<<std::dec<<std::endl;
  }
  
  std::cout<<std::endl;


}

int main(int argc, char** argv) {
  if(argc<2){
    std::cout<<"Usage: prelim num_values [iterations]"<<std::endl;
    return 1;
  }

  int num_values = atoi(argv[1]);
  int iterations = 1;

  if(argc==3){
    iterations = atoi(argv[2]);
  }

  std::cout<<"Size of Arrow table: "<<num_values<<" values."<<std::endl;
  std::shared_ptr<arrow::Table> table = generate_table(num_values);

  write_parquet_file(*table, "int64array.prq", num_values, true, true);
  write_parquet_file(*table, "int64array_nosnap.prq", num_values, false, true);
  write_parquet_file(*table, "int64array_nodict.prq", num_values, true, false);
  write_parquet_file(*table, "int64array_nosnap_nodict.prq", num_values, false, false);

/*
  examine_metadata("int64array.prq");
  examine_metadata("int64array_nosnap.prq");
  examine_metadata("int64array_nodict.prq");
  examine_metadata("int64array_nosnap_nodict.prq");
*/

  parquet_to_arrow_benchmark("int64array.prq", iterations);
  parquet_to_arrow_benchmark("int64array_nosnap.prq", iterations);
  parquet_to_arrow_benchmark("int64array_nodict.prq", iterations);
  parquet_to_arrow_benchmark("int64array_nosnap_nodict.prq", iterations);

  /* std::shared_ptr<arrow::Int64Array> i64Array = std::static_pointer_cast<arrow::Int64Array>(table->column(0)->data()->chunk(0));

  for(int i=0; i<10; i++){
    std::cout<<i64Array->Value(i)<<std::endl;
  }*/
}