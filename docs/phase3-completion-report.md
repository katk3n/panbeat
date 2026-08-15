# PanBeat Phase 3 completion report

Status: **PHASE 3 COMPLETE**

> Evidence retention: `artifacts/raw/`はローカル／CI出力であり、Gitにはcommitしない。以下のrun IDと結果summaryは追跡と再生成のために記録している。

Phase 3 は2026-08-12に完了した。P301で選択した Quiet Forge を出発点とし、製品責任者の反復レビューを経て、3種の瞑想的背景、半透明の銅色ハンドパン、局所発光Toneオーブ、収束Dingリング、拡大Slapリングへ仕上げた。Phase 3完了は正式release、署名、公証、配布の許可ではない。

## 最終自動証跡

- 最終gate: `artifacts/raw/phase3-p310-final-20260812/run-manifest.json`
- 再現command: `scripts/check-phase3-p310 phase3-p310-final-20260812`
- 全自動test、macOS build、package inspection、全画面capture、最大負荷測定はpassした。
- 独立した2 replayのjudgement recordとScoreは相互にbyte-identicalで、Phase 2 P212 baselineとも一致した。1600×900のGameplay screenshotも2 runでbyte-identicalだった。
- 最大負荷はactive note 64、feedback 64で、frame p95 16.937 ms、Node増加0、Resource増加0だった。
- 最終buildは`artifacts/builds/phase3-p310-final-20260812-build/PanBeat.zip`で再生成できる。archive自体は`.gitignore`対象であり、manifestにSHA-256を記録する。

## Story traceability

| Story | Canonical evidence |
|---|---|
| P301 | `artifacts/raw/phase3-p301-approval-20260812/run-manifest.json` |
| P302 | `artifacts/raw/phase3-p302-ding-20260812t1530/run-manifest.json` |
| P303 | `artifacts/raw/phase3-p303-rich-ui-v3-20260812/run-manifest.json` |
| P304 | `artifacts/raw/phase3-p304-shell-20260812t1615/run-manifest.json` |
| P305 | `artifacts/raw/phase3-p305-field-20260812t1640/run-manifest.json` |
| P306 | `artifacts/raw/miss-text-only-p306-20260812/run-manifest.json` |
| P307 | `artifacts/raw/phase3-p307-hud-20260812t1810/run-manifest.json` |
| P308 | `artifacts/raw/repeat-play-p308-20260812/run-manifest.json` |
| P309 | `artifacts/raw/phase3-p309-runtime-background-v9-20260812/run-manifest.json` |
| P310 | `artifacts/raw/phase3-p310-final-20260812/run-manifest.json` |

最終visual補足証跡は、3背景と銅色を示す`background-selection-copper-v13-20260812`、最新の判定feedbackとラベルを示す`miss-text-only-v15-20260812`に限定した。

## 実機・製品責任者受入れ

- `phase3-p310-device-visual-v6-20260812`でMood Panによる一曲通しを完了し、Tone / Ding / Slap、HUD、Results遷移、画面消失、重複遷移、MIDI入力停止、眩しさ・疲労に問題がないことを確認した。
- その後のvisual-only修正は各device previewで確認され、最終確認で背景切替、銅色、シアンオーブ、Bloom、`PERFECT`全文表示、MISSの×印撤去に問題なしと製品責任者が回答した。したがって最終受入れは「一曲通し＋後続visual差分の実機spot check」のcomposite evidenceとする。
- 36秒音源に対して旧P216譜面が冒頭4ノートで終わる問題は、2〜33秒に32ノートを配置するP310専用譜面へ置き換えた。
- Resultsから同一曲の`Play Again`またはSong Libraryへ戻れるため、processを終了せず反復演奏できる。

## 確定した視覚仕様

- Gameplayとmenuは外部画像を使わず、repository内shaderで瞑想的な霧、halo、caustic lightを描画する。
- Gameplay背景は`silent_resonance`、`breath_of_dawn`、`deep_resonance`から曲ごとに選択でき、将来package metadataで指定できる解決順をADR-006に固定した。
- ハンドパンは背景を透過する銅色。誤判定を誘う外周の金色ringと旧highlight arcは使わない。
- Toneは前景の明るいシアン発光オーブで、追従trailを持たない。Ding / Slapは一重ringとし、HIT時は放射線や白flashではなくBloomを強める。
- MISSはtextのみ、`PERFECT`は計測した文字幅で欠けずに表示する。
- Reduced Effectsは製品判断によりPhase 3対象外。Glow-off、monochrome、高コントラストはaccessibility検証用設定として維持する。
- 通常起動はmaximized、reference captureは1600×900、対応下限検証は1280×720とする。

## Post-Phase 3 status

- Phase 3完了時点では`R-P1-001`、`R-P1-003`、外部allocation profilingをFinal Phaseへ引き継いだ。
- 2026-08-14の製品判断によりFinal Phaseは現行ロードマップから外した。これらの測定値と制約は解決済みにせず、既知の制約として保持する。
- Practice Mode、左右手ガイド、苦手箇所分析、Free Play、Pressure / dynamicsはPhase 3外であり、release blockerではない。
- 現在のbuildについて、署名、公証、store配布、または正式なrelease candidate品質を主張しない。将来正式配布を計画する場合は新しいrelease計画を作成する。
