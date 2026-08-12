# Phase 3 screenshot regression review

Phase 3 の screenshot は `scripts/check-phase3-p309 RUN_ID` が固定 fixture、時刻、window size、表示設定で生成し、`artifacts/raw/RUN_ID/run-manifest.json` に SHA-256 を保存する。

## Review procedure

1. 直前の成功 run と新 run の同名 PNG を比較する。
2. geometry、文字切れ、操作重なり、Tone / Ding / Slap と grade の識別、focus、状態 label を確認する。
3. 差分が仕様変更によるものなら、対応 story ID、理由、変更した token または描画契約を新 manifest に記録する。
4. 理由を説明できない差分、fixture の欠落、log の `SCRIPT ERROR` / `ERROR:` は regression として run を失敗にする。
5. 検証中は古い raw evidence を上書きせず、新しい run ID で再取得する。

Phase完了時は、completion reportまたは最終manifestから参照されるstory別の最終run、実機受入れ、代表的な最終visual比較だけをローカル／CIのcanonical evidenceとして残せる。`artifacts/raw/`全体をGitへcommitしない。中間調整、失敗run、preview session、同じ条件の旧runは、最終manifestへ取り込まれていないことを確認して削除できる。raw evidence、再生成可能なbuild archive、report logが必要なら、最終runのdocumented commandから再生成する。

画像の一致だけで judgement の不変性を主張しない。通常、Glow-off、monochrome、high-contrast の replay record は別途 byte comparison する。また shader-backed capture は warm-up と render synchronization 後の画像だけを採用し、HUD 以外が空の初回 frame は失敗として保存する。
