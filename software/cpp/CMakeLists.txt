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
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(PTOA ptoa)

project(${PTOA} VERSION 0.0.1 DESCRIPTION "ptoa software library")

set(SOURCES
		src/ptoa/SWParquetReader.cpp)

set(HEADERS
		src/ptoa/SWParquetReader.h
		src/ptoa/ptoa.h)

add_library(${PTOA} SHARED ${HEADERS} ${SOURCES})

find_library(LIB_ARROW arrow)
find_library(LIB_PARQUET parquet)
find_library(LIB_FLETCHER fletcher)

target_link_libraries(${PTOA} ${LIB_PARQUET} ${LIB_ARROW} $(LIB_FLETCHER))
