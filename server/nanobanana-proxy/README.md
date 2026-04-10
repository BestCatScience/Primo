# Nano Banana Proxy

`atelierprime` の有料 Nano Banana 機能を代理実行するサーバーです。

このサーバーは次を行います。

- アプリから送られた `Authorization: Bearer <Transaction JWS>` を検証
- `com.atelierprime.nanobanana.monthly` の購読権利が有効か確認
- 有効ならサーバー側の `GEMINI_API_KEY` で Nano Banana を呼ぶ
- 生成画像だけをアプリへ返す

## 前提

- Node.js 20 以上
- App Store Connect で `com.atelierprime.nanobanana.monthly` を作成済み
- サーバー環境変数 `GEMINI_API_KEY` を設定済み
- Apple Root CA 証明書を `certs/` に配置済み

## セットアップ

1. 依存関係を入れる

```bash
cd server/nanobanana-proxy
npm install
```

2. `.env.example` を `.env` にコピーして値を埋める

```bash
cp .env.example .env
```

3. Apple PKI から root certificate を取得して `certs/` に置く

想定ファイル名:

- `certs/AppleRootCA-G3.cer`
- `certs/AppleRootCA-G2.cer`
- `certs/AppleIncRootCertificate.cer`

4. 開発起動

```bash
npm run dev
```

## iOS アプリ側設定

`App/Support/Info.plist` の `NanoBananaProxyEndpoint` に公開 URL を入れます。

例:

```xml
<key>NanoBananaProxyEndpoint</key>
<string>https://api.example.com/nanobanana/edit</string>
```

## API

### `POST /nanobanana/edit`

Headers:

```http
Authorization: Bearer <StoreKit Transaction JWS>
Content-Type: application/json
```

Body:

```json
{
  "prompt": "Turn this sketch into a polished watercolor illustration",
  "model": "gemini-3.1-flash-image-preview",
  "mime_type": "image/png",
  "image_base64": "..."
}
```

Success:

```json
{
  "image_base64": "...",
  "product_id": "com.atelierprime.nanobanana.monthly",
  "environment": "Sandbox"
}
```

## 本番運用メモ

- `GEMINI_API_KEY` は絶対にアプリへ埋め込まない
- `NanoBananaProxyEndpoint` には HTTPS のみ使う
- レート制限とログ監視を入れる
- App Store Server Notifications V2 を受けて権利キャッシュするとなお良い
- 生成上限を課金プランごとに持たせるなら、このサーバーで追加制御する
