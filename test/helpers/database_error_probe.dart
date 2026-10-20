import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseException> databaseErrorCarrying(String text) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
  );
  try {
    await db.execute('CREATE TABLE probe (text TEXT UNIQUE)');
    await db.insert('probe', {'text': text});
    await db.insert('probe', {'text': text});
  } on DatabaseException catch (error) {
    return error;
  } finally {
    await db.close();
  }
  throw StateError('duplicate insert unexpectedly succeeded');
}
