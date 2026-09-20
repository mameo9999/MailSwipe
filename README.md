# MailSwipe

iCloudの未読メールを古い順に1通ずつ確認する、個人利用向けiPhoneアプリです。

## 現在の段階

フェーズ2の画面試作です。iCloudにはまだ接続せず、仮メールで次の動作を確認できます。

- 件名、送信者、受信日時、本文の表示
- 右スワイプ：既読として処理
- 左スワイプ：未読のまま確認済みにする
- 下スワイプ：現在の起動中に処理したメールを1通ずつさかのぼる
- 戻ったメールを左右どちらにも再スワイプ
- 確認済みメールを次回取得対象から除外
- 確認済み履歴のリセット
- 外部画像をボタン操作まで読み込まないHTML表示
- 添付ファイル欄の表示

## 構成

- SwiftUI
- XcodeGen
- GitHub Actionsによる無料ビルド
- 現段階では`MockMailService`を使用
- iCloud接続段階でMailCore2、Keychain、IMAPを追加予定

## ローカル生成（Macがある場合）

```sh
brew install xcodegen
xcodegen generate
open MailSwipe.xcodeproj
```

Windows環境ではGitHub ActionsでXcodeプロジェクトを生成し、コンパイルします。

## セキュリティ

Apple Accountの通常パスワードは使用しません。iCloud接続時はアプリ用パスワードをiPhone上で入力し、Keychainへ保存します。認証情報はGitHubへ保存しません。

