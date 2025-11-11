#!/bin/bash
#
# fixed2csv.sh - UTF-8固定長ファイルを可変長(CSV/TSV)に変換
# 表示幅ベース: 半角文字=1、全角文字=2
#
# 使用例: ./fixed2csv.sh -w 10,20,15 -d , -t input.txt output.csv
#
# 注意: このスクリプトはPython3を使用します
#

usage() {
    cat <<EOF
使用方法: $0 -w widths [-d delimiter] [-t] [-h] input output

オプション:
  -w widths    各フィールドの表示幅をカンマ区切りで指定 (例: 10,20,15)
               ※半角文字=1、全角文字=2として計算
  -d delimiter 区切り文字 (デフォルト: ,) タブの場合は -d tab
  -t           フィールドの前後の空白を削除
  -h           このヘルプを表示

例:
  $0 -w 10,20,15 -d , -t input.txt output.csv
  $0 -w 8,12,20 -d tab input.txt output.tsv
  $0 -w 5,10,15,20 -d '|' input.txt output.txt

注意:
  - 入力ファイルはUTF-8エンコーディングである必要があります
  - フィールド幅は表示幅（半角=1、全角=2）で指定します
  - Python3が必要です
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

# Python3の確認
if ! command -v python3 >/dev/null 2>&1; then
    echo "エラー: python3が見つかりません" >&2
    exit 1
fi

# Pythonスクリプトで処理
python3 - "$INPUT" "$OUTPUT" "$WIDTHS" "$DELIMITER" "$TRIM" <<'PYTHON_EOF'
import sys
import unicodedata
import csv

def get_display_width(char):
    """文字の表示幅を取得（半角=1、全角=2）"""
    if unicodedata.east_asian_width(char) in ('F', 'W'):
        return 2
    return 1

def get_string_width(s):
    """文字列の表示幅を計算"""
    return sum(get_display_width(c) for c in s)

def substr_by_width(s, start_width, length_width):
    """表示幅に基づいて部分文字列を取得"""
    current_width = 0
    start_pos = 0

    # 開始位置を探す
    for i, char in enumerate(s):
        if current_width >= start_width:
            start_pos = i
            break
        current_width += get_display_width(char)
    else:
        start_pos = len(s)

    # 指定された幅分を取得
    current_width = 0
    end_pos = start_pos

    for i in range(start_pos, len(s)):
        char = s[i]
        char_width = get_display_width(char)

        # 次の文字を追加すると幅を超える場合は終了
        if current_width + char_width > length_width:
            break

        current_width += char_width
        end_pos = i + 1

    return s[start_pos:end_pos]

def main():
    if len(sys.argv) != 6:
        print("エラー: 引数が不正です", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    widths_str = sys.argv[3]
    delimiter = sys.argv[4]
    trim = sys.argv[5] == '1'

    # タブ文字の処理
    if delimiter == 'tab':
        delimiter = '\t'

    # 幅をパース
    widths = [int(w) for w in widths_str.split(',')]

    line_count = 0

    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:

        writer = csv.writer(outfile, delimiter=delimiter, quoting=csv.QUOTE_MINIMAL, lineterminator='\n')

        for line in infile:
            line = line.rstrip('\n\r')
            line_count += 1

            # フィールドを抽出（表示幅ベース）
            fields = []
            pos = 0

            for width in widths:
                field = substr_by_width(line, pos, width)
                pos += width

                # トリミング（半角空白とタブのみ、全角空白は除外）
                if trim:
                    field = field.strip(' \t')

                fields.append(field)

            writer.writerow(fields)

    print(f"変換完了: {line_count} 行処理しました")

if __name__ == '__main__':
    main()
PYTHON_EOF

exit $?
