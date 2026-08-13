# PanBeat Phase 4: Score Format Expansion

## P401: NotePan schema 6/8を直接importする

**ストーリー:** NotePan利用者として、MusicXMLへ事前変換せずに単一trackの`.pan`譜面をSong Libraryへ取り込み、同じInstrument ProfileとGameplayで演奏したい。

**実施内容:** schema 6/8非圧縮tablatureの安全なbinary readerを追加し、共通Symbolic Score、Runtime Chart、atomic song packageへ接続する。埋め込みmetadataと特殊奏法を明示契約で変換し、ゲームで表現しない装飾は永続warningにする。

**受け入れ条件:** schema 6/8の通常音、Ghost、`S/T` Slap、`d/P/F` Ding、拍節、split、離散tempo、tempo ramp、metadataが決定的にimportされる。tempo rampは96 TPQのtick単位で開始BPMから終了BPMまで線形展開される。圧縮stream、未対応schema、bundle、複数track、不正binary、不完全・重複・譜面外のtempo rampは固有diagnosticで拒否される。MusicXML/MXL、overlay、既存package、Gameplay、Resultsが回帰しない。

**Definition of Done:** [`notepan-import.md`](./notepan-import.md)の契約、schema fixture、P401 test、全Godot test、macOS buildを同じrun IDで再現し、manifestとchecksumを`artifacts/raw/`へ保存する。
