/// 树形节点拖放的放置槽位（相簿树与分类树共用）。
///
/// 拖动到目标节点的上半边缘条 = [before]（插到目标前，同级/跨层排序），
/// 下半边缘条 = [after]（插到目标后），中部 = [child]（移入为目标子级）。
enum GalleryTreeDropSlot { before, after, child }
