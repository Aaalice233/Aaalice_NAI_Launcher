#ifndef RUNNER_TASK_RUNNER_WINDOW_LOOKUP_H_
#define RUNNER_TASK_RUNNER_WINDOW_LOOKUP_H_

// irondash 按类名跨进程查找任务窗口，后启动的 Flutter 程序会让拖放等待永不返回。
// 此处改写插件的这项导入，优先返回调用线程的窗口，找不到时沿用原查询。
void InstallTaskRunnerWindowLookup();

#endif
