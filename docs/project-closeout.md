# PanBeat project closeout

Status: **CURRENT ROADMAP COMPLETE**

2026-08-14の製品判断により、Web提供、Web MIDI PoC、従来のFinal Release Hardening（FH01〜FH04）は現行ロードマップに含めない。Phase 1〜4で得た測定値と既知制約は解決済みに変更せず保持する。現在のbuildは機能完成したmacOS向けbuildであり、署名、公証、store配布、または正式なrelease candidate品質を主張しない。

## Closeout verification

- Run ID: `closeout-final-r4-20260814`
- Reproduction: `scripts/check-game --mode all --run-id closeout-final-r4-20260814`
- Node tests: 34/34 pass
- JSON Schema cases: 20/20 pass
- Godot tests: 514/514 pass
- Deterministic replay: 7/7 pass（Godot合計に含む）
- macOS build: pass
- Build: `artifacts/builds/closeout-final-r4-20260814/PanBeat.zip`
- Build SHA-256: `4a74864b156cb0577acec70fdfd1e17953bdac282b3387333a5eec67293f7ab1`
- Build size: 63,111,044 bytes

`artifacts/`のrun出力はGit管理対象外である。上記commandは同じ検査構成を新しい一意のrun IDで再実行するためのもので、既存runを上書きしない。

## Test decisions

- P204 canonical chart testは必要と判断した。左右手metadata追加後にgoldenが古いままだったため、`hand: unspecified`を含む現在の決定的出力へ更新した。
- Phase 1/2 baseline checksum testsは必要と判断した。意図的な左右手契約変更をamendmentとして記録し、現在の承認済みschema/chart checksumへ更新した。将来の未承認変更検出は維持する。
- P310 testは必要と判断したが、Git管理されない過去の`artifacts/raw/`を直接読む検査はclean checkoutで再現できないため削除した。代わりに、commit済みのdesign decision、completion report、実機protocol、受け入れ譜面、現行closeout判断を検証する9件へ整理した。
- Phase 1 gate auditは履歴整合性のため必要と判断した。旧Final Phaseの内容が履歴として残ることと、現行計画が`NOT PLANNED`であることを同時に検証するよう更新した。
- Product integration testは必要と判断した。judgementに関係するgolden fieldsと左右手metadataを分離して検証し、入力eventへ表示用hand情報を混ぜない構成にした。
- phase別のcapture、measure、runner、PoCは過去の受け入れ証拠を再生成するため保持した。sourceや文書から参照されない製品GDScriptは確認されなかった。
- `shared/fixtures/expected-results/README.md`は、実データを持たない旧placeholderで、golden dataが`shared/fixtures/test-pack/`へ確立済みのため削除した。

## Harness cleanup

- `npm test`を追加し、全Node testを標準commandで実行可能にした。
- `scripts/check-game --mode tools`を追加した。
- `scripts/check-game --mode test/all`へNode testとschema validationを統合し、Godot testだけ通ってtooling regressionを見落とす状態を解消した。

## Remaining diagnostics

- restricted macOS環境ではGodotがsystem CA certificate取得warningを出すが、全testとexportはexit code 0で完了した。
- headless integration testで実際の`AudioStreamPlayer`を開始すると、Godot 4.6 Dummy audio終了時に`AudioStreamWAV` / `AudioStreamPlaybackWAV`の解放warningが出る。player停止、transport参照解放、stream解除、node解放後も再現するが、36/36 testとprocess exitは成功する。製品実行中の増加を示す証拠ではなく、headless process終了診断として残す。
- R-P1-001、R-P1-003、外部allocation未計測、標準MIDI hot-plug制約は既知制約のままである。Final Phaseを実施しない判断によって測定済みまたは解決済みにはしていない。
