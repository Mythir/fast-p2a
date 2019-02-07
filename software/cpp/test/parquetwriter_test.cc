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

#include <stdlib.h>
#include <cstdlib>
#include <string.h>

#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/thrift.h>

#include "../src/ptoa/parquetwriter.h"
#include "../src/ptoa/ptoa.h"

std::string gen_random_string(const int length) {
    static const char alphanum[] =
            "0123456789"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "abcdefghijklmnopqrstuvwxyz";

    std::string result(length, 0);

    for (int i = 0; i < length; ++i) {
        result[i] = alphanum[rand() % (sizeof(alphanum) - 1)];
    }

    return result;
}

std::shared_ptr<arrow::Table> generate_int64_table(int num_values) {
    arrow::Int64Builder i64builder;
    for (int i = 0; i < num_values; i++) {
        int number = rand();
        PARQUET_THROW_NOT_OK(i64builder.Append(number));

    }
    std::shared_ptr<arrow::Array> i64array;
    PARQUET_THROW_NOT_OK(i64builder.Finish(&i64array));

    std::shared_ptr<arrow::Schema> schema = arrow::schema(
            {arrow::field("int", arrow::int64(), true)});

    return arrow::Table::Make(schema, {i64array});
}

std::shared_ptr<arrow::Table> generate_str_table(int num_values, int min_length, int max_length) {
    arrow::StringBuilder strbuilder;
    for (int i = 0; i < num_values; i++) {
        int length = rand() % (max_length - min_length + 1) + min_length;
        PARQUET_THROW_NOT_OK(strbuilder.Append(gen_random_string(length)));
    }
    std::shared_ptr<arrow::Array> strarray;
    PARQUET_THROW_NOT_OK(strbuilder.Finish(&strarray));

    std::shared_ptr<arrow::Schema> schema = arrow::schema(
            {arrow::field("str", arrow::utf8(), true)});

    return arrow::Table::Make(schema, {strarray});
}

int main(int argc, char **argv) {
  auto writer = std::make_shared<ptoa::ParquetWriter>();

  std::shared_ptr<arrow::Table> test_table = generate_int64_table(100);

  writer->write(test_table, "./test_nodict.prq");

  writer->enable_dictionary();

  writer->write(test_table, "./test_yesdict.prq");

  format::DictionaryPageHeader dict_page_header;


  return 0;
}