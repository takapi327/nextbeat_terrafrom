# cloudflare-os フォーク手順

upstream: https://github.com/cloudflare/cloudflare-os （Apache 2.0）

Cloudflare OS は「フォークして自社版として保守する」前提の OSS で、upstream は外部コントリビューションを
原則受け付けない方針。よって改修はすべてフォーク側で持ち、upstream の更新を定期的に取り込む運用になる。

## 1. フォーク方式の選択

| 方式 | 作り方 | 向き | 注意 |
|---|---|---|---|
| A. 通常のフォーク | GitHub の Fork ボタン | 個人検証（今回の PoC はこれで十分） | **public リポジトリのフォークは private にできない**。コミットが fork network 上で公開される |
| B. private ミラー | 下記の bare clone + push | 会社利用（Entra テナント ID 等の社内情報が差分に乗るため） | GitHub 上の fork 関係がないので PR ベースの upstream 同期 UI は使えない（コマンドで同期する） |

### 方式 A: 通常フォーク（PoC 用）

```console
$ gh repo fork cloudflare/cloudflare-os --clone --remote
$ cd cloudflare-os
$ git remote -v   # origin = takapi327/cloudflare-os, upstream = cloudflare/cloudflare-os
```

### 方式 B: private ミラー（会社利用時）

```console
$ gh repo create <org>/cloudflare-os --private
$ git clone --bare https://github.com/cloudflare/cloudflare-os.git
$ cd cloudflare-os.git
$ git push --mirror https://github.com/<org>/cloudflare-os.git
$ cd .. && rm -rf cloudflare-os.git

$ git clone https://github.com/<org>/cloudflare-os.git
$ cd cloudflare-os
$ git remote add upstream https://github.com/cloudflare/cloudflare-os.git
```

## 2. 初期セットアップと動作確認

```console
$ pnpm install
$ pnpm run-local          # http://localhost:8787 で全スタック起動（0円）
$ pnpm lint               # 型チェック・生成物チェック込み
```

開発時はフロント/バックを分けて起動する:

```console
$ pnpm dev-server
$ pnpm dev-client         # http://localhost:3000
```

## 3. ブランチ戦略と差分の置き場所ルール

```
main        : upstream/main + 自社差分（常にデプロイ可能な状態を保つ）
feature/*   : 作業ブランチ。main へ PR
```

フォークの保守コストは「upstream とどれだけ diff を持つか」で決まる。差分は以下に限定する。

| 置き場所 | 内容 | upstream 競合リスク |
|---|---|---|
| `packages/gatekeeper-<name>/`（新規追加） | 独自ゲートキーパー（Entra サインイン、社内 API 連携等）。1 ゲートキーパー = 1 Worker の独立パッケージで、ルーターが service binding を自動検出する | ほぼゼロ |
| `packages/bundled-blueprints/` | 社内標準の Gadget テンプレート追加 | 低 |
| 各 Worker の `cloudflare.config.ts` / 環境変数 | デプロイ設定（`wrangler.jsonc` は生成物なので直接編集しない。`pnpm configs:generate` で再生成） | 低 |
| `packages/workshop-backend/`（カーネル） | **原則変更禁止**。upstream 自身が「全行レビュー対象のカーネル」と位置付けており、ここを触ると毎回の merge で競合解消を負う。変更したくなったら、まずゲートキーパー追加か admin 設定で代替できないか検討する | 高 |

シークレット（OAuth クライアントシークレット等）はコミットせず `wrangler secret put` で設定する。

## 4. upstream 追従手順（月 1 回目安）

early access 期は更新が速いため、放置すると merge が重くなる。定期実行をカレンダー化しておく。

```console
$ git fetch upstream
$ git log --oneline main..upstream/main   # 取り込む内容を事前に把握する
$ git switch -c feature/sync-upstream-$(date +%Y%m%d)
$ git merge upstream/main
# 競合は「3. 置き場所ルール」を守れていれば設定ファイル程度に収まるはず
$ pnpm install && pnpm lint && pnpm test
$ pnpm run-local                          # 独自ゲートキーパー含めて手動スモーク
# → main へ PR
```

方式 A（通常フォーク）なら `gh repo sync takapi327/cloudflare-os --source cloudflare/cloudflare-os` も使えるが、
自社差分がある場合は上記の merge + 検証フローを基本とする。

## 5. デプロイ

PoC では wrangler で手元からデプロイする（手順の位置づけは SETUP.md ステップ 6）。

```console
$ wrangler login
$ pnpm build
# デプロイ対象 Worker ごとに wrangler deploy（router / workshop-backend / 各 gatekeeper）
```

本格運用に移行する場合は、デプロイ用 starter リポジトリ
https://github.com/cloudflare/cloudflare-os-starter を参照し、CI（GitHub Actions）からの
デプロイに切り替える。CI 用の Cloudflare API トークンはリポジトリ secrets に置き、
権限は Workers Scripts: Edit 等の必要最小限に絞る。

## 6. 会社利用に昇格する際の TODO

- [ ] 方式 B（private ミラー）で `<org>/cloudflare-os` を作り直す（PoC の差分を cherry-pick）
- [ ] branch protection（レビュー必須）+ 認可まわり（`packages/gatekeeper-*`、`auth` 系）に CODEOWNERS
- [ ] write 権限を SRE + 指名メンテナに限定（read は社内公開で可）
- [ ] upstream 追従を CI の定期ジョブ化（merge → lint/test → PR 自動作成）
