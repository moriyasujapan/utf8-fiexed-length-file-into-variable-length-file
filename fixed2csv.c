/*
 * fixed2csv.c - UTF-8固定長ファイルを可変長(CSV/TSV)に変換
 *
 * コンパイル: gcc -o fixed2csv fixed2csv.c
 * 使用例: ./fixed2csv -w 10,20,15 -d , input.txt output.csv
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <wchar.h>
#include <locale.h>

#define MAX_FIELDS 256
#define MAX_LINE 65536

/* UTF-8文字の先頭バイトかどうかを判定 */
int is_utf8_start(unsigned char c) {
    return (c & 0xC0) != 0x80;
}

/* UTF-8文字列の文字数をカウント（バイト数ではなく文字数） */
size_t utf8_strlen(const char *s) {
    size_t count = 0;
    while (*s) {
        if (is_utf8_start(*s)) {
            count++;
        }
        s++;
    }
    return count;
}

/* UTF-8文字列から指定文字数分を取得 */
void utf8_substr(const char *src, size_t start_chars, size_t len_chars, char *dest, size_t dest_size) {
    size_t char_count = 0;
    size_t byte_pos = 0;
    size_t start_byte = 0;
    size_t end_byte = 0;

    /* 開始位置を探す */
    while (src[byte_pos] && char_count < start_chars) {
        if (is_utf8_start(src[byte_pos])) {
            char_count++;
        }
        byte_pos++;
    }
    start_byte = byte_pos;

    /* 終了位置を探す */
    char_count = 0;
    while (src[byte_pos] && char_count < len_chars) {
        if (is_utf8_start(src[byte_pos])) {
            char_count++;
        }
        byte_pos++;
    }
    end_byte = byte_pos;

    /* コピー */
    size_t copy_len = end_byte - start_byte;
    if (copy_len >= dest_size) {
        copy_len = dest_size - 1;
    }
    memcpy(dest, src + start_byte, copy_len);
    dest[copy_len] = '\0';
}

/* 文字列の前後の空白を削除 */
void trim(char *str) {
    char *end;

    /* 先頭の空白をスキップ */
    while (*str && isspace((unsigned char)*str)) {
        str++;
    }

    if (*str == 0) {
        return;
    }

    /* 末尾の空白を削除 */
    end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) {
        end--;
    }
    *(end + 1) = '\0';

    /* 先頭が空白でずれている場合は詰める */
    if (str != str) {
        memmove(str, str, strlen(str) + 1);
    }
}

/* CSVフィールドのエスケープ処理 */
void csv_escape(const char *src, char *dest, size_t dest_size, char delimiter) {
    int need_quote = 0;

    /* クォートが必要かチェック */
    if (strchr(src, delimiter) || strchr(src, '"') || strchr(src, '\n') || strchr(src, '\r')) {
        need_quote = 1;
    }

    if (!need_quote) {
        snprintf(dest, dest_size, "%s", src);
        return;
    }

    /* クォートで囲み、内部のクォートは二重化 */
    size_t pos = 0;
    dest[pos++] = '"';

    for (const char *p = src; *p && pos < dest_size - 3; p++) {
        if (*p == '"') {
            dest[pos++] = '"';
            dest[pos++] = '"';
        } else {
            dest[pos++] = *p;
        }
    }

    dest[pos++] = '"';
    dest[pos] = '\0';
}

void usage(const char *prog) {
    fprintf(stderr, "使用方法: %s -w widths [-d delimiter] [-t] [-h] input output\n", prog);
    fprintf(stderr, "\n");
    fprintf(stderr, "オプション:\n");
    fprintf(stderr, "  -w widths    各フィールドの文字幅をカンマ区切りで指定 (例: 10,20,15)\n");
    fprintf(stderr, "  -d delimiter 区切り文字 (デフォルト: ,) タブの場合は -d $'\\t'\n");
    fprintf(stderr, "  -t           フィールドの前後の空白を削除\n");
    fprintf(stderr, "  -h           このヘルプを表示\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "例:\n");
    fprintf(stderr, "  %s -w 10,20,15 -d , -t input.txt output.csv\n", prog);
    fprintf(stderr, "  %s -w 8,12,20 -d $'\\t' input.txt output.tsv\n", prog);
}

int main(int argc, char *argv[]) {
    int opt;
    char *widths_str = NULL;
    char delimiter = ',';
    int trim_fields = 0;
    int widths[MAX_FIELDS];
    int field_count = 0;

    /* ロケールをUTF-8に設定 */
    setlocale(LC_ALL, "");

    /* コマンドライン引数の解析 */
    while ((opt = getopt(argc, argv, "w:d:th")) != -1) {
        switch (opt) {
            case 'w':
                widths_str = optarg;
                break;
            case 'd':
                if (strcmp(optarg, "\\t") == 0 || strcmp(optarg, "\t") == 0) {
                    delimiter = '\t';
                } else {
                    delimiter = optarg[0];
                }
                break;
            case 't':
                trim_fields = 1;
                break;
            case 'h':
                usage(argv[0]);
                return 0;
            default:
                usage(argv[0]);
                return 1;
        }
    }

    if (!widths_str || optind + 2 != argc) {
        usage(argv[0]);
        return 1;
    }

    /* 幅の解析 */
    char *token = strtok(widths_str, ",");
    while (token && field_count < MAX_FIELDS) {
        widths[field_count++] = atoi(token);
        token = strtok(NULL, ",");
    }

    if (field_count == 0) {
        fprintf(stderr, "エラー: フィールド幅が指定されていません\n");
        return 1;
    }

    /* ファイルを開く */
    const char *input_file = argv[optind];
    const char *output_file = argv[optind + 1];

    FILE *in = fopen(input_file, "r");
    if (!in) {
        perror("入力ファイルを開けません");
        return 1;
    }

    FILE *out = fopen(output_file, "w");
    if (!out) {
        perror("出力ファイルを開けません");
        fclose(in);
        return 1;
    }

    /* 行ごとに処理 */
    char line[MAX_LINE];
    int line_num = 0;

    while (fgets(line, sizeof(line), in)) {
        line_num++;

        /* 改行を削除 */
        size_t len = strlen(line);
        if (len > 0 && line[len - 1] == '\n') {
            line[len - 1] = '\0';
            len--;
        }
        if (len > 0 && line[len - 1] == '\r') {
            line[len - 1] = '\0';
            len--;
        }

        /* フィールドごとに分割 */
        size_t pos = 0;
        for (int i = 0; i < field_count; i++) {
            char field[MAX_LINE];
            char escaped[MAX_LINE * 2];

            /* フィールドを切り出し */
            utf8_substr(line, pos, widths[i], field, sizeof(field));
            pos += widths[i];

            /* トリミング */
            if (trim_fields) {
                /* UTF-8対応の簡易トリミング */
                char *start = field;
                char *end = field + strlen(field) - 1;

                /* 先頭の空白を削除 */
                while (*start && (*start == ' ' || *start == '\t')) {
                    start++;
                }

                /* 末尾の空白を削除 */
                while (end > start && (*end == ' ' || *end == '\t' || *end == '\0')) {
                    end--;
                }
                *(end + 1) = '\0';

                if (start != field) {
                    memmove(field, start, strlen(start) + 1);
                }
            }

            /* CSVエスケープ */
            csv_escape(field, escaped, sizeof(escaped), delimiter);

            /* 出力 */
            fputs(escaped, out);
            if (i < field_count - 1) {
                fputc(delimiter, out);
            }
        }
        fputc('\n', out);
    }

    fclose(in);
    fclose(out);

    printf("変換完了: %d 行処理しました\n", line_num);
    return 0;
}
