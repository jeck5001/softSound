// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTableTable extends BooksTable
    with TableInfo<$BooksTableTable, BooksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _narratorMeta = const VerificationMeta(
    'narrator',
  );
  @override
  late final GeneratedColumn<String> narrator = GeneratedColumn<String>(
    'narrator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestChapterMeta = const VerificationMeta(
    'latestChapter',
  );
  @override
  late final GeneratedColumn<String> latestChapter = GeneratedColumn<String>(
    'latest_chapter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inBookshelfMeta = const VerificationMeta(
    'inBookshelf',
  );
  @override
  late final GeneratedColumn<bool> inBookshelf = GeneratedColumn<bool>(
    'in_bookshelf',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_bookshelf" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addTimeMeta = const VerificationMeta(
    'addTime',
  );
  @override
  late final GeneratedColumn<DateTime> addTime = GeneratedColumn<DateTime>(
    'add_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<DateTime> updateTime = GeneratedColumn<DateTime>(
    'update_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    sourceId,
    name,
    author,
    narrator,
    coverUrl,
    intro,
    detailUrl,
    chapterCount,
    latestChapter,
    inBookshelf,
    addTime,
    updateTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BooksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('narrator')) {
      context.handle(
        _narratorMeta,
        narrator.isAcceptableOrUnknown(data['narrator']!, _narratorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    }
    if (data.containsKey('latest_chapter')) {
      context.handle(
        _latestChapterMeta,
        latestChapter.isAcceptableOrUnknown(
          data['latest_chapter']!,
          _latestChapterMeta,
        ),
      );
    }
    if (data.containsKey('in_bookshelf')) {
      context.handle(
        _inBookshelfMeta,
        inBookshelf.isAcceptableOrUnknown(
          data['in_bookshelf']!,
          _inBookshelfMeta,
        ),
      );
    }
    if (data.containsKey('add_time')) {
      context.handle(
        _addTimeMeta,
        addTime.isAcceptableOrUnknown(data['add_time']!, _addTimeMeta),
      );
    }
    if (data.containsKey('update_time')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['update_time']!, _updateTimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BooksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BooksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      narrator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrator'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      detailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_url'],
      )!,
      chapterCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_count'],
      ),
      latestChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter'],
      ),
      inBookshelf: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_bookshelf'],
      )!,
      addTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}add_time'],
      )!,
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}update_time'],
      ),
    );
  }

  @override
  $BooksTableTable createAlias(String alias) {
    return $BooksTableTable(attachedDatabase, alias);
  }
}

class BooksTableData extends DataClass implements Insertable<BooksTableData> {
  final int id;
  final String bookId;
  final String sourceId;
  final String name;
  final String? author;
  final String? narrator;
  final String? coverUrl;
  final String? intro;
  final String detailUrl;
  final int? chapterCount;
  final String? latestChapter;
  final bool inBookshelf;
  final DateTime addTime;
  final DateTime? updateTime;
  const BooksTableData({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.name,
    this.author,
    this.narrator,
    this.coverUrl,
    this.intro,
    required this.detailUrl,
    this.chapterCount,
    this.latestChapter,
    required this.inBookshelf,
    required this.addTime,
    this.updateTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || narrator != null) {
      map['narrator'] = Variable<String>(narrator);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    map['detail_url'] = Variable<String>(detailUrl);
    if (!nullToAbsent || chapterCount != null) {
      map['chapter_count'] = Variable<int>(chapterCount);
    }
    if (!nullToAbsent || latestChapter != null) {
      map['latest_chapter'] = Variable<String>(latestChapter);
    }
    map['in_bookshelf'] = Variable<bool>(inBookshelf);
    map['add_time'] = Variable<DateTime>(addTime);
    if (!nullToAbsent || updateTime != null) {
      map['update_time'] = Variable<DateTime>(updateTime);
    }
    return map;
  }

  BooksTableCompanion toCompanion(bool nullToAbsent) {
    return BooksTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      name: Value(name),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      narrator: narrator == null && nullToAbsent
          ? const Value.absent()
          : Value(narrator),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      detailUrl: Value(detailUrl),
      chapterCount: chapterCount == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterCount),
      latestChapter: latestChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(latestChapter),
      inBookshelf: Value(inBookshelf),
      addTime: Value(addTime),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
    );
  }

  factory BooksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BooksTableData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      name: serializer.fromJson<String>(json['name']),
      author: serializer.fromJson<String?>(json['author']),
      narrator: serializer.fromJson<String?>(json['narrator']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      intro: serializer.fromJson<String?>(json['intro']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      chapterCount: serializer.fromJson<int?>(json['chapterCount']),
      latestChapter: serializer.fromJson<String?>(json['latestChapter']),
      inBookshelf: serializer.fromJson<bool>(json['inBookshelf']),
      addTime: serializer.fromJson<DateTime>(json['addTime']),
      updateTime: serializer.fromJson<DateTime?>(json['updateTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String?>(author),
      'narrator': serializer.toJson<String?>(narrator),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'intro': serializer.toJson<String?>(intro),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'chapterCount': serializer.toJson<int?>(chapterCount),
      'latestChapter': serializer.toJson<String?>(latestChapter),
      'inBookshelf': serializer.toJson<bool>(inBookshelf),
      'addTime': serializer.toJson<DateTime>(addTime),
      'updateTime': serializer.toJson<DateTime?>(updateTime),
    };
  }

  BooksTableData copyWith({
    int? id,
    String? bookId,
    String? sourceId,
    String? name,
    Value<String?> author = const Value.absent(),
    Value<String?> narrator = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> intro = const Value.absent(),
    String? detailUrl,
    Value<int?> chapterCount = const Value.absent(),
    Value<String?> latestChapter = const Value.absent(),
    bool? inBookshelf,
    DateTime? addTime,
    Value<DateTime?> updateTime = const Value.absent(),
  }) => BooksTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    name: name ?? this.name,
    author: author.present ? author.value : this.author,
    narrator: narrator.present ? narrator.value : this.narrator,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    intro: intro.present ? intro.value : this.intro,
    detailUrl: detailUrl ?? this.detailUrl,
    chapterCount: chapterCount.present ? chapterCount.value : this.chapterCount,
    latestChapter: latestChapter.present
        ? latestChapter.value
        : this.latestChapter,
    inBookshelf: inBookshelf ?? this.inBookshelf,
    addTime: addTime ?? this.addTime,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
  );
  BooksTableData copyWithCompanion(BooksTableCompanion data) {
    return BooksTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      narrator: data.narrator.present ? data.narrator.value : this.narrator,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      intro: data.intro.present ? data.intro.value : this.intro,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      chapterCount: data.chapterCount.present
          ? data.chapterCount.value
          : this.chapterCount,
      latestChapter: data.latestChapter.present
          ? data.latestChapter.value
          : this.latestChapter,
      inBookshelf: data.inBookshelf.present
          ? data.inBookshelf.value
          : this.inBookshelf,
      addTime: data.addTime.present ? data.addTime.value : this.addTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('narrator: $narrator, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('inBookshelf: $inBookshelf, ')
          ..write('addTime: $addTime, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    sourceId,
    name,
    author,
    narrator,
    coverUrl,
    intro,
    detailUrl,
    chapterCount,
    latestChapter,
    inBookshelf,
    addTime,
    updateTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BooksTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.name == this.name &&
          other.author == this.author &&
          other.narrator == this.narrator &&
          other.coverUrl == this.coverUrl &&
          other.intro == this.intro &&
          other.detailUrl == this.detailUrl &&
          other.chapterCount == this.chapterCount &&
          other.latestChapter == this.latestChapter &&
          other.inBookshelf == this.inBookshelf &&
          other.addTime == this.addTime &&
          other.updateTime == this.updateTime);
}

class BooksTableCompanion extends UpdateCompanion<BooksTableData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> name;
  final Value<String?> author;
  final Value<String?> narrator;
  final Value<String?> coverUrl;
  final Value<String?> intro;
  final Value<String> detailUrl;
  final Value<int?> chapterCount;
  final Value<String?> latestChapter;
  final Value<bool> inBookshelf;
  final Value<DateTime> addTime;
  final Value<DateTime?> updateTime;
  const BooksTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.narrator = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.inBookshelf = const Value.absent(),
    this.addTime = const Value.absent(),
    this.updateTime = const Value.absent(),
  });
  BooksTableCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String sourceId,
    required String name,
    this.author = const Value.absent(),
    this.narrator = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    required String detailUrl,
    this.chapterCount = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.inBookshelf = const Value.absent(),
    this.addTime = const Value.absent(),
    this.updateTime = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       name = Value(name),
       detailUrl = Value(detailUrl);
  static Insertable<BooksTableData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? name,
    Expression<String>? author,
    Expression<String>? narrator,
    Expression<String>? coverUrl,
    Expression<String>? intro,
    Expression<String>? detailUrl,
    Expression<int>? chapterCount,
    Expression<String>? latestChapter,
    Expression<bool>? inBookshelf,
    Expression<DateTime>? addTime,
    Expression<DateTime>? updateTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (narrator != null) 'narrator': narrator,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (intro != null) 'intro': intro,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (latestChapter != null) 'latest_chapter': latestChapter,
      if (inBookshelf != null) 'in_bookshelf': inBookshelf,
      if (addTime != null) 'add_time': addTime,
      if (updateTime != null) 'update_time': updateTime,
    });
  }

  BooksTableCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? name,
    Value<String?>? author,
    Value<String?>? narrator,
    Value<String?>? coverUrl,
    Value<String?>? intro,
    Value<String>? detailUrl,
    Value<int?>? chapterCount,
    Value<String?>? latestChapter,
    Value<bool>? inBookshelf,
    Value<DateTime>? addTime,
    Value<DateTime?>? updateTime,
  }) {
    return BooksTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      name: name ?? this.name,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      detailUrl: detailUrl ?? this.detailUrl,
      chapterCount: chapterCount ?? this.chapterCount,
      latestChapter: latestChapter ?? this.latestChapter,
      inBookshelf: inBookshelf ?? this.inBookshelf,
      addTime: addTime ?? this.addTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (narrator.present) {
      map['narrator'] = Variable<String>(narrator.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (latestChapter.present) {
      map['latest_chapter'] = Variable<String>(latestChapter.value);
    }
    if (inBookshelf.present) {
      map['in_bookshelf'] = Variable<bool>(inBookshelf.value);
    }
    if (addTime.present) {
      map['add_time'] = Variable<DateTime>(addTime.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<DateTime>(updateTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('narrator: $narrator, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('inBookshelf: $inBookshelf, ')
          ..write('addTime: $addTime, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTableTable extends PlayHistoryTable
    with TableInfo<$PlayHistoryTableTable, PlayHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chapterNameMeta = const VerificationMeta(
    'chapterName',
  );
  @override
  late final GeneratedColumn<String> chapterName = GeneratedColumn<String>(
    'chapter_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayTimeMeta = const VerificationMeta(
    'lastPlayTime',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayTime = GeneratedColumn<DateTime>(
    'last_play_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    sourceId,
    chapterIndex,
    chapterName,
    position,
    duration,
    lastPlayTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('chapter_name')) {
      context.handle(
        _chapterNameMeta,
        chapterName.isAcceptableOrUnknown(
          data['chapter_name']!,
          _chapterNameMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('last_play_time')) {
      context.handle(
        _lastPlayTimeMeta,
        lastPlayTime.isAcceptableOrUnknown(
          data['last_play_time']!,
          _lastPlayTimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      chapterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_name'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
      lastPlayTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_play_time'],
      )!,
    );
  }

  @override
  $PlayHistoryTableTable createAlias(String alias) {
    return $PlayHistoryTableTable(attachedDatabase, alias);
  }
}

class PlayHistoryTableData extends DataClass
    implements Insertable<PlayHistoryTableData> {
  final int id;
  final String bookId;
  final String sourceId;
  final int chapterIndex;
  final String? chapterName;
  final int position;
  final int duration;
  final DateTime lastPlayTime;
  const PlayHistoryTableData({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.chapterIndex,
    this.chapterName,
    required this.position,
    required this.duration,
    required this.lastPlayTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    if (!nullToAbsent || chapterName != null) {
      map['chapter_name'] = Variable<String>(chapterName);
    }
    map['position'] = Variable<int>(position);
    map['duration'] = Variable<int>(duration);
    map['last_play_time'] = Variable<DateTime>(lastPlayTime);
    return map;
  }

  PlayHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      chapterIndex: Value(chapterIndex),
      chapterName: chapterName == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterName),
      position: Value(position),
      duration: Value(duration),
      lastPlayTime: Value(lastPlayTime),
    );
  }

  factory PlayHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryTableData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterName: serializer.fromJson<String?>(json['chapterName']),
      position: serializer.fromJson<int>(json['position']),
      duration: serializer.fromJson<int>(json['duration']),
      lastPlayTime: serializer.fromJson<DateTime>(json['lastPlayTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterName': serializer.toJson<String?>(chapterName),
      'position': serializer.toJson<int>(position),
      'duration': serializer.toJson<int>(duration),
      'lastPlayTime': serializer.toJson<DateTime>(lastPlayTime),
    };
  }

  PlayHistoryTableData copyWith({
    int? id,
    String? bookId,
    String? sourceId,
    int? chapterIndex,
    Value<String?> chapterName = const Value.absent(),
    int? position,
    int? duration,
    DateTime? lastPlayTime,
  }) => PlayHistoryTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterName: chapterName.present ? chapterName.value : this.chapterName,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    lastPlayTime: lastPlayTime ?? this.lastPlayTime,
  );
  PlayHistoryTableData copyWithCompanion(PlayHistoryTableCompanion data) {
    return PlayHistoryTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      position: data.position.present ? data.position.value : this.position,
      duration: data.duration.present ? data.duration.value : this.duration,
      lastPlayTime: data.lastPlayTime.present
          ? data.lastPlayTime.value
          : this.lastPlayTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterName: $chapterName, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('lastPlayTime: $lastPlayTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    sourceId,
    chapterIndex,
    chapterName,
    position,
    duration,
    lastPlayTime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterName == this.chapterName &&
          other.position == this.position &&
          other.duration == this.duration &&
          other.lastPlayTime == this.lastPlayTime);
}

class PlayHistoryTableCompanion extends UpdateCompanion<PlayHistoryTableData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<int> chapterIndex;
  final Value<String?> chapterName;
  final Value<int> position;
  final Value<int> duration;
  final Value<DateTime> lastPlayTime;
  const PlayHistoryTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.position = const Value.absent(),
    this.duration = const Value.absent(),
    this.lastPlayTime = const Value.absent(),
  });
  PlayHistoryTableCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String sourceId,
    this.chapterIndex = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.position = const Value.absent(),
    this.duration = const Value.absent(),
    this.lastPlayTime = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId);
  static Insertable<PlayHistoryTableData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterName,
    Expression<int>? position,
    Expression<int>? duration,
    Expression<DateTime>? lastPlayTime,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterName != null) 'chapter_name': chapterName,
      if (position != null) 'position': position,
      if (duration != null) 'duration': duration,
      if (lastPlayTime != null) 'last_play_time': lastPlayTime,
    });
  }

  PlayHistoryTableCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<int>? chapterIndex,
    Value<String?>? chapterName,
    Value<int>? position,
    Value<int>? duration,
    Value<DateTime>? lastPlayTime,
  }) {
    return PlayHistoryTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterName: chapterName ?? this.chapterName,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      lastPlayTime: lastPlayTime ?? this.lastPlayTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterName.present) {
      map['chapter_name'] = Variable<String>(chapterName.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (lastPlayTime.present) {
      map['last_play_time'] = Variable<DateTime>(lastPlayTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterName: $chapterName, ')
          ..write('position: $position, ')
          ..write('duration: $duration, ')
          ..write('lastPlayTime: $lastPlayTime')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTableTable booksTable = $BooksTableTable(this);
  late final $PlayHistoryTableTable playHistoryTable = $PlayHistoryTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    booksTable,
    playHistoryTable,
  ];
}

typedef $$BooksTableTableCreateCompanionBuilder =
    BooksTableCompanion Function({
      Value<int> id,
      required String bookId,
      required String sourceId,
      required String name,
      Value<String?> author,
      Value<String?> narrator,
      Value<String?> coverUrl,
      Value<String?> intro,
      required String detailUrl,
      Value<int?> chapterCount,
      Value<String?> latestChapter,
      Value<bool> inBookshelf,
      Value<DateTime> addTime,
      Value<DateTime?> updateTime,
    });
typedef $$BooksTableTableUpdateCompanionBuilder =
    BooksTableCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> name,
      Value<String?> author,
      Value<String?> narrator,
      Value<String?> coverUrl,
      Value<String?> intro,
      Value<String> detailUrl,
      Value<int?> chapterCount,
      Value<String?> latestChapter,
      Value<bool> inBookshelf,
      Value<DateTime> addTime,
      Value<DateTime?> updateTime,
    });

class $$BooksTableTableFilterComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrator => $composableBuilder(
    column: $table.narrator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inBookshelf => $composableBuilder(
    column: $table.inBookshelf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addTime => $composableBuilder(
    column: $table.addTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrator => $composableBuilder(
    column: $table.narrator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inBookshelf => $composableBuilder(
    column: $table.inBookshelf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addTime => $composableBuilder(
    column: $table.addTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTableTable> {
  $$BooksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get narrator =>
      $composableBuilder(column: $table.narrator, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get inBookshelf => $composableBuilder(
    column: $table.inBookshelf,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addTime =>
      $composableBuilder(column: $table.addTime, builder: (column) => column);

  GeneratedColumn<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );
}

class $$BooksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTableTable,
          BooksTableData,
          $$BooksTableTableFilterComposer,
          $$BooksTableTableOrderingComposer,
          $$BooksTableTableAnnotationComposer,
          $$BooksTableTableCreateCompanionBuilder,
          $$BooksTableTableUpdateCompanionBuilder,
          (
            BooksTableData,
            BaseReferences<_$AppDatabase, $BooksTableTable, BooksTableData>,
          ),
          BooksTableData,
          PrefetchHooks Function()
        > {
  $$BooksTableTableTableManager(_$AppDatabase db, $BooksTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> narrator = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<int?> chapterCount = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                Value<bool> inBookshelf = const Value.absent(),
                Value<DateTime> addTime = const Value.absent(),
                Value<DateTime?> updateTime = const Value.absent(),
              }) => BooksTableCompanion(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                name: name,
                author: author,
                narrator: narrator,
                coverUrl: coverUrl,
                intro: intro,
                detailUrl: detailUrl,
                chapterCount: chapterCount,
                latestChapter: latestChapter,
                inBookshelf: inBookshelf,
                addTime: addTime,
                updateTime: updateTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String sourceId,
                required String name,
                Value<String?> author = const Value.absent(),
                Value<String?> narrator = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                required String detailUrl,
                Value<int?> chapterCount = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                Value<bool> inBookshelf = const Value.absent(),
                Value<DateTime> addTime = const Value.absent(),
                Value<DateTime?> updateTime = const Value.absent(),
              }) => BooksTableCompanion.insert(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                name: name,
                author: author,
                narrator: narrator,
                coverUrl: coverUrl,
                intro: intro,
                detailUrl: detailUrl,
                chapterCount: chapterCount,
                latestChapter: latestChapter,
                inBookshelf: inBookshelf,
                addTime: addTime,
                updateTime: updateTime,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTableTable,
      BooksTableData,
      $$BooksTableTableFilterComposer,
      $$BooksTableTableOrderingComposer,
      $$BooksTableTableAnnotationComposer,
      $$BooksTableTableCreateCompanionBuilder,
      $$BooksTableTableUpdateCompanionBuilder,
      (
        BooksTableData,
        BaseReferences<_$AppDatabase, $BooksTableTable, BooksTableData>,
      ),
      BooksTableData,
      PrefetchHooks Function()
    >;
typedef $$PlayHistoryTableTableCreateCompanionBuilder =
    PlayHistoryTableCompanion Function({
      Value<int> id,
      required String bookId,
      required String sourceId,
      Value<int> chapterIndex,
      Value<String?> chapterName,
      Value<int> position,
      Value<int> duration,
      Value<DateTime> lastPlayTime,
    });
typedef $$PlayHistoryTableTableUpdateCompanionBuilder =
    PlayHistoryTableCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> sourceId,
      Value<int> chapterIndex,
      Value<String?> chapterName,
      Value<int> position,
      Value<int> duration,
      Value<DateTime> lastPlayTime,
    });

class $$PlayHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryTableTable> {
  $$PlayHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayTime => $composableBuilder(
    column: $table.lastPlayTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryTableTable> {
  $$PlayHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayTime => $composableBuilder(
    column: $table.lastPlayTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryTableTable> {
  $$PlayHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayTime => $composableBuilder(
    column: $table.lastPlayTime,
    builder: (column) => column,
  );
}

class $$PlayHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayHistoryTableTable,
          PlayHistoryTableData,
          $$PlayHistoryTableTableFilterComposer,
          $$PlayHistoryTableTableOrderingComposer,
          $$PlayHistoryTableTableAnnotationComposer,
          $$PlayHistoryTableTableCreateCompanionBuilder,
          $$PlayHistoryTableTableUpdateCompanionBuilder,
          (
            PlayHistoryTableData,
            BaseReferences<
              _$AppDatabase,
              $PlayHistoryTableTable,
              PlayHistoryTableData
            >,
          ),
          PlayHistoryTableData,
          PrefetchHooks Function()
        > {
  $$PlayHistoryTableTableTableManager(
    _$AppDatabase db,
    $PlayHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<DateTime> lastPlayTime = const Value.absent(),
              }) => PlayHistoryTableCompanion(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterName: chapterName,
                position: position,
                duration: duration,
                lastPlayTime: lastPlayTime,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String sourceId,
                Value<int> chapterIndex = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> duration = const Value.absent(),
                Value<DateTime> lastPlayTime = const Value.absent(),
              }) => PlayHistoryTableCompanion.insert(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterName: chapterName,
                position: position,
                duration: duration,
                lastPlayTime: lastPlayTime,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayHistoryTableTable,
      PlayHistoryTableData,
      $$PlayHistoryTableTableFilterComposer,
      $$PlayHistoryTableTableOrderingComposer,
      $$PlayHistoryTableTableAnnotationComposer,
      $$PlayHistoryTableTableCreateCompanionBuilder,
      $$PlayHistoryTableTableUpdateCompanionBuilder,
      (
        PlayHistoryTableData,
        BaseReferences<
          _$AppDatabase,
          $PlayHistoryTableTable,
          PlayHistoryTableData
        >,
      ),
      PlayHistoryTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db, _db.booksTable);
  $$PlayHistoryTableTableTableManager get playHistoryTable =>
      $$PlayHistoryTableTableTableManager(_db, _db.playHistoryTable);
}
