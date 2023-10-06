import 'dart:isolate';

import 'package:isar/isar.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:yana/models/metadata.dart';
import 'package:yana/models/relay_list.dart';
import 'package:yana/nostr/nip02/contact_list.dart';
import 'package:yana/utils/platform_util.dart';

class DB {
  static const _VERSION = 6;

  static const _dbName = "yana.db";

  static Database? _database;

  late Future<Isar> dbFuture;

  static late Isar _db;
  late SendPort _dbWorkerSendPort;

  static init() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = await Isar.open(
      [RelayListSchema, ContactListSchema, MetadataSchema],
      directory: dir.path,
    );
    String path = _dbName;

    if (!PlatformUtil.isWeb()) {
      var databasesPath =
          PlatformUtil.isWindowsOrLinux() ? "/tmp/" : await getDatabasesPath();
      path = join(databasesPath, _dbName);
    }

    _database = await openDatabase(path, version: _VERSION,
        onOpen: (Database db) async {
      print('Database version ${await db.getVersion()}');
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      print("Migration Database from $oldVersion to $newVersion");
      if (newVersion == _VERSION && oldVersion < 4) {
        String sql = "ALTER TABLE dm_session_info ADD known INTEGER";
        print("Migration SQL: $sql");
        await db.execute(sql);
      }
    }, onCreate: (Database db, int version) async {
      db.execute(
          "create table event(key_index  INTEGER, id         text,pubkey     text,created_at integer,kind       integer,tags       text,content    text);");
      db.execute(
          "create unique index event_key_index_id_uindex on event (key_index, id);");
      db.execute(
          "create index event_date_index    on event (key_index, kind, created_at);");
      db.execute(
          "create index event_pubkey_index    on event (key_index, kind, pubkey, created_at);");
      db.execute(
          "create table dm_session_info(key_index  INTEGER, pubkey      text    not null,readed_time integer not null,known INTEGER, value1      text,value2      text,value3      text);");
      db.execute(
          "create unique index dm_session_info_uindex on dm_session_info (key_index, pubkey);");
    });
  }

  static Future<Database> getCurrentDatabase() async {
    if (_database == null) {
      await init();
    }
    return _database!;
  }

  static Future<DatabaseExecutor> getDB(DatabaseExecutor? db) async {
    if (db != null) {
      return db;
    }
    return getCurrentDatabase();
  }

  static Isar getIsar() {
    return _db;
  }

  static void close() {
    _database?.close();
    _database = null;
  }
}
