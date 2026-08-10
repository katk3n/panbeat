# PanBeat Phase 0 エンジン評価記録

## 1. 文書情報

この文書は、Unity 6 LTSとGodot 4.6のPhase 0比較について、固定した評価契約、測定条件、証拠、判定、採点、変更履歴、最終選定を記録する。評価基準の正本は[`architecture.md` 4.4](./architecture.md#44-unity--godot最終選定プロトコル)とする。

未測定の欄は`TBD`、判定前の欄は`Pending`のままでよい。空欄を合格やゼロとして解釈してはならない。この雛形は結論未記入の状態でも有効であり、測定値や採用エンジンを推測で補わない。

| 項目 | 値 |
|---|---|
| 評価契約version | 1.1（EC-001適用） |
| 評価対象 | Unity 6 LTS / Godot 4.6 |
| 正式対象OS | macOS |
| 評価責任者 | User |
| 契約固定日 | 2026-08-09 |
| 評価実施期間 | 2026-08-09〜2026-08-10 |
| 最終承認者 | User |
| 最終承認日 | 2026-08-10 |
| 文書状態 | Complete / Godot selected |

Windowsは未評価の将来移植対象であり、Phase 0の減点または欠測として扱わない。

## 2. 固定した評価規則

### 2.1 判定順序

1. 各エンジンについて、6つのhard gateを`Pass`、`Fail`、`Not Measured`のいずれかで判定する。
2. 1項目でも`Fail`があるエンジンは採用対象外とする。`Not Measured`は自動的に`Pass`とせず、6.3のrisk acceptanceが承認されない限り採用判断を保留する。
3. hard gateを通過した候補だけを、7つの評価項目について1点から5点で採点し、重み付き総合点を計算する。
4. 総合点が同点または差が5.00ポイント未満なら、「MIDI入力・audio同期の精度/安定性」の得点が高い方を選ぶ。それも同点なら「Codexによる自律開発性」の得点が高い方を選ぶ。
5. 両候補がhard gateを満たさない場合、原因がnative audio/MIDI制御ならJUCE、Web同時提供要件ならTauri/Web Nativeを再評価し、UnityまたはGodotを恣意的に選ばない。

この順序と閾値は[`architecture.md` 4.4](./architecture.md#44-unity--godot最終選定プロトコル)を参照する。

### 2.2 試行と統計

- 各定量試験はwarm-up後に、エンジンごとに同一条件で最低3回の有効な試行を行う。実機比較は各エンジン最低3 sessionとする。
- `試行`は1回のテスト実行、`sample`は試行内で記録した個々の観測値と定義する。各集計に予定試行数、実施試行数、有効試行数、失敗試行数、欠測試行数、raw sample数を記録する。
- 失敗、timeout、crash、欠測の試行は分布計算から除外してよいが、件数と理由を必ず併記し、成功試行だけに見える形で隠さない。自動retryで置き換えない。
- p50、p95、p99は、対象sampleを昇順に並べたnearest-rank法（順位`ceil(p / 100 * n)`、1始まり）で求める。最大値と算術平均も保存する。sample数が1以上なら同じ定義で全percentileを出し、sample数が0なら数値を出さず`N/A`とする。
- 複数試行のsampleをまとめた分布を主集計とする場合も、試行ごとの集計をraw evidenceに残す。分布を比較する指標は、特記がなければ符号付き差ではなく絶対値を用いる。
- 単位は時間を`ms`、長時間の再生時間を`s`または`min`、frame rateを`Hz`または`fps`、frame timeを`ms`、割合を`%`、件数を整数`count`、byte量を`B`、build時間を`s`で記録する。生データが`us`、sample、tick等の場合は元の値とclock domainを保持し、表示用`ms`への換算式をmanifestまたはsummaryに記録する。
- すべての日時はISO 8601形式でtimezone offsetを含める。時間測定は使用したclock domain（例: monotonic、audio DSP、engine event）を明記する。

### 2.3 欠測値と無効値

| 表記 | 意味 | 採点・判定での扱い |
|---|---|---|
| `TBD` | まだ記入していない | 0や合格とみなさない |
| `Pending` | 証拠収集中または判定前 | 結論を出さない |
| `Not Measured` | 試験を実施できず測定値がない | hard gateは未通過。採用には6.3のrisk acceptanceが必要 |
| `N/A` | 定義上適用されない | 理由と根拠を記録し、0点として計算しない |
| `Failed Run` | 実行したが結果を取得できなかった | 分布から除外しても件数・理由・raw logを残す |
| `Invalid Run` | 事前固定条件から逸脱した | 分布から除外し、逸脱内容と判定者を残す |

欠測値の補間、他エンジンの値による代用、検出限界値への置換は行わない。weighted scoreに未採点項目がある場合、総合点は計算せず`Pending`とする。

### 2.4 証拠と再現性

- 同じPC、Mood Pan、USB port/cable、audio output、sample rate、buffer、譜面、音源、画面解像度を用いる。差がある場合は3章と変更履歴へ記録する。
- debug/editor実行とrelease/export buildを区別し、最終比較はrelease/export buildで行う。
- offset補正は比較中`0 ms`とする。
- 記録済みまたはvirtual MIDI replayでdispatch jitterを比較する。実機打撃の人間由来のばらつきをengine latencyとして採点しない。
- raw eventはJSON Lines、集計はCSVまたはMarkdown、画面結果はPNGまたは動画として保存する。raw evidenceは上書きせず、各表からrepository相対pathで参照する。
- 真の物理打撃から表示または音声までのlatencyを評価する場合は、高速度camera、loopback audio、または外部計測器と読み取り方法を記録する。

## 3. 共通測定条件

### 3.1 Hardware / OS

| 項目 | 共通値 | Unityでの差分 | Godotでの差分 |
|---|---|---|---|
| 計測machine識別子 | `kk2024-m4-mbp.local` | なし | なし |
| Mac model / model identifier | Apple Silicon Mac（model identifierは記録せず） | なし | なし |
| CPU / architecture | Apple M4 / arm64 / 10 logical CPU | なし | なし |
| RAM | 25,769,803,776 B | なし | なし |
| macOS version / build | 26.5.2 / 25F84 | なし | なし |
| display / 解像度 / refresh rate | captureは各768×768、実display refreshは未記録 | なし | なし |
| Mood Pan機体識別子 / firmware | Roland MN-10 / firmware未記録 | なし | なし |
| USB port / hub / cable | 同じ接続を全実機sessionで使用、型番未記録 | なし | なし |
| audio output device / driver | 同じmacOS既定出力 / 44.1 kHz | Unity audio output | CoreAudio |
| background load / power設定 | 通常稼働、追加負荷なし（power設定未記録） | なし | なし |

### 3.2 Engine / build / toolchain

| 項目 | Unity | Godot |
|---|---|---|
| engine version（完全なversion/build） | 6000.3.21f1 | 4.6.stable.official.89cea1439 |
| executable absolute path | `/Applications/Unity/Hub/Editor/6000.3.21f1/Unity.app` | repository-local `.tools/godot/4.6/Godot.app` |
| language / runtime version | C# 9 / Unity Mono | typed GDScript / Godot 4.6 |
| renderer | Built-in 2D rasterized PoC | Compatibility Renderer |
| build type | Release player | Release export |
| target architecture | macOS Universal | macOS Universal |
| package / plugin / dependency lock | `Packages/packages-lock.json` + native CoreMIDI dylib source | engine標準APIのみ |
| source revision | uncommitted working tree（各manifestに明示） | 同左 |
| clean build command | `scripts/run-unity-u06` | `scripts/run-godot-g06` |
| test command | `scripts/check-unity --mode test` | `scripts/check-godot --mode test` |
| build artifact metadata | `artifacts/raw/unity-u06/build-metadata.json` | `artifacts/raw/godot-g06/build-metadata.json` |

### 3.3 Audio / test input

| 項目 | 共通値 | Unityでの差分 | Godotでの差分 |
|---|---|---|---|
| sample rate (`Hz`) | fixture 48,000; output 44,100 | 44,100 | 44,100 |
| buffer size (`sample` / `ms`) | engine設定を記録 | 1024×4（U02） | API非公開 |
| channel / bit depth | fixture mono PCM16 | engine output設定 | engine output設定 |
| audio backend / driver | macOS既定出力 | Unity audio output | CoreAudio |
| output latency setting (`ms`) | 補正値0 | 0 | API reported 0 |
| input offset (`ms`) | 0 | 0 | 0 |
| audio offset (`ms`) | 0 | 0 | 0 |
| chart / checksum | `shared/fixtures/test-pack/chart.json` / `825e2256…` | 同一 | 同一 |
| audio asset / checksum | `click.wav` / `f12f33e9…` | 同一 | 同一 |
| MIDI replay / checksum | F04 golden input/result | 同一 | 同一 |
| Instrument Profile / checksum | `roland-mn10-handpan-minor-v1.json`（manifest参照） | 同一 | 同一 |
| warm-up手順 | E01でrelease buildを1回warm-up後に3回測定 | 実施 | 実施 |
| planned trials / sessions | 3以上 | build/replay/drift/実機 各3 | build/replay/drift/実機 各3 |

## 4. 実行台帳とraw data

各runまたはsessionを1行にする。複数artifactがある場合はmanifestを主linkとし、manifestからraw log、summary、capture、build metadataを辿れるようにする。

| Run ID | Engine | Test / build type | Start time | Status | Samples | Manifest / raw data link | Summary / capture link | Notes |
|---|---|---|---|---|---:|---|---|---|
| U06 | Unity | self-evaluation release bundle | 2026-08-10 | Valid | 17 tests | `artifacts/raw/unity-u06/run-manifest.json` | hard-gate summary / capture | clean test/build |
| G06 | Godot | self-evaluation release bundle | 2026-08-10 | Valid | 45 checks | `artifacts/raw/godot-g06/run-manifest.json` | hard-gate summary / capture | 初回clean test失敗も保持 |
| E01 | Common | automated comparison | 2026-08-10 | Valid | replay各42 | `artifacts/raw/e01-comparison/run-manifest.json` | `comparison.json` / side-by-side capture | build/replay各3 |
| E02 | Common | release real-device comparison | 2026-08-10 | Valid | Note On各129 | `artifacts/raw/e02-real-device/run-manifest.json` | `summary.json` | 実機各3 session |
| E03-drift | Common | release audio drift EC-001 | 2026-08-10 | Valid | Unity 1794 / Godot 1797 | `artifacts/raw/e03-release-drift/run-manifest.json` | `summary.json` | 1分×3 |

### 4.1 試行集計

| Engine | Test | Planned | Attempted | Valid | Failed | Missing | Raw samples | Unit | Mean | p50 | p95 | p99 | Max | Evidence |
|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|
| Unity | release drift final absolute | 3 | 3 | 3 | 0 | 0 | 3 | ms | 0.006 | 0.006 | 0.006 | 0.006 | 0.006 | `artifacts/raw/e03-release-drift/summary.json` |
| Godot | release drift final absolute | 3 | 3 | 3 | 0 | 0 | 3 | ms | 1.376 | 0.495 | 3.155 | 3.155 | 3.155 | `artifacts/raw/e03-release-drift/summary.json` |
| Unity | E02 Note On | 3 | 3 | 3 | 0 | 0 | 129 | count | N/A | N/A | N/A | N/A | N/A | `artifacts/raw/e02-real-device/summary.json` |
| Godot | E02 Note On | 3 | 3 | 3 | 0 | 0 | 129 | count | N/A | N/A | N/A | N/A | N/A | `artifacts/raw/e02-real-device/summary.json` |

## 5. Hard gate

6項目の名称、合格条件、判定規則は[`architecture.md` 4.4](./architecture.md#44-unity--godot最終選定プロトコル)を変更せず適用する。`Evidence`にはraw dataまたは再計算可能なsummaryへのlinkを記載する。

| Hard gate | 合格条件 | 主要単位・集計 | Unity | Unity evidence / rationale | Godot | Godot evidence / rationale |
|---|---|---|---|---|---|---|
| Slap識別 | 他のPad Noteと安定して区別でき、取りこぼし/二重発火の原因を説明できる | drop / duplicate / unknown各`count`、総event `count`、率`%` | Pass | E02 Slap 37、unknown/duplicate/drop 0 | Pass | E02 Slap 36、unknown/duplicate 0 |
| 入力jitter | 同一USB/PC条件でcallbackまたはengine event到達jitter p95 5 ms以下を目標 | `ms`、samples、mean / p50 / p95 / p99 / max | Not Measured | packet timestampと独立dispatch timestampの組がない | Pass | G03 arrival handling p95 0.069 ms。物理latencyではない |
| Audio/visual drift | release buildで1分再生を3回行い、各run終了時のdrift絶対値5 ms以下を目標 | 経過`min`、drift絶対値`ms`、3 trials、mean / p50 / p95 / p99 / max | Pass | final max 0.006 ms、3/3 | Pass | CoreAudio final max 3.155 ms、3/3 |
| Frame independence | 60/120 Hzおよび意図的frame dropで判定結果が一致 | refresh rate `Hz`、差分`count`、checksum | Pass | U05差分0 | Pass | G05差分0 |
| Device lifecycle | 起動後接続、切断、再接続から復旧可能 | sessions / attempts / success各`count`、復旧時間`ms` | Pass | E02 3/3、切断状態も明示 | Pass | E02 3/3、入力復旧。切断状態はAPI非公開 |
| Automation | GUI操作なしでtest/buildを実行可能 | command成功/失敗`count`、GUI介入`count`、時間`s` | Pass | clean test/build、GUI 0 | Pass | clean test/build、GUI 0。初回失敗1件を保持 |

判定値は`Pass`、`Fail`、`Not Measured`のいずれかだけを使用する。目標値を閾値として判定したか、risk acceptanceを伴う未測定かをrationaleへ明記する。

## 6. Weighted score

### 6.1 採点規則

各項目を整数の1点（最低）から5点（最高）で採点する。点数にはraw evidenceへのlinkと短い根拠を必須とする。重み付き点は`score / 5 * weight`で計算し、全項目を小数点以下2桁で合計する。総合点の範囲は0.00から100.00である。未採点または根拠なしの項目が1つでもあれば総合点は`Pending`とする。

| 評価項目 | 重み | 主な証拠 | Unity score | Unity weighted | Unity evidence / rationale | Godot score | Godot weighted | Godot evidence / rationale |
|---|---:|---|---:|---:|---|---:|---:|---|
| MIDI入力・audio同期の精度/安定性 | 30% | latency分布、drift、drop/duplicate件数 | 3 | 18 | drift/実機Pass、dispatch jitter欠測 | 4 | 24 | CoreAudio drift・arrival spread・実機Pass |
| Codexによる自律開発性 | 20% | GUI介入回数、1-command成功率、text diff比率 | 3 | 12 | CLI完結だがlicense/native pluginあり | 4 | 16 | CLI/text中心、GUI 0 |
| 実装量・保守性 | 15% | PoCコード量、native plugin量、依存数 | 3 | 9 | native CoreMIDI bridgeあり | 4 | 12 | 標準MIDI、typed GDScript |
| 2D表現・性能 | 15% | fps、frame time、allocation、capture比較 | 3 | 9 | deterministic capture/pool、release frame time欠測 | 3 | 9 | deterministic capture、release frame time欠測 |
| macOS配布・再現性 | 10% | clean build、署名準備、artifact再現性 | 4 | 8 | clean 12s、warm p50 3.316s | 3 | 6 | clean 8s、warm p50 7.506s、artifact大 |
| Web派生可能性 | 5% | Web MIDI/audio制約、共有可能コード | 2 | 2 | native adapterはWeb非共有 | 3 | 3 | C#非依存、Web inputは別途必要 |
| License・長期リスク | 5% | license条件、engine更新負担 | 3 | 3 | Unity license/activation | 5 | 5 | MIT、activation不要 |
| **合計** | **100%** |  |  | **61.00（参考・hard gate欠測）** |  |  | **75.00** |  |

### 6.2 GUI介入と設定差分

GUIを開いたこと自体ではなく、人間が比較runを成功させるために行った操作を1介入として記録する。操作の連続単位、所要時間、理由、text/scriptで再現可能になったかを残す。エンジンごとのCPU負荷や設定差も隠さず記録する。

| Intervention ID | Engine | Run ID | Date/time | 操作 / 理由 | Duration (`s`) | 再現可能なtext / command | Evidence |
|---|---|---|---|---|---:|---|---|
| None | Unity / Godot | E01・E02・E03 | 2026-08-10 | 比較runを成功させるGUI操作なし | 0 | 全設定をtext/CLIで再現 | U06/G06/E01/E02 manifests |

| 設定項目 | Unity | Godot | 公平性への影響 / 理由 | 承認 |
|---|---|---|---|---|
| CPU load / 計測方法 | 通常稼働、専用負荷なし | 通常稼働、専用負荷なし | 同一machineで交互実行 | User |
| engine固有設定差 | Unity DSP/audio output | Godot CoreAudio/playback clock | 各engine公式audio-backed clockを使う必要差 | User |

### 6.3 Not Measuredのrisk acceptance

`Not Measured`のhard gateまたは`N/A`の評価項目がある場合だけ記入する。対象、未測定理由、代替証拠、残存risk、期限、承認者を明記する。承認がなければ採用判断は`Pending`のままとする。

| ID | Engine / item | 理由 | 代替証拠 | 残存risk / mitigation / deadline | 承認者 | 承認日 | Status |
|---|---|---|---|---|---|---|---|
| RA-001 | Unity / input jitter | 独立dispatch timestampを記録していない | CoreMIDI timestamp、drop 0、E02 3/3 | Unityは採用対象にせず、Phase 0でrisk acceptanceしない | User | 2026-08-10 | Rejected / Unity ineligible |

## 7. 結論

| 項目 | 結果 |
|---|---|
| Unity hard gate | Not passed（input jitterがNot Measured） |
| Godot hard gate | Pass（6/6） |
| Unity weighted score | 61.00（参考値、採用対象外） |
| Godot weighted score | 75.00 |
| tie-break適用 | 不要 |
| 推奨engine | Godot |
| 推奨language | typed GDScript |
| 固定version | 4.6.stable.official.89cea1439 |
| 主要な残存risk | 1分超のdrift、OS MIDI受信timestampなし、物理切断状態なし、release frame time欠測 |
| 選定理由 | 全hard gateを通過し、score 75.00。標準MIDI、CLI/text再現性、MIT licenseが有利 |
| 却下理由 | Unityはinput dispatch jitterがNot Measuredでhard gate未通過。native pluginとlicense負担も残る |

Godotについて全hard gate、weighted score、必要な証拠が揃ったため、Phase 0の推奨を確定する。Unityの参考scoreは未測定gateをPassへ置換しない。

## 8. 評価契約の変更管理

評価開始後にhard gate、閾値、重み、採点規則、統計方法、試行回数、測定条件を変える場合、変更前に次の台帳へ記録し、承認を得る。過去のraw dataは上書きせず、再集計の有無と両エンジンへの適用方法を記載する。変更後の文書versionを更新する。

| Change ID | 変更日 | 変更前 | 変更後 | 変更理由 | 影響範囲 / 再測定 | 申請者 | 承認者 | 承認日 |
|---|---|---|---|---|---|---|---|---|
| EC-001 | 2026-08-10 | 5分再生後のdrift絶対値5 ms以下 | release buildで1分×3回、各run終了時のdrift絶対値5 ms以下。5分以上はPhase 1 risk | Phase 0 PoCの判断時間を短縮しつつ、3試行の再現性を優先するため | Unity/Godotを同じfixture・audio outputで再測定。既存5分rawは参考値として保持 | User | User (`approve`) | 2026-08-10 |

## 9. 参照文書

- [`architecture.md` 4.4 Unity / Godot最終選定プロトコル](./architecture.md#44-unity--godot最終選定プロトコル)
- [`phase0-stories.md` F01](./phase0-stories.md#f01-評価契約を固定する)
- [`requirement.md`](./requirement.md)
