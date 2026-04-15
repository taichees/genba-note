import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final databaseConnectionProvider = FutureProvider<Database>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  return database.open();
});
