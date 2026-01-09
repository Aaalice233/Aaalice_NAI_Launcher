import os
path = "lib/presentation/widgets/auth/credentials_login_form.dart"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
new_lines = []
in_state = False
for line in lines:
    if "class _CredentialsLoginFormState" in line:
        in_state = True
        new_lines.append(line)
        new_lines.append("  late final TextEditingController emailController;\n")
        new_lines.append("  late final TextEditingController passwordController;\n")
        new_lines.append("  final formKey = GlobalKey<FormState>();\n\n")
        new_lines.append("  @override\n")
        new_lines.append("  void initState() {\n")
        new_lines.append("    super.initState();\n")
        new_lines.append("    emailController = TextEditingController();\n")
        new_lines.append("    passwordController = TextEditingController();\n")
        new_lines.append("  }\n")
        continue
    if in_state:
        if "final emailController =" in line or "final passwordController =" in line or "final formKey =" in line:
            continue
    new_lines.append(line)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)
