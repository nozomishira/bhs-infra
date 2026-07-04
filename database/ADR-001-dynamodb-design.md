# ADR-001: DynamoDB テーブル設計

## 概要

インドネシア語学習アプリ（bhs-webapp）の問題データ・セッション管理を
DynamoDB で管理するための設計方針。

---

## 設計原則

- **低コスト優先**: PAY_PER_REQUEST（オンデマンド）課金。RCU/WCUの無駄を最小化
- **シンプルなアクセスパターン**: テーブル2つ、GSI最小限
- **拡張性**: ユーザー管理（Cognito連携）・進捗記録は将来追加できる構造
- **レベル拡張**: 現在 Level 1〜50、将来は 100 以上に拡張可能

---

## テーブル一覧

| テーブル名 | 用途 |
|---|---|
| `{prefix}-bhs-questions` | 問題データ（語彙・文法） |
| `{prefix}-bhs-quiz-sessions` | クイズセッション記録（将来のユーザー進捗管理） |

---

## bhs-questions テーブル

### キー設計

| キー | 型 | 値の例 | 説明 |
|---|---|---|---|
| PK (HASH) | String | `LEVEL#01` | ゼロ埋め2桁でソート順を保証 |
| SK (RANGE) | String | `QUESTION#<uuid>` | 問題の一意識別子 |

### 属性

| 属性名 | 型 | 必須 | 説明 |
|---|---|---|---|
| `pk` | S | ✓ | `LEVEL#<NN>` (NN = 01〜50) |
| `sk` | S | ✓ | `QUESTION#<uuid>` |
| `questionId` | S | ✓ | UUID v4 |
| `level` | N | ✓ | 数値のレベル (1〜50) |
| `type` | S | ✓ | `vocabulary` / `grammar` |
| `category` | S | ✓ | `greeting` / `noun` / `adjective` / `sentence` など |
| `question` | S | ✓ | 問題文（日本語） |
| `options` | L | ✓ | 選択肢の配列 (4択) |
| `correctAnswer` | N | ✓ | 正解インデックス (0〜3) |
| `explanation` | S | ✓ | 解説文 |
| `indonesianWord` | S | - | インドネシア語の単語（単語問題の場合） |
| `createdAt` | S | ✓ | ISO8601形式 |
| `updatedAt` | S | ✓ | ISO8601形式 |

### GSI: type-level-index

| キー | 値 |
|---|---|
| GSI PK (HASH) | `type` (`vocabulary` / `grammar`) |
| GSI SK (RANGE) | `level` (数値) |

**用途**: タイプ別・レベル範囲での問題フィルタリング（将来の管理アプリ向け）

### アクセスパターン

| パターン | 操作 | 条件 |
|---|---|---|
| レベルを指定して問題を取得 | Query | `pk = "LEVEL#<NN>"` |
| タイプ＋レベルで問題を取得 | Query on GSI | `type = "vocabulary"`, `level = 1` |
| 問題を1件取得 | GetItem | `pk + sk` |

### ランダム取得の実装方針

DynamoDB はネイティブのランダム取得をサポートしないため、
Lambda 側でアプリケーションロジックとして処理する:

1. `Query` でそのレベルの全問題 ID を取得（`ProjectionExpression` で ID のみ）
2. Lambda 内でシャッフル（Fisher-Yates）
3. 先頭 N 件の ID を `BatchGetItem` で取得

各レベル 20 問程度なので、フルスキャンのコストは無視できる。

---

## bhs-quiz-sessions テーブル

現時点ではユーザー認証なし。セッションIDで匿名記録する。
Cognito 導入時は `userId` を PK に変更するか、GSI を追加する。

### キー設計

| キー | 型 | 値の例 |
|---|---|---|
| PK (HASH) | String | `SESSION#<uuid>` |
| SK (RANGE) | String | `METADATA` |

### 属性

| 属性名 | 型 | 必須 | 説明 |
|---|---|---|---|
| `pk` | S | ✓ | `SESSION#<uuid>` |
| `sk` | S | ✓ | `METADATA` (固定) |
| `sessionId` | S | ✓ | UUID v4 |
| `level` | N | ✓ | クイズで選択したレベル |
| `questionCount` | N | ✓ | 選択した問題数 (5/10/15/20) |
| `score` | N | ✓ | 正解数 |
| `totalQuestions` | N | ✓ | 出題数 |
| `courseType` | S | ✓ | `vocabulary` / `grammar` / `exam` |
| `createdAt` | S | ✓ | ISO8601形式 |
| `ttl` | N | - | TTL (90日後のUnixタイム。古いセッション自動削除) |

---

## 将来の拡張計画

```
Cognito 導入後:
  bhs-quiz-sessions の PK を USER#<cognitoId> に変更
  SK を SESSION#<createdAt> にしてユーザーごとの履歴を Query 可能にする

管理アプリ (bhs-webadmin) 向け:
  bhs-questions テーブルに対して PutItem/UpdateItem/DeleteItem を追加
  type-level-index GSI で管理画面のフィルタリングに対応

レベル拡張:
  PK の NN を 3桁ゼロ埋め（LEVEL#001）に将来変更するか、
  現在の 2桁のまま Level 50 以上は 3桁混在でも Query は動作する
  → 拡張時は migration スクリプトで一括更新する想定
```

---

## TTL 設定

`bhs-quiz-sessions` テーブルにのみ TTL を設定。
問題データ（`bhs-questions`）には TTL 不要。

---

## コスト見積もり（東京リージョン）

| 操作 | 想定量/月 | 概算コスト |
|---|---|---|
| bhs-questions Query | 10,000回 | ~$0.01 |
| bhs-questions BatchGetItem | 10,000回 (20件/回) | ~$0.05 |
| bhs-quiz-sessions PutItem | 5,000回 | ~$0.005 |
| ストレージ (1,000問 × 1KB) | ~1MB | 無視できる |
| **合計** | | **~$0.10/月** |

無料枠（25GB ストレージ、200万リクエスト/月）の範囲内で十分収まる想定。
