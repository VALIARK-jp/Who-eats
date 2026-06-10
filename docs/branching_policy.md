# Branching Policy

This repository uses the following branch workflow.

## Branch Roles

- `main`
  - Protected integration branch for release-ready changes only.
  - Merge into `main` happens only when `develop` is merged by the owner.
- `develop`
  - Base branch for all day-to-day work.
  - All feature / fix branches must branch off `develop`.

## Rules

- Never merge directly into `develop`.
- All changes must go through a Pull Request.
- Do not work from `main` unless the task is specifically about release integration.
- `main` is used only when merging `develop` for release.

## Suggested Flow

1. Create a branch from `develop`.
2. Make changes on that branch.
3. Open a Pull Request targeting `develop`.
4. After review and approval, merge into `develop`.
5. When `develop` is ready for release, merge it into `main`.
