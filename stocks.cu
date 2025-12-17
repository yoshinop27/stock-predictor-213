#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include <stddef.h>
#include <math.h>

#define PERIOD 30
#define MAX_DAYS 200

// defining functions
__global__ void kernel (float* data, float* sma_output, float* gpu_rsi_output, int length);

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

    // Num of threads per block
    int num_threads_total = i - (PERIOD - 1);

    // Moving data to the GPU for SMAs
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

    // Memory allocation for RSI
    float* gpu_rsi_output;
    if (cudaMalloc(&gpu_rsi_output, sizeof(float) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate SMA output on GPU\n");
        cudaFree(gpu_data);
        return 1;
    }

    // Run Kernel
    int threads_per_block = 90;
    kernel<<<2, threads_per_block>>>(gpu_data, gpu_sma_output, gpu_rsi_output, i);

    cudaDeviceSynchronize();

    // Copy results back to host

    float sma_results[i];
    if (cudaMemcpy(sma_results, gpu_sma_output, sizeof(float) * i, cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from GPU\n");
    }

    float rsi_results[i];
    if (cudaMemcpy(rsi_results, gpu_rsi_output, sizeof(float) * i, cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from GPU\n");
    }

    // Calculate average difference of SMAs with discounting factor

    float differences[num_threads_total-1];
    for (int day = PERIOD; day < i; day++) {
        differences[day - PERIOD] = (sma_results[day] - sma_results[day - 1]);
    }

    float average_difference = 0;
    float discounting_factor = 0.99f;
    for (int j = 0; j < num_threads_total - 1; j++) {
        average_difference += differences[j] * powf(discounting_factor, j);
    }
    average_difference /= (num_threads_total - 1);

    printf("SMA: %f\n", average_difference);

    // Calculate average RSI change

    float pos_rsi;
    float neg_rsi;
    for (int day = 1; day < i; day++) {
        if (rsi_results[day] > 0) {
            pos_rsi += rsi_results[day];
        } else {
            neg_rsi += rsi_results[day];
        }
    }
    float avg_gain = pos_rsi / (i - 1);
    float avg_loss = neg_rsi / (i - 1);

    float final_rsi = 100 - (100 / (1 + (avg_gain / fabs(avg_loss)))); // geeksforgeeks.org/c/fabs-function-in-c


    printf("RSI: %f\n", final_rsi);

    // Free all memory
    cudaFree(gpu_data);
    cudaFree(gpu_sma_output);
}

// Function to calculate SMAs over a dataset
__global__ void kernel (float* data, float* sma_output, float* gpu_rsi_output, int length) {
    switch(blockIdx.x) {
        case 0:
            // Simple Moving Average Calculation
            int day = threadIdx.x + (PERIOD - 1);
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
            break;
        case 1:
            // Relative Strength Index
            int day_rsi = threadIdx.x;
            // Bounds checking
            if (day_rsi == 0 || day_rsi >= length) {
                return;
            }

            float change = data[day_rsi] - data[day_rsi - 1];
            gpu_rsi_output[day_rsi] = change; // Placeholder for RSI calculation
            break;
    }
}