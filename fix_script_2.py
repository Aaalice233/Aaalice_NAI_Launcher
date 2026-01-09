import os

def fix_account_quick_switch():
    path = "lib/presentation/widgets/auth/account_quick_switch.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Replace the accounts.map(...).toList(), with spread operator
    import re
    pattern = r"children: accounts\.map\(\(account\) => _buildAccountTile\((.*?)\)\)\.toList\(\),"
    replacement = r"children: [\n              ...accounts.map((account) => _buildAccountTile(\1)),\n            ],"
    
    # Use a simpler replacement if regex is tricky
    old = "children: accounts.map((account) => _buildAccountTile("
    new_text = "children: [\n              ...accounts.map((account) => _buildAccountTile("
    content = content.replace(old, new_text)
    content = content.replace(")).toList(),", ")),\n            ],")
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

fix_account_quick_switch()
