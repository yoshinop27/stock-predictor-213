#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include "algorithims/sma.cu"

#define MAX_DAYS 1000000

int main(int argc, char** argv){
    printf("This is a Stock Predictor\n");
    // Store the user's input
    char buff[100];

    // write values to closing prices array
    int* closing_prices = malloc(sizeof(int) * MAX_DAYS);

    printf("Enter a Path to the CSV file: \n");
  
    // Read input from the user
    fgets(buff, sizeof(buff), stdin);
    int sizeStr = strlen(buff);

    //remove the new-line at the end
    buff[strcspn(buff, "\n")] = 0;

    //go to the file and open
    FILE *file;
    file = fopen(buff, "r");
    if(file == NULL){
        perror("Failed to open file");
        return 1;
    }

    // read file line by line (store first value in closing_prices array)
    char line[1000];
    int i = 0;
    while (fgets(line, sizeof(line), file) != NULL && i < MAX_DAYS){
        closing_prices[i] = atoi(line);
        i++;
    }

    // close the file
    fclose(file);

    // Set up kernel GPU
    data_t* data = malloc(sizeof(data_t));
    data->values = closing_prices;
    data->period = 30;
    data->length = i;

    // Calculate number of threads needed (one for each day starting from day 29)
    int num_threads_total = i - (data->period - 1);
    if (num_threads_total <= 0) {
        printf("Not enough data points. Need at least 30 days.\n");
        return 1;
    }

    // threads per block
    int threads_per_block = i;

    // Allocate GPU memory for data
    data_t* gpu_data;
    if (cudaMalloc(&gpu_data, sizeof(data_t)) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate data on GPU\n");
        return 1;
    }

    // Allocate GPU memory for SMA output
    int* gpu_sma_output;
    if (cudaMalloc(&gpu_sma_output, sizeof(int) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate SMA output on GPU\n");
        cudaFree(gpu_data);
        return 1;
    }

    // Copy data to GPU
    if (cudaMemcpy(gpu_data, data, sizeof(data_t), cudaMemcpyHostToDevice) != cudaSuccess) {
        fprintf(stderr, "Failed to copy data to GPU\n");
        cudaFree(gpu_data);
        cudaFree(gpu_sma_output);
        return 1;
    }

    // Run the kernel with one thread per day (minus 29)
    kernel<<<num_blocks, threads_per_block>>>(gpu_data, gpu_sma_output);

    // Wait for kernel to complete
    cudaDeviceSynchronize();

    // Allocate host memory for results
    int* sma_results = malloc(sizeof(int) * i);

    // Copy results back from GPU
    if (cudaMemcpy(sma_results, gpu_sma_output, sizeof(int) * i, cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from GPU\n");
    }

    // calculate differences between each days sma and the previous days sma w/ discounting factor
    int differeneces[i];
    int discounting_factor = .99;
    for (int day = i-1; day >= 0; day--) {
        differences[day] = (sma_results[day] - sma_results[day-1]) * discounting_factor;
    }

    // calculate the average difference
    int average_difference = 0;
    for (int day = i-1; day >= 0; day--) {
        average_difference += differences[day];
    }
    average_difference /= i;

    // Free all memory
    cudaFree(gpu_data);
    cudaFree(gpu_sma_output);
    free(sma_results);
    free(data);
    free(closing_prices);
}