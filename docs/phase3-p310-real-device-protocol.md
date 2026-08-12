# P310 Mood Pan real-device acceptance protocol

P310 の自動 gate が成功した後、macOS buildの通常表示で1 session実施する。実機値や視認性所見を推測で埋めない。

## Prerequisites

- Mood Pan を USB 接続し、MN-10 port が macOS から見える状態にする。
- 他の MIDI 使用アプリを閉じる。
- `artifacts/builds/phase3-p310-final-20260812-build/PanBeat.zip` が存在することを確認する。なければ`scripts/check-phase3-p310 phase3-p310-final-20260812`で再生成する。
- 問題が起きたら PanBeat を終了し、USB を再接続してから同じ command を再実行する。無音だけで切断とは判定しない。

## Extended acceptance score

以前の `P216 Acceptance` は36秒の音源に対して冒頭2秒・4ノートだけだったため、Phase 3実機確認には使用しない。各sessionの開始時に Song Library で既存の `P216 Acceptance` を選択し、次の3ファイルを指定して **Re-import** する。新しい譜面は2秒のcount-in後、2〜33秒に1秒間隔で32ノートを配置し、曲末に2秒の余韻を残す。

- Score: `shared/fixtures/musicxml/p310-real-device.musicxml`
- Audio: `game/content/phase1-fixed-song-v1/orbit-practice.wav`
- Overlay: `shared/fixtures/musicxml/p310-real-device-overlay.json`

インポート後、詳細欄が `IMPORTED`、選択行が `VALID` であることを確認してから `Play Selected` を押す。既存曲がない環境ではタイトルを `P310 Phase 3 Acceptance` として **Import** する。

## Real-device session — High-quality visual mode

```sh
scripts/run-phase3-p310-real-device phase3-p310-device-final-20260812
```

同じrun IDを再実行しても既存証跡は上書きせず、`session-001`、`session-002`のように新しいsessionを追加する。別buildを確認する場合は第2引数にbuild run IDを指定する。

1. Device Setup で `MIDI READY` と選択 port／profile を確認する。
2. Tone、Ding、Slap を各3回以上打ち、input monitor の奏法と位置を確認する。
3. Calibration を実行し、5 valid hits 以上で Analyze、Apply & Save まで進める。
4. Song Libraryで上記の拡張譜面をRe-importし、Tone / Ding / Slapを含む32ノートを最後まで演奏する。
5. Ding が内向き収束リング、Slap が外向き拡大リングとして読めること、HUD がノーツを隠さないこと、Results が1回だけ開くことを確認する。
6. PanBeat を終了し、Codex に所見を伝える。

## Observations to report

- sessionを完走できたか
- Tone / Ding / Slap の読み間違いの有無
- HUD 重なり、画面消失、重複 Results 遷移、入力時 UI 停止の有無
- 発光、残光、シェーダー表現の見栄えと眩しさ・疲労
- 再現手順付きの問題（あれば）

実機受入れは2026-08-12に完了し、最終状態は[`phase3-completion-report.md`](./phase3-completion-report.md)へ記録した。Phase 3完了後も、正式 release、署名、公証、配布可能とは表現しない。
