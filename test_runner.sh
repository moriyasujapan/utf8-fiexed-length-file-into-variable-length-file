#!/bin/bash
#
# test_runner.sh - 半角全角の組み合わせテスト
#

set -e

echo "=========================================="
echo "半角全角バグ検出テストスイート"
echo "=========================================="
echo ""

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# テスト結果のカウンタ
PASS_COUNT=0
FAIL_COUNT=0

# テスト関数
run_test() {
    local test_name="$1"
    local input_file="$2"
    local widths="$3"
    local expected_fields="$4"

    echo "----------------------------------------"
    echo "テスト: $test_name"
    echo "入力: $input_file"
    echo "幅指定: $widths"

    # C言語版で実行
    LANG=C.UTF-8 ./fixed2csv -w "$widths" -d ',' -t "$input_file" test_c_output.csv 2>/dev/null

    # シェルスクリプト版で実行
    ./fixed2csv.sh -w "$widths" -d ',' -t "$input_file" test_sh_output.csv 2>/dev/null

    # 結果を比較
    if diff -q test_c_output.csv test_sh_output.csv > /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: C言語版とシェルスクリプト版の出力が一致"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: C言語版とシェルスクリプト版の出力が不一致"
        echo "C言語版:"
        head -3 test_c_output.csv
        echo "シェルスクリプト版:"
        head -3 test_sh_output.csv
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # フィールド数チェック
    local field_count=$(head -1 test_c_output.csv | awk -F',' '{print NF}')
    if [ "$field_count" -eq "$expected_fields" ]; then
        echo -e "${GREEN}✓ PASS${NC}: フィールド数が正しい ($field_count)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: フィールド数が不正 (期待: $expected_fields, 実際: $field_count)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # サンプル出力を表示
    echo "出力サンプル (最初の3行):"
    head -3 test_c_output.csv | while IFS= read -r line; do
        echo "  [$line]"
    done
    echo ""
}

# 表示幅の計算テスト
test_display_width() {
    echo "=========================================="
    echo "表示幅計算の検証"
    echo "=========================================="
    echo ""

    cat > test_width_check.txt << 'EOF'
A         B         C
あ        い        う
AB        XY        12
あい      いう      うえ
ABCあ     XYZい     123う
EOF

    echo "テスト文字列の表示幅を検証:"
    python3 << 'PYEOF'
import unicodedata

def get_display_width(char):
    if unicodedata.east_asian_width(char) in ('F', 'W'):
        return 2
    return 1

def get_string_width(s):
    return sum(get_display_width(c) for c in s)

test_strings = [
    "A         ",  # 半角1文字 + 空白9 = 10
    "あ        ",  # 全角1文字 + 空白8 = 10
    "AB        ",  # 半角2文字 + 空白8 = 10
    "あい      ",  # 全角2文字 + 空白6 = 10
    "ABCあ     ",  # 半角3 + 全角1 + 空白5 = 10
]

for s in test_strings:
    width = get_string_width(s)
    print(f"'{s}' -> 幅={width} (期待: 10)")
PYEOF

    run_test "表示幅10の均一フィールド" "test_width_check.txt" "10,10,10" 3
}

# 境界ケーステスト
test_boundary_cases() {
    echo "=========================================="
    echo "境界ケースのテスト"
    echo "=========================================="
    echo ""

    # 奇数幅に全角文字
    cat > test_odd_width.txt << 'EOF'
あいうえおかきくけこ
ABCDEFGHIJ
AあBいCうDえE
EOF

    run_test "奇数幅(5)に全角文字" "test_odd_width.txt" "5,5" 2

    # 全角文字がフィールド境界で切れる
    cat > test_boundary_split.txt << 'EOF'
あいう    ABCDE
ABCDE     あいう
あいうえおABCDE
EOF

    run_test "全角文字が境界で切れるケース" "test_boundary_split.txt" "10,10" 2

    # 空フィールド
    cat > test_empty_field.txt << 'EOF'
          FILLED
FILLED
          FILLED
EOF

    run_test "空フィールド（空白のみ）" "test_empty_field.txt" "10,10" 2
}

# 混在ケーステスト
test_mixed_cases() {
    echo "=========================================="
    echo "半角全角混在のテスト"
    echo "=========================================="
    echo ""

    cat > test_mixed.txt << 'EOF'
山田太郎  東京都    100-0001
John      Tokyo     12345
山A田B    東XY都    100-XY
ｱｲｳｴｵ      ABCDE     あaいbう
MIXあ混   合いTest  文う字
EOF

    run_test "半角全角混在" "test_mixed.txt" "10,10,10" 3
}

# 半角カナテスト
test_halfwidth_kana() {
    echo "=========================================="
    echo "半角カナのテスト"
    echo "=========================================="
    echo ""

    cat > test_halfwidth.txt << 'EOF'
ｱｲｳｴｵｶｷｸｹｺABCDE
ｱｲｳｴｵ    ｶｷｸｹｺ    あいうえお
ABCDEあいうえおｱｲｳｴｵ
EOF

    run_test "半角カナの幅計算" "test_halfwidth.txt" "10,10,10" 3
}

# 長さオーバーのテスト
test_overflow() {
    echo "=========================================="
    echo "フィールド長オーバーのテスト"
    echo "=========================================="
    echo ""

    cat > test_overflow.txt << 'EOF'
ABCDEFGHIJKLMNOPQRSTUVWXYZ
あいうえおかきくけこさしすせそ
MixedあいうTest文字列overflow
EOF

    run_test "フィールド長オーバー" "test_overflow.txt" "10,10,10" 3
}

# 特殊文字テスト
test_special_chars() {
    echo "=========================================="
    echo "特殊文字のテスト"
    echo "=========================================="
    echo ""

    cat > test_special.txt << 'EOF'
カンマ,含む テスト      データ
"引用符"  改行なし  データ
スペース  　全角    Space
EOF

    run_test "特殊文字（カンマ、引用符、全角空白）" "test_special.txt" "10,10,10" 3
}

# メイン実行
main() {
    # ビルド
    if [ ! -f "fixed2csv" ]; then
        echo "C言語版をコンパイル中..."
        gcc -Wall -O2 -o fixed2csv fixed2csv.c
        echo ""
    fi

    if [ ! -x "fixed2csv.sh" ]; then
        chmod +x fixed2csv.sh
    fi

    # テスト実行
    test_display_width
    test_boundary_cases
    test_mixed_cases
    test_halfwidth_kana
    test_overflow
    test_special_chars

    # 既存のテストファイルも実行
    if [ -f "test_cases.txt" ]; then
        run_test "基本テストケース" "test_cases.txt" "10,10,10" 3
    fi

    if [ -f "test_edge_cases.txt" ]; then
        run_test "エッジケース" "test_edge_cases.txt" "5,7,8" 3
    fi

    # クリーンアップ
    rm -f test_c_output.csv test_sh_output.csv
    rm -f test_width_check.txt test_odd_width.txt test_boundary_split.txt
    rm -f test_empty_field.txt test_mixed.txt test_halfwidth.txt
    rm -f test_overflow.txt test_special.txt

    # 結果サマリー
    echo "=========================================="
    echo "テスト結果サマリー"
    echo "=========================================="
    TOTAL=$((PASS_COUNT + FAIL_COUNT))
    echo -e "合計: $TOTAL テスト"
    echo -e "${GREEN}成功: $PASS_COUNT${NC}"
    echo -e "${RED}失敗: $FAIL_COUNT${NC}"

    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}すべてのテストが成功しました！${NC}"
        return 0
    else
        echo -e "\n${RED}いくつかのテストが失敗しました${NC}"
        return 1
    fi
}

main "$@"
