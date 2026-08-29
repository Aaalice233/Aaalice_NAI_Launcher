import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';

void main() {
  test('未保存草稿不会被延迟到达的持久化状态覆盖', () {
    final notifier = AgentPromptDraftNotifier();
    addTearDown(notifier.dispose);

    notifier.synchronizeSaved(value: '已保存', mode: AgentSystemPromptMode.append);
    notifier.updateDraft('用户草稿');
    notifier.synchronizeSaved(
      value: '延迟状态',
      mode: AgentSystemPromptMode.override,
    );

    expect(notifier.state.saved, '已保存');
    expect(notifier.state.draft, '用户草稿');
    expect(notifier.state.dirty, isTrue);
  });

  test('保存期间继续编辑时只更新保存基线而不覆盖新草稿', () {
    final notifier = AgentPromptDraftNotifier();
    addTearDown(notifier.dispose);

    notifier.synchronizeSaved(value: '旧值', mode: AgentSystemPromptMode.append);
    notifier.updateDraft('待保存');
    notifier.updateMode(AgentSystemPromptMode.override);
    final savingRevision = notifier.state.revision;
    notifier.beginSave();
    notifier.updateDraft('保存期间的新输入');
    notifier.finishSave(
      revision: savingRevision,
      saved: '待保存',
      savedMode: AgentSystemPromptMode.override,
    );

    expect(notifier.state.saved, '待保存');
    expect(notifier.state.draft, '保存期间的新输入');
    expect(notifier.state.savedMode, AgentSystemPromptMode.override);
    expect(notifier.state.draftMode, AgentSystemPromptMode.override);
    expect(notifier.state.dirty, isTrue);
    expect(notifier.state.saving, isFalse);
  });

  test('仅切换模式也会标记未保存并可放弃', () {
    final notifier = AgentPromptDraftNotifier();
    addTearDown(notifier.dispose);
    notifier.synchronizeSaved(value: '内容', mode: AgentSystemPromptMode.append);

    notifier.updateMode(AgentSystemPromptMode.override);
    expect(notifier.state.dirty, isTrue);

    notifier.discard();
    expect(notifier.state.draftMode, AgentSystemPromptMode.append);
    expect(notifier.state.dirty, isFalse);
  });
}
