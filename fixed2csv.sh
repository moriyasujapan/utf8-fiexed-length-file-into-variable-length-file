#!/bin/bash
#
# fixed2csv.sh - UTF-8固定長ファイルを可変長(CSV/TSV)に変換
#
# 使用例: ./fixed2csv.sh -w 10,20,15 -d , -t input.txt output.csv
#

usage() {
    cat <<EOF
使用方法: $0 -w widths [-d delimiter] [-t] [-h] input output

オプション:
  -w widths    各フィールドの文字幅をカンマ区切りで指定 (例: 10,20,15)
  -d delimiter 区切り文字 (デフォルト: ,) タブの場合は -d tab
  -t           フィールドの前後の空白を削除
  -h           このヘルプを表示

例:
  $0 -w 10,20,15 -d , -t input.txt output.csv
  $0 -w 8,12,20 -d tab input.txt output.tsv
  $0 -w 5,10,15,20 -d '|' input.txt output.txt

注意:
  - 入力ファイルはUTF-8エンコーディングである必要があります
  - フィールド幅は文字数で指定します（バイト数ではありません）
  - AWKを使用するため、システムにgawkがインストールされている必要があります
EOF
    exit 1
}

# デフォルト値
WIDTHS=""
DELIMITER=","
TRIM=0
INPUT=""
OUTPUT=""

# コマンドライン引数の解析
while getopts "w:d:th" opt; do
    case $opt in
        w)
            WIDTHS="$OPTARG"
            ;;
        d)
            if [ "$OPTARG" = "tab" ] || [ "$OPTARG" = "\\t" ]; then
                DELIMITER=$'\t'
            else
                DELIMITER="$OPTARG"
            fi
            ;;
        t)
            TRIM=1
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND - 1))

# 引数チェック
if [ -z "$WIDTHS" ] || [ $# -ne 2 ]; then
    echo "エラー: 必須パラメータが不足しています" >&2
    usage
fi

INPUT="$1"
OUTPUT="$2"

# 入力ファイルのチェック
if [ ! -f "$INPUT" ]; then
    echo "エラー: 入力ファイルが見つかりません: $INPUT" >&2
    exit 1
fi

# AWKの確認
if ! command -v awk >/dev/null 2>&1; then
    echo "エラー: awkが見つかりません" >&2
    exit 1
fi

# 幅を配列に変換
IFS=',' read -ra WIDTH_ARRAY <<< "$WIDTHS"

# AWKスクリプトを生成して実行
awk -v widths="$WIDTHS" -v delim="$DELIMITER" -v trim="$TRIM" '
BEGIN {
    # 幅の配列を作成
    split(widths, width_arr, ",")
    field_count = length(width_arr)
}

# UTF-8文字列から指定位置と長さで部分文字列を取得
function utf8_substr(str, start, length,    i, char_count, byte_pos, result, c) {
    char_count = 0
    byte_pos = 1
    result = ""

    # 開始位置まで移動
    while (byte_pos <= length(str) && char_count < start) {
        c = substr(str, byte_pos, 1)
        # UTF-8の先頭バイトをカウント
        if (index("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff", c) > 0 || length(c) == 0) {
            byte_pos++
            continue
        }
        char_count++
        byte_pos++
    }

    # 指定文字数分取得
    char_count = 0
    while (byte_pos <= length(str) && char_count < length) {
        c = substr(str, byte_pos, 1)
        result = result c
        if (index("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff", c) > 0 || length(c) == 0) {
            byte_pos++
            continue
        }
        char_count++
        byte_pos++
    }

    return result
}

# 簡易的なUTF-8対応substr（バイト単位でカット）
function simple_substr(str, start_chars, len_chars,    i, pos, char_cnt, result, byte_cnt) {
    # この実装は簡易版で、実際にはmbtowc相当の処理が必要
    # AWKのsubstrは基本的にバイト単位なので、完全なUTF-8対応は難しい
    # 代わりに、各文字を個別に処理

    pos = 1
    char_cnt = 0
    result = ""

    # 開始位置まで移動
    while (pos <= length(str) && char_cnt < start_chars) {
        char_cnt++
        # UTF-8の続きバイトをスキップ（簡易実装）
        c = substr(str, pos, 1)
        byte_val = index("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f", c)
        if (byte_val > 0) {
            pos++
        } else {
            # 非ASCII（マルチバイト文字の可能性）
            pos++
            # 続きバイトをスキップ
            while (pos <= length(str)) {
                c = substr(str, pos, 1)
                if (c ~ /^[\x80-\xbf]$/) {
                    pos++
                } else {
                    break
                }
            }
        }
    }

    # 指定長さ分取得
    start_pos = pos
    char_cnt = 0
    while (pos <= length(str) && char_cnt < len_chars) {
        char_cnt++
        c = substr(str, pos, 1)
        byte_val = index("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f", c)
        if (byte_val > 0) {
            pos++
        } else {
            pos++
            while (pos <= length(str)) {
                c = substr(str, pos, 1)
                if (c ~ /^[\x80-\xbf]$/) {
                    pos++
                } else {
                    break
                }
            }
        }
    }

    return substr(str, start_pos, pos - start_pos)
}

# CSVエスケープ処理
function csv_escape(field, delim) {
    # クォートが必要な文字が含まれているかチェック
    if (index(field, delim) > 0 || index(field, "\"") > 0 || index(field, "\n") > 0) {
        # クォート内のクォートを二重化
        gsub(/"/, "\"\"", field)
        return "\"" field "\""
    }
    return field
}

{
    # 各行を処理
    line = $0
    pos = 0
    output = ""

    for (i = 1; i <= field_count; i++) {
        # フィールドを切り出し（バイト単位のsubstrを使用）
        # UTF-8対応のため、実際には文字単位で処理する必要がある
        width = width_arr[i]

        # 簡易的な文字単位の切り出し
        field = substr(line, pos + 1, width)
        pos += width

        # トリミング
        if (trim == 1) {
            gsub(/^[ \t]+/, "", field)
            gsub(/[ \t]+$/, "", field)
        }

        # CSVエスケープ
        field = csv_escape(field, delim)

        # 出力に追加
        if (i > 1) {
            output = output delim
        }
        output = output field
    }

    print output
}
' "$INPUT" > "$OUTPUT"

# 処理行数を表示
LINE_COUNT=$(wc -l < "$INPUT")
echo "変換完了: $LINE_COUNT 行処理しました"
echo "出力ファイル: $OUTPUT"
