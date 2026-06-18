# Typed Audio Sources Design

## Goal

Integrate a first batch of audiobook sources recovered from `/Users/jfwang/Documents/base_apk_work` into SoftSound while keeping the existing JSON rule source system intact.

The first batch is:

- `XA`: Ximalaya free album content.
- `xiaoKu`: Kuwo audiobook content.
- `liuYue`: 5weiting / 6yueting content.
- `xiaoLiang`: Yuetingba content.
- `xiaoQing`: Qingting content.

## Context

SoftSound currently loads source definitions from `assets/sources/*.json` into `SourceRule` and resolves search, detail, chapters, and audio URLs through `SourceParser`.

The APK-derived sources are not all expressible as selector-only JSON rules. Some use JSON APIs, some use HTML scraping, and some need signing, AES decryption, cookies, or server-assisted validation from the original FlyBird app. The first version should support complete playback only where the logic can be implemented locally from the recovered Java code.

## Approach

Add a typed adapter layer beside the existing JSON rule parser:

- `SourceParser` checks whether a `SourceRule.sourceId` has a registered typed adapter.
- If an adapter exists, `SourceParser.search`, `getBookDetail`, `getChapterList`, and `getAudioUrl` delegate to it.
- If no adapter exists, `SourceParser` keeps using the current selector and JSON-path implementation.

This keeps current sources working and avoids overloading `SourceRule` with complex scripting, decryption, and multi-step API flows.

## Source Metadata

The five new sources are still exposed as built-in `SourceRule` entries so the existing source manager UI can list, enable, and disable them.

Each typed source JSON should contain:

- A stable `sourceId` matching the adapter registry key.
- A readable `sourceName`.
- The public base host when one exists.
- Schema-complete no-op `search`, `detail`, `chapter`, and `audio` fields only to satisfy model requirements.
- A marker convention in `sourceType`, such as `typed-audio`, so the UI and future tooling can distinguish adapter-backed sources.

## Adapter Contract

Create a focused interface with these methods:

- `Future<List<Book>> search(SourceRule source, String keyword)`
- `Future<Book?> getBookDetail(SourceRule source, Book book)`
- `Future<List<Chapter>> getChapterList(SourceRule source, Book book)`
- `Future<String?> getAudioUrl(SourceRule source, Chapter chapter)`

Adapters return existing `Book` and `Chapter` models. Data needed by subsequent adapter calls should be encoded in stable fields:

- `Book.detailUrl` stores the album id, original page URL, or adapter-specific token as needed.
- `Chapter.url` stores the playable URL when already known, or the request token needed to retrieve it.
- `Chapter.audioUrl` stores a direct URL when the chapter list already provides one.

No page should import a concrete adapter. Pages keep calling `SourceParser`.

## Source Scope

### XA

`XA` maps to Ximalaya free content.

Supported in v1:

- Search albums through the recovered `XaSouSuo` flow.
- Fetch album chapters from `mobile.ximalaya.com/mobile/others/ca/album/track`.
- Use direct free chapter URLs from `playUrl64`, `playPathAacv164`, `playUrl32`, or `playPathAacv224`.
- Filter or skip paid and restricted tracks.

Out of scope in v1:

- `TsService().neiRong()` server validation.
- The incomplete `neiRongWp123` path.
- Paid or geo-restricted playback.

### xiaoKu

`xiaoKu` maps to Kuwo audiobook content.

Supported in v1:

- Search albums with `search.kuwo.cn` and fall back to `tingshu.kuwo.cn` when needed.
- Fetch album tracks from the Kuwo album info endpoint.
- Retrieve playable URLs using the recovered request flow where no external FlyBird server dependency is required.

Out of scope in v1:

- Category browsing.
- Paid or copyright-blocked content.

### liuYue

`liuYue` maps to 5weiting / 6yueting content.

Supported in v1:

- Search via the `web/index/search` JSON endpoint.
- Fetch chapter lists from the mobile list page.
- Resolve audio URLs through the recovered `video_new` endpoint when the required `time` and `sign` flow can be reproduced locally.

Out of scope in v1:

- Any path that requires FlyBird `TsService` to mint a signature and cannot be recreated locally.
- Site-specific URL rewrite edge cases not covered by fixtures.

### xiaoLiang

`xiaoLiang` maps to Yuetingba content.

Supported in v1:

- Search via `www.yuetingba.cn/Search`.
- Fetch chapter lists from the album detail page.
- Resolve audio URLs from `docs-listen/{trackId}/ting-with-efi` by porting the recovered AES/CBC decryption.

Out of scope in v1:

- Anti-rate-limit retries beyond a small bounded retry policy.
- Paid or unavailable content.

### xiaoQing

`xiaoQing` maps to Qingting content.

Supported in v1:

- Search via `webapi.qtfm.cn/api/mobile/search/keyword`.
- Fetch channel programs through `webapi.qtfm.cn/api/mobile/channels/{id}` and `/programs`.
- Only list and play free programs.

Out of scope in v1:

- Paid channel playback.
- Category browsing.
- Uploading unavailable works to any remote backend.

## Error Handling

Adapters should fail soft:

- Search failures return an empty result list and log the source-specific error.
- Detail and chapter failures return `null` or an empty chapter list.
- Audio URL failures return `null`, allowing the existing player error path to show `无法获取音频地址`.
- Paid, restricted, missing, or server-assisted-only content should be represented as skipped results or chapters rather than crashing.

Error messages should be source-specific in logs, but user-facing messages should stay concise.

## Testing

Use adapter-level tests before production code changes.

Test fixtures should cover:

- Search response parsing for each source.
- Chapter list parsing for each source.
- Audio URL extraction or decryption for each source where locally possible.
- Paid/restricted filtering for `XA` and `xiaoQing`.
- Registry fallback: typed sources route to adapters and existing JSON sources continue to use the current parser path.

Network tests should not be required for normal CI. Live endpoint checks can be separate manual smoke tests because these upstream sites may change.

## Migration Steps

1. Add the typed adapter interface and registry.
2. Add fixture-driven tests for routing and for each selected source.
3. Implement one adapter at a time, starting with the lowest-risk source.
4. Add five built-in typed source JSON files under `assets/sources/`.
5. Update `SourcesNotifier` to load these files and remove the missing `ting56.json` reference.
6. Run static analysis and targeted tests once Flutter SDK is available.

## Acceptance Criteria

- Existing JSON sources still load and parse through the current code path.
- The five typed sources appear in source management and can be enabled or disabled.
- Search returns normalized `Book` results for each typed source using fixtures.
- Book detail loads chapters for each typed source using fixtures.
- A free chapter can resolve to a direct audio URL for each typed source where local logic is available.
- Paid or unsupported content is skipped or fails gracefully without crashing.
