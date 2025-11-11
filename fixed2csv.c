/*
 * fixed2csv.c - UTF-8固定長ファイルを可変長(CSV/TSV)に変換
 * 表示幅ベース: 半角文字=1、全角文字=2
 *
 * コンパイル: gcc -o fixed2csv fixed2csv.c
 * 使用例: ./fixed2csv -w 10,20,15 -d , input.txt output.csv
 */

#define _XOPEN_SOURCE 700

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <wchar.h>
#include <locale.h>

#define MAX_FIELDS 256
#define MAX_LINE 65536

/* UTF-8の1文字をデコードしてワイド文字に変換 */
int utf8_to_wchar(const char *str, wchar_t *wc, size_t *bytes_consumed) {
    mbstate_t state;
    memset(&state, 0, sizeof(state));

    size_t result = mbrtowc(wc, str, MB_CUR_MAX, &state);

    if (result == (size_t)-1 || result == (size_t)-2) {
        /* 無効なUTF-8シーケンス */
        *bytes_consumed = 1;
        *wc = L'?';
        return -1;
    }

    *bytes_consumed = result;
    return 0;
}

/* 文字の表示幅を取得（半角=1、全角=2） */
int get_char_width(wchar_t wc) {
    int w = wcwidth(wc);

    if (w < 0) {
        /* 制御文字など */
        return 0;
    }

    return w;
}

/* UTF-8文字列の表示幅を計算 */
size_t utf8_display_width(const char *str) {
    size_t width = 0;
    const char *p = str;

    while (*p) {
        wchar_t wc;
        size_t bytes;

        if (utf8_to_wchar(p, &wc, &bytes) == 0) {
            width += get_char_width(wc);
        }

        p += bytes;
    }

    return width;
}

/* UTF-8文字列から表示幅に基づいて部分文字列を取得 */
void utf8_substr_by_width(const char *src, size_t start_width, size_t len_width,
                          char *dest, size_t dest_size) {
    size_t current_width = 0;
    const char *start_ptr = src;
    const char *end_ptr = src;
    const char *p = src;

    /* 開始位置を探す（表示幅ベース） */
    while (*p && current_width < start_width) {
        wchar_t wc;
        size_t bytes;

        if (utf8_to_wchar(p, &wc, &bytes) == 0) {
            current_width += get_char_width(wc);
        }

        p += bytes;
    }
    start_ptr = p;

    /* 指定された表示幅分を取得 */
    current_width = 0;
    while (*p && current_width < len_width) {
        wchar_t wc;
        size_t bytes;

        if (utf8_to_wchar(p, &wc, &bytes) == 0) {
            int char_width = get_char_width(wc);

            /* 次の文字を追加すると幅を超える場合は終了 */
            if (current_width + char_width > len_width) {
                break;
            }

            current_width += char_width;
        }

        p += bytes;
    }
    end_ptr = p;

    /* コピー */
    size_t copy_len = end_ptr - start_ptr;
    if (copy_len >= dest_size) {
        copy_len = dest_size - 1;
    }
    memcpy(dest, start_ptr, copy_len);
    dest[copy_len] = '\0';
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
    fprintf(stderr, "  -w widths    各フィールドの表示幅をカンマ区切りで指定 (例: 10,20,15)\n");
    fprintf(stderr, "               ※半角文字=1、全角文字=2として計算\n");
    fprintf(stderr, "  -d delimiter 区切り文字 (デフォルト: ,) タブの場合は -d $'\\t'\n");
    fprintf(stderr, "  -t           フィールドの前後の空白を削除\n");
    fprintf(stderr, "  -h           このヘルプを表示\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "例:\n");
    fprintf(stderr, "  %s -w 10,20,15 -d , -t input.txt output.csv\n", prog);
    fprintf(stderr, "  %s -w 8,12,20 -d $'\\t' input.txt output.tsv\n", prog);
    fprintf(stderr, "\n");
    fprintf(stderr, "注意: 幅は表示幅（半角=1、全角=2）で指定します\n");
}

int main(int argc, char *argv[]) {
    int opt;
    char *widths_str = NULL;
    char delimiter = ',';
    int trim_fields = 0;
    int widths[MAX_FIELDS];
    int field_count = 0;

    /* ロケールをUTF-8に設定 */
    if (!setlocale(LC_ALL, "")) {
        setlocale(LC_ALL, "C.UTF-8");
    }

    /* ロケールがUTF-8でない場合は明示的に設定を試行 */
    if (MB_CUR_MAX < 2) {
        if (!setlocale(LC_ALL, "C.UTF-8")) {
            if (!setlocale(LC_ALL, "en_US.UTF-8")) {
                setlocale(LC_ALL, "ja_JP.UTF-8");
            }
        }
    }

    /* それでもだめなら警告 */
    if (MB_CUR_MAX < 2) {
        fprintf(stderr, "警告: UTF-8ロケールを設定できませんでした。正しく動作しない可能性があります。\n");
        fprintf(stderr, "環境変数を設定してください: export LANG=C.UTF-8\n");
    }

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

        /* フィールドごとに分割（表示幅ベース） */
        size_t pos = 0;
        for (int i = 0; i < field_count; i++) {
            char field[MAX_LINE];
            char escaped[MAX_LINE * 2];

            /* フィールドを切り出し（表示幅ベース） */
            utf8_substr_by_width(line, pos, widths[i], field, sizeof(field));
            pos += widths[i];

            /* トリミング */
            if (trim_fields) {
                /* UTF-8対応のトリミング */
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
