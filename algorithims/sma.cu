#include <stdio.h>
#include <stddef.h>

#define MAX 1000000

// create struct type
typedef struct sma {
    intptr_t period;
    intptr_t sum;
} sma_t;

// create time data type
typedef struct data {
    int values[MAX];
    size_t length;
    int period;
} data_t;


// Function to calculate SMAs over a dataset
__global__ void kernel (data_t* data) {

    // retrieve data 
    int* values = data->values;
    int length = data->length;
    int period = data->period;

    // Positional variables
    int day = threadIdx.x;

    // Move to start of 30 day period
    int* first_day = values + (day - 29);

    // calculate sum
    int sum = 0;
    for (int i = 0; i <= period; i++){
        int* cur_day = first_day + i * sizeof(int);
        sum += *cur_day;
    }

    // calculate sma
    int sma = sum/period;   

}

// Thread Function
void* sma_thread (void* args) {

    // Cast params to appropriate fields
    sma_t* sma_args = (sma_t*)args;
    intptr_t period = sma_args->period;
    intptr_t sum = sma_args->sum;

    // sma calculation
    int sma = sum/period;


}