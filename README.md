# pr-inbox

レビュー依頼と自分の PR を「次にやること」順に並べる Claude Code の mod。

- プロンプトの下に件数を常時表示する (`👀 レビュー 0 (+bot 2) · ⚠ 高リスク 1 · 🔴 要対応 2 · ✅ マージ可 0 · ⏳ 待ち 9`)
- `/prs` でペインを開く
  - **レビュー依頼**: 依頼から時間が経っている順。PR ごとに要約・危険性 (低/中/高)・リリース時の影響 (あり/なし/判定不能、フィーチャーフラグを考慮) を自動で付ける
  - **自分の PR**: 要対応 (変更依頼・CI 失敗・コンフリクト) → マージ可 → レビュー待ち → 放置 の順
- 新しいレビュー依頼や、自分の PR の承認・変更依頼・CI 失敗をトーストで知らせる

動作確認した Claude Code: v2.1.288 (mods は v2.1.287 以降が必要)

## 使い方

```bash
claude --plugin-dir ~/mods/pr-inbox
```

| キー | 操作 |
| :- | :- |
| `1` / `2` | レビュー依頼 / 自分の PR |
| `j` / `k` | 次 / 前の PR を選ぶ |
| `e` | Claude に解説 (自分の PR なら対応方法の相談) を依頼する |
| `a` | approve する (確認ダイアログで「Approve する」を選んだときだけ実行) |
| `o` | ブラウザで開く |
| `b` / `s` | bot の PR / 放置中の PR を表示・畳む |
| `r` | 再取得 |
| `Esc` | 閉じる |

`/prs refresh` はペインを開かずに再取得して件数を表示する。

## 必要なもの

- [GitHub CLI](https://cli.github.com/) (`gh auth login` 済み)。PR の取得・diff・approve はすべて `gh` で行う

## 設定

`/config` (または `/plugin configure`) で変えられる。

| 項目 | 既定値 | 内容 |
| :- | :- | :- |
| `org_filter` | (空) | 指定するとその org の PR だけを対象にする |
| `stale_days` | 30 | この日数以上更新のない自分の PR を「放置」に畳む |
| `refresh_minutes` | 5 | GitHub に問い合わせる間隔 |
| `summary_model` | sonnet | レビュー依頼の要約・危険性・影響を判定するモデル |

要約と判定は PR ごとに 1 回モデルを呼ぶ (利用者のプランを使う)。結果は PR の更新日時と一緒に保存し、PR が更新されたときだけ作り直す。判定は目安で、approve の前には中身を確認すること。

## 開発

```bash
pnpm install
claude --plugin-dir .   # 一度読み込むと .claude-plugin/types/ に型定義が生成される (typecheck に必要)
pnpm run check          # validate (--strict) → tsc → Biome → claude plugin test
```

テストは `tests/*.test.ts`。GitHub・モデル・store はすべて stub に差し替えるので、ネットワークに出ない。
