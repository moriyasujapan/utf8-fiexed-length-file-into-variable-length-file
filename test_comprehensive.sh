#!/bin/bash
#
# test_comprehensive.sh - 包括的なバグ検出テスト
#

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

test_case() {
    local name="$1"
    local input_file="$2"
    local widths="$3"
    local description="$4"

    echo ""
    echo -e "${BLUE}[テスト]${NC} $name"
    echo "  説明: $description"
    echo "  幅指定: $widths"

    # 実行
    LANG=C.UTF-8 ./fixed2csv -w "$widths" -d , -t "$input_file" test_c.csv 2>/dev/null
    ./fixed2csv.sh -w "$widths" -d , -t "$input_file" test_sh.csv 2>/dev/null

    # 比較
    if diff -q test_c.csv test_sh.csv > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PASS${NC}: C言語版とシェルスクリプト版が一致"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}: 出力が不一致"
        echo "  --- C言語版 ---"
        head -3 test_c.csv | sed 's/^/    /'
        echo "  --- シェルスクリプト版 ---"
        head -3 test_sh.csv | sed 's/^/    /'
        echo "  --- diff ---"
        diff -u test_c.csv test_sh.csv | head -20 | sed 's/^/    /'
        FAIL=$((FAIL + 1))
    fi

    # サンプル出力
    echo "  出力例:"
    head -2 test_c.csv | sed 's/^/    /'
}

echo "=========================================="
echo "  半角全角バグ検出テスト (包括版)"
echo "=========================================="

# テスト1: 奇数幅に全角文字
cat > test1.txt << 'EOF'
あいうえおかきくけこ
ABCDEFGHIJ
AあBいCうDえE
EOF
test_case "奇数幅(5)に全角文字" "test1.txt" "5,5" \
    "幅5のフィールドに全角文字（幅2）を配置。'あい'（幅4）しか入らない"

# テスト2: フィールド境界で全角文字が分断される
cat > test2.txt << 'EOF'
あいう    ABCDE
ABCDE     あいう
あいうえおABCDE
EOF
test_case "全角文字が境界で分断" "test2.txt" "10,10" \
    "フィールド境界で全角文字が切れないことを確認"

# テスト3: 半角カナの幅
cat > test3.txt << 'EOF'
ｱｲｳｴｵｶｷｸｹｺABCDE
ｱｲｳｴｵ    ｶｷｸｹｺ    ABCDE
全角全角  半角ｶﾅｶﾅ   MIX混合
EOF
test_case "半角カナの幅計算" "test3.txt" "10,10,10" \
    "半角カナ（幅1）と全角文字（幅2）の混在"

# テスト4: 全角空白の扱い
cat > test4.txt << 'EOF'
前　全角空白　後
前 半角空白 後
前　　　　　後
EOF
test_case "全角空白" "test4.txt" "10,10,10" \
    "全角空白（U+3000）はトリミングしない"

# テスト5: 幅を超える全角文字
cat > test5.txt << 'EOF'
あ        い        う
ああ      いい      うう
あああ    いいい    ううう
ああああ  いいいい  うううう
あああああいいいいいううううう
EOF
test_case "全角文字が幅を超える" "test5.txt" "10,10,10" \
    "全角文字が指定幅を超える場合の切り詰め"

# テスト6: 1文字幅のフィールド
cat > test6.txt << 'EOF'
ABCDE
あいうえお
AあBいC
EOF
test_case "1文字幅フィールド" "test6.txt" "1,1,1,1,1" \
    "幅1のフィールドに全角文字は入らない"

# テスト7: 混在パターン
cat > test7.txt << 'EOF'
Aあいう   Bｶｷｸｹｺ   C01234
山田太郎  東京都    〒100-
Mix混合   ﾊﾝABC    全角全
EOF
test_case "複雑な混在" "test7.txt" "10,10,10" \
    "半角、全角、半角カナ、記号の混在"

# テスト8: 空白のみのフィールド
cat > test8.txt << 'EOF'
          DATA1     DATA2
DATA1               DATA2
DATA1     DATA2
EOF
test_case "空白のみのフィールド" "test8.txt" "10,10,10" \
    "トリミング後に空文字列になるフィールド"

# テスト9: CSVエスケープが必要な文字
cat > test9.txt << 'EOF'
カンマ,含む改行
なし      "引用符"  含む
A"B"C     XYZ       123
EOF
test_case "CSVエスケープ" "test9.txt" "10,10,10" \
    "カンマと引用符を含むフィールド"

# テスト10: 幅0のフィールド（エラーケース）
cat > test10.txt << 'EOF'
ABCDEFGHIJ
あいうえお
EOF
# 幅0は除外
test_case "連続フィールド" "test10.txt" "5,5" \
    "幅5の2フィールド"

# テスト11: 文字幅の境界値
cat > test11.txt << 'EOF'
A         あ        AB        あい
ABC       あいう    ABCD      あいうえ
ABCDE     あいうえおABCDEFGH  あいうえおか
EOF
test_case "文字幅の境界値" "test11.txt" "10,10,10,10" \
    "半角1～5文字と全角1～5文字の組み合わせ"

# テスト12: 特殊な Unicode 文字
cat > test12.txt << 'EOF'
山田太郎  🗾日本    Test絵文
  田中    ♥記号    ①②③
EOF
test_case "特殊Unicode文字" "test12.txt" "10,10,10" \
    "絵文字や記号などの特殊文字（環境依存）"

# テスト13: 長い行の処理
cat > test13.txt << 'EOF'
ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz
あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめも
MixedあいうTestこれは長い行ですLongLineTestCaseForBugDetection
EOF
test_case "長い行" "test13.txt" "10,10,10" \
    "フィールド幅を大きく超える行"

# テスト14: 幅と文字数の不一致
cat > test14.txt << 'EOF'
12345678901234567890
あいうえおかきくけこ
1あ2い3う4え5お
EOF
test_case "幅20の処理" "test14.txt" "20" \
    "半角20文字=全角10文字の検証"

# テスト15: 制御文字（タブ）
cat > test15.txt << 'EOF'
A	B    C
X	Y    Z
EOF
test_case "タブ文字" "test15.txt" "10,10,10" \
    "タブ文字が含まれる行"

echo ""
echo "=========================================="
echo "  テスト結果サマリー"
echo "=========================================="
TOTAL=$((PASS + FAIL))
echo "合計: $TOTAL テスト"
echo -e "${GREEN}成功: $PASS${NC}"
echo -e "${RED}失敗: $FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${GREEN}✓ すべてのテストが成功しました！${NC}"
    RESULT=0
else
    echo -e "\n${RED}✗ $FAIL 個のテストが失敗しました${NC}"
    RESULT=1
fi

# クリーンアップ
rm -f test*.txt test_c.csv test_sh.csv

exit $RESULT
