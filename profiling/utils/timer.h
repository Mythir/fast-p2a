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

// The timer class is based on code from Johan Peltenburg (https://github.com/johanpel)

#pragma once

#include <chrono>
#include <vector>

class Timer {
  using system_clock = std::chrono::system_clock;
  using nanoseconds = std::chrono::nanoseconds;
  using time_point = std::chrono::time_point<system_clock, nanoseconds>;
  using duration = std::chrono::duration<double>;

  private:
    std::vector<double> history;
  
    time_point start_{};
    time_point stop_{};
  
  public:
    Timer() = default;
  
    inline void start() { start_ = std::chrono::high_resolution_clock::now(); }
    inline void stop() { stop_ = std::chrono::high_resolution_clock::now(); }
  
    inline void record() { history.push_back(this->seconds()); }
    inline void clear_history() { history.clear(); }
  
    double seconds();
    double average();
    double total();
};
