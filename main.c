#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char** argv){
    // User can pass in one file on the command line
    char* filepath = argv[1];
    printf("This is a stock predictor. <Something about providing the path to the file>");
    FILE *file = fopen(filepath, "r");
    if (file == NULL) {
        printf("The file is not opened.");
    }

}