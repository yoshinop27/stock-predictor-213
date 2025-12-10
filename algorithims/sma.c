#include <stdio.h>
#include <stddef.h>

#define MAX 1000000

// create struct type
typedef struct sma {
    intptr_t period;
    intptr_t sum;
} sma_t;


// Function to calculate SMAs over a dataset
void calculate_sma (int data[]) {

    // Array to store results
    float sma_results[MAX];

    // Length of period
    int period = 30;
    // TODO Create thread that takes in (data point, period, data)


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