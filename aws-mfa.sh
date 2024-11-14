#!/bin/bash

# 定数
REGION="ap-northeast-1"
SESSION_DURATION="43200"  # 12時間

# カラー設定
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# プロファイル一覧の取得
get_profiles() {
    grep '^\[' ~/.aws/credentials | tr -d '[]'
}

# MFAデバイス一覧の取得
get_mfa_devices() {
    local profile=$1
    aws iam list-mfa-devices \
        --profile "$profile" \
        --output text \
        --query 'MFADevices[].SerialNumber'
}

echo -e "${CYAN}=== AWS MFA認証セットアップ ===${NC}"

# プロファイル選択
echo -e "\n利用可能なプロファイル:"
profiles=$(get_profiles)
PS3="プロファイルを選択してください (番号): "
select SOURCE_PROFILE in $profiles; do
    if [ -n "$SOURCE_PROFILE" ]; then
        break
    else
        echo "有効なプロファイルを選択してください"
    fi
done

# MFAデバイスの取得と選択
echo -e "\nMFAデバイスを取得中..."
MFA_DEVICES=($(get_mfa_devices "$SOURCE_PROFILE"))

if [ ${#MFA_DEVICES[@]} -eq 0 ]; then
    echo "❌ エラー: MFAデバイスが見つかりません"
    exit 1
fi

echo "MFAデバイスを選択してください:"
PS3="MFAデバイスを選択してください (番号): "
select MFA_SERIAL_NUMBER in "${MFA_DEVICES[@]}"; do
    if [ -n "$MFA_SERIAL_NUMBER" ]; then
        break
    else
        echo "有効なMFAデバイスを選択してください"
    fi
done

# MFAコードの入力
while true; do
    read -p "MFAコードを入力 (6桁): " MFA_TOKEN
    if [[ $MFA_TOKEN =~ ^[0-9]{6}$ ]]; then
        break
    else
        echo "有効なMFAコード（6桁の数字）を入力してください"
    fi
done

# セッションプロファイル名の設定
SESSION_PROFILE="${SOURCE_PROFILE}-mfa"

# 設定内容の確認
echo -e "\n${CYAN}=== 設定内容 ===${NC}"
echo "元のプロファイル: $SOURCE_PROFILE"
echo "MFAセッション用プロファイル: $SESSION_PROFILE"
echo "MFAデバイス: $MFA_SERIAL_NUMBER"
echo "リージョン: $REGION"

# 確認プロンプト
read -p $'\n処理を続行しますか？ (Y/n): ' CONFIRM
if [[ $CONFIRM =~ ^[Nn] ]]; then
    echo "処理を中断しました"
    exit 0
fi

# 一時認証情報の取得
echo -e "\n🔑 一時認証情報を取得中..."
get_session_token_cmd="aws sts get-session-token \
    --serial-number $MFA_SERIAL_NUMBER \
    --token-code $MFA_TOKEN \
    --profile $SOURCE_PROFILE \
    --output text \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]'"

echo "実行コマンド:"
echo "$get_session_token_cmd"

CREDENTIALS=$(eval "$get_session_token_cmd")

if [ $? -ne 0 ]; then
    echo "❌ エラー: 認証情報の取得に失敗しました"
    exit 1
fi

# 認証情報の解析
read ACCESS_KEY SECRET_KEY SESSION_TOKEN EXPIRATION <<< "$CREDENTIALS"

# 値の確認
if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$SESSION_TOKEN" ]; then
    echo "❌ エラー: 認証情報の解析に失敗しました"
    exit 1
fi

# ~/.aws/credentials の更新
echo "📝 認証情報を更新中..."
aws configure set aws_access_key_id "$ACCESS_KEY" --profile "$SESSION_PROFILE"
aws configure set aws_secret_access_key "$SECRET_KEY" --profile "$SESSION_PROFILE"
aws configure set aws_session_token "$SESSION_TOKEN" --profile "$SESSION_PROFILE"
aws configure set region "$REGION" --profile "$SESSION_PROFILE"

# 完了メッセージ
echo -e "\n${GREEN}✅ セットアップ完了!${NC}"
echo "プロファイル '$SESSION_PROFILE' が更新されました"
echo "有効期限: $EXPIRATION"
echo ""
echo "設定されたプロファイル内容:"
echo "aws_access_key_id = $ACCESS_KEY"
echo "aws_secret_access_key = ${SECRET_KEY:0:10}..."
echo "aws_session_token = ${SESSION_TOKEN:0:20}..."
echo ""
echo "使用例:"
echo "aws s3 ls --profile $SESSION_PROFILE"
echo "または"
echo "export AWS_PROFILE=$SESSION_PROFILE"

# プロファイルのテスト
echo -e "\nプロファイルのテスト中..."
aws sts get-caller-identity --profile "$SESSION_PROFILE"