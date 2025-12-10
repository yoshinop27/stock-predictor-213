#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char** argv){
    printf("This is a Stock Predic")
    char buff[500];
  
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
    }

}