# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

cmake_minimum_required(VERSION 3.10)

project(main)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC -Ofast -march=native")

set(PRIM prim)

project(${PRIM} VERSION 0.0.1 DESCRIPTION "prim benchmarks")

set(SOURCES
		../ptoa/LemireBitUnpacking.cpp
		../ptoa/SWParquetReaderDelta.cpp
		../ptoa/SWParquetReader.cpp
		../../utils/timer.cpp
		src/prim.cpp)

set(HEADERS
		../ptoa/LemireBitUnpacking.h
		../ptoa/SWParquetReader.h
		../ptoa/ptoa.h
		../../utils/timer.h)

find_library(LIB_ARROW arrow)
find_library(LIB_PARQUET parquet)

add_executable(${PRIM} ${HEADERS} ${SOURCES})

target_include_directories(${PRIM} PRIVATE ../../utils ../ptoa)
target_link_libraries(${PRIM} ${LIB_PARQUET} ${LIB_ARROW})
