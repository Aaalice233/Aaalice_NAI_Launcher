# 数据库连接管理迁移指南

## 概述

本项目已从手动数据库连接管理迁移到基于租借（Lease）的连接管理模式。
本指南帮助开发者从旧 API 迁移到新 API。

## 旧 API (已废弃)

### 手动获取和释放连接

```dart
// 旧模式 - 已废弃
final db = await _acquireDb();
try {
  await db.query(...);
} finally {
  await _releaseDb(db);
}
```

### 使用重试包装器

```dart
// 旧模式 - 已废弃
final result = await _executeWithRetry(
  (db) => db.query(...),
  operationName: 'my_operation',
);
```

## 新 API (推荐)

### 方法 1: 使用 BaseDataSource.execute() (推荐)

适用于简单的单次数据库操作，自动管理连接生命周期：

```dart
final result = await execute(
  'operation_name',
  (db) async {
    return await db.query(...);
  },
  timeout: const Duration(seconds: 10),
  maxRetries: 3,
);
```

### 方法 2: 使用 acquireLease()

适用于需要长时间持有连接或多个操作的场景：

```dart
final lease = await acquireLease(
  operationId: 'my_operation',
  timeout: const Duration(seconds: 5),
);

try {
  final result = await lease.execute(
    (db) => db.query(...),
    validateBefore: true,
  );
} finally {
  await lease.dispose();
}
```

### 方法 3: 使用 _executeWithLease() (内部方法)

适用于需要额外错误处理和重试逻辑的场景：

```dart
final result = await _executeWithLease(
  (db) => db.query(...),
  operationName: 'my_operation',
);
```

## 批量操作

### 使用流式批处理

```dart
await for (final item in _executeBatchWithLease(items, (db, item) async {
  await db.insert(...);
})) {
  // 处理完成的 item
}
```

## 废弃方法列表

| 方法 | 废弃原因 | 替代方案 |
|------|---------|---------|
| `_acquireDb()` | 手动连接管理容易出错 | `acquireLease()` 或 `execute()` |
| `_releaseDb()` | 配合 `_acquireDb()` 使用 | `lease.dispose()` |
| `_executeWithRetry()` | 已被新架构取代 | `_executeWithLease()` 或 `execute()` |
| `_executeWithLease()` | 内部私有方法 | `BaseDataSource.execute()` 或 `SimpleLeaseHelper` |

## 迁移检查清单

- [ ] 替换所有 `_acquireDb()` + `_releaseDb()` 组合
- [ ] 替换所有 `_executeWithRetry()` 调用
- [ ] 确保使用 `try/finally` 或 `execute()` 自动管理连接
- [ ] 测试数据库操作在连接池重置后的恢复能力

## 注意事项

1. **连接生命周期**: 新架构自动管理连接生命周期，不需要手动释放
2. **错误处理**: `execute()` 自动处理重试和超时
3. **并发安全**: 租借机制确保连接在并发场景下的安全性
4. **性能**: 连接池复用连接，无需担心频繁获取/释放的性能问题
