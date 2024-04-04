#include <chrono>

static std::chrono::high_resolution_clock::time_point start = std::chrono::high_resolution_clock::now();

extern "C" {
  void startTime() {
    auto start = std::chrono::high_resolution_clock::now();
  }

  double endTime() {
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::micro> elapsed_time = end - start;
    return elapsed_time.count();
  }
};
