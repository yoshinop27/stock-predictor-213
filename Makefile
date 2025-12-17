CC := nvcc
CFLAGS := -g

all: stocks 

clean:
	rm -f stocks

stocks: stocks.cu algorithms/sma.cu 
	$(CC) $(CFLAGS) -o stocks stocks.cu algorithms/sma.cu

zip:
	@echo "Generating stocks.zip file to submit to Gradescope..."
	@zip -q -r stocks.zip . -x .git/\* .vscode/\* .clang-format .gitignore stocks 
	@echo "Done. Please upload stocks.zip to Gradescope."

format:
	@echo "Reformatting source code."
	@clang-format -i --style=file $(wildcard *.c) $(wildcard *.h) $(wildcard *.cu)
	@echo "Done."

.PHONY: all clean zip format

