# PanBeat Phase 4: Score Format Expansion

## P401: NotePan schema 6/8を直接importする

**ストーリー:** NotePan利用者として、MusicXMLへ事前変換せずに単一trackの`.pan`譜面をSong Libraryへ取り込み、同じInstrument ProfileとGameplayで演奏したい。

**実施内容:** schema 6/8非圧縮tablatureの安全なbinary readerを追加し、共通Symbolic Score、Runtime Chart、atomic song packageへ接続する。埋め込みmetadataと特殊奏法を明示契約で変換し、ゲームで表現しない装飾は永続warningにする。

**受け入れ条件:** schema 6/8の通常音、Ghost、`S/T/K` Slap、`d/P/F` Ding、拍節、split、離散tempo、tempo ramp、metadataが決定的にimportされる。`K`はschema 6 code `40`とschema 8 code `152`の両方を受け付ける。tempo rampは96 TPQのtick単位で開始BPMから終了BPMまで線形展開される。圧縮stream、未対応schema、bundle、複数track、不正binary、不完全・重複・譜面外のtempo rampは固有diagnosticで拒否される。MusicXML/MXL、overlay、既存package、Gameplay、Resultsが回帰しない。

**Definition of Done:** [`notepan-import.md`](./notepan-import.md)の契約、schema fixture、P401 test、全Godot test、macOS buildを同じrun IDで再現し、manifestとchecksumを`artifacts/raw/`へ保存する。

## P402: 曲別カスタムスケールと演奏配置を確認する

**ストーリー:** Mood Pan利用者として、D Kurd以外の曲を選んだときに必要な実音と物理配置を確認し、Mood Panを同じ配置へ設定して演奏したい。

**実施内容:** 固定の機器Profileと曲別`performance_layout`を分離する。MusicXMLでは最低音をDing、残りを昇順のToneへ割り当て、NotePanでは埋め込みDingを優先する。Song Libraryにスケール名、使用音、中央Ding＋外周8音のハンドパン図による標準ジグザグ配置と任意の自由打撃MIDI確認を表示し、Gameplayでは同じ配置からeffective profileを生成する。MIDI確認で一致した音は図上の対応パッドを強調する。譜面、音源、Overlay、音域指定はImport/Re-importモーダルへ集約し、ファイル名の長さがSong Library本体の配置へ影響しないようにする。モーダル本文は縦スクロール可能とし、長いimport診断でも全文と固定操作ボタンへ到達できるようにする。

**受け入れ条件:** MusicXMLとNotePanの最大9実音が欠落なく決定的に配置され、表示、MIDI正規化、Gameplay判定が同じlayout IDを使う。異名同音は1実音として扱い原表記を表示する。10実音以上、複数Ding、同一targetへの複数pitch、SlapとのMIDI衝突はimportを拒否する。MIDI確認は任意で、期待音と想定外音を区別し、Song Library退出時に状態を破棄する。既存packageと結果履歴は引き続き読める。

**Definition of Done:** package 1.3 schema fixture、P402 focused test、全Godot test、macOS buildを同じrun IDで再現し、manifestとchecksumを`artifacts/raw/`へ保存する。
