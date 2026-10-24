import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the [QueryExecutor] backing the SQLite offline cache.
Future<QueryExecutor> openLocalDatabase({
  String fileName = 'crystal_messenger.db',
}) async {
  Directory documents;
  try {
    documents = await getApplicationDocumentsDirectory();
  } on MissingPluginException {
    documents = Directory.systemTemp;
  }
  final file = File(p.join(documents.path, fileName));
  return NativeDatabase.createInBackground(file);
}
