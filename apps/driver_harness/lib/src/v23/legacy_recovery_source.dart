part of 'legacy_recovery_archive.dart';

/// Native read-only adapter. Never invokes old restore() methods: those can
/// clear missing-file preferences. Auth/session preferences are not included.
Future<Map<String, Object?>> readLegacyDraftPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  return {
    for (final key in preferences.getKeys().where(_LegacySource.draftKey))
      key: preferences.get(key),
  };
}

class _LegacySource {
  _LegacySource(
    String databasePath,
    Directory supportDirectory,
    this.factory,
    this.preferences,
  ) : database = p.absolute(p.normalize(databasePath)),
      support = supportDirectory.resolveSymbolicLinksSync();
  final String database, support;
  final legacy.DatabaseFactory factory;
  final Future<Map<String, Object?>> Function() preferences;
  static const mediaRoots = [
    'pod_drafts',
    'delivery_problem_drafts',
    'pod_evidence',
    'delivery_exception_evidence',
    'message_media',
    'debug_acceptance',
  ];
  static const _prefixes = [
    'pod_draft_photo_path_',
    'pod_draft_photo_captured_at_',
    'delivery_problem_photo_',
    'delivery_problem_note_',
    'delivery_problem_category_',
    'operations_message_draft_v1_',
    'operations_message_location_draft_v1_',
    'operations_message_media_draft_v1_',
  ];
  static bool draftKey(String key) =>
      _prefixes.any(key.startsWith) ||
      {
        'debug_acceptance_photo_path',
        'debug_acceptance_photo_captured_at',
      }.contains(key);

  void requireSafeFile(String path) {
    if (path != database) {
      if (!p.isWithin(support, path)) {
        throw const LegacyRecoveryException('UNSAFE_LEGACY_PATH');
      }
      var ancestor = p.dirname(path);
      while (ancestor != support) {
        if (FileSystemEntity.typeSync(ancestor, followLinks: false) !=
            FileSystemEntityType.directory) {
          throw const LegacyRecoveryException('UNSAFE_LEGACY_PATH');
        }
        ancestor = p.dirname(ancestor);
      }
    } else {
      // The database directory is explicit/trusted, but must resolve to itself.
      // Never follow a dangling or replaced database symlink.
      if (Directory(p.dirname(path)).resolveSymbolicLinksSync() !=
          p.dirname(path)) {
        throw const LegacyRecoveryException('UNSAFE_LEGACY_PATH');
      }
    }
    if (FileSystemEntity.typeSync(path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const LegacyRecoveryException('UNSAFE_LEGACY_PATH');
    }
  }

  Future<_LegacySnapshot> scan() async {
    requireSafeFile(database);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      if (FileSystemEntity.typeSync('$database$suffix', followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const LegacyRecoveryException('LEGACY_WRITER_NOT_QUIESCENT');
      }
    }
    final files = <Map<String, Object?>>[];
    final issues = <Map<String, String>>[];
    final references = <Map<String, Object?>>[];
    final roots = <String, String>{};
    var totalBytes = 0;
    Future<void> addFile(String name, String path) async {
      if (files.length >= 10000) {
        throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
      }
      requireSafeFile(path);
      final before = File(path).statSync();
      if (before.size > 256 * 1024 * 1024 ||
          totalBytes + before.size > 1024 * 1024 * 1024) {
        throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
      }
      final digest = await sha256
          .bind(File(path).openRead(0, before.size + 1))
          .first;
      requireSafeFile(path);
      final after = File(path).statSync();
      if (before.size != after.size ||
          before.modified != after.modified ||
          before.changed != after.changed) {
        throw const LegacyRecoveryException('LEGACY_SOURCE_CHANGED');
      }
      totalBytes += before.size;
      files.add({
        'name': name,
        'path': path,
        'status': 'file',
        'sha256': digest.toString(),
        'size': before.size,
      });
      if (before.size == 0) issues.add({'code': 'EMPTY_FILE', 'source': name});
    }

    await addFile('database', database);
    final inventory = await LegacyUpgradeInventory.inspect(
      databasePath: database,
      factory: factory,
    );
    if (inventory.rows.length > 100000) {
      throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
    }
    void reference(String source, Object? path, Object? hash, Object? size) {
      if (path is! String || path.isEmpty) {
        issues.add({'code': 'MISSING_FILE_REFERENCE', 'source': source});
      } else {
        references.add({
          'source': source,
          'path': path,
          'sha256': hash,
          'size': size,
        });
      }
    }

    void attachments(String source, Object? value) {
      try {
        final decoded = jsonDecode(value as String) as List;
        if (decoded.length > 100) throw const FormatException();
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i] as Map<String, dynamic>;
          if (item['kind'] != 'location') {
            reference(
              '$source/$i',
              item['localPath'],
              item['sha256'],
              item['byteSize'],
            );
          }
        }
      } catch (_) {
        issues.add({
          'code': 'UNREADABLE_ATTACHMENT_REFERENCES',
          'source': source,
        });
      }
    }

    final old = await factory.openDatabase(
      database,
      options: legacy.OpenDatabaseOptions(
        readOnly: true,
        singleInstance: false,
      ),
    );
    try {
      for (final table in [
        'pod_evidence_outbox',
        'delivery_exception_evidence_outbox',
        'message_media_outbox',
      ]) {
        var offset = 0;
        while (true) {
          final batch = await old.query(
            table,
            orderBy: 'id',
            limit: 256,
            offset: offset,
          );
          for (final row in batch) {
            final origin = '$table/${row['id']}';
            if (table == 'message_media_outbox') {
              attachments(origin, row['attachments_json']);
            } else {
              reference(
                origin,
                row['local_path'],
                row['sha256'],
                row['byte_size'],
              );
            }
          }
          offset += batch.length;
          if (offset > 100000) {
            throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
          }
          if (batch.length < 256) break;
        }
      }
    } finally {
      await old.close();
    }
    final rawPreferences = await preferences();
    final selected = <String, Object?>{};
    for (final key in rawPreferences.keys.where(draftKey).toList()..sort()) {
      final value = rawPreferences[key];
      // Preserve unexpected types verbatim if JSON-representable; do not repair.
      selected[key] = jsonDecode(jsonEncode(value));
      if (key.startsWith('pod_draft_photo_path_') ||
          key.startsWith('delivery_problem_photo_') ||
          key == 'debug_acceptance_photo_path') {
        reference('preference/$key', value, null, null);
      } else if (key.startsWith('operations_message_media_draft_v1_')) {
        attachments('preference/$key', value);
      }
    }
    if (selected.length > 10000 ||
        utf8.encode(jsonEncode(selected)).length > 16 * 1024 * 1024) {
      throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
    }

    var visited = 0;
    Future<void> walk(String path, int depth) async {
      if (++visited > 10000 || depth > 16) {
        throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
      }
      final name = 'media/${p.relative(path, from: support)}';
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.file) {
        await addFile(name, path);
      } else if (type == FileSystemEntityType.directory) {
        final children = Directory(path).listSync(followLinks: false)
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final entry in children) {
          await walk(entry.path, depth + 1);
        }
      } else {
        // Keep the unsafe entry's identity in the encrypted manifest, but never
        // read its target or mistake this partial preservation for a full copy.
        files.add({'name': name, 'path': path, 'status': 'unsafe'});
        issues.add({'code': 'UNSAFE_FILE_NOT_COPIED', 'source': name});
      }
    }

    for (final root in mediaRoots) {
      final path = p.join(support, root);
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      roots[root] = type.toString();
      if (type != FileSystemEntityType.notFound) await walk(path, 0);
    }
    final byPath = {for (final file in files) file['path']: file};
    final referenced = <String>{};
    for (final ref in references) {
      final source = ref['source'] as String;
      final path = ref['path'] as String;
      final candidate = p.isAbsolute(path) ? p.normalize(path) : '';
      final file = byPath[candidate];
      if (file == null || file['name'] == 'database') {
        issues.add({'code': 'MISSING_OR_OUTSIDE_MEDIA_ROOT', 'source': source});
        continue;
      }
      referenced.add(candidate);
      if (file['status'] != 'file' ||
          (ref['sha256'] != null && ref['sha256'] != file['sha256']) ||
          (ref['size'] != null && ref['size'] != file['size'])) {
        issues.add({'code': 'FILE_REFERENCE_MISMATCH', 'source': source});
      }
    }
    for (final file in files.where((f) => f['name'] != 'database')) {
      if (!referenced.contains(file['path'])) {
        issues.add({
          'code': 'ORPHAN_RETAINED',
          'source': file['name'] as String,
        });
      }
    }
    // Catch changes during SQL inspection, not just between whole scans.
    requireSafeFile(database);
    if (File(database).lengthSync() != files.first['size'] ||
        (await sha256
                    .bind(
                      File(
                        database,
                      ).openRead(0, (files.first['size'] as int) + 1),
                    )
                    .first)
                .toString() !=
            files.first['sha256']) {
      throw const LegacyRecoveryException('LEGACY_SOURCE_CHANGED');
    }
    for (final suffix in ['-wal', '-shm', '-journal']) {
      if (FileSystemEntity.typeSync('$database$suffix', followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw const LegacyRecoveryException('LEGACY_WRITER_NOT_QUIESCENT');
      }
    }
    files.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final manifest = jsonEncode({
      'format': 'rounds-legacy-recovery-v1',
      'database_path': database,
      'support_path': support,
      'ownership': 'unproven',
      'automatic_replay': false,
      'roots': roots,
      'rows': [
        for (final row in inventory.rows)
          {
            'table': row.table,
            'id': row.sourceId,
            'sha256': row.rowSha256,
            'status': row.status,
            'recovery': row.recoveryReasons,
          },
      ],
      'preferences': selected,
      'references': references,
      'files': files,
      'issues': issues,
    });
    if (utf8.encode(manifest).length > 32 * 1024 * 1024) {
      throw const LegacyRecoveryException('LEGACY_INVENTORY_LIMIT');
    }
    return _LegacySnapshot(
      manifest,
      files,
      inventory.rows.length,
      selected.length,
      issues.length,
    );
  }
}

class _LegacySnapshot {
  _LegacySnapshot(
    this.manifest,
    this.files,
    this.rowCount,
    this.preferenceCount,
    this.issueCount,
  );
  final String manifest;
  final List<Map<String, Object?>> files;
  final int rowCount, preferenceCount, issueCount;
  String get id => _digest(utf8.encode(manifest));
  int get fileCount => files.where((f) => f['status'] == 'file').length;
}
