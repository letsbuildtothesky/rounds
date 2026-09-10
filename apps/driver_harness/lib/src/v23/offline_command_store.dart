part of 'encrypted_work_store.dart';

/// Local queue status only. 'committed' means THIS command's server receipt,
/// never whole delivery completion. No bearer/capability/file path is exposed.
class StoredExecutionCommand {
  StoredExecutionCommand._(Map<String, Object?> row)
    : commandId = row['command_id'] as String,
      commandType = row['command_type'] as String,
      state = row['state'] as String,
      attempts = row['attempts'] as int,
      requestHash = row['request_hash'] as String,
      errorCode = row['error_code'] as String?,
      nextRetryAt = row['next_retry_at'] as String?;
  final String commandId, commandType, state, requestHash;
  final String? errorCode, nextRetryAt;
  final int attempts;
  @override
  String toString() => 'StoredExecutionCommand($commandType, $state)';
}

/// Only a validated committed report can create this read selector. Fresh
/// queries cannot rewrite it or turn it into execution permission.
class ReportedPickupIssue {
  ReportedPickupIssue._(this._json);
  final String _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  @override
  String toString() => 'ReportedPickupIssue(redacted)';
}

extension NativeObservationCommands on EncryptedDriverStore {
  Future<ReportedPickupIssue> reportedPickupIssue(String observationId) =>
      _serial(() async {
        final o = _observationRow(observationId);
        if (o == null || o['command_id'] == null) {
          throw const EncryptedStoreException('ISSUE_NOT_REPORTED');
        }
        final row = _commandRow(o['command_id'] as String);
        if (row['command_type'] != 'ReportIssue' ||
            row['state'] != 'committed' ||
            row['server_receipt_json'] == null) {
          throw const EncryptedStoreException('ISSUE_NOT_REPORTED');
        }
        final receipt =
            jsonDecode(row['server_receipt_json'] as String)
                as Map<String, dynamic>;
        _checkReceipt(row, receipt);
        final wire =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final fence = wire['execution_fence'] as Map;
        if (fence['observation_id'] != observationId) {
          throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
        }
        return ReportedPickupIssue._(
          jsonEncode({
            'principal_id': _device.principalId,
            'tenant_id': wire['context']['tenant_id'],
            'city_id': wire['context']['city_id'],
            'round_id': wire['payload']['round_id'],
            'delivery_id': wire['payload']['delivery_id'],
            'assignment_id': fence['assignment_id'],
            'assignment_version': fence['assignment_version'],
            'observation_id': observationId,
            'issue_id': receipt['data']['resource']['id'],
          }),
        );
      });

  /// Explicit foreground adapter only; does not select work or launch a sender.
  /// V1 action payload = `{"command_payload": {...}}`. Authority/IDs and
  /// expected versions are supplied below, never by a screen or fresh query.
  Future<StoredExecutionCommand> materializeObservation(
    String observationId,
  ) => _serial(() async {
    final observation = _observationRow(observationId);
    if (observation == null) {
      throw const EncryptedStoreException('OBSERVATION_NOT_FOUND');
    }
    if (observation['command_id'] != null) {
      return StoredExecutionCommand._(
        _commandRow(observation['command_id'] as String),
      );
    }
    final saved = await _inspectObservation(observation);
    if (saved.state != 'local_recorded') {
      throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
    }
    final o = saved.toJson(),
        context = o['execution_context'] as Map<String, dynamic>;
    if (!_fenceCurrent(o)) {
      throw const EncryptedStoreException('EXECUTION_FENCE_CHANGED');
    }
    final type = {
      'arrival': 'ConfirmArrival',
      'pickup': 'ConfirmPickup',
      'handoff': 'RecordHandoff',
      'proof': 'SubmitProof',
      'completion': 'CompleteDelivery',
      'issue': 'ReportIssue',
    }[o['kind']];
    if (type == null) {
      throw const EncryptedStoreException('COMMAND_NOT_CONNECTED');
    }
    final action = o['observed_payload'] as Map<String, dynamic>;
    if (type != 'ReportIssue' &&
        (action.length != 1 ||
            action['command_payload'] is! Map<String, dynamic>)) {
      throw const EncryptedStoreException('OBSERVATION_FORMAT_UNSUPPORTED');
    }
    final payload = type == 'ReportIssue'
        ? _pickupIssuePayload(o, context)
        : Map<String, dynamic>.from(action['command_payload'] as Map);
    // Bounded linear delivery chain for this increment. Unsupported branching
    // retains all observations; it is never silently flattened/rebased.
    final chain = <Map<String, dynamic>>[], receipts = <Map<String, dynamic>>[];
    final seen = <String>{observationId};
    var cursor = o;
    while ((cursor['predecessor_observation_ids'] as List).isNotEmpty) {
      final parents = cursor['predecessor_observation_ids'] as List;
      if (parents.length != 1 ||
          !seen.add(parents.single as String) ||
          seen.length > 128) {
        throw const EncryptedStoreException('DEPENDENCY_CHAIN_UNSUPPORTED');
      }
      final row = _observationRow(parents.single as String);
      if (row == null || row['command_id'] == null) {
        throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
      }
      final parent =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      if (canonicalNativeCommand(parent['execution_context']) !=
              canonicalNativeCommand(context) ||
          parent['device_id'] != o['device_id'] ||
          parent['session_epoch'] != o['session_epoch']) {
        throw const EncryptedStoreException('DEPENDENCY_SCOPE_MISMATCH');
      }
      final command = _commandRow(row['command_id'] as String);
      if (command['state'] != 'committed' ||
          command['server_receipt_json'] == null) {
        throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
      }
      final receipt =
          jsonDecode(command['server_receipt_json'] as String)
              as Map<String, dynamic>;
      _checkReceipt(command, receipt);
      chain.insert(0, parent);
      receipts.insert(0, receipt);
      cursor = parent;
    }
    final versions = <String, Map<String, dynamic>>{
      for (final root in context['expected_versions'] as List)
        '${root['aggregate_type']}:${root['id']}': Map<String, dynamic>.from(
          root as Map,
        ),
    };
    final sources = <String, Map<String, dynamic>>{};
    for (var i = 0; i < receipts.length; i++) {
      final r = receipts[i];
      for (final field in ['current_versions', 'resources']) {
        final roots = r[field] as List;
        for (var j = 0; j < roots.length; j++) {
          final root = Map<String, dynamic>.from(roots[j] as Map),
              key = '${root['aggregate_type']}:${root['id']}';
          final old = versions[key];
          if (old != null &&
              (root['version'] as num) < (old['version'] as num)) {
            throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
          }
          versions[key] = root;
          sources[key] = {
            'parent': chain[i]['observation_id'],
            'pointer': '/$field/$j/version',
            'command': r['command_id'],
          };
        }
      }
    }
    final bindings = <Map<String, dynamic>>[];
    final mediaDependencies = <String>[];
    Map<String, dynamic>? pickupMedia;
    void bind(Map<String, dynamic> source, String target, Object? value) =>
        bindings.add({...source, 'target': target, 'value': value});
    void absent(Iterable<String> keys) {
      if (keys.any(payload.containsKey)) {
        throw const EncryptedStoreException('OBSERVATION_AUTHORITY_OVERRIDE');
      }
    }

    int? pickupIndex;
    for (var i = 0; i < chain.length; i++) {
      if (chain[i]['kind'] == 'pickup') pickupIndex = i;
    }
    Map<String, dynamic>? attempt;
    Map<String, dynamic>? attemptSource;
    if (pickupIndex != null) {
      final list = receipts[pickupIndex]['data']['attempts'] as List;
      final matches = [
        for (var j = 0; j < list.length; j++)
          if (list[j]['fulfillment_unit_id'] == o['fulfillment_unit_id']) j,
      ];
      if (matches.length != 1) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
      final index = matches.single;
      attempt = Map<String, dynamic>.from(list[index] as Map);
      attemptSource = {
        'parent': chain[pickupIndex]['observation_id'],
        'pointer': '/data/attempts/$index/id',
        'command': receipts[pickupIndex]['command_id'],
      };
    }
    final required = <String>[];
    if (type == 'ReportIssue') {
      if (chain.any(
        (p) =>
            !{'arrival', 'issue'}.contains(p['kind']) ||
            p['stop_id'] != o['stop_id'],
      )) {
        throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
      }
      if (_pickupPhotoId(o) != null) {
        _requirePickupPhoto(o);
        pickupMedia = _requireVerifiedPhoto(observationId, _pickupPhotoId(o));
        payload['asset_ids'] = [pickupMedia['asset_id']];
        mediaDependencies.add(pickupMedia['command'] as String);
      } else if ((o['assets'] as List).isNotEmpty) {
        throw const EncryptedStoreException('OBSERVATION_AUTHORITY_OVERRIDE');
      }
      required.add('rounds:${context['round_id']}');
      if (payload['delivery_id'] != null) {
        required.add('deliveries:${payload['delivery_id']}');
      }
    } else if (type == 'ConfirmArrival') {
      absent(['stop_id']);
      payload['stop_id'] = o['stop_id'];
      if (chain.isNotEmpty &&
          (attempt == null ||
              attempt['stop_id'] != o['stop_id'] ||
              chain.last['kind'] != 'pickup')) {
        throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
      }
      if (payload['point'] != null
          ? payload['accuracy_m'] is! num ||
                (payload['accuracy_m'] as num) < 0 ||
                payload['override_reason'] != null
          : payload['accuracy_m'] != null ||
                payload['override_reason'] is! String ||
                (payload['override_reason'] as String).trim().isEmpty) {
        throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
      }
      required.add('stops:${o['stop_id']}');
    } else if (type == 'ConfirmPickup') {
      absent(['round_id', 'pickup_stop_id']);
      payload['round_id'] = context['round_id'];
      payload['pickup_stop_id'] = o['stop_id'];
      if (chain.length != 1 ||
          chain.single['kind'] != 'arrival' ||
          chain.single['stop_id'] != o['stop_id']) {
        throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
      }
      final units = payload['fulfillment_unit_ids'];
      final allowed = context['stop_units'][o['stop_id']] as List;
      if (units is! List ||
          units.length != allowed.length ||
          units.toSet().length != units.length ||
          !allowed.every(units.contains) ||
          payload['manifest_ids'] is! List) {
        throw const EncryptedStoreException('OBSERVATION_OUTSIDE_CONTEXT');
      }
      required.addAll([
        'rounds:${context['round_id']}',
        'stops:${o['stop_id']}',
        for (final id in payload['manifest_ids'] as List) 'manifests:$id',
        for (final id in units) 'fulfillment_units:$id',
      ]);
    } else if (type == 'RecordHandoff') {
      absent(['attempt_id']);
      if (attempt == null ||
          attempt['stop_id'] != o['stop_id'] ||
          chain.isEmpty ||
          chain.last['kind'] != 'arrival' ||
          chain.last['stop_id'] != o['stop_id']) {
        throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
      }
      payload['attempt_id'] = attempt['id'];
      bind(attemptSource!, '/payload/attempt_id', attempt['id']);
      required.add('delivery_attempts:${attempt['id']}');
    } else {
      if (attempt == null ||
          attempt['stop_id'] != o['stop_id'] ||
          chain.isEmpty ||
          chain.last['stop_id'] != o['stop_id'] ||
          chain.last['fulfillment_unit_id'] != o['fulfillment_unit_id']) {
        throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
      }
      absent([
        'attempt_id',
        'handoff_id',
        'policy_version_id',
        'proof_submission_id',
      ]);
      payload['attempt_id'] = attempt['id'];
      bind(attemptSource!, '/payload/attempt_id', attempt['id']);
      required.add('delivery_attempts:${attempt['id']}');
      void fromLast(String field, String pointer, Object? value) {
        payload[field] = value;
        bind(
          {
            'parent': chain.last['observation_id'],
            'pointer': pointer,
            'command': receipts.last['command_id'],
          },
          '/payload/$field',
          value,
        );
      }

      if (type == 'SubmitProof') {
        if (chain.last['kind'] != 'handoff') {
          throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
        }
        fromLast(
          'handoff_id',
          '/data/handoff_id',
          receipts.last['data']['handoff_id'],
        );
        fromLast(
          'policy_version_id',
          '/data/proof_policy_version_id',
          receipts.last['data']['proof_policy_version_id'],
        );
        if (payload['evidence'] is! List) {
          throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
        }
        final evidence = payload['evidence'] as List;
        for (var i = 0; i < evidence.length; i++) {
          if (evidence[i] is! Map) {
            throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
          }
          final ref = Map<String, dynamic>.from(evidence[i] as Map);
          if (ref.containsKey('asset_id') ||
              ref.containsKey('location_observation_id')) {
            throw const EncryptedStoreException(
              'OBSERVATION_AUTHORITY_OVERRIDE',
            );
          }
          if (ref['kind'] == 'photo') {
            final media = _requireVerifiedPhoto(
              o['observation_id'] as String,
              ref.remove('local_asset_id'),
            );
            ref['asset_id'] = media['asset_id'];
            mediaDependencies.add(media['command'] as String);
            bind(
              {
                'parent': chain.last['observation_id'],
                'pointer': '/data/resource/id',
                'command': media['command'],
              },
              '/payload/evidence/$i/asset_id',
              media['asset_id'],
            );
          } else if (ref['kind'] == 'signature') {
            throw const EncryptedStoreException('COMMAND_NOT_CONNECTED');
          } else if (ref['kind'] == 'location') {
            final index = chain.lastIndexWhere(
              (p) => p['kind'] == 'arrival' && p['stop_id'] == o['stop_id'],
            );
            if (index < 0) {
              throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
            }
            final roots = receipts[index]['resources'] as List;
            final at = roots.indexWhere(
              (r) => r['aggregate_type'] == 'location_observations',
            );
            if (at < 0 ||
                roots
                        .where(
                          (r) => r['aggregate_type'] == 'location_observations',
                        )
                        .length !=
                    1) {
              throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
            }
            ref['location_observation_id'] = roots[at]['id'];
            bind(
              {
                'parent': chain[index]['observation_id'],
                'pointer': '/resources/$at/id',
                'command': receipts[index]['command_id'],
              },
              '/payload/evidence/$i/location_observation_id',
              roots[at]['id'],
            );
          }
          evidence[i] = ref;
        }
      } else {
        if (chain.last['kind'] != 'proof' || payload.length != 1) {
          throw const EncryptedStoreException('DEPENDENCY_SEQUENCE_INVALID');
        }
        fromLast(
          'proof_submission_id',
          '/data/resource/id',
          receipts.last['data']['resource']['id'],
        );
      }
    }
    if (required.toSet().length != required.length) {
      throw const EncryptedStoreException('INVALID_OBSERVED_ACTION');
    }
    final roots = <Map<String, dynamic>>[];
    for (final key in required..sort()) {
      final root = versions[key];
      if (root == null) {
        throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
      }
      if (sources[key] != null) {
        bind(
          sources[key]!,
          '/expected_versions/${roots.length}/version',
          root['version'],
        );
      }
      roots.add(root);
    }
    final id = _newCommandId();
    final wire = <String, dynamic>{
      'command_id': id,
      'context': {
        'tenant_id': context['tenant_id'],
        'city_id': context['city_id'],
      },
      'occurred_at': o['observed_at'],
      'expected_versions': roots,
      'payload': payload,
      'execution_fence': {
        'assignment_id': o['assignment_id'],
        'assignment_version': o['assignment_version'],
        'observation_id': observationId,
      },
    };
    validateCommandWire('${type}Request', wire);
    final bytes = canonicalNativeCommand(wire),
        digest = _requestDigest(type, wire);
    await _boundary('command_before_commit');
    _commit(() {
      _db.execute(
        'INSERT INTO pending_commands(command_id,principal_id,tenant_id,command_type,payload_json,request_hash,expected_versions_json,occurred_at,queued_at,state) VALUES(?,?,?,?,?,?,?,?,?,\'queued\')',
        [
          id,
          _device.principalId,
          context['tenant_id'],
          type,
          bytes,
          digest,
          canonicalNativeCommand(roots),
          o['observed_at'],
          _commandClock().toUtc().toIso8601String(),
        ],
      );
      _db.execute(
        'UPDATE local_observations SET command_id=? WHERE observation_id=? AND principal_id=? AND command_id IS NULL',
        [id, observationId, _device.principalId],
      );
      for (final r in roots) {
        _db.execute('INSERT INTO command_roots VALUES(?,?,?,?)', [
          id,
          r['aggregate_type'],
          r['id'],
          r['version'],
        ]);
      }
      for (final r in receipts) {
        _db.execute('INSERT INTO command_dependencies VALUES(?,?)', [
          id,
          r['command_id'],
        ]);
      }
      for (final dependency in mediaDependencies.toSet()) {
        _db.execute('INSERT INTO command_dependencies VALUES(?,?)', [
          id,
          dependency,
        ]);
      }
      for (final b in bindings) {
        _db.execute('INSERT INTO observation_bindings VALUES(?,?,?,?,?,?,?)', [
          _device.principalId,
          observationId,
          b['parent'],
          b['pointer'],
          b['target'],
          canonicalNativeCommand(b['value']),
          b['command'],
        ]);
      }
      if (pickupMedia != null) _bindPickupPhotoReport(o, id, pickupMedia);
    });
    await _boundary('command_queued');
    return StoredExecutionCommand._(_commandRow(id));
  });

  Future<StoredExecutionCommand?> observationCommand(String id) => _serial(
    () async {
      final row = _observationRow(id);
      return row?['command_id'] == null
          ? null
          : StoredExecutionCommand._(_commandRow(row!['command_id'] as String));
    },
  );

  /// At most one POST or GET. Serial store ownership prevents concurrent sends.
  /// Persist sending before IO; any interrupted send restarts with status only.
  Future<StoredExecutionCommand> synchronizeObservation(
    String id, {
    required DriverDeviceRegistrationClient transport,
    required String bearer,
  }) => _serial(() async {
    final o = _observationRow(id);
    if (o == null || o['command_id'] == null) {
      throw const EncryptedStoreException('COMMAND_NOT_MATERIALIZED');
    }
    return _synchronizeCommand(
      _commandRow(o['command_id'] as String),
      o,
      transport: transport,
      bearer: bearer,
      observationId: id,
    );
  });

  Future<StoredExecutionCommand> _synchronizeCommand(
    Map<String, Object?> row,
    Map<String, Object?> o, {
    required DriverDeviceRegistrationClient transport,
    required String bearer,
    String? observationId,
  }) async {
    final commandId = row['command_id'] as String;
    if ({
      'committed',
      'rejected',
      'retained_for_review',
      'needs_review',
    }.contains(row['state'])) {
      return StoredExecutionCommand._(row);
    }
    final now = _commandClock().toUtc();
    if (row['next_retry_at'] != null &&
        DateTime.parse(row['next_retry_at'] as String).isAfter(now)) {
      return StoredExecutionCommand._(row);
    }
    final status = row['state'] == 'unknown' || row['state'] == 'sending';
    final observation =
        jsonDecode(o['payload_json'] as String) as Map<String, dynamic>;
    if (!status && !_fenceCurrent(observation)) {
      _commandState(
        commandId,
        'needs_review',
        error: 'EXECUTION_FENCE_CHANGED',
      );
      return StoredExecutionCommand._(_commandRow(commandId));
    }
    if (_db.select(
      'SELECT 1 FROM command_dependencies d JOIN pending_commands c ON c.command_id=d.depends_on_command_id WHERE d.command_id=? AND (c.principal_id<>? OR c.state<>\'committed\') LIMIT 1',
      [commandId, _device.principalId],
    ).isNotEmpty) {
      throw const EncryptedStoreException('DEPENDENCY_UNRESOLVED');
    }
    final saved = await _inspectObservation(o);
    if (saved.state != 'local_recorded') {
      throw const EncryptedStoreException('EVIDENCE_REQUIRES_RECOVERY');
    }
    _commit(
      () => _db.execute(
        'UPDATE pending_commands SET state=?,attempts=attempts+1 WHERE command_id=?',
        [status ? 'unknown' : 'sending', commandId],
      ),
    );
    await _boundary('command_before_http');
    try {
      final reply = await transport.exchangeExecutionCommand(
        device: _device,
        bearer: bearer,
        commandType: row['command_type'] as String,
        frozenRequest: row['payload_json'] as String,
        statusOnly: status,
      );
      _active();
      final r = reply.toJson();
      if (reply.httpStatus != 200) {
        final absent =
            status && reply.httpStatus == 404 && r['code'] == 'NOT_FOUND';
        _commandState(
          commandId,
          absent && _fenceCurrent(observation) ? 'queued' : 'unknown',
          error: r['code'] as String,
          retry: true,
          retryAfterSeconds: reply.retryAfterSeconds,
        );
      } else if (r['state'] == 'committed' || r['state'] == 'rejected') {
        _checkReceipt(row, r);
        await _boundary('command_before_receipt');
        _commit(() {
          _db.execute(
            'UPDATE pending_commands SET state=?,server_receipt_json=?,next_retry_at=NULL,error_code=? WHERE command_id=?',
            [
              r['state'],
              canonicalNativeCommand(r),
              r['state'] == 'rejected' ? r['error']['code'] : null,
              commandId,
            ],
          );
          if (observationId != null) {
            _db.execute(
              'UPDATE local_observations SET reconciled_at=? WHERE observation_id=?',
              [_commandClock().toUtc().toIso8601String(), observationId],
            );
          }
        });
        await _boundary('command_receipt_committed');
      } else {
        _commandState(
          commandId,
          'unknown',
          error: 'UNKNOWN_RESULT',
          retry: true,
        );
      }
    } on DeviceEnrollmentException catch (error) {
      // A denial invalidates the store. Never persist/return through a new login.
      _active();
      _commandState(commandId, 'unknown', error: error.code, retry: true);
    }
    return StoredExecutionCommand._(_commandRow(commandId));
  }

  Map<String, Object?> _commandRow(String id) {
    final rows = _db.select(
      'SELECT * FROM pending_commands WHERE command_id=? AND principal_id=?',
      [id, _device.principalId],
    );
    if (rows.length != 1) {
      throw const EncryptedStoreException('COMMAND_NOT_FOUND');
    }
    final r = rows.single,
        wire = jsonDecode(r['payload_json'] as String) as Map<String, dynamic>;
    if (wire['command_id'] != id ||
        canonicalNativeCommand(wire) != r['payload_json'] ||
        _requestDigest(r['command_type'] as String, wire) !=
            r['request_hash'] ||
        canonicalNativeCommand(wire['expected_versions']) !=
            r['expected_versions_json']) {
      throw const EncryptedStoreException('COMMAND_REQUIRES_RECOVERY');
    }
    validateCommandWire('${r['command_type']}Request', wire);
    return r;
  }

  bool _fenceCurrent(Map<String, dynamic> o) =>
      _db.select(
        'SELECT 1 FROM execution_fences WHERE principal_id=? AND assignment_id=? AND assignment_version=? AND accepted_scope_hash=? AND invalidated_at IS NULL',
        [
          _device.principalId,
          o['assignment_id'],
          o['assignment_version'],
          o['execution_context']['accepted_scope_hash'],
        ],
      ).length ==
      1;
  void _commandState(
    String id,
    String state, {
    String? error,
    bool retry = false,
    int retryAfterSeconds = 30,
  }) => _commit(
    () => _db.execute(
      'UPDATE pending_commands SET state=?,error_code=?,next_retry_at=? WHERE command_id=?',
      [
        state,
        error,
        retry
            ? _commandClock()
                  .toUtc()
                  .add(Duration(seconds: max(30, retryAfterSeconds)))
                  .toIso8601String()
            : null,
        id,
      ],
    ),
  );
  void _checkReceipt(Map<String, Object?> row, Map<String, dynamic> r) {
    final type = row['command_type'] as String;
    validateCommandWire(
      r['state'] == 'rejected'
          ? 'RejectedCommandStatus'
          : type == 'ReserveAsset'
          ? 'ReserveAssetReceipt'
          : '${type}Result',
      r,
    );
    if (r['command_id'] != row['command_id'] || r['command_type'] != type) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (r['state'] == 'rejected') return;
    final wire =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
        payload = wire['payload'] as Map;
    final seen = <String>{};
    for (final field in ['current_versions', 'resources']) {
      for (final root in r[field] as List) {
        if (!seen.add('${root['aggregate_type']}:${root['id']}')) {
          throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
        }
      }
    }
    final changed = r['current_versions'] as List;
    final expected = wire['expected_versions'] as List;
    if (type == 'ReportIssue') {
      // Reporting may leave an already-held delivery/Round unchanged. Only
      // actual changed selected roots may increment; no synthetic +1 for waits.
      final resources = r['resources'] as List;
      if (r['data']['state'] != 'open' ||
          resources.length != 1 ||
          resources.single['aggregate_type'] != 'issues' ||
          resources.single['version'] != 1 ||
          canonicalNativeCommand(resources.single) !=
              canonicalNativeCommand(r['data']['resource']) ||
          payload['issue_type'] == 'pickup_wait' && changed.isNotEmpty ||
          changed.any(
            (v) => !expected.any(
              (e) =>
                  e['aggregate_type'] == v['aggregate_type'] &&
                  e['id'] == v['id'] &&
                  v['version'] == e['version'] + 1,
            ),
          )) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
      return;
    }
    for (final old in expected) {
      final matches = changed
          .where(
            (v) =>
                v['aggregate_type'] == old['aggregate_type'] &&
                v['id'] == old['id'],
          )
          .toList();
      if (matches.length != 1 ||
          matches.single['version'] != old['version'] + 1) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
    }
    if (type == 'ConfirmArrival') {
      final stop = changed
          .where(
            (v) =>
                v['aggregate_type'] == 'stops' && v['id'] == payload['stop_id'],
          )
          .toList();
      if (stop.length != 1 ||
          canonicalNativeCommand(stop.single) !=
              canonicalNativeCommand(r['data']['resource']) ||
          changed.length > 2 ||
          changed.any(
            (v) =>
                v['aggregate_type'] != 'stops' &&
                v['aggregate_type'] != 'delivery_attempts',
          )) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
    } else if (!{'SubmitProof', 'CompleteDelivery'}.contains(type) &&
        changed.length != expected.length) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'ConfirmArrival' &&
            r['data']['resource']['id'] != payload['stop_id'] ||
        type == 'RecordHandoff' &&
            r['data']['attempt_id'] != payload['attempt_id']) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'ConfirmPickup') {
      final units = payload['fulfillment_unit_ids'] as List,
          attempts = r['data']['attempts'] as List;
      if (attempts.length != units.length ||
          attempts.map((a) => a['fulfillment_unit_id']).toSet().length !=
              units.length ||
          attempts.any((a) => !units.contains(a['fulfillment_unit_id']))) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
      final collected = r['data']['collected_units'] as List;
      if (collected.length != units.length ||
          collected.map((u) => u['id']).toSet().length != units.length ||
          collected.any((u) => !units.contains(u['id'])) ||
          attempts.map((a) => a['id']).toSet().length != attempts.length ||
          attempts.any(
            (a) => !(r['resources'] as List).any(
              (v) =>
                  v['aggregate_type'] == 'delivery_attempts' &&
                  v['id'] == a['id'] &&
                  v['version'] == a['version'],
            ),
          )) {
        throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
      }
    }
    if (type == 'RecordHandoff' &&
        canonicalNativeCommand(r['data']['quantities']) !=
            canonicalNativeCommand(payload['quantities'])) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'ReserveAsset' &&
        ((r['resources'] as List).length != 1 ||
            r['resources'][0]['aggregate_type'] != 'assets' ||
            r['resources'][0]['id'] != r['data']['asset_id'] ||
            r['resources'][0]['version'] != 1)) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'VerifyAsset' &&
        (r['data']['state'] != 'verified' ||
            r['data']['resource']['id'] != payload['asset_id'] ||
            canonicalNativeCommand(r['data']['resource']) !=
                canonicalNativeCommand(changed.single))) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'SubmitProof' &&
        (r['data']['state'] != 'pending' ||
            !(r['resources'] as List).any(
              (v) =>
                  canonicalNativeCommand(v) ==
                  canonicalNativeCommand(r['data']['resource']),
            ) ||
            changed.any(
              (v) => !{
                'delivery_attempts',
                'deliveries',
              }.contains(v['aggregate_type']),
            ))) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
    if (type == 'CompleteDelivery' &&
        (r['data']['state'] != 'completed' ||
            r['data']['resource']['id'] != payload['attempt_id'] ||
            !changed.any(
              (v) =>
                  canonicalNativeCommand(v) ==
                  canonicalNativeCommand(r['data']['resource']),
            ) ||
            !changed.any(
              (v) =>
                  v['aggregate_type'] == 'proof_submissions' &&
                  v['id'] == payload['proof_submission_id'],
            ))) {
      throw const EncryptedStoreException('INVALID_RECEIPT_BINDING');
    }
  }
}

String _requestDigest(String type, Map<String, dynamic> wire) => hash.sha256
    .convert(
      utf8.encode(
        canonicalNativeCommand({
          'protocol': 'rounds-v23-r1',
          'command_type': type,
          'request': wire,
        }),
      ),
    )
    .toString();
String _newCommandId() {
  final random = Random.secure(),
      bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
