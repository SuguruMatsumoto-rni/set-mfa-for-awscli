# AWS MFA認証スクリプト 利用手順

## 概要
AWS CLIで一時的な認証情報を取得し、MFA認証を行うためのシェルスクリプトです。プロファイル選択、MFAデバイスの選択、トークンコードの入力を対話形式で行い、一時認証情報を設定します。

## 前提条件
- AWS CLIがインストールされていること
- AWS認証情報（`~/.aws/credentials`）が設定済みであること
- IAMユーザーにMFAデバイスが設定済みであること

## セットアップ

1. スクリプトの保存
```bash
# スクリプトを任意の場所に保存（例: ~/aws-mfa.sh）
curl -o ~/aws-mfa.sh https://raw.githubusercontent.com/SuguruMatsumoto-rni/set-mfa-for-awscli/main/aws-mfa.sh

# 実行権限を付与
chmod +x ~/aws-mfa.sh

# エイリアスを設定（zshの場合）
echo 'alias aws-mfa="~/aws-mfa.sh"' >> ~/.zshrc

# 設定を反映
source ~/.zshrc
# または上記のスクリプトをコピーして保存

# 実行権限を付与
chmod +x ~/aws-mfa.sh
```

2. エイリアスの設定（オプション）
```bash
# ~/.zshrc または ~/.bashrc に追加
alias aws-mfa='~/aws-mfa.sh'

# 設定の反映
source ~/.zshrc  # または source ~/.bashrc
```

## 使用方法

1. スクリプトの実行
```bash
# 直接実行する場合
~/aws-mfa.sh

# エイリアスを設定した場合
aws-mfa
```

2. 対話形式での入力
- プロファイルの選択（例: aws-stg-user）
- MFAデバイスの選択
- MFAコードの入力（6桁）
- 確認後に実行

3. 作成されるプロファイル
- 元のプロファイル名に `-mfa` が付加されます
- 例: `aws-stg-user` → `aws-stg-user-mfa`

4. 認証後のAWS CLIコマンド実行
```bash
# プロファイルを指定して実行
aws s3 ls --profile aws-stg-user-mfa

# または環境変数として設定
export AWS_PROFILE=aws-stg-user-mfa
aws s3 ls
```

## スクリプトの動作

1. プロファイル一覧を `~/.aws/credentials` から取得
2. 選択したプロファイルに紐づくMFAデバイスを取得
3. MFAトークンコードを入力
4. AWS STSから一時認証情報を取得
5. 新しいプロファイルとして認証情報を保存

## 注意事項

- 一時認証情報の有効期限は12時間（43200秒）
- 期限切れ後は再度実行が必要
- リージョンは `ap-northeast-1` に固定
- 既存のMFAセッションプロファイルは上書きされます

## トラブルシューティング

1. 権限エラーが発生する場合
```bash
# スクリプトの実行権限を確認
ls -l ~/aws-mfa.sh
# 権限がない場合は付与
chmod +x ~/aws-mfa.sh
```

2. プロファイルが表示されない場合
```bash
# 認証情報ファイルを確認
cat ~/.aws/credentials
```

3. MFAデバイスが取得できない場合
```bash
# IAMユーザーのMFAデバイスを確認
aws iam list-mfa-devices --profile your-profile
```

## 実行例

```bash
$ aws-mfa

=== AWS MFA認証セットアップ ===

利用可能なプロファイル:
1) default
2) aws-stg-user
プロファイルを選択してください (番号): 2

MFAデバイスを取得中...
MFAデバイスを選択してください:
1) arn:aws:iam::123456789012:mfa/mfa_auth
MFAデバイスを選択してください (番号): 1

MFAコードを入力 (6桁): 123456

=== 設定内容 ===
元のプロファイル: aws-stg-user
MFAセッション用プロファイル: aws-stg-user-mfa
MFAデバイス: arn:aws:iam::123456789012:mfa/mfa_auth
リージョン: ap-northeast-1

処理を続行しますか？ (Y/n): y

🔑 一時認証情報を取得中...
📝 認証情報を更新中...

✅ セットアップ完了!
```

## 関連情報
- [AWS CLI Command Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html)
- [AWS STS get-session-token](https://docs.aws.amazon.com/cli/latest/reference/sts/get-session-token.html)
