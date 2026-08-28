import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';

void main() {
  test('未保存草稿不会被延迟到达的持久化状态覆盖', () {
    final notifier = AgentPromptDraftNotifier();
    addTearDown(notifier.dispose);

    notifier.synchronizeSaved('已保存');
    notifier.updateDraft('用户草稿');
    notifier.synchronizeSaved('延迟状态');

    expect(notifier.state.saved, '已保存');
    expect(notifier.state.draft, '用户草稿');
    expect(notifier.state.dirty, isTrue);
  });

  test('保存期间继续编辑时只更新保存基线而不覆盖新草稿', () {
    final notifier = AgentPromptDraftNotifier();
    addTearDown(notifier.dispose);

    notifier.synchronizeSaved('旧值');
    notifier.updateDraft('待保存');
    final savingRevision = notifier.state.revision;
    notifier.beginSave();
    notifier.updateDraft('保存期间的新输入');
    notifier.finishSave(revision: savingRevision, saved: '待保存');

    expect(notifier.state.saved, '待保存');
    expect(notifier.state.draft, '保存期间的新输入');
    expect(notifier.state.dirty, isTrue);
    expect(notifier.state.saving, isFalse);
  });
}
