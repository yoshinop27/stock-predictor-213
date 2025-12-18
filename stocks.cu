#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include <stddef.h>
#include <math.h>
#include "util.h"

#define PERIOD 30
#define MAX_DAYS 200

// defining functions
__global__ void kernel (float* data, float* sma_output, float* gpu_rsi_output, linreg_t linreg, int length);

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

    float* gpu_rsi_output;
    if (cudaMalloc(&gpu_rsi_output, sizeof(float) * i) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate RSI output on GPU\n");
        cudaFree(gpu_data);
        cudaFree(gpu_sma_output);
        return 1;
    }

    linreg_t* gpu_linreg;
    if (cudaMalloc(&gpu_linreg, sizeof(linreg_t)) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate gpu linreg output on GPU\n");
        cudaFree(gpu_data);
        cudaFree(gpu_linreg);
        return 1;
    }

    // Run Kernel
    int threads_per_block = 90;
    kernel<<<2, threads_per_block>>>(gpu_data, gpu_sma_output, gpu_rsi_output, gpu_linreg, i);

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

    linreg_t linreg_result;
    if (cudaMemcpy(&linreg_result, gpu_linreg, sizeof(linreg_t), cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy linreg results from GPU\n");
    }

    printf("Linear Regression SumY: %f\n", linreg_result.sumY);

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

    float pos_rsi = 0.0f;
    float neg_rsi = 0.0f;
    int gain_count = 0;
    int loss_count = 0;
    for (int day = 1; day < i; day++) {
        if (rsi_results[day] > 0) {
            pos_rsi += rsi_results[day];
            gain_count++;
        } else if (rsi_results[day] < 0) {
            neg_rsi += fabs(rsi_results[day]);
            loss_count++;
        }
    }
    float avg_gain = gain_count > 0 ? pos_rsi / gain_count : 0.0f;
    float avg_loss = loss_count > 0 ? neg_rsi / loss_count : 0.0f;

    float final_rsi = 0.0f;
    if (avg_loss > 0.0f) {
        float rs = avg_gain / avg_loss;
        final_rsi = 100.0f - (100.0f / (1.0f + rs));
    }

    printf("RSI: %f\n", final_rsi);

    cudaFree(gpu_data);
    cudaFree(gpu_sma_output);
    cudaFree(gpu_rsi_output);
    cudaFree(gpu_linreg);
}

// Function to calculate statistics over a dataset
__global__ void kernel (float* data, float* sma_output, float* gpu_rsi_output, linreg_t* linreg, int length) {
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
        case 2:
            // Linear Regression - sumY
            __shared__ float closing_prices[PERIOD];
            int day_lr = threadIdx.x;
            // transfer data into a shared array that can be manipulated
            closing_prices[day_lr] = data[day_lr];
            __syncthreads();

            // perform linear regression calculations here
            for (int i = 0; i < PERIOD; i*=2) {
                if (day_lr & i == 0 && day_lr + i < PERIOD) {
                    closing_prices[day_lr] += closing_prices[day_lr + i];
                    __syncthreads();
                }
            }
            linreg->sumY = closing_prices[0];
            break;
        case 3:
            // Linear Regression - sumXY
            __shared__ float xy_prices[PERIOD];
            int day_lr_2 = threadIdx.x;
            // transfer data into a shared array that can be manipulated
            xy_prices[day_lr_2] = data[day_lr_2] * day_lr_2;
            __syncthreads();

            // perform linear regression calculations here
            for (int i = 0; i < PERIOD; i*=2) {
                if (day_lr_2 & i == 0 && day_lr_2 + i < PERIOD) {
                    xy_prices[day_lr_2] += xy_prices[day_lr_2 + i];
                    __syncthreads();
                }
            }
            linreg->sumXY = xy_prices[0];
            break;
    }
}
