import 'typed_source_adapter.dart';
import 'liuyue_source_adapter.dart';
import 'lrts_source_adapter.dart';
import 'xa_source_adapter.dart';
import 'xiaoku_source_adapter.dart';
import 'xiaoliang_source_adapter.dart';
import 'xiaoqing_source_adapter.dart';

class TypedSourceRegistry {
  final Map<String, TypedSourceAdapter> _adapters;

  TypedSourceRegistry(Iterable<TypedSourceAdapter> adapters)
      : _adapters = {
          for (final adapter in adapters) adapter.sourceId: adapter,
        };

  TypedSourceAdapter? adapterFor(String sourceId) => _adapters[sourceId];
}

final typedSourceRegistry = TypedSourceRegistry([
  XaSourceAdapter(),
  XiaoKuSourceAdapter(),
  LiuYueSourceAdapter(),
  XiaoLiangSourceAdapter(),
  XiaoQingSourceAdapter(),
  // 懒人听书：依据 2026-10-13 对 m.lrts.me 的真实请求新增
  LrtsSourceAdapter(),
]);
