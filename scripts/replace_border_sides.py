# -*- coding: utf-8 -*-
"""
统一替换项目中的装饰性 BorderSide 为 ThemedBorder

注意：
1. 只替换用于 Border(top/bottom/left/right) 的装饰性边框
2. 不替换按钮的 side: BorderSide(...) 属性
3. 使用 UTF-8 编码读写文件
"""

import os
import re
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(r"e:\Aaalice_NAI_Launcher\lib\presentation")

# ThemedBorder 的相对导入路径
THEMED_BORDER_IMPORT = "import '{}widgets/common/themed_border.dart';"

# 需要跳过的文件
SKIP_FILES = [
    "themed_border.dart",
    "themed_divider.dart",
]

# 替换统计
stats = {
    "files_scanned": 0,
    "files_modified": 0,
    "borders_replaced": 0,
    "imports_added": 0,
    "skipped_complex": [],
}


def calculate_relative_import(file_path: Path) -> str:
    """计算从当前文件到 widgets/common/themed_border.dart 的相对路径"""
    try:
        rel_path = file_path.relative_to(PROJECT_ROOT)
    except ValueError:
        return None

    depth = len(rel_path.parts) - 1
    prefix = "../" * depth

    return THEMED_BORDER_IMPORT.format(prefix)


def has_themed_border_import(content: str) -> bool:
    """检查文件是否已导入 ThemedBorder"""
    return "themed_border.dart" in content


def add_import_statement(content: str, import_stmt: str) -> str:
    """在适当位置添加 import 语句"""
    lines = content.split('\n')

    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("import "):
            last_import_idx = i

    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, import_stmt)
    else:
        lines.insert(0, import_stmt)

    return '\n'.join(lines)


def replace_border_sides(content: str, file_path: Path) -> tuple[str, int]:
    """
    替换装饰性 BorderSide 为 ThemedBorder
    返回: (新内容, 替换数)
    """
    count = 0

    # 模式1: border: Border(bottom: BorderSide(color: xxx.outlineVariant.withOpacity(0.3), width: 1))
    # 替换为: border: ThemedBorder.bottom(context)
    patterns = [
        # bottom BorderSide with outlineVariant
        (
            r'border:\s*Border\(\s*bottom:\s*BorderSide\(\s*color:\s*colorScheme\.outlineVariant\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.bottom(context)',
        ),
        # top BorderSide with outlineVariant
        (
            r'border:\s*Border\(\s*top:\s*BorderSide\(\s*color:\s*colorScheme\.outlineVariant\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.top(context)',
        ),
        # left BorderSide with outlineVariant
        (
            r'border:\s*Border\(\s*left:\s*BorderSide\(\s*color:\s*colorScheme\.outlineVariant\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.left(context)',
        ),
        # right BorderSide with outlineVariant
        (
            r'border:\s*Border\(\s*right:\s*BorderSide\(\s*color:\s*colorScheme\.outlineVariant\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.right(context)',
        ),
        # bottom with theme.dividerColor
        (
            r'border:\s*Border\(\s*bottom:\s*BorderSide\(\s*color:\s*theme\.dividerColor\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.bottom(context)',
        ),
        # top with theme.dividerColor
        (
            r'border:\s*Border\(\s*top:\s*BorderSide\(\s*color:\s*theme\.dividerColor\.withOpacity\([\d.]+\),?\s*(?:width:\s*1,?)?\s*\),?\s*\)',
            'border: ThemedBorder.top(context)',
        ),
        # bottom with dividerColor (no opacity)
        (
            r'border:\s*Border\(\s*bottom:\s*BorderSide\(\s*color:\s*theme\.dividerColor\),?\s*\)',
            'border: ThemedBorder.bottom(context)',
        ),
        # top with dividerColor (no opacity)
        (
            r'border:\s*Border\(\s*top:\s*BorderSide\(\s*color:\s*theme\.dividerColor\),?\s*\)',
            'border: ThemedBorder.top(context)',
        ),
    ]

    for pattern, replacement in patterns:
        content, n = re.subn(pattern, replacement, content, flags=re.DOTALL)
        count += n

    # 检测复杂模式（记录但不替换）
    complex_patterns = [
        r'BorderSide\([^)]*Colors\.white',  # 白色边框
        r'BorderSide\([^)]*colorScheme\.primary',  # 主色边框
    ]

    for pattern in complex_patterns:
        if re.search(pattern, content):
            stats["skipped_complex"].append(
                f"{file_path.name}: Complex BorderSide pattern")
            break

    return content, count


def process_file(file_path: Path) -> bool:
    """处理单个文件，返回是否修改"""
    if file_path.name in SKIP_FILES:
        return False

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
    except UnicodeDecodeError:
        print(f"  [跳过] 编码错误: {file_path}")
        return False

    stats["files_scanned"] += 1

    # 检查是否有需要替换的内容
    if 'BorderSide(' not in original_content:
        return False

    # 执行替换
    new_content, count = replace_border_sides(original_content, file_path)

    if count == 0:
        return False

    # 检查是否需要添加 import
    import_added = False
    if not has_themed_border_import(new_content):
        import_stmt = calculate_relative_import(file_path)
        if import_stmt:
            new_content = add_import_statement(new_content, import_stmt)
            import_added = True
            stats["imports_added"] += 1

    # 写回文件
    if new_content != original_content:
        with open(file_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(new_content)

        stats["files_modified"] += 1
        stats["borders_replaced"] += count

        print(f"  [修改] {file_path.relative_to(PROJECT_ROOT.parent.parent)}")
        print(
            f"         BorderSide: {count}, Import: {'添加' if import_added else '已存在'}")
        return True

    return False


def main():
    print("=" * 60)
    print("统一替换装饰性 BorderSide -> ThemedBorder")
    print("=" * 60)
    print(f"\n扫描目录: {PROJECT_ROOT}\n")

    dart_files = list(PROJECT_ROOT.rglob("*.dart"))
    print(f"找到 {len(dart_files)} 个 Dart 文件\n")

    for file_path in dart_files:
        process_file(file_path)

    print("\n" + "=" * 60)
    print("替换统计")
    print("=" * 60)
    print(f"扫描文件数:            {stats['files_scanned']}")
    print(f"修改文件数:            {stats['files_modified']}")
    print(f"替换 BorderSide 数:    {stats['borders_replaced']}")
    print(f"添加 import 数:        {stats['imports_added']}")

    if stats["skipped_complex"]:
        print("\n" + "-" * 60)
        print("需要手动处理的复杂情况（已记录）:")
        print("-" * 60)
        seen = set()
        for item in stats["skipped_complex"]:
            if item not in seen:
                print(f"  - {item}")
                seen.add(item)

    print("\n完成!")


if __name__ == "__main__":
    main()
