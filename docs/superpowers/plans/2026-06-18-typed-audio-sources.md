# Typed Audio Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a typed source adapter layer and integrate five APK-derived audiobook sources: `XA`, `xiaoKu`, `liuYue`, `xiaoLiang`, and `xiaoQing`.

**Architecture:** Keep the existing JSON `SourceRule` parser as the fallback path. Add a typed adapter registry keyed by `sourceId`; `SourceParser` delegates search, detail, chapter, and audio operations to adapters when registered.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, `html`, `json_path`, Drift models, fixture-driven tests.

---

## File Structure

- Create `lib/services/typed_sources/typed_source_adapter.dart`: adapter interface.
- Create `lib/services/typed_sources/typed_source_registry.dart`: adapter lookup and registration.
- Create `lib/services/typed_sources/source_utils.dart`: shared URL, JSON, parsing, ID helpers.
- Create `lib/services/typed_sources/xa_source_adapter.dart`: Ximalaya free content adapter.
- Create `lib/services/typed_sources/xiaoku_source_adapter.dart`: Kuwo adapter.
- Create `lib/services/typed_sources/liuyue_source_adapter.dart`: 5weiting / 6yueting adapter.
- Create `lib/services/typed_sources/xiaoliang_source_adapter.dart`: Yuetingba adapter and AES/CBC URL decrypt helper.
- Create `lib/services/typed_sources/xiaoqing_source_adapter.dart`: Qingting adapter.
- Modify `lib/services/source_parser.dart`: delegate to registry before current parser paths.
- Modify `lib/features/source_manager/source_manager_page.dart`: load the five typed sources and remove missing `ting56.json`.
- Add `assets/sources/xa.json`, `assets/sources/xiaoku.json`, `assets/sources/liuyue.json`, `assets/sources/xiaoliang.json`, `assets/sources/xiaoqing.json`.
- Add tests under `test/services/typed_sources/` using fixture strings.

## Task 1: Adapter Interface And Registry

**Files:**
- Create: `lib/services/typed_sources/typed_source_adapter.dart`
- Create: `lib/services/typed_sources/typed_source_registry.dart`
- Create: `lib/services/typed_sources/source_utils.dart`
- Modify: `lib/services/source_parser.dart`
- Test: `test/services/typed_sources/typed_source_registry_test.dart`

- [ ] **Step 1: Write the failing registry test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/data/models/source_rule.dart';
import 'package:soft_sound/services/typed_sources/typed_source_adapter.dart';
import 'package:soft_sound/services/typed_sources/typed_source_registry.dart';

class FakeAdapter implements TypedSourceAdapter {
  @override
  String get sourceId => 'fake_typed';

  @override
  Future<List<Book>> search(SourceRule source, String keyword) async => const [];

  @override
  Future<Book?> getBookDetail(SourceRule source, Book book) async => book;

  @override
  Future<List<Chapter>> getChapterList(SourceRule source, Book book) async => const [];

  @override
  Future<String?> getAudioUrl(SourceRule source, Chapter chapter) async => null;
}

void main() {
  test('registry returns adapter for matching typed source id', () {
    final registry = TypedSourceRegistry([FakeAdapter()]);

    expect(registry.adapterFor('fake_typed'), isA<FakeAdapter>());
    expect(registry.adapterFor('plain_json'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/typed_sources/typed_source_registry_test.dart`

Expected: FAIL because `TypedSourceAdapter` and `TypedSourceRegistry` do not exist.

- [ ] **Step 3: Implement interface and registry**

Create the interface and registry. Add source utils with deterministic ID helpers and safe JSON helpers.

- [ ] **Step 4: Delegate in `SourceParser`**

At the start of `search`, `getBookDetail`, `getChapterList`, and `getAudioUrl`, look up `typedSourceRegistry.adapterFor(source.sourceId)`. If present, return the adapter result. Otherwise continue the existing implementation unchanged.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/services/typed_sources/typed_source_registry_test.dart`

Expected: PASS.

## Task 2: XA Adapter

**Files:**
- Create: `lib/services/typed_sources/xa_source_adapter.dart`
- Create: `assets/sources/xa.json`
- Test: `test/services/typed_sources/xa_source_adapter_test.dart`

- [ ] **Step 1: Write failing tests**

Cover Ximalaya search parsing, chapter parsing with free direct play URLs, and paid track filtering.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/typed_sources/xa_source_adapter_test.dart`

Expected: FAIL because `XaSourceAdapter` does not exist.

- [ ] **Step 3: Implement XA search**

Use `https://m.ximalaya.com/m-revision/page/search?kw={keyword}&core=album&page=1&rows=20`. Normalize free album results into `Book`.

- [ ] **Step 4: Implement XA chapters and audio**

Use `http://mobile.ximalaya.com/mobile/others/ca/album/track/{albumId}/{asc}/{page}/{pageSize}`. For each track, choose `playUrl64`, `playPathAacv164`, `playUrl32`, then `playPathAacv224`. Store the direct URL in `Chapter.audioUrl`.

- [ ] **Step 5: Add source JSON**

Add `assets/sources/xa.json` with `sourceId: "XA"` and `sourceType: "typed-audio"`.

- [ ] **Step 6: Run tests**

Run: `flutter test test/services/typed_sources/xa_source_adapter_test.dart`

Expected: PASS.

## Task 3: xiaoKu Adapter

**Files:**
- Create: `lib/services/typed_sources/xiaoku_source_adapter.dart`
- Create: `assets/sources/xiaoku.json`
- Test: `test/services/typed_sources/xiaoku_source_adapter_test.dart`

- [ ] **Step 1: Write failing tests**

Cover Kuwo album search parsing, album chapter parsing, and direct audio URL extraction from track metadata.

- [ ] **Step 2: Implement search and chapter list**

Use `search.kuwo.cn/r.s` for album search and `stype=albuminfo` for chapter lists.

- [ ] **Step 3: Implement audio resolution**

Return a direct audio URL if the chapter metadata contains one. If the recovered flow requires an extra endpoint and the endpoint is locally reproducible, implement it; otherwise return `null` and let the player show the normal audio failure.

- [ ] **Step 4: Add source JSON and run tests**

Run: `flutter test test/services/typed_sources/xiaoku_source_adapter_test.dart`

Expected: PASS.

## Task 4: liuYue Adapter

**Files:**
- Create: `lib/services/typed_sources/liuyue_source_adapter.dart`
- Create: `assets/sources/liuyue.json`
- Test: `test/services/typed_sources/liuyue_source_adapter_test.dart`

- [ ] **Step 1: Write failing tests**

Cover JSON search parsing, mobile chapter list parsing, and `videoUrl` extraction from a `video_new` response.

- [ ] **Step 2: Implement search and chapters**

Use `/web/index/search?content={keyword}&type=1&pageNum=1` and `/list/{bookId}`.

- [ ] **Step 3: Implement audio resolution**

Use `video_new` only when timestamp and sign are available locally. Otherwise return `null`.

- [ ] **Step 4: Add source JSON and run tests**

Run: `flutter test test/services/typed_sources/liuyue_source_adapter_test.dart`

Expected: PASS.

## Task 5: xiaoLiang Adapter

**Files:**
- Create: `lib/services/typed_sources/xiaoliang_source_adapter.dart`
- Create: `assets/sources/xiaoliang.json`
- Test: `test/services/typed_sources/xiaoliang_source_adapter_test.dart`

- [ ] **Step 1: Write failing tests**

Cover Yuetingba search parsing, chapter parsing, and AES/CBC decrypt helper for a known fixture.

- [ ] **Step 2: Implement search and chapters**

Use `/Search?type=1&name={keyword}` and the album detail page structure recovered from `XiaoLiangService`.

- [ ] **Step 3: Implement AES/CBC audio URL decryption**

Port `gk`, `gi`, and `decrypt` from `XiaoLiangService.java`. Use `pointycastle` or Dart crypto primitives available in the project; if no AES/CBC dependency exists, add the smallest suitable dependency.

- [ ] **Step 4: Add source JSON and run tests**

Run: `flutter test test/services/typed_sources/xiaoliang_source_adapter_test.dart`

Expected: PASS.

## Task 6: xiaoQing Adapter

**Files:**
- Create: `lib/services/typed_sources/xiaoqing_source_adapter.dart`
- Create: `assets/sources/xiaoqing.json`
- Test: `test/services/typed_sources/xiaoqing_source_adapter_test.dart`

- [ ] **Step 1: Write failing tests**

Cover Qingting search parsing, free channel program parsing, and paid program filtering.

- [ ] **Step 2: Implement search and chapters**

Use `webapi.qtfm.cn/api/mobile/search/keyword/{keyword}`, `webapi.qtfm.cn/api/mobile/channels/{id}`, and `/programs`.

- [ ] **Step 3: Implement audio resolution**

Return direct free program URLs when exposed in fixture or API metadata. Return `null` for paid programs.

- [ ] **Step 4: Add source JSON and run tests**

Run: `flutter test test/services/typed_sources/xiaoqing_source_adapter_test.dart`

Expected: PASS.

## Task 7: Built-In Loading And Smoke Validation

**Files:**
- Modify: `lib/features/source_manager/source_manager_page.dart`
- Test: `test/features/source_manager/sources_notifier_test.dart`

- [ ] **Step 1: Write failing source list test**

Assert that built-in source paths include the five typed JSON files and no longer include `assets/sources/ting56.json`.

- [ ] **Step 2: Update built-in source list**

Load `xa.json`, `xiaoku.json`, `liuyue.json`, `xiaoliang.json`, and `xiaoqing.json`.

- [ ] **Step 3: Run focused tests**

Run: `flutter test test/services/typed_sources test/features/source_manager`

Expected: PASS.

- [ ] **Step 4: Run static analysis**

Run: `flutter analyze`

Expected: no new issues from typed source work.

