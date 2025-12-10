CC := clang
CFLAGS := -g -Wall -Werror -Wno-unused-function -Wno-unused-variable

all: stock-predictor

clean:
	rm -f stock-predictor

stock-predictor: main.c algorithims/sma.c
	$(CC) $(CFLAGS) -o stock-predictor main.c algorithims/sma.c -lpthread

zip:
	@echo "Generating stock-predictor.zip file to submit to Gradescope..."
	@zip -q -r stock-predictor.zip . -x .git/\* .vscode/\* .clang-format .gitignore stock-predictor
	@echo "Done. Please upload stock-predictor.zip to Gradescope."
