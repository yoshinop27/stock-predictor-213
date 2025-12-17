#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <stddef.h>
#include <cmath>
#include "algorithms/sma.cu"
#include "util.h"

#define PERIOD 30
#define MAX_DAYS 200
#define LENGTH 90

// Function to calculate SMAs over a dataset
__global__ void kernel (float* data, float* sma_output) {


    // Positional variables - support multiple blocks
    // Map thread index to day index (thread 0 -> day 29, thread 1 -> day 30, etc.)
    int thread_idx = blockIdx.x * blockDim.x + threadIdx.x;
    int day = thread_idx + (PERIOD - 1);  // Add 29 to get actual day index

    // Bounds check: ensure we don't exceed array bounds
    if (day >= LENGTH) {
        return;
    }

    // Move to start of period (period days before current day)
    float* first_day = data + (day - (PERIOD - 1));

    // calculate sum
    float sum = 0;
    for (int i = 0; i < PERIOD; i++){
        sum += first_day[i];
    }

    // calculate sma and store result
    sma_output[day] = sum / PERIOD;   
}

int main(int argc, char** argv){

    printf("This is a Stock Predictor\n");
    // Store the user's input
    char buff[100];

    printf("Enter a Path to the CSV file: \n");
    
    FILE *file;
    // Loop until user gives us a good path
    while (1){

        // Read input from the user
        fgets(buff, sizeof(buff), stdin);
        int sizeStr = strlen(buff);

        //remove the new-line at the end
        buff[strcspn(buff, "\n")] = 0;

        // get file
        if ((file = fopen(buff, "r")) != NULL){
            break;
        }

        printf("Please provide the correct file path from the root.\n");
    }

    // read file line by line (store first value in closing_prices array)
    char line[200];
    int i = 0;

    // variables to store data in
    char* date[MAX_DAYS];
    float open[MAX_DAYS];
    float high[MAX_DAYS];
    float low[MAX_DAYS];
    float close[MAX_DAYS];
    float adj_close[MAX_DAYS];
    float volume[MAX_DAYS];

    // parse line
    while (fgets(line, sizeof(line), file) != NULL && i < MAX_DAYS){
        sscanf(line, "%s,%f,%f,%f,%f,%f,%f", &date, &open, &high, &low, &close, &adj_close, &volume);
        i++;
    }

    // close the file
    fclose(file);

    // Calculate number of threads needed (one for each day starting from day 29)
    int num_threads_total = i - (29);
    if (num_threads_total <= 0) {
        printf("Not enough data points. Need at least 30 days.\n");
        return 1;
    }

    // Allocate GPU memory for data
    float* gpu_data;
    if (cudaMalloc(&gpu_data, sizeof(float) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate data on GPU\n");
        return 1;
    }

    // Allocate GPU memory for SMA output
    float* gpu_sma_output;
    if (cudaMalloc(&gpu_sma_output, sizeof(float) * num_threads_total) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate SMA output on GPU\n");
        cudaFree(gpu_data);
        return 1;
    }

    // Copy data to GPU
    if (cudaMemcpy(gpu_data, close, sizeof(float) * i, cudaMemcpyHostToDevice) != cudaSuccess) {
        fprintf(stderr, "Failed to copy data to GPU\n");
        cudaFree(gpu_data);
        cudaFree(gpu_sma_output);
        return 1;
    }

    // Run the kernel with one thread per day (minus 29)
    kernel<<<1, num_threads_total>>>(gpu_data, gpu_sma_output);

    // Wait for kernel to complete
    cudaDeviceSynchronize();

    // Allocate host memory for results
    float sma_results[num_threads_total];

    // Copy results back from GPU
    if (cudaMemcpy(sma_results, gpu_sma_output, sizeof(float) * num_threads_total, cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from GPU\n");
    }

    // calculate differences between each days sma and the previous days sma w/ discounting factor
    float differences[num_threads_total-1];
    float discounting_factor = .99;
    int k=1;
    for (int day = num_threads_total-2; day > 0; day--) {
        differences[day] = (sma_results[day] - sma_results[day-1]) * pow(discounting_factor,k);
        k++;
    }

    // calculate the average difference
    float average_difference = 0;
    for (int i = 0; i < num_threads_total - 2; i++) {
        average_difference += differences[i];
    }
    average_difference /= (num_threads_total - 2);

    printf("%d\n", average_difference);

    // Free all memory
    cudaFree(gpu_data);
    cudaFree(gpu_sma_output);
}