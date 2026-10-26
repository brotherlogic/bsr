# BSR (Beer Selector & Recommender)

BSR is a mobile application and Go gRPC / Connect-RPC backend for choosing what beer to drink at a bar, pub, or brewery by cross-referencing Untappd venue activity against personal Untappd history.

See [INTENT.md](file:///workspaces/bsr/INTENT.md) for the complete architecture, data model, and implementation roadmap.

## Development Workflow

We follow a strict Test-Driven Development (TDD) process. Always write a failing test before implementing a new feature or bug fix.
- Mock external services to support unit tests and avoid side effects.

### Feature Completion

Refer to [ISSUES.md](file:///workspaces/bsr/ISSUES.md) for details on the issue processing workflow lifecycle and label transitions.
Once you've finished a change or feature, run the `finish.md` workflow.
