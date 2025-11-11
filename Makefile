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
	rm -f $(TARGET) sample_output.csv sample_output.tsv sample_output_sh.csv

test: $(TARGET)
	@echo "=== テスト1: CSV出力（トリミングあり） ==="
	@echo "注意: 表示幅ベース（半角=1、全角=2）で処理します"
	LANG=C.UTF-8 LC_ALL=C.UTF-8 ./$(TARGET) -w 10,20,10 -d , -t sample_input.txt sample_output.csv
	@echo ""
	@echo "=== 出力内容 ==="
	cat sample_output.csv
	@echo ""
	@echo "=== テスト2: TSV出力（トリミングあり） ==="
	LANG=C.UTF-8 LC_ALL=C.UTF-8 ./$(TARGET) -w 10,20,10 -d $$'\t' -t sample_input.txt sample_output.tsv
	@echo ""
	@echo "=== 出力内容 ==="
	cat sample_output.tsv
	@echo ""
	@echo "=== テスト3: シェルスクリプト版のテスト ==="
	./fixed2csv.sh -w 10,20,10 -d , -t sample_input.txt sample_output_sh.csv
	@echo ""
	@echo "=== シェルスクリプト版の出力 ==="
	cat sample_output_sh.csv

install: $(TARGET)
	install -m 755 $(TARGET) /usr/local/bin/
	install -m 755 fixed2csv.sh /usr/local/bin/

uninstall:
	rm -f /usr/local/bin/$(TARGET)
	rm -f /usr/local/bin/fixed2csv.sh
