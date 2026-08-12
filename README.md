# PanBeat

PanBeatは、Roland Mood PanをMIDIコントローラーとして演奏を学ぶための
リズムゲームです。

## Documentation

- [プロダクト要件](docs/requirement.md)
- [技術選定・アーキテクチャ](docs/architecture.md)
- [Phase 1ストーリーバックログ](docs/phase1-stories.md)
- [Phase 1 acceptance manifest](docs/phase1-acceptance.json)
- [Phase 1 completion report](docs/phase1-completion-report.md)
- [Final Phase: Release Hardening](docs/final-phase-stories.md)

Phase 1のProduct Vertical Sliceは自動試験とMood Pan実機3 sessionで完了しています。長時間driftとMIDI dispatchの2つの性能目標は、機能開発を止めない`deferred-release-gate-blocker`としてFinal Release Hardening Phaseへ送っています。これはMVP完成やrelease許可を意味しません。
