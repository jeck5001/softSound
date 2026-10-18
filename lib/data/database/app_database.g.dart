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

class $DownloadChaptersTableTable extends DownloadChaptersTable
    with TableInfo<$DownloadChaptersTableTable, DownloadChaptersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadChaptersTableTable(this.attachedDatabase, [this._alias]);
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNameMeta = const VerificationMeta(
    'chapterName',
  );
  @override
  late final GeneratedColumn<String> chapterName = GeneratedColumn<String>(
    'chapter_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DownloadStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(DownloadStatus.queued.index),
      ).withConverter<DownloadStatus>(
        $DownloadChaptersTableTable.$converterstatus,
      );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
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
    remoteUrl,
    localPath,
    downloadedBytes,
    totalBytes,
    status,
    error,
    durationMs,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadChaptersTableData> instance, {
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
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_name')) {
      context.handle(
        _chapterNameMeta,
        chapterName.isAcceptableOrUnknown(
          data['chapter_name']!,
          _chapterNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterNameMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
  @override
  DownloadChaptersTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadChaptersTableData(
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
      )!,
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      status: $DownloadChaptersTableTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadChaptersTableTable createAlias(String alias) {
    return $DownloadChaptersTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DownloadStatus, int, int> $converterstatus =
      const EnumIndexConverter<DownloadStatus>(DownloadStatus.values);
}

class DownloadChaptersTableData extends DataClass
    implements Insertable<DownloadChaptersTableData> {
  final int id;

  /// 所属书籍 ID（与 BooksTable.bookId 对应）。
  final String bookId;

  /// 书源 ID，便于按源清理。
  final String sourceId;

  /// 章节序号（与 Chapter 列表顺序一致）。
  final int chapterIndex;

  /// 章节名，用于列表展示。
  final String chapterName;

  /// 远端音频地址（缓存来源）。
  final String? remoteUrl;

  /// 本地文件路径；完成后才有值。
  final String? localPath;

  /// 已下载字节数，用于进度展示。
  final int downloadedBytes;

  /// 文件总字节数；未知时为 0。
  final int totalBytes;

  /// 下载状态（存 [DownloadStatus] 的 index）。
  final DownloadStatus status;

  /// 失败原因。
  final String? error;

  /// 音频时长（毫秒），用于展示与空间统计。
  final int durationMs;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DownloadChaptersTableData({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.chapterIndex,
    required this.chapterName,
    this.remoteUrl,
    this.localPath,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.status,
    this.error,
    required this.durationMs,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_name'] = Variable<String>(chapterName);
    if (!nullToAbsent || remoteUrl != null) {
      map['remote_url'] = Variable<String>(remoteUrl);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['total_bytes'] = Variable<int>(totalBytes);
    {
      map['status'] = Variable<int>(
        $DownloadChaptersTableTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DownloadChaptersTableCompanion toCompanion(bool nullToAbsent) {
    return DownloadChaptersTableCompanion(
      id: Value(id),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      chapterIndex: Value(chapterIndex),
      chapterName: Value(chapterName),
      remoteUrl: remoteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUrl),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      downloadedBytes: Value(downloadedBytes),
      totalBytes: Value(totalBytes),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      durationMs: Value(durationMs),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadChaptersTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadChaptersTableData(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterName: serializer.fromJson<String>(json['chapterName']),
      remoteUrl: serializer.fromJson<String?>(json['remoteUrl']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      status: $DownloadChaptersTableTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      error: serializer.fromJson<String?>(json['error']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
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
      'chapterName': serializer.toJson<String>(chapterName),
      'remoteUrl': serializer.toJson<String?>(remoteUrl),
      'localPath': serializer.toJson<String?>(localPath),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'status': serializer.toJson<int>(
        $DownloadChaptersTableTable.$converterstatus.toJson(status),
      ),
      'error': serializer.toJson<String?>(error),
      'durationMs': serializer.toJson<int>(durationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DownloadChaptersTableData copyWith({
    int? id,
    String? bookId,
    String? sourceId,
    int? chapterIndex,
    String? chapterName,
    Value<String?> remoteUrl = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    int? downloadedBytes,
    int? totalBytes,
    DownloadStatus? status,
    Value<String?> error = const Value.absent(),
    int? durationMs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DownloadChaptersTableData(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterName: chapterName ?? this.chapterName,
    remoteUrl: remoteUrl.present ? remoteUrl.value : this.remoteUrl,
    localPath: localPath.present ? localPath.value : this.localPath,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    totalBytes: totalBytes ?? this.totalBytes,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    durationMs: durationMs ?? this.durationMs,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadChaptersTableData copyWithCompanion(
    DownloadChaptersTableCompanion data,
  ) {
    return DownloadChaptersTableData(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadChaptersTableData(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterName: $chapterName, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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
    remoteUrl,
    localPath,
    downloadedBytes,
    totalBytes,
    status,
    error,
    durationMs,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadChaptersTableData &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterName == this.chapterName &&
          other.remoteUrl == this.remoteUrl &&
          other.localPath == this.localPath &&
          other.downloadedBytes == this.downloadedBytes &&
          other.totalBytes == this.totalBytes &&
          other.status == this.status &&
          other.error == this.error &&
          other.durationMs == this.durationMs &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DownloadChaptersTableCompanion
    extends UpdateCompanion<DownloadChaptersTableData> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<int> chapterIndex;
  final Value<String> chapterName;
  final Value<String?> remoteUrl;
  final Value<String?> localPath;
  final Value<int> downloadedBytes;
  final Value<int> totalBytes;
  final Value<DownloadStatus> status;
  final Value<String?> error;
  final Value<int> durationMs;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DownloadChaptersTableCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DownloadChaptersTableCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String sourceId,
    required int chapterIndex,
    required String chapterName,
    this.remoteUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       chapterIndex = Value(chapterIndex),
       chapterName = Value(chapterName);
  static Insertable<DownloadChaptersTableData> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterName,
    Expression<String>? remoteUrl,
    Expression<String>? localPath,
    Expression<int>? downloadedBytes,
    Expression<int>? totalBytes,
    Expression<int>? status,
    Expression<String>? error,
    Expression<int>? durationMs,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterName != null) 'chapter_name': chapterName,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (localPath != null) 'local_path': localPath,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (durationMs != null) 'duration_ms': durationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DownloadChaptersTableCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<int>? chapterIndex,
    Value<String>? chapterName,
    Value<String?>? remoteUrl,
    Value<String?>? localPath,
    Value<int>? downloadedBytes,
    Value<int>? totalBytes,
    Value<DownloadStatus>? status,
    Value<String?>? error,
    Value<int>? durationMs,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DownloadChaptersTableCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterName: chapterName ?? this.chapterName,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localPath: localPath ?? this.localPath,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $DownloadChaptersTableTable.$converterstatus.toSql(status.value),
      );
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadChaptersTableCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterName: $chapterName, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('localPath: $localPath, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('durationMs: $durationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ListeningStatsTableTable extends ListeningStatsTable
    with TableInfo<$ListeningStatsTableTable, ListeningStatsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListeningStatsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _totalSecondsMeta = const VerificationMeta(
    'totalSeconds',
  );
  @override
  late final GeneratedColumn<int> totalSeconds = GeneratedColumn<int>(
    'total_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, totalSeconds, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'listening_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListeningStatsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('total_seconds')) {
      context.handle(
        _totalSecondsMeta,
        totalSeconds.isAcceptableOrUnknown(
          data['total_seconds']!,
          _totalSecondsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListeningStatsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListeningStatsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      totalSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_seconds'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ListeningStatsTableTable createAlias(String alias) {
    return $ListeningStatsTableTable(attachedDatabase, alias);
  }
}

class ListeningStatsTableData extends DataClass
    implements Insertable<ListeningStatsTableData> {
  final int id;

  /// 累计收听秒数（只增不减，除非用户主动清空统计）。
  final int totalSeconds;

  /// 最近一次累计时间。
  final DateTime updatedAt;
  const ListeningStatsTableData({
    required this.id,
    required this.totalSeconds,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['total_seconds'] = Variable<int>(totalSeconds);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ListeningStatsTableCompanion toCompanion(bool nullToAbsent) {
    return ListeningStatsTableCompanion(
      id: Value(id),
      totalSeconds: Value(totalSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory ListeningStatsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListeningStatsTableData(
      id: serializer.fromJson<int>(json['id']),
      totalSeconds: serializer.fromJson<int>(json['totalSeconds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'totalSeconds': serializer.toJson<int>(totalSeconds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ListeningStatsTableData copyWith({
    int? id,
    int? totalSeconds,
    DateTime? updatedAt,
  }) => ListeningStatsTableData(
    id: id ?? this.id,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ListeningStatsTableData copyWithCompanion(ListeningStatsTableCompanion data) {
    return ListeningStatsTableData(
      id: data.id.present ? data.id.value : this.id,
      totalSeconds: data.totalSeconds.present
          ? data.totalSeconds.value
          : this.totalSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListeningStatsTableData(')
          ..write('id: $id, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, totalSeconds, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListeningStatsTableData &&
          other.id == this.id &&
          other.totalSeconds == this.totalSeconds &&
          other.updatedAt == this.updatedAt);
}

class ListeningStatsTableCompanion
    extends UpdateCompanion<ListeningStatsTableData> {
  final Value<int> id;
  final Value<int> totalSeconds;
  final Value<DateTime> updatedAt;
  const ListeningStatsTableCompanion({
    this.id = const Value.absent(),
    this.totalSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ListeningStatsTableCompanion.insert({
    this.id = const Value.absent(),
    this.totalSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<ListeningStatsTableData> custom({
    Expression<int>? id,
    Expression<int>? totalSeconds,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (totalSeconds != null) 'total_seconds': totalSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ListeningStatsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? totalSeconds,
    Value<DateTime>? updatedAt,
  }) {
    return ListeningStatsTableCompanion(
      id: id ?? this.id,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (totalSeconds.present) {
      map['total_seconds'] = Variable<int>(totalSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListeningStatsTableCompanion(')
          ..write('id: $id, ')
          ..write('totalSeconds: $totalSeconds, ')
          ..write('updatedAt: $updatedAt')
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
  late final $DownloadChaptersTableTable downloadChaptersTable =
      $DownloadChaptersTableTable(this);
  late final $ListeningStatsTableTable listeningStatsTable =
      $ListeningStatsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    booksTable,
    playHistoryTable,
    downloadChaptersTable,
    listeningStatsTable,
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
typedef $$DownloadChaptersTableTableCreateCompanionBuilder =
    DownloadChaptersTableCompanion Function({
      Value<int> id,
      required String bookId,
      required String sourceId,
      required int chapterIndex,
      required String chapterName,
      Value<String?> remoteUrl,
      Value<String?> localPath,
      Value<int> downloadedBytes,
      Value<int> totalBytes,
      Value<DownloadStatus> status,
      Value<String?> error,
      Value<int> durationMs,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$DownloadChaptersTableTableUpdateCompanionBuilder =
    DownloadChaptersTableCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> sourceId,
      Value<int> chapterIndex,
      Value<String> chapterName,
      Value<String?> remoteUrl,
      Value<String?> localPath,
      Value<int> downloadedBytes,
      Value<int> totalBytes,
      Value<DownloadStatus> status,
      Value<String?> error,
      Value<int> durationMs,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DownloadChaptersTableTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadChaptersTableTable> {
  $$DownloadChaptersTableTableFilterComposer({
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

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DownloadStatus, DownloadStatus, int>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadChaptersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadChaptersTableTable> {
  $$DownloadChaptersTableTableOrderingComposer({
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

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadChaptersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadChaptersTableTable> {
  $$DownloadChaptersTableTableAnnotationComposer({
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

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DownloadStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadChaptersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadChaptersTableTable,
          DownloadChaptersTableData,
          $$DownloadChaptersTableTableFilterComposer,
          $$DownloadChaptersTableTableOrderingComposer,
          $$DownloadChaptersTableTableAnnotationComposer,
          $$DownloadChaptersTableTableCreateCompanionBuilder,
          $$DownloadChaptersTableTableUpdateCompanionBuilder,
          (
            DownloadChaptersTableData,
            BaseReferences<
              _$AppDatabase,
              $DownloadChaptersTableTable,
              DownloadChaptersTableData
            >,
          ),
          DownloadChaptersTableData,
          PrefetchHooks Function()
        > {
  $$DownloadChaptersTableTableTableManager(
    _$AppDatabase db,
    $DownloadChaptersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadChaptersTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadChaptersTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadChaptersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> chapterName = const Value.absent(),
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DownloadChaptersTableCompanion(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterName: chapterName,
                remoteUrl: remoteUrl,
                localPath: localPath,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                status: status,
                error: error,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String sourceId,
                required int chapterIndex,
                required String chapterName,
                Value<String?> remoteUrl = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<DownloadStatus> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DownloadChaptersTableCompanion.insert(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterName: chapterName,
                remoteUrl: remoteUrl,
                localPath: localPath,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                status: status,
                error: error,
                durationMs: durationMs,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadChaptersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadChaptersTableTable,
      DownloadChaptersTableData,
      $$DownloadChaptersTableTableFilterComposer,
      $$DownloadChaptersTableTableOrderingComposer,
      $$DownloadChaptersTableTableAnnotationComposer,
      $$DownloadChaptersTableTableCreateCompanionBuilder,
      $$DownloadChaptersTableTableUpdateCompanionBuilder,
      (
        DownloadChaptersTableData,
        BaseReferences<
          _$AppDatabase,
          $DownloadChaptersTableTable,
          DownloadChaptersTableData
        >,
      ),
      DownloadChaptersTableData,
      PrefetchHooks Function()
    >;
typedef $$ListeningStatsTableTableCreateCompanionBuilder =
    ListeningStatsTableCompanion Function({
      Value<int> id,
      Value<int> totalSeconds,
      Value<DateTime> updatedAt,
    });
typedef $$ListeningStatsTableTableUpdateCompanionBuilder =
    ListeningStatsTableCompanion Function({
      Value<int> id,
      Value<int> totalSeconds,
      Value<DateTime> updatedAt,
    });

class $$ListeningStatsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ListeningStatsTableTable> {
  $$ListeningStatsTableTableFilterComposer({
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

  ColumnFilters<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ListeningStatsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ListeningStatsTableTable> {
  $$ListeningStatsTableTableOrderingComposer({
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

  ColumnOrderings<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListeningStatsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListeningStatsTableTable> {
  $$ListeningStatsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get totalSeconds => $composableBuilder(
    column: $table.totalSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ListeningStatsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListeningStatsTableTable,
          ListeningStatsTableData,
          $$ListeningStatsTableTableFilterComposer,
          $$ListeningStatsTableTableOrderingComposer,
          $$ListeningStatsTableTableAnnotationComposer,
          $$ListeningStatsTableTableCreateCompanionBuilder,
          $$ListeningStatsTableTableUpdateCompanionBuilder,
          (
            ListeningStatsTableData,
            BaseReferences<
              _$AppDatabase,
              $ListeningStatsTableTable,
              ListeningStatsTableData
            >,
          ),
          ListeningStatsTableData,
          PrefetchHooks Function()
        > {
  $$ListeningStatsTableTableTableManager(
    _$AppDatabase db,
    $ListeningStatsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListeningStatsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListeningStatsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ListeningStatsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalSeconds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ListeningStatsTableCompanion(
                id: id,
                totalSeconds: totalSeconds,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalSeconds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ListeningStatsTableCompanion.insert(
                id: id,
                totalSeconds: totalSeconds,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ListeningStatsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListeningStatsTableTable,
      ListeningStatsTableData,
      $$ListeningStatsTableTableFilterComposer,
      $$ListeningStatsTableTableOrderingComposer,
      $$ListeningStatsTableTableAnnotationComposer,
      $$ListeningStatsTableTableCreateCompanionBuilder,
      $$ListeningStatsTableTableUpdateCompanionBuilder,
      (
        ListeningStatsTableData,
        BaseReferences<
          _$AppDatabase,
          $ListeningStatsTableTable,
          ListeningStatsTableData
        >,
      ),
      ListeningStatsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableTableManager get booksTable =>
      $$BooksTableTableTableManager(_db, _db.booksTable);
  $$PlayHistoryTableTableTableManager get playHistoryTable =>
      $$PlayHistoryTableTableTableManager(_db, _db.playHistoryTable);
  $$DownloadChaptersTableTableTableManager get downloadChaptersTable =>
      $$DownloadChaptersTableTableTableManager(_db, _db.downloadChaptersTable);
  $$ListeningStatsTableTableTableManager get listeningStatsTable =>
      $$ListeningStatsTableTableTableManager(_db, _db.listeningStatsTable);
}
