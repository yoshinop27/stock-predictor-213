#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include <stddef.h>
#include <math.h>

#define PERIOD 30
#define MAX_DAYS 200

// Function to calculate SMAs over a dataset
__global__ void kernel (float* data, float* sma_output, int length) {
    int thread_idx = blockIdx.x * blockDim.x + threadIdx.x;
    int day = thread_idx + (PERIOD - 1);
    if (day >= length) {
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

    char date[MAX_DAYS][20];
    float open[MAX_DAYS];
    float high[MAX_DAYS];
    float low[MAX_DAYS];
    float close[MAX_DAYS];
    float adj_close[MAX_DAYS];
    float volume[MAX_DAYS];

    while (fgets(line, sizeof(line), file) != NULL && i < MAX_DAYS){
        sscanf(line, "%19[^,],%f,%f,%f,%f,%f,%f", date[i], &open[i], &high[i], &low[i], &close[i], &adj_close[i], &volume[i]);
        i++;
    }

    // close the file
    fclose(file);

    int num_threads_total = i - (PERIOD - 1);
    if (num_threads_total <= 0) {
        printf("Not enough data points. Need at least 30 days.\n");
        return 1;
    }

    float* gpu_data;
    if (cudaMalloc(&gpu_data, sizeof(float) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate data on GPU\n");
        return 1;
    }

    float* gpu_sma_output;
    if (cudaMalloc(&gpu_sma_output, sizeof(float) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate SMA output on GPU\n");
        cudaFree(gpu_data);
        return 1;
    }

    if (cudaMemcpy(gpu_data, close, sizeof(float) * i, cudaMemcpyHostToDevice) != cudaSuccess) {
        fprintf(stderr, "Failed to copy data to GPU\n");
        cudaFree(gpu_data);
        cudaFree(gpu_sma_output);
        return 1;
    }

    int threads_per_block = 256;
    int num_blocks = (num_threads_total + threads_per_block - 1) / threads_per_block;
    kernel<<<num_blocks, threads_per_block>>>(gpu_data, gpu_sma_output, i);

    cudaDeviceSynchronize();

    float* sma_results = malloc(sizeof(float) * i);

    if (cudaMemcpy(sma_results, gpu_sma_output, sizeof(float) * i, cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from GPU\n");
    }

    float differences[num_threads_total-1];
    float discounting_factor = 0.99f;
    int k = 1;
    for (int day = PERIOD; day < i; day++) {
        differences[day - PERIOD] = (sma_results[day] - sma_results[day - 1]) * powf(discounting_factor, k);
        k++;
    }

    float average_difference = 0;
    for (int j = 0; j < num_threads_total - 1; j++) {
        average_difference += differences[j];
    }
    average_difference /= (num_threads_total - 1);

    printf("%f\n", average_difference);

    free(sma_results);

    // Free all memory
    cudaFree(gpu_data);
    cudaFree(gpu_sma_output);
}