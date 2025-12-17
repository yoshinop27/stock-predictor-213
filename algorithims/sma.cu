#include <stdio.h>
#include <stddef.h>

#define MAX 1000000

// create time data type
typedef struct data {
    int values[MAX];
    int period;
    int length;
} data_t;


// Function to calculate SMAs over a dataset
__global__ void kernel (data_t* data, int* sma_output) {

    // retrieve data 
    int* values = data->values;
    int length = data->length;
    int period = data->period;

    // Positional variables - support multiple blocks
    // Map thread index to day index (thread 0 -> day 29, thread 1 -> day 30, etc.)
    int thread_idx = blockIdx.x * blockDim.x + threadIdx.x;
    int day = thread_idx + (period - 1);  // Add 29 to get actual day index

    // Bounds check: ensure we don't exceed array bounds
    if (day >= length) {
        return;
    }

    // Move to start of period (period days before current day)
    int* first_day = values + (day - (period - 1));

    // calculate sum
    int sum = 0;
    for (int i = 0; i < period; i++){
        sum += first_day[i];
    }

    // calculate sma and store result
    sma_output[day] = sum / period;   
}
