# PanBeat Final Phase: Release Hardening

## 1. 目的と開始条件

このPhaseは、主要な製品機能とコンテンツ実装が一通り完了し、release candidateを作る直前に開始する。Phase 1で計測した長時間driftとMIDI dispatch p95は、それ以前の機能開発を止めないが、このFinal Phaseを通過するまで正式releaseを許可しない。

開始条件は次のとおりとする。

- MVP対象機能がfeature completeである
- 最終的な音源形式、判定窓、対応端末・OS範囲が候補として固定されている
- Device SetupとCalibrationが実機試験可能である
- release相当buildを再現可能な一意のcommandがある

## 2. FH01: 性能測定を実利用条件へ更新する

**目的:** Phase 1のstress測定と実際のrelease条件を区別し、改善対象を正しく特定する。

**実施内容:** 6分以上の実音源を1倍速で3回再生し、開始・途中・終了のtransport/audio差と傾きを保存する。MIDIは人工的な1 frame待ちを入れない測定経路を作り、60 Hz、120 Hz、実機またはvirtual CoreMIDIで受付から判定timestamp確定までを測る。

**完了条件:** raw log、環境、build、audio device/sample rate/buffer、fixture checksum、p50/p95/p99/maxが保存され、Phase 1値との差を測定方法込みで説明できる。

## 3. FH02: 長時間driftを改善する

**目的:** 長時間曲でもaudio-backed transportと判定時刻を安定させる。

**実施内容:** FH01で累積傾斜が確認された場合、sample-based位置、clock anchor、resampling条件、開始・終了frame量子化を分離して修正する。終了frameだけの観測誤差を累積driftと混同しない。

**完了条件:** release相当・実速度・6分以上×3回で最終絶対driftの各runが5 ms以下となる。基準変更は実測とプロダクト判断を別ADRへ残した場合だけ認める。

## 4. FH03: MIDI dispatchと判定timestampを改善する

**目的:** main-loopのframe待ちが判定gradeへ影響しない入力経路を成立させる。

**実施内容:** まずGodot `_input`から同frameで軽量queueへ渡し、60/120 Hzを比較する。必要ならMIDI到着monotonic timestampをsong timeへ変換して判定へ使い、表示feedbackの遅延と判定時刻を分離する。Godot標準APIで不足する場合のみCoreMIDI callbackと固定長queueのnative adapterを採用する。

Phase 2 P216では、起動後にUSB接続したMN-10をGodot 4.6標準CoreMIDI backendが再検出せず、`Reopen MIDI`では`NO MIDI PORTS`のまま、USB接続後のアプリ再起動で復旧した。Phase 2ではdocumented relaunch routeを既知制約として受け入れた。FH03ではnative CoreMIDI adapterの採否を、hot-plug通知・再接続、drop/duplicate、CoreMIDI packet timestamp、Universal 2 build・署名・保守コストをGodot標準経路と比較して判断する。採用済みとは扱わない。

**完了条件:** 定義済みの受付点から判定timestamp確定までのp95が5 ms以下で、drop/duplicateがなく、OS受信timestampの有無が明記される。Mood Pan実機でTone / Ding / SlapとCalibrationを再受け入れする。

## 5. FH04: Final Release Gate

**目的:** 性能改善による機能回帰がなく、release品質を満たすことを確定する。

**完了条件:** 

- FH01〜FH03のraw evidenceと再生成commandが揃う
- 長時間driftとMIDI dispatch p95が目標を満たす
- 外部profilerで定常allocationを確認する
- 外部end-to-end latencyは2026-08-12の製品判断により計測しない。software timestampを物理end-to-end latencyとして代用せず、この非実施判断をrelease資料にも保持する
- 自動test、決定的replay、build検査、Mood Pan実機受け入れを再実行する
- R-P1-001とR-P1-003を、測定値を伴って`resolved`へ更新する
- 未達項目が一つでもあればrelease candidateを合格扱いしない

## 6. 運用規則

- R-P1-001とR-P1-003はFinal Phaseまで削除せず、`deferred-release-gate-blocker`として追跡する。
- 機能開発中に明確な体感不具合や判定誤りが再現した場合は、Final Phaseを待たず原因storyを再開する。
- Phase 1のraw測定値と当時のBlocked判断証拠は変更せず、後続判断を別manifestとして追加する。
