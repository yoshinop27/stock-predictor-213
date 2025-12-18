// #include <stdio.h>
// #include <stdlib.h>
// #include <string.h>
// #include <cuda_runtime.h>
// #include <stddef.h>
// #include <math.h>

// #define PERIOD 30
// #define MAX_DAYS 200

typedef struct linreg {
    double sumY;
    double sumXY;
} linreg_t;

// // Function to calculate statistics over a dataset
// __global__ void kernel (float* data, float* sma_output, float* gpu_rsi_output, linreg_t* linreg, int length) {
//     switch(blockIdx.x) {
//         case 0:
//             // Simple Moving Average Calculation
//             int day = threadIdx.x + (PERIOD - 1);
//             if (day >= length) {
//                 return;
//             }

//             // Move to start of period (period days before current day)
//             float* first_day = data + (day - (PERIOD - 1));

//             // calculate sum
//             float sum = 0;
//             for (int i = 0; i < PERIOD; i++){
//                 sum += first_day[i];
//             }

//             // calculate sma and store result
//             sma_output[day] = sum / PERIOD;   
//             break;
//         case 1:
//             // Relative Strength Index
//             int day_rsi = threadIdx.x;
//             // Bounds checking
//             if (day_rsi == 0 || day_rsi >= length) {
//                 return;
//             }

//             float change = data[day_rsi] - data[day_rsi - 1];
//             gpu_rsi_output[day_rsi] = change; // Placeholder for RSI calculation
//             break;
//         case 2:
//             // Linear Regression - sumY
//             __shared__ float closing_prices[PERIOD];
//             int day_lr = threadIdx.x;
//             // transfer data into a shared array that can be manipulated
//             closing_prices[day_lr] = data[day_lr];
//             __syncthreads();

//             // perform linear regression calculations here
//             for (int i = 0; i < PERIOD; i*=2) {
//                 if (day_lr & i == 0 && day_lr + i < PERIOD) {
//                     closing_prices[day_lr] += closing_prices[day_lr + i];
//                     __syncthreads();
//                 }
//             }
//             linreg->sumY = closing_prices[0];
//             break;
//         case 3:
//             // Linear Regression - sumXY
//             __shared__ float xy_prices[PERIOD];
//             int day_lr_2 = threadIdx.x;
//             // transfer data into a shared array that can be manipulated
//             xy_prices[day_lr_2] = data[day_lr_2] * day_lr_2;
//             __syncthreads();

//             // perform linear regression calculations here
//             for (int i = 0; i < PERIOD; i*=2) {
//                 if (day_lr_2 & i == 0 && day_lr_2 + i < PERIOD) {
//                     xy_prices[day_lr_2] += xy_prices[day_lr_2 + i];
//                     __syncthreads();
//                 }
//             }
//             linreg->sumXY = xy_prices[0];
//             break;
//     }
    
// }