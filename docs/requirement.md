# PanBeat 要件定義書

## 1. 概要

### 1.1 プロジェクト名

**PanBeat**

### 1.2 プロジェクト概要

**PanBeat** は、電子ハンドパン **Roland Mood Pan** をゲームコントローラーとして使用するリズムゲームである。

Mood Panの円形のTone Field配置と中央のDingをそのままゲームUIへマッピングし、画面上のノーツを見ながら実際のMood Panを叩いてプレイする。

一般的なレーン型リズムゲームではなく、**ハンドパンそのものの物理配置と奏法を活用した放射状のリズムゲーム**とする。

### 1.3 コンセプト

> **Play the beat. Learn the pan.**

ゲームとして楽しみながら、実際のハンドパン演奏につながる体験を提供する。

ゲーム画面と実際のMood PanのTone Field配置を一致させることで、ゲームをプレイする行為そのものが、Tone Fieldの位置、リズム、フレーズ、奏法を身体的に覚える練習になることを目指す。

### 1.4 設計上の主要原則

PanBeatでは以下を主要原則とする。

- 実際の楽器とゲーム画面の空間配置を一致させる
- すべてのノーツは共通のSpawn Ringから発生する
- Tone FieldノーツはSpawn Ringから対象Tone Fieldへ放射する
- DingノーツはSpawn Ringから中央へ収束する
- SlapノーツはSpawn Ringから外周へリング状に拡大する
- Tone FieldとSlapは共通のOuter Hit Radiusで判定する
- ノーツの「方向」と「形状」によって奏法を表現する
- 譜面が各ノートへ明示する`hand: right / left`を唯一の左右手情報とし、右手はシアン、左手はマゼンタでToneノートとDing / Slapリングを色分けする。左右手を実行時に位置や順番から推測しない
- MusicXMLを標準形式とし、NotePan schema 6/8も直接インポート可能にする
- 楽譜、楽器構成、ゲーム固有情報を分離する
- ゲームを上達することが実際の演奏習得につながる設計とする

---

# 2. 対象デバイス

## 2.1 楽器

Roland Mood Panを主対象とする。

初期実装でゲーム入力として対応する基本音色はHandpanとする。
GamelanはMIDI調査用の比較データとして利用できるが、PanBeatの基本音色や
必須対応profileには含めない。

PanBeatへの入力にはMIDIを利用する。

初期実装ではUSB MIDIによる接続を優先する。

将来的にはBluetooth MIDIへの対応も検討する。

## 2.2 入力

基本的なゲーム入力として以下を利用する。

- 各Tone FieldのMIDI Note On
- DingのMIDI Note On
- Slapに対応するMIDI入力
- MIDI Velocity

実機検証により、SlapはMIDI Noteとして取得可能であることを確認済みとする。具体的なNote Number、MIDI Channel、Velocity特性、およびTone/Style設定による差は、実装時にInstrument Profile用の実機データとして採取する。

将来的には以下もゲーム要素として利用できるよう設計を拡張可能とする。

- Pressure
- Aftertouch
- Control Change
- 同時入力
- 長押し
- Roll
- Mute
- Ghost Note

---

# 3. 基本ゲームシステム

## 3.1 基本ルール

音楽に合わせて画面上にノーツを表示する。

プレイヤーはノーツが対応する判定位置へ到達したタイミングで、実際のMood Panを指定された奏法で叩く。

基本的な入力対象は以下とする。

- Tone Field
- Ding
- Slap

入力タイミングと譜面上のノート時刻との差によって判定を行う。

ノーツのスクロール速度は曲ごとに調節できるものとする。速度変更は画面へ出現してから判定位置へ到達するまでの表示時間だけを変更し、譜面時刻、判定窓、音声、transportには影響させない。高密度の譜面では高速設定により画面内の同時表示数を減らせるものとする。

基本判定は以下とする。

- Perfect
- Great
- Good
- Miss

具体的な判定時間幅は実装・プレイテスト時に調整する。

---

# 4. 画面レイアウト

## 4.1 基本レイアウト

ゲーム画面にはMood Panを上から見た配置を再現する。

中央にDingを配置し、その周囲に実際のMood Panと対応したTone Fieldを配置する。

Tone Fieldの中心が並ぶ円周を **Outer Hit Radius** と定義する。

```text id="tx8w70"
              Outer Hit Radius

                   ◉
             ◉           ◉

         ◉                   ◉

                    ◎
                   Ding

         ◉                   ◉

             ◉           ◉
```

画面上のTone Field位置と実際の楽器上の位置を可能な限り一致させる。

---

# 5. Spawn Ring

## 5.1 概要

DingとOuter Hit Radiusの間に、ノーツが発生する仮想的な円周 **Spawn Ring** を配置する。

```text id="upax6n"
          Outer Hit Radius
                 ↑
                 │
          ─ Spawn Ring ─
                 │
                 ↓
                Ding
```

Spawn RingをPanBeatにおける**ノーツの共通起点**とする。

すべての基本ノーツは原則としてSpawn Ringから出現する。

## 5.2 表示

Spawn Ringは常時明瞭に表示する必要はない。

通常時は、

- 非表示
- 非常に低い透明度
- 微弱な発光

のいずれかとする。

ノーツ発生時に必要に応じて一時的な発光・Pulseを行う。

---

# 6. Outer Hit Radius

## 6.1 定義

Tone Fieldが配置されている円周を **Outer Hit Radius** と定義する。

Outer Hit Radiusは、

- Tone Field
- Slap

に共通する外側のHIT位置として使用する。

Slap専用の追加判定リングは設けない。

## 6.2 目的

Tone FieldとSlapのHIT半径を共通化することで、

- 判定位置を単純化する
- 視線移動を減らす
- 同時刻ノーツのタイミングを比較しやすくする
- 画面上の判定ラインを増やさない

ことを目的とする。

---

# 7. Tone Fieldノーツ

## 7.1 移動

Tone Fieldノーツは、

**Spawn Ring → 対象Tone Field**

へ放射状に移動する。

```text id="f7vstq"
             ◉ Tone Field
             ↑
             ○
             ↑
        Spawn Ring
```

ノーツが対象Tone Fieldへ到達した瞬間をジャストタイミングとする。

## 7.2 形状

Tone Fieldノーツは**局所的な円またはリング**として表示する。

移動方向そのものが対象Tone Fieldを示す。

## 7.3 HIT

HIT位置は対象Tone Fieldの中心が存在するOuter Hit Radius上とする。

ノーツリングとTone Fieldの判定表示が一致する瞬間を視覚的なジャストタイミングとする。

---

# 8. Dingノーツ

## 8.1 移動

DingノーツはSpawn Ringに**360°のリング**として出現する。

リングがDingを中心として内側へ収束する。

```text id="uipxmr"
       Spawn Ring
       ╭───────╮
       │   ◎   │
       ╰───────╯
            ↓
         (  ◎  )
            ↓
          ( ◎ )
            ↓
            ◎
           HIT
```

## 8.2 HIT

リングがDingの判定リングと一致した瞬間をジャストタイミングとする。

## 8.3 視覚的意味

**全周リング + inward motion**

をDing固有の視覚表現とする。

---

# 9. Slapノーツ

## 9.1 基本コンセプト

Slapは特定の音程を持つTone Fieldノーツとは異なる奏法として扱う。

Slapノーツは、Spawn Ringから**360°のリングが外側へ拡大する表現**とする。

## 9.2 移動

SlapノーツはSpawn Ring上にリングとして出現し、Outer Hit Radiusへ向かって拡大する。

```text id="o0bvms"
          Outer Hit Radius
        ╭───────────────╮
        │               │
        │   ╭───────╮   │
        │   │ Spawn │   │
        │   │ Ring  │   │
        │   ╰───────╯   │
        │       ◎       │
        ╰───────────────╯

                 ↑
              expand
```

時間の経過とともに、

```text id="wt7jei"
Spawn
  ↓

   ( ○ )

     ↓

  (     ○     )

     ↓

────────────────
Outer Hit Radius
      HIT
```

のように拡大する。

## 9.3 HIT位置

Slapノーツのリングが**Outer Hit Radiusと一致した瞬間**をジャストタイミングとする。

Slap専用のHit Ringは追加しない。

Tone FieldとSlapは同一の外側HIT半径を共有する。

## 9.4 視覚的意味

**全周リング + outward motion**

をSlap固有の視覚表現とする。

---

# 10. ノーツの視覚文法

PanBeatでは、ノーツの**形状 × 移動方向**によって奏法を表現する。

| 奏法 | 形状 | 移動方向 | HIT位置 |
|---|---|---|---|
| Tone Field | 局所リング | Outward | 対象Tone Field / Outer Hit Radius |
| Slap | 全周リング | Outward | Outer Hit Radius |
| Ding | 全周リング | Inward | 中央Ding |

このため、

```text id="glal94"
Directional + Outward
        =
    Tone Field


Omnidirectional + Outward
        =
       Slap


Omnidirectional + Inward
        =
       Ding
```

という視覚文法が成立する。

色だけに依存せず、**ノーツの形状と運動そのものから奏法を判断できること**を重要なUX原則とする。

---

# 11. PanBeatの空間モデル

PanBeatのゲームフィールドは、大きく3つの同心円構造として扱う。

```text id="w42umk"
          OUTER HIT RADIUS
       ╭─────────────────╮
       │   Tone / Slap   │
       │                 │
       │   SPAWN RING    │
       │     ╭─────╮     │
       │     │  ◎  │     │
       │     ╰─────╯     │
       │       Ding      │
       ╰─────────────────╯
```

### Outer Hit Radius

Tone FieldおよびSlapのHIT位置。

### Spawn Ring

すべての基本ノーツの発生位置。

### Ding

中央のHIT位置。

この3層構造をPanBeatのゲームフィールドにおける基本座標系とする。

---

# 12. HIT演出

## 12.1 Tone Field

対象Tone Fieldを中心として局所的なRippleを発生させる。

## 12.2 Ding

中央から比較的大きなRippleを発生させる。

## 12.3 Slap

Outer Hit Radiusへの到達時に、外周全体へ短時間のPulseまたはRippleを発生させる。

Slapは打撃的な奏法であるため、Tone FieldやDingより短く明確な視覚フィードバックを検討する。

---

# 13. 複数ノーツ

Tone、Ding、Slapは同一画面上に同時に存在可能とする。

形状と移動方向によって識別する。

```text id="c04ebc"
           ◉
           ↑
           ○            ← Tone

      (         )       ← Slap
           ↑

       Spawn Ring

           ↓
        (  ◎  )         ← Ding
```

複数種類のノーツが混在しても、共通のSpawn Ringを起点とすることで視覚的な秩序を維持する。

---

# 14. 判定システム

## 14.1 タイミング判定

```text id="01ly7r"
delta = actual_input_time - expected_note_time
```

`abs(delta)` に応じて、

- Perfect
- Great
- Good
- Miss

を決定する。

## 14.2 入力種別判定

タイミングに加えて、期待された奏法と実際のMIDI入力が一致することを確認する。

```text id="xjgdlt"
correct input type
+
correct target
+
correct timing
```

Tone Fieldでは対象Pitch/Tone Fieldも判定する。

SlapおよびDingでは対応する入力種別を判定する。

---

# 15. MIDIレイテンシー補正

以下を調整可能とする。

- Input Offset
- Audio Offset

将来的には自動キャリブレーションも検討する。

---

# 16. Velocity

MVPではVelocityを基本判定条件には含めない。

将来的には、

- Accent
- Ghost Note
- Dynamics Challenge

などへ利用する。

---

# 17. 楽譜・譜面アーキテクチャ

MusicXMLをPanBeatの標準的な楽譜インポート形式とし、NotePan schema 6/8の非圧縮`.pan` tablatureも直接インポートできるようにする。

```text id="htk5nc"
MusicXML
    ↓
MusicXML Parser
    ↓
Musical Events
    ↓
Instrument Profile
    ↓
Game Chart
    ↓
PanBeat Game Engine
```

MusicXMLをゲーム中に直接処理するのではなく、ロード時にGame Chartへ変換する。

NotePanもゲーム中に直接処理せず、ロード時に同じMusical EventsとGame Chartへ正規化する。

---

# 18. MusicXMLインポート

MusicXMLから最低限以下を解析する。

- Pitch
- Note onset
- Duration
- Rest
- Tempo
- Time Signature
- Measure
- Tie

MuseScore等から、

```text id="llrxlo"
MuseScore
    ↓
MusicXML
    ↓
PanBeat
    ↓
Game Chart
    ↓
PLAY
```

というワークフローを可能にする。

---

# 19. Instrument Profile

MusicXML上のPitchと物理的な入力を分離する。

```text id="ajly9m"
Musical Event
      ↓
Instrument Profile
      ↓
Physical Input
```

Instrument Profileでは、

- Ding
- 各Tone Field
- Slap

に対応するMIDI入力を定義可能とする。

これにより異なるMood Pan設定や将来的な他の電子ハンドパンへの対応を可能にする。

---

# 20. Game Chart

Game ChartはMusicXML解析結果をゲーム用に正規化した内部形式とする。

Tone Field例：

```json id="0gdqzk"
{
  "time": 12.5,
  "type": "tone",
  "target": "tone_3",
  "pitch": "A4",
  "duration": 0.25
}
```

Ding例：

```json id="twb3ku"
{
  "time": 14.0,
  "type": "ding",
  "target": "ding",
  "pitch": "D3",
  "duration": 0.5
}
```

Slap例：

```json id="o37f44"
{
  "time": 14.5,
  "type": "slap",
  "target": "outer_ring"
}
```

Game Engineは `type` と `target` から、

- ノーツ形状
- Spawn位置
- 移動方向
- HIT位置
- アニメーション
- MIDI判定方法

を決定する。

---

# 21. MusicXMLとゲーム固有情報の分離

曲データは概念的に以下とする。

```text id="fyv4rm"
song/
├── score.musicxml
├── chart.json
└── audio.mp3               # 任意の伴奏音源
```

MusicXMLは音楽的な原譜、`chart.json` はPanBeat固有情報、`audio.mp3` は任意の伴奏音源を保持する。Mood Pan本体の発音だけで演奏する曲はaudioなしでimport・再生でき、その場合は譜面の時間を再生時間とする。

MusicXMLでSlapをどのように表現・識別するかについては、MusicXMLのパーカッション記譜またはPanBeat固有のメタデータとの組み合わせを含め、実装設計時に決定する。

ハンドパン譜が実音より1オクターブ高く記譜されている場合、import時に明示的なoctave-down mappingを選択できる。自動推測は通常記譜との音域重複で誤mappingを起こすため行わず、MusicXMLの原音高は保持したままtarget解決時だけ12 semitone下げる。

NotePan由来の`<unpitched>`は、NotePan lyricのprimary labelを使用する。`g`（Ghost）はMood Panで再現できないため時刻だけ保持してRuntime Noteを生成せず、`S`と`T`はSlapへ変換する。`T+1`や`S+6`の`+`以降はMusicXMLの直後の`<chord/>` pitched noteとして個別にimport・判定する。

NotePan `.pan` schema 6およびschema 8の直接importでは、単一trackの非圧縮tablatureだけを対象とする。埋め込みの実音pitchをInstrument Profileへ解決し、`S`と`T`はSlap、`d`、`P`、`F`はDing、`g`は時刻のみとして扱う。tempo rampは開始BPMから終了BPMまで96 TPQのtick単位で線形展開し、決定的なtempo mapへ変換する。bundle、圧縮stream、未対応schema、複数track、不完全・重複・譜面外のtempo rampは推測または黙った欠落を行わず明示的に拒否する。ゲームに表現先がない装飾は基礎attackへ縮退し、再生可能なwarningとしてpackageに保持する。

練習時は曲ごとに50〜100%のテンポを選択できる。伴奏音源の音程は原音を維持し、audio-backed transport、audioなしのclock、ノーツ表示、MIDI判定、進捗、完了時刻は同じ倍率の楽曲時刻を使用する。これはノーツの見た目だけを変える速度設定とは分離する。

Mood Panが未接続でも、MIDIエラーとview-only状態を演奏画面へ明示したうえで、音源、楽曲時刻、ノーツ表示を開始できる。未接続中はMIDI判定入力を利用できないが、譜面のノート配置確認を妨げない。

譜面が想定するハンドパンのスケール名は音符列から推測しない。MusicXMLではsource checksumに結び付いたPanBeat overlayの任意メタデータ`handpan_scale_name`で明示し、NotePanでは`.pan`に格納されたscale名を使用する。インポート後は曲packageのメタデータとして保持し、曲選択画面の一覧と詳細に表示する。未指定の既存曲は有効なまま`Not specified`と表示する。

---

# 22. MusicXML対応範囲

## MVP

- 単一パート
- 単音および和音（同時ノートを個別判定）
- 基本的な音価
- 休符
- 拍子
- テンポ
- タイ
- 基本的なテンポ変更

## 将来

- Tuplet
- Grace Note
- Repeat
- Volta
- D.C. / D.S.
- Dynamics
- Articulation
- 複数パート
- Slap等の奏法情報

---

# 23. ゲームモード

## Song Mode

通常のリズムゲームモード。

## Practice Mode

- BPM変更
- 区間ループ
- 苦手フレーズ反復
- メトロノーム
- 左右の手のガイド

などを将来的に提供する。

## Free Play

譜面なしでMood Panを演奏し、Tone、Ding、Slapに応じた異なるビジュアルフィードバックを表示する。

---

# 24. スコア

以下を基本評価対象とする。

- Timing Accuracy
- Correct Note
- Correct Technique
- Combo

終了時には、

- Score
- Accuracy
- Max Combo
- Perfect
- Great
- Good
- Miss

を表示する。

---

# 25. ビジュアルデザイン

デザインキーワード：

- Minimal
- Ambient
- Circular
- Resonant
- Calm
- Futuristic

主な視覚モチーフ：

- Circle
- Ring
- Ripple
- Pulse
- Glow

色だけで情報を伝えるのではなく、**形状・方向・動きによる情報表現**を優先する。

---

# 26. MVP要件

## MIDI

- Mood Pan USB MIDI入力
- Tone Field入力
- Ding入力
- Slap入力
- MIDI Note On等のイベント処理

## MusicXML

- MusicXML読み込み
- Pitch
- Note/Rest
- Tempo
- Time Signature
- Tie
- 基本Tempo Change

## Gameplay

- MusicXML → Game Chart
- 音源再生
- Mood Pan円形UI
- Spawn Ring
- Outer Hit Radius
- Tone Field放射ノーツ
- Ding収束ノーツ
- Slap拡大リングノーツ
- Perfect / Great / Good / Miss
- Combo
- Score
- Input/Audio Offset

## MVP完成条件

> **MusicXMLをPanBeatへ読み込み、Tone、Ding、Slapを含む譜面を、放射・収束・拡大という視覚表現を見ながら実際のMood Panで演奏できること。**

---

# 27. 将来的な方向性

PanBeatは、ゲームとして楽しみながら実際のハンドパン演奏を習得するプラットフォームを目指す。

```text id="qpe5o9"
MusicXML
    ↓
PanBeat
    ↓
位置を覚える
    ↓
リズムを覚える
    ↓
奏法を覚える
    ↓
フレーズを覚える
    ↓
画面への依存を減らす
    ↓
実際のハンドパン演奏
```

最終的な理想は、

> **PanBeatでクリアした曲を、そのまま実際のハンドパンで演奏できる**

状態である。

---

# 28. PanBeatのコアデザイン

PanBeatでは**Spawn Ringをノーツの時間的・空間的起点**とする。

そこからの「方向」と「形状」によって奏法を表現する。

```text id="zotq1a"
                   OUTER HIT RADIUS
                  Tone / Slap HIT
                         ↑
                         │
              ───── SPAWN RING ─────
                         │
                         ↓
                        DING
```

### Tone

**Directional + Outward**

Spawn Ringから特定のTone Fieldへ放射する。

### Slap

**Omnidirectional + Outward**

Spawn Ringから全周リングとしてOuter Hit Radiusへ拡大する。

### Ding

**Omnidirectional + Inward**

Spawn Ringから全周リングとして中央へ収束する。

この**「形状 × 方向」**による視覚文法を、PanBeat固有のゲームプレイおよびビジュアルアイデンティティの中心とする。
