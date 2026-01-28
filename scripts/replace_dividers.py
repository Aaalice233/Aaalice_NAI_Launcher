# -*- coding: utf-8 -*-
"""
统一替换项目中的 Divider/VerticalDivider 为 ThemedDivider
注意：
1. 使用 UTF-8 编码读写文件
2. 严格匹配模式
3. 自动添加 import 语句
4. 跳过已使用 ThemedDivider 的文件中的 ThemedDivider 调用
"""

import os
import re
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(r"e:\Aaalice_NAI_Launcher\lib\presentation")

# ThemedDivider 的相对导入路径（从 widgets/common/themed_divider.dart）
THEMED_DIVIDER_IMPORT = "import '{}widgets/common/themed_divider.dart';"

# 需要跳过的文件（ThemedDivider 自身定义文件）
SKIP_FILES = [
    "themed_divider.dart",
]

# 替换统计
stats = {
    "files_scanned": 0,
    "files_modified": 0,
    "dividers_replaced": 0,
    "vertical_dividers_replaced": 0,
    "imports_added": 0,
    "skipped_complex": [],  # 跳过的复杂情况
}


def calculate_relative_import(file_path: Path) -> str:
    """计算从当前文件到 widgets/common/themed_divider.dart 的相对路径"""
    # 获取相对于 lib/presentation 的路径
    try:
        rel_path = file_path.relative_to(PROJECT_ROOT)
    except ValueError:
        return None

    # 计算需要向上的层数
    depth = len(rel_path.parts) - 1  # -1 因为最后一个是文件名
    prefix = "../" * depth

    return THEMED_DIVIDER_IMPORT.format(prefix)


def has_themed_divider_import(content: str) -> bool:
    """检查文件是否已导入 ThemedDivider"""
    return "themed_divider.dart" in content


def add_import_statement(content: str, import_stmt: str) -> str:
    """在适当位置添加 import 语句"""
    lines = content.split('\n')

    # 找到最后一个 import 语句的位置
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("import "):
            last_import_idx = i

    if last_import_idx >= 0:
        # 在最后一个 import 后插入
        lines.insert(last_import_idx + 1, import_stmt)
    else:
        # 没有 import，在文件开头插入
        lines.insert(0, import_stmt)

    return '\n'.join(lines)


def replace_dividers(content: str, file_path: Path) -> tuple[str, int, int]:
    """
    替换 Divider 和 VerticalDivider 为 ThemedDivider
    返回: (新内容, 替换的Divider数, 替换的VerticalDivider数)
    """
    divider_count = 0
    vertical_count = 0

    # 模式1: const Divider() 或 Divider()
    pattern1 = r'\bconst\s+Divider\s*\(\s*\)'
    replacement1 = 'const ThemedDivider()'
    content, n = re.subn(pattern1, replacement1, content)
    divider_count += n

    # 模式2: const Divider(height: N) - 简单的 height 参数
    pattern2 = r'\bconst\s+Divider\s*\(\s*height\s*:\s*(\d+(?:\.\d+)?)\s*\)'
    replacement2 = r'const ThemedDivider(height: \1)'
    content, n = re.subn(pattern2, replacement2, content)
    divider_count += n

    # 模式3: Divider(height: N, ...) 非 const
    pattern3 = r'(?<!\bconst\s)\bDivider\s*\(\s*height\s*:\s*(\d+(?:\.\d+)?)\s*\)'
    replacement3 = r'ThemedDivider(height: \1)'
    content, n = re.subn(pattern3, replacement3, content)
    divider_count += n

    # 模式4: const VerticalDivider(width: 1, indent: N, endIndent: M)
    pattern4 = r'\bconst\s+VerticalDivider\s*\(\s*width\s*:\s*1\s*,\s*indent\s*:\s*(\d+)\s*,\s*endIndent\s*:\s*(\d+)\s*\)'
    replacement4 = r'const ThemedDivider(height: 1, vertical: true, indent: \1, endIndent: \2)'
    content, n = re.subn(pattern4, replacement4, content)
    vertical_count += n

    # 模式5: VerticalDivider( 带动态参数 - 记录但不替换
    pattern5_check = r'VerticalDivider\s*\([^)]*(?:color|thickness)\s*:'
    if re.search(pattern5_check, content):
        stats["skipped_complex"].append(
            f"{file_path}: VerticalDivider with color/thickness")

    # 模式6: Divider( 带 color 参数 - 记录但不替换（需要手动处理）
    pattern6_check = r'Divider\s*\([^)]*color\s*:'
    if re.search(pattern6_check, content):
        stats["skipped_complex"].append(
            f"{file_path}: Divider with color parameter")

    return content, divider_count, vertical_count


def process_file(file_path: Path) -> bool:
    """处理单个文件，返回是否修改"""
    # 跳过特定文件
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
    if 'Divider(' not in original_content and 'VerticalDivider(' not in original_content:
        return False

    # 如果只有 ThemedDivider 没有原生 Divider，跳过
    if 'ThemedDivider(' in original_content:
        # 检查是否还有原生 Divider（排除 ThemedDivider）
        temp = re.sub(r'ThemedDivider\s*\(', '', original_content)
        if 'Divider(' not in temp and 'VerticalDivider(' not in temp:
            return False

    # 执行替换
    new_content, divider_count, vertical_count = replace_dividers(
        original_content, file_path)

    total_replaced = divider_count + vertical_count
    if total_replaced == 0:
        return False

    # 检查是否需要添加 import
    import_added = False
    if not has_themed_divider_import(new_content):
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
        stats["dividers_replaced"] += divider_count
        stats["vertical_dividers_replaced"] += vertical_count

        print(f"  [修改] {file_path.relative_to(PROJECT_ROOT.parent.parent)}")
        print(
            f"         Divider: {divider_count}, VerticalDivider: {vertical_count}, Import: {'添加' if import_added else '已存在'}")
        return True

    return False


def main():
    print("=" * 60)
    print("统一替换 Divider/VerticalDivider -> ThemedDivider")
    print("=" * 60)
    print(f"\n扫描目录: {PROJECT_ROOT}\n")

    # 遍历所有 .dart 文件
    dart_files = list(PROJECT_ROOT.rglob("*.dart"))
    print(f"找到 {len(dart_files)} 个 Dart 文件\n")

    for file_path in dart_files:
        process_file(file_path)

    # 打印统计
    print("\n" + "=" * 60)
    print("替换统计")
    print("=" * 60)
    print(f"扫描文件数:            {stats['files_scanned']}")
    print(f"修改文件数:            {stats['files_modified']}")
    print(f"替换 Divider 数:       {stats['dividers_replaced']}")
    print(f"替换 VerticalDivider:  {stats['vertical_dividers_replaced']}")
    print(f"添加 import 数:        {stats['imports_added']}")

    if stats["skipped_complex"]:
        print("\n" + "-" * 60)
        print("需要手动处理的复杂情况:")
        print("-" * 60)
        for item in stats["skipped_complex"]:
            print(f"  - {item}")

    print("\n完成!")


if __name__ == "__main__":
    main()
