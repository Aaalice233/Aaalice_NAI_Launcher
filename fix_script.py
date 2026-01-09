import os

def fix_credentials_login_form():
    path = "lib/presentation/widgets/auth/credentials_login_form.dart"
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    new_lines = []
    in_state = False
    for i, line in enumerate(lines):
        if "class _CredentialsLoginFormState extends ConsumerState<CredentialsLoginForm> {" in line:
            in_state = True
            new_lines.append(line)
            new_lines.append("  late final TextEditingController emailController;\n")
            new_lines.append("  late final TextEditingController passwordController;\n")
            new_lines.append("  final formKey = GlobalKey<FormState>();\n")
            new_lines.append("\n")
            new_lines.append("  @override\n")
            new_lines.append("  void initState() {\n")
            new_lines.append("    super.initState();\n")
            new_lines.append("    emailController = TextEditingController();\n")
            new_lines.append("    passwordController = TextEditingController();\n")
            new_lines.append("  }\n")
            continue
        
        if in_state:
            if "final emailController = TextEditingController();" in line:
                continue
            if "final passwordController = TextEditingController();" in line:
                continue
            if "final formKey = GlobalKey<FormState>();" in line:
                continue
        
        new_lines.append(line)
    
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

def fix_account_quick_switch():
    path = "lib/presentation/widgets/auth/account_quick_switch.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Line 77: )).toList(), -> )).toList(), (already has comma?)
    # Wait, the analyze output said:
    # info - Missing a required trailing comma - lib\presentation\widgets\auth\account_quick_switch.dart:77:14 - require_trailing_commas
    # Line 77 in read output: 00077|             )).toList(),
    # Maybe it wants a comma inside the toList() or before it? 
    # Usually it's about the last argument in a multiline call.
    # children: accounts.map((account) => _buildAccountTile( ... )).toList(),
    
    # Let's just add a comma if it's missing in a way that satisfies the linter.
    # Actually, the linter usually wants:
    # children: [
    #   ...accounts.map(...),
    # ],
    
    content = content.replace(")).toList(),", ")).toList(),\n") # This is likely not it.
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

fix_credentials_login_form()
# fix_account_quick_switch() # I'll do this manually after checking the exact line
