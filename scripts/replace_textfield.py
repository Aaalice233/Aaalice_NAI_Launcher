#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TextField/TextFormField 批量替换脚本

将 TextField 替换为 ThemedInput
将 TextFormField 替换为 ThemedFormInput

使用方法:
    python replace_textfield.py [--dry-run]
    
    --dry-run: 仅预览变更，不实际修改文件
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional

# 项目根目录
PROJECT_ROOT = Path(r"e:\Aaalice_NAI_Launcher")
LIB_DIR = PROJECT_ROOT / "lib"

# 跳过的文件（这些文件需要手动处理）
SKIP_FILES = {
    "themed_input.dart",
    "themed_form_input.dart",
    "autocomplete_text_field.dart",
    "draggable_number_input.dart",
    "themed_dropdown.dart",
}

# ThemedInput 的 import 路径
THEMED_INPUT_IMPORT = "import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';"
THEMED_FORM_INPUT_IMPORT = "import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';"

# 统计信息
stats = {
    "files_scanned": 0,
    "files_modified": 0,
    "textfield_replaced": 0,
    "textformfield_replaced": 0,
    "skipped_files": [],
}


def find_matching_paren(text: str, start: int) -> int:
    """
    从 start 位置开始找到匹配的右括号位置
    start 应该是左括号 '(' 的位置
    """
    if start >= len(text) or text[start] != '(':
        return -1

    depth = 0
    i = start
    while i < len(text):
        char = text[i]
        if char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return i
        elif char == '"' or char == "'":
            # 跳过字符串
            quote = char
            i += 1
            while i < len(text) and text[i] != quote:
                if text[i] == '\\':
                    i += 1  # 跳过转义字符
                i += 1
        i += 1
    return -1


def extract_decoration_props(decoration_content: str) -> dict:
    """
    从 InputDecoration 内容中提取属性
    """
    props = {}

    # 提取 hintText
    hint_match = re.search(
        r"hintText:\s*['\"]([^'\"]*)['\"]", decoration_content)
    if hint_match:
        props['hintText'] = hint_match.group(1)

    # 提取 hintText (变量形式)
    hint_var_match = re.search(r"hintText:\s*(\w+)", decoration_content)
    if hint_var_match and not hint_match:
        props['hintText_var'] = hint_var_match.group(1)

    # 提取 labelText
    label_match = re.search(
        r"labelText:\s*['\"]([^'\"]*)['\"]", decoration_content)
    if label_match:
        props['labelText'] = label_match.group(1)

    # 提取 prefixIcon
    prefix_match = re.search(
        r"prefixIcon:\s*(.+?)(?:,\s*(?:suffixIcon|hintText|labelText|border|contentPadding)|\s*\))", decoration_content, re.DOTALL)
    if prefix_match:
        props['prefixIcon'] = prefix_match.group(1).strip().rstrip(',')

    # 提取 suffixIcon
    suffix_match = re.search(
        r"suffixIcon:\s*(.+?)(?:,\s*(?:prefixIcon|hintText|labelText|border|contentPadding)|\s*\))", decoration_content, re.DOTALL)
    if suffix_match:
        props['suffixIcon'] = suffix_match.group(1).strip().rstrip(',')

    # 提取 contentPadding
    padding_match = re.search(
        r"contentPadding:\s*(EdgeInsets[^,\)]+)", decoration_content)
    if padding_match:
        props['contentPadding'] = padding_match.group(1).strip()

    return props


def replace_textfield_in_content(content: str, dry_run: bool = False) -> tuple[str, int, int]:
    """
    在内容中替换 TextField 和 TextFormField
    返回: (修改后的内容, TextField替换数, TextFormField替换数)
    """
    textfield_count = 0
    textformfield_count = 0

    # 查找所有 TextField( 和 TextFormField( 的位置
    # 使用简单的替换策略：只替换类名，保留大部分参数

    # 替换 TextFormField (先处理更长的名字)
    pattern_form = r'\bTextFormField\s*\('
    for match in list(re.finditer(pattern_form, content)):
        textformfield_count += 1

    if textformfield_count > 0:
        content = re.sub(pattern_form, 'ThemedFormInput(', content)

    # 替换 TextField
    pattern_text = r'\bTextField\s*\('
    for match in list(re.finditer(pattern_text, content)):
        textfield_count += 1

    if textfield_count > 0:
        content = re.sub(pattern_text, 'ThemedInput(', content)

    # 处理 decoration: InputDecoration(...) -> 扁平化参数
    # 这个比较复杂，暂时只做简单的 hintText 提取

    return content, textfield_count, textformfield_count


def add_imports_if_needed(content: str, need_themed_input: bool, need_themed_form_input: bool) -> str:
    """
    如果需要，添加 import 语句
    """
    lines = content.split('\n')

    # 找到最后一个 import 语句的位置
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith('import '):
            last_import_idx = i

    imports_to_add = []

    if need_themed_input and THEMED_INPUT_IMPORT not in content:
        # 检查是否已经有相对导入
        if "import 'themed_input.dart'" not in content and "import '../common/themed_input.dart'" not in content:
            imports_to_add.append(THEMED_INPUT_IMPORT)

    if need_themed_form_input and THEMED_FORM_INPUT_IMPORT not in content:
        if "import 'themed_form_input.dart'" not in content and "import '../common/themed_form_input.dart'" not in content:
            imports_to_add.append(THEMED_FORM_INPUT_IMPORT)

    if imports_to_add and last_import_idx >= 0:
        for imp in imports_to_add:
            lines.insert(last_import_idx + 1, imp)
        content = '\n'.join(lines)

    return content


def process_file(filepath: Path, dry_run: bool = False) -> bool:
    """
    处理单个文件
    返回: 是否有修改
    """
    filename = filepath.name

    # 跳过特殊文件
    if filename in SKIP_FILES:
        stats["skipped_files"].append(str(filepath))
        return False

    # 读取文件
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  [ERROR] 无法读取文件: {e}")
        return False

    original_content = content

    # 检查是否包含 TextField 或 TextFormField
    has_textfield = 'TextField(' in content or 'TextField (' in content
    has_textformfield = 'TextFormField(' in content or 'TextFormField (' in content

    if not has_textfield and not has_textformfield:
        return False

    # 替换
    content, tf_count, tff_count = replace_textfield_in_content(
        content, dry_run)

    # 添加 import
    if tf_count > 0 or tff_count > 0:
        content = add_imports_if_needed(content, tf_count > 0, tff_count > 0)

    # 检查是否有实际修改
    if content == original_content:
        return False

    stats["textfield_replaced"] += tf_count
    stats["textformfield_replaced"] += tff_count

    # 输出信息
    rel_path = filepath.relative_to(PROJECT_ROOT)
    print(f"  {rel_path}: TextField={tf_count}, TextFormField={tff_count}")

    # 写入文件
    if not dry_run:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
        except Exception as e:
            print(f"    [ERROR] 无法写入文件: {e}")
            return False

    return True


def main():
    dry_run = '--dry-run' in sys.argv

    if dry_run:
        print("=" * 60)
        print("DRY RUN 模式 - 仅预览变更，不修改文件")
        print("=" * 60)
    else:
        print("=" * 60)
        print("正在执行 TextField/TextFormField 批量替换")
        print("=" * 60)

    print(f"\n扫描目录: {LIB_DIR}")
    print(f"跳过文件: {SKIP_FILES}\n")

    # 扫描所有 .dart 文件
    dart_files = list(LIB_DIR.rglob("*.dart"))
    stats["files_scanned"] = len(dart_files)

    print(f"找到 {len(dart_files)} 个 .dart 文件\n")
    print("开始处理...")
    print("-" * 40)

    for filepath in dart_files:
        if process_file(filepath, dry_run):
            stats["files_modified"] += 1

    print("-" * 40)
    print("\n统计信息:")
    print(f"  扫描文件数: {stats['files_scanned']}")
    print(f"  修改文件数: {stats['files_modified']}")
    print(f"  TextField 替换数: {stats['textfield_replaced']}")
    print(f"  TextFormField 替换数: {stats['textformfield_replaced']}")

    if stats["skipped_files"]:
        print(f"\n跳过的文件 ({len(stats['skipped_files'])} 个):")
        for f in stats["skipped_files"]:
            print(f"  - {f}")

    if dry_run:
        print("\n[DRY RUN] 未实际修改任何文件")
        print("移除 --dry-run 参数以执行实际替换")
    else:
        print("\n替换完成！请运行 flutter analyze 检查语法错误")


if __name__ == "__main__":
    main()
