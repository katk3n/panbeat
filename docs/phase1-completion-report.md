# Phase 1 Completion Report

> Evidence retention: 本書に記載した`artifacts/raw/`のrun IDはローカル／CI出力であり、Gitにはcommitしない。完了状態は本書、versioned test、再現commandを正とする。

## Gate decision

**Decision: Complete with deferred release-gate items（2026-08-12）**

固定JSON譜面1曲を使うGodot 4.6 macOS Product Vertical Sliceは、自動受け入れとMood Pan実機3 sessionで機能受け入れを完了した。P111では次の2つがアーキテクチャ目標5 msを超えた。

- CoreAudio release相当5分59秒×3回の最終絶対drift: 6.078 / 2.387 / 4.186 ms。p95/max 6.078 ms。
- recorded-burst MIDI acceptance-to-Gameplay dispatch: p50 6.516 ms、p95 8.295 ms、p99 9.764 ms。

実機3 sessionで体感上の問題がなく、値がPerfect判定幅±30 msより小さいこと、Phase 1測定が0.1倍速audioと人工的な1 frame待ちを含むことを踏まえ、プロダクト責任者は両項目を`deferred-release-gate-blocker`へ再分類した。Phase 1の後続機能開発は許可するが、[`final-phase-stories.md`](./final-phase-stories.md)を完了するまでrelease candidateは合格させない。

P101〜P114のstory作業と監査は完了しているが、これは`docs/requirement.md`のMVP完成やrelease許可を意味しない。最初の`Blocked`判断は`artifacts/raw/phase1-p114-gate-20260812/run-manifest.json`へ履歴として保持し、本判断が後からsupersedeする。

## 固定された製品契約

| 項目 | Phase 1で固定した値 |
|---|---|
| Engine | Godot 4.6.stable.official.89cea1439 / typed GDScript |
| Target | macOS universal release / Compatibility Renderer |
| Build command | `scripts/check-phase1-acceptance UNIQUE_RUN_ID` |
| Accepted build | `phase1-p112-acceptance-k-20260812` / SHA-256 `45ad64f9c6662f3aa973fd7d3a4edae22af3f0126c2d49fedefead56cbee44e6` |
| Fixed song | `phase1-fixed-song-v1` / `game/content/phase1-fixed-song-v1/package.json` |
| Runtime audio | 48 kHz mono signed 16-bit PCM WAV |
| Instrument Profile | `roland-mn10-handpan-minor-v1` / SHA-256 `abfe1eae01e2b2c1e24801a7946354f35924426adc33c903672dce4d036fb42d` |
| Judgement rule | `panbeat-phase1-standard-v1` |
| Score rule | `panbeat-phase1-score-v1` |

## Story監査

| Story | 状態 | 主証拠 |
|---|---|---|
| P101 | Done | `artifacts/raw/phase1-p101-baseline-20260810T124443Z/run-manifest.json` |
| P102 | Done | `artifacts/raw/phase1-p102-harness-20260810T125200Z/run-manifest.json` |
| P103 | Done | `artifacts/raw/phase1-p103-song-20260810T130100Z/run-manifest.json` |
| P104 | Done | `artifacts/raw/phase1-p104-runtime-chart-20260810T131300Z/run-manifest.json` |
| P105 | Done | `artifacts/raw/phase1-p105-audio-transport-20260810T134000Z/run-manifest.json` |
| P106 | Done after P113 correction | `artifacts/raw/phase1-p113-device-01-baseline-20260812/diagnostics.json`、cold-start unit test、P112 j/k |
| P107 | Done | `artifacts/raw/phase1-p107-gameplay-20260810T143000Z/run-manifest.json` |
| P108 | Done | `artifacts/raw/phase1-p108-judgement-20260810T150000Z/run-manifest.json` |
| P109 | Done | `artifacts/raw/phase1-p109-score-offset-20260810T153000Z/run-manifest.json` |
| P110 | Done | `artifacts/raw/phase1-p110-vertical-slice-20260810T160000Z/run-manifest.json` |
| P111 | Done; 2 targets deferred to Final Phase | `artifacts/raw/phase1-p111-performance/run-manifest.json` |
| P112 | Done after correction | `artifacts/raw/phase1-p112-acceptance/run-manifest.json` |
| P113 | Done, 3/3 sessions | `artifacts/raw/phase1-p113-device-acceptance-20260812/run-manifest.json` |
| P114 | Done; owner reclassification recorded | `artifacts/raw/phase1-p114-gate-reclassification-20260812/run-manifest.json` |

## Phase 1完了チェックリスト監査

- [x] 製品runtime pathからPhase 0固有名と`pocs/`依存を除去した。
- [x] 固定譜面・同期WAV・version・checksum・CC0 provenanceを保存した。
- [x] 実物ハンドパン式の外周8音（左上8、右上7）、Ding、Slapを描画・撮影した。
- [x] audio-backed transportでcount-in、pause/resume、終了を動作させた。
- [x] USB MIDIとreplayを共通の正規化・判定契約へ接続した。
- [x] Perfect / Great / Good / Miss / Extra Hitとscore/comboをversion付きruleから再現した。
- [x] offset符号規約をunit testと+30 ms実機sessionで確認した。
- [x] frame sequence/stall後のtransport復帰を確認した。
- [x] 5分以上×3回、frame time/pool、MIDI dispatchを計測した。ただしdriftとdispatchは目標未達である。
- [x] clean checkout相当のtest/replay/build/screenshotを1 commandで2回独立実行した。
- [x] Mood Pan Handpan / Minorで3 session完走し、Tone / Ding / Slap、pause/resume、再接続を確認した。
- [x] 未確認機能、Godot API制約、blockerを明記した。
- [x] Phase 2項目を先取りせず、以下へ引き継いだ。

## Phase 2への引き継ぎ

- MusicXML 4.0を音楽原本、PanBeat overlayをゲーム注釈としてimportし、未対応要素を黙って破棄しないdiagnosticsを作る。
- Device SetupでMIDI port/profile選択、open-before-enumerate、切断時のreopen/relaunch導線を実装する。Godotのport listだけで物理切断を断定しない。
- CalibrationでInput/Audio Offsetを測定・保存し、符号説明とmigrationを用意する。
- Song Library、Results、設定保存、結果履歴を実装する。
- 高速度カメラ、audio loopback等で物理打撃から音・画面までのend-to-end latencyを測る。software timestampだけで確定しない。
- 長時間曲についてWAV/OGGの容量、変換、seek/loop精度を比較する。
- Handpan / Minor以外のTone/Style、BLE、Pressure、Muteは実測profileが揃うまで対応済みとしない。

## Final Release Hardening Phaseへの必須引き継ぎ

- 6分以上の実音源を1倍速で3回測り、drift各run 5 ms以下を確認する。
- 人工的なframe待ちを除いたMIDI測定を60/120 Hzと実機またはvirtual CoreMIDIで行い、dispatch p95 5 ms以下を確認する。
- 必要ならsample-based transport、MIDI arrival timestampのsong-time変換、native CoreMIDI adapterを実装する。
- 外部allocation profilerと高速度撮影またはaudio loopbackでrelease品質を確認する。
- R-P1-001とR-P1-003が実測付きで`resolved`になるまで正式releaseを許可しない。

## 残存risk

`docs/phase1-acceptance.json`のR-P1-001〜R-P1-007を正とする。R-P1-001とR-P1-003は通常の機能開発を止めないが、Final Release Hardening Phaseを止める未解決blockerである。
