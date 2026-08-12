# P113 Mood Pan実機受け入れ手順

## 対象と前提

- 対象buildはP112で連続2回合格したmacOS universal release buildである。
- Mood Pan MN-10をUSB接続し、本体を`Handpan / Minor`に設定する。
- 操作ノブとプレイヤーがある側を画面下とする。外周は8音で、画面上側は左上が8、右上が7、中央は番号を付けないDingである。
- Tone / Ding / Slap以外のTone/Style、BLE、Pressure、Muteはこの受け入れでは確認しない。

各sessionは約36秒である。ノーツが対象へ到達するタイミングで、Toneは表示番号の外周Tone Field、Dingは中央、Slapは外縁を打つ。終了後に`COMPLETE`、score、accuracy、max combo、各判定数を確認してからウィンドウを閉じる。

## Session 1: clean launch / baseline

1. アプリが起動していない状態でMood PanをUSB接続し、`Handpan / Minor`へ設定する。
2. 次を実行する。

   ```sh
   scripts/run-phase1-p113-session phase1-p113-device-01-baseline-retry1-20260812 baseline
   ```

3. Tone / Ding / Slapをすべて少なくとも1回入力し、期待したtarget/techniqueにfeedbackが表示されることを観察する。
4. 曲を完走し、summaryを確認してウィンドウを閉じる。

## Session 2: +30 ms Input Offset

1. Mood Panを接続したまま、次を実行する。

   ```sh
   scripts/run-phase1-p113-session phase1-p113-device-02-offset-positive-20260812 offset-positive
   ```

2. Tone / Ding / Slapをすべて少なくとも1回入力し、曲を完走する。
3. このrunではInput Offsetが`+0.030 s`である。自動検査は、全Judgement Recordが`actual + 30,000 - expected - audio offset`の式を一度だけ適用していることを確認する。

## Session 3: pause/resume / disconnect/reconnect

1. 次を実行する。

   ```sh
   scripts/run-phase1-p113-session phase1-p113-device-03-pause-reconnect-20260812 pause-reconnect
   ```

2. 再生中にSpaceを押してpauseし、音とノーツが止まることを確認する。pause中に1回打撃し、判定feedbackやcomboへの入力として扱われないことを確認する。
3. pause中にUSBを外し、3秒待って再接続する。3秒待ってからSpaceでresumeする。
4. 復旧しない場合はウィンドウを閉じる。失敗runは消さず、新しいRUN_IDで再起動し、再openで復旧した事実を記録する。自動復旧はPhase 1必須ではない。
5. Tone / Ding / Slapをすべて少なくとも1回入力し、完走する。二重再生、note二重spawn、pause中入力による不整合がないことを観察する。

## 証拠と報告

各runは`artifacts/raw/<RUN_ID>/`へ、次を別々に保存する。

- `judgement-records.json`: 判定record
- `summary.json`: 終了summary
- `diagnostics.json`: MIDI raw/normalized入力、port lifecycle、session lifecycle
- `software-manifest.json`: build/profile checksumと自動検査結果
- `operator-observations.json`: 利用者の目視・聴感所見のみ

物理打撃から音・画面までの遅延は主観所見として記録し、software timestampからend-to-end latencyを算出しない。3 run後、Codexへ各sessionの目視・聴感結果を伝える。Codexが`operator-observations.json`へ反映し、P113全体の完了条件を監査する。
