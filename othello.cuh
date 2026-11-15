#pragma once // read this file only once even if it is included multiple times
#include <cstdint> // this gives us uint64_t
#ifdef __CUDACC__ // if gpu compiler is reading the file
#define HD  __host__ __device__ __forceinline__ // this means the function can be called from both CPU and GPU
#define HDR __host__ __device__        // recursive functions cannot be force-inlined
#else                                  // compiling with g++
#define HD  static inline
#define HDR static
#endif

// ---------------------------------------------------------------------------
// Step 1: the board as two 64-bit numbers
// ---------------------------------------------------------------------------
struct Board{
    uint64_t black;
    uint64_t white;
    int side;
};




