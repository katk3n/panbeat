# PanBeat repository guidance

このファイルは、PanBeatで作業するCodexが継続的に守るリポジトリ共通の指示を定義する。
現在の開発フェーズ、対象プラットフォーム、個別タスクの内容はここへ重複して記載せず、`docs/`以下の文書を正とする。

## Source of truth

- プロダクト要件は`docs/requirement.md`を参照する。
- 技術選定、アーキテクチャ、ADR、現在の未確定事項は`docs/architecture.md`を参照する。
- フェーズ別のストーリー、依存関係、受け入れ条件、Definition of Doneは、該当する`docs/phase*-stories.md`を参照する。
- 文書と実装が矛盾する場合は、黙って一方を正とせず、矛盾を報告して影響範囲を明らかにする。
- 未決定の技術候補を、ADRが確定する前に採用済みとして扱わない。

## Task workflow

- 作業開始前に、依頼に対応するフェーズとストーリーを特定し、依存ストーリーの成果物と受け入れ条件を確認する。
- ユーザーから明示的な指示がない限り、1つのCodexタスクでは1つのストーリーだけを完了する。
- 選択したストーリーの範囲外へ実装を広げない。範囲外で見つけた課題は、必要に応じて後続作業として報告する。
- 既存のユーザー変更を保持し、依頼と無関係なファイルや変更を巻き戻さない。
- 実装と同じタスク内で、該当するテスト、検証、文書更新まで行う。
- リポジトリに確立済みのコマンドやスクリプトがある場合はそれを優先し、新しい実行手順を導入した場合は再現可能な形で記録する。

## Engineering constraints

- 対象プラットフォームと対応範囲は、該当フェーズの文書に従う。将来候補を現在の対応対象として扱わない。
- Domainと共通データ契約を、ゲームエンジン、OS、GUI、ファイルシステムから可能な限り独立させる。
- エンジン間比較では、共通のschema、fixture、MIDI trace、期待結果、計測条件を使用する。一方だけに有利な仕様変更を行わない。
- 判定やノーツ位置をframe countへ依存させず、設計書で定義されたaudio-backed transportを時刻の基準とする。
- EditorやGUIでしか再現できない設定を避け、可能な限りテキスト形式の設定、固定version、CLI、scriptで再現可能にする。
- 仮実装、空のstub、常に成功するmockによってテストや受け入れ条件を通過させない。

## Verification and evidence

- 完了判定には、対象ストーリーの受け入れ条件と共通Definition of Doneを使用する。
- MIDI trace、benchmark、drift/jitter log、screenshot、run manifestなど、判断に使ったraw evidenceを同一run内で上書きせず、ローカルまたはCI artifactとして保存する。`artifacts/raw/`はGitへcommitしない。
- 計測値には、可能な範囲で実行環境、version、設定、入力fixture、実行時刻を紐付ける。
- 実行できなかった検証を、成功したものとして報告しない。未実施項目、理由、必要な次の操作を明記する。
- completion reportにはrun ID、再現command、主要結果、必要なchecksumを記録し、Git checkoutだけでraw evidenceが存在するとは仮定しない。
- 作業完了時には、変更内容、実行した検証、その結果、残る制約またはblockerを簡潔に報告する。

## Mood Pan real-device work

- Codexは実機検証に必要なtool、記録形式、手順、期待する操作を先に準備する。
- ユーザーはMood Panの接続、設定変更、打撃など物理操作を担当する。
- 実機から取得していない値を推測でInstrument Profileへ確定しない。
- 実機検証結果とrecorded MIDI replayの結果を区別し、どちらを根拠にしたか記録する。

## Plans

- 通常の1ストーリー作業に`PLANS.md`やExecPlanを必須としない。
- 複数の独立したマイルストーンを含む長時間作業では、必要に応じてExecPlanを使用する。その場合も、対象ストーリーの範囲と受け入れ条件は変更しない。
