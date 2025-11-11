# Makefile for fixed2csv

CC = gcc
CFLAGS = -Wall -O2
TARGET = fixed2csv
SOURCE = fixed2csv.c

.PHONY: all clean test

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE)

clean:
	rm -f $(TARGET) sample_output.csv sample_output.tsv

test: $(TARGET)
	@echo "=== テスト1: CSV出力（トリミングあり） ==="
	./$(TARGET) -w 10,20,10 -d , -t sample_input.txt sample_output.csv
	@echo ""
	@echo "=== 出力内容 ==="
	cat sample_output.csv
	@echo ""
	@echo "=== テスト2: TSV出力（トリミングあり） ==="
	./$(TARGET) -w 10,20,10 -d $$'\t' -t sample_input.txt sample_output.tsv
	@echo ""
	@echo "=== 出力内容 ==="
	cat sample_output.tsv

install: $(TARGET)
	install -m 755 $(TARGET) /usr/local/bin/
	install -m 755 fixed2csv.sh /usr/local/bin/

uninstall:
	rm -f /usr/local/bin/$(TARGET)
	rm -f /usr/local/bin/fixed2csv.sh
