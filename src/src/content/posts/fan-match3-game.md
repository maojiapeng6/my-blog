---
title: 扇韵连连趣：用 Python 写一个消消乐，把非遗折扇装进游戏里
published: 2026-09-10
pinned: false
description: 江苏省职业院校学生创新创业培育计划项目「金陵流华·西游扇影」的最后一块拼图，是一个能玩的 Python 小游戏。这篇把它的代码结构、四个核心算法、六个真实踩坑，以及最后交出去的成果完整记下来——附运行录屏与四类扇子 Q 版设计图。
tags: [Python, pygame, 小游戏开发, 消消乐, 非遗, 大创项目]
category: 编程实践
author: Peng
image: ./images/fan-match3-cover.jpg
slug: fan-match3-game
---

## 一、起念：文化项目最后缺的是一个「能玩的东西」

2023 年，我参加的是江苏省职业院校学生创新创业培育计划项目「金陵流华·西游扇影」，项目编号 G-2023-1314。

要做的题目很清楚：金陵折扇是江苏省非遗，2009 年进了省级非遗名录，但它正在遇到的问题很现实——**老的多、年轻的少；会做的师傅在变老，愿意学的年轻人不多。**

调研、访谈、写论文、做问卷、拍照片、跑集市，这些我们都做了。论文《金陵折扇文化的保护、继承与发扬》后来被《丝网印刷》录用。但一路走下来我越来越确定一件事：

> **不是年轻人不喜欢传统，是他们没有"碰"到传统的方式。**

展板和论文是**要主动去读**的，你得先有兴趣才会翻开；而游戏是**主动去玩**的，玩完三分钟你记住了颜色、记住了扇子、记住了"哦这个东西挺好看"。

所以项目最后一份交付物，我们加了一个可以双击打开就能玩的东西——「扇韵连连趣」，一个用 Python + pygame 写的消消乐。

这篇写的就是它：代码怎么分、哪几个算法最费脑子、踩了哪些坑、最后到底交出了什么。

## 二、成品长什么样

| 项目 | 参数 |
| --- | --- |
| 游戏名 | 扇韵连连趣 |
| 技术栈 | Python 3 + pygame |
| 窗口尺寸 | 850 × 600 |
| 素材规格 | 背景 850×600，格子砖 218×218，动物/棋子 40×40 |
| 内容 | 主菜单选关树 + 多关卡消消乐 + 能量/金币结算 |
| 操作 | 鼠标点选关卡与棋子交换，Q / ESC 退出 |
| 音效 | 主界面 BGM 与关卡 BGM 自动切换 |

启动先进入主菜单：一把展开的扇面做成的选择树，显示当前能量和金币，点一下关卡就切进棋盘。

<div style="margin:1.5rem 0;">
  <video controls preload="metadata" poster="/images/fanshoot/fan-cover.png" style="width:100%;border-radius:12px;box-shadow:0 4px 20px rgba(0,0,0,0.15);">
    <source src="/assets/videos/match3-demo.mp4" type="video/mp4">
    你的浏览器不支持视频播放，请换个浏览器试试。
  </video>
  <p style="font-size:0.85rem;opacity:0.65;margin:0.6rem 0 1rem;line-height:1.6;">
    <strong>实际运行录屏。</strong>从进主菜单、点关卡、交换棋子到消除结算，全流程没有剪辑，就是双击 exe 之后真实发生的事。画面右下角是金币累加，界面上方是能量条。
  </p>
</div>

## 三、代码是怎么组织的

工程不算大（整个游戏加素材不到两千行），但**一开始就把模块分开了**，这是后来少翻车很多次的原因：

```
┌────────────────────────────────────────┐
│  main.py  —— 只负责主循环与事件分发      │
│  （不做任何游戏逻辑，只读状态、调方法）   │
├────────────────────────────────────────┤
│  manager.py                             │
│   ├ ManagerTree   主菜单：选关、能量、金币│
│   ├ Manager       关卡：棋盘、消除、结算  │
│   └ SoundPlay     音效资源与播放控制      │
├────────────────────────────────────────┤
│  sprites / 素材                          │
│   bg 850×600 · brick 218×218 · animal 40×40 │
└────────────────────────────────────────┘
```

核心思路是**主循环不写判断，只写流程**。我最初的版本把 `if 在菜单就画菜单` 全塞进 while 里，改一个关卡规则得通读两百行。后来拆成状态驱动，主循环变成这个样子（下面是从源码里摘出来的骨架，缩进为了排版做了压缩）：

```python
while True:
    if m.level == 0:                       # level == 0 是主菜单
        if sound_sign == 0:
            game_bgm.stop()
            world_bgm.play(-1)             # 主界面 BGM，循环
            sound_sign = 1
    else:
        if sound_sign == 1:
            world_bgm.stop()
            game_bgm.play(-1)              # 关卡 BGM，循环
            sound_sign = 0
        m.set_level_mode(m.level)
        sprite_group = m.draw()
        if m.type == 0:
            m.eliminate_animal()           # 找出并消除相邻同色
            m.death_map()                  # 死局检测与重排
            m.exchange(sprite_group)        # 交换判定与回退
            m.judge_level()                 # 结算：能量 / 金币 / 过关
    for event in pygame.event.get():
        if event.type == KEYDOWN and event.key in (K_q, K_ESCAPE):
            exit()
        if event.type == QUIT:
            sys.exit()
        m.level, m.energy_num, m.money = tree.mouse_select(
            event, m.level, m.energy_num, m.money)
        m.mouse_select(event)
        m.mouse_image()
    pygame.display.flip()
```

这段里最值得说的一行是 `pygame.display.flip()` 放在循环**最后**——它不在任何一个分支里。我第一版把它写在 `else` 里面，结果主菜单一动不动，找了半小时才知道是刷新只发生在关卡分支里。

## 四、四个真正费脑子的算法

消消乐听起来简单，真写起来，**难的全在处理"边界情况"**，不是匹配本身。

| 模块 | 职责 | 最容易错的地方 |
| --- | --- | --- |
| `eliminate_animal()` | 扫描相邻同色并消除 | 消除后索引错位 |
| `exchange()` | 玩家交换两枚棋子并判定 | 换了没成必须先换回来 |
| 下落补位 | 上方棋子下落、顶栏生成新棋子 | 补位要按列独立处理 |
| `death_map()` | 检测是否还有可行解 | 不检测会直接卡死 |
| `judge_level()` | 结算能量、金币、过关条件 | 边界：差一步时怎么判 |

### 1. 相邻消除：先扫后删，绝不在扫的过程中删

第一版我是边遍历边 `remove()`，结果整列棋子错位——因为列表长度在遍历中变了。正确做法是**先标记、后清空**：

```python
to_kill = set()
for r in range(rows):
    for c in range(cols):
        color = board[r][c]
        # 向右同色、向下同色分别延伸，长度 >= 3 才计入
        if 向右同色数量 + 1 >= 3: to_kill.add(...)
        if 向下同色数量 + 1 >= 3: to_kill.add(...)
# 扫描全部结束，再统一清掉
```

### 2. 交换失败必须"换回去"

玩家点两枚棋子交换，然后判：这次交换有没有形成消除？**没有就换回来**——这一步漏了，棋子会永久错位，玩两关棋盘就乱了。所以我把交换和回退放在同一个方法里，保证原子性：

```python
交换 -> 扫描 -> 有消除 ? 保留 : 换回原位
```

### 3. 下落补位：按列独立，别按行

一个棋子掉下去，它**上面**的所有棋子跟着掉，最顶上补新的。这个必须一列一列地处理，按行处理会出现斜着掉的鬼畜效果。补满之后要**再扫一次**，因为新补的棋子可能又凑成了三连（连锁）。

### 4. `death_map()`：整个项目里最容易被漏掉的函数

这是我写的第三个版本才补上的。

逻辑是：**如果棋盘上不存在任何一次有效交换，那这局就是死的。** 检测方法是遍历所有相邻的两两交换，看是否存在至少一种能触发消除的组合；没有就整体重排，重排后仍然无解就重开。

> 没有这个函数，玩家玩到某一局会发现"怎么点都没反应"——棋子明明还在，但怎么换都不消除。这就是卡死。很多网上开源的小游戏 demo 恰恰死在这儿。

## 五、踩过的六个坑

1. **`display.flip()` 位置写错** → 只在一个分支刷新，主菜单永远静止
2. **精灵组删除后仍被引用** → 索引错位，消除第三排时第一排棋子坐标全飘
3. **音效格式** → pygame 的 mixer 对 mp3 支持不稳，最后统一转 wav，加载慢一点但不会中途哑掉
4. **状态用一个 `sound_sign` 变量切** → 从关卡退回主菜单时音乐切不回去。后来彻底拆成状态机，`level == 0` 只判断"在不在菜单"，音乐单独一套逻辑
5. **死局不检测** → 就是上面说的，直接卡死（详见第四节）
6. **pygame 默认字体没有中文** → 所有中文文字改成渲染到离屏 Surface 再贴，或者指定系统字体路径

## 六、最后交出去的东西

项目走到结项，实际产出是这样一份清单：

<div style="margin:1.5rem 0;">
  <p style="font-size:0.92rem;opacity:0.8;margin:0 0 1rem;line-height:1.7;">下面是四类扇子的 <strong>Q 版设计图</strong>——游戏里棋盘上的棋子图案，就是照着这套设计做出来的：</p>
  <img src="/assets/images/fanshoot/fan-bamboo.jpg" alt="竹板扇 Q版设计" style="width:100%;border-radius:10px;box-shadow:0 2px 12px rgba(0,0,0,0.12);">
  <p style="font-size:0.85rem;opacity:0.65;margin:0.6rem 0 1rem;line-height:1.6;">
    <strong>竹板扇。</strong>Q 版造型保留了竹板拼合的扇骨与活动铆钉结构，开合有明确的"咔"手感——这类扇子适合久拿，也是设计稿里改得最多的一把。
  </p>
  <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;">
    <div>
      <img src="/assets/images/fanshoot/fan-palm.jpg" alt="掌扇 Q版设计" style="width:100%;border-radius:10px;box-shadow:0 2px 12px rgba(0,0,0,0.12);">
      <p style="font-size:0.82rem;opacity:0.65;margin:0.5rem 0 0;line-height:1.55;"><strong>掌扇。</strong>扇面小、扇柄短，收起来能塞进口袋，是"便携"这一维度上的代表。</p>
    </div>
    <div>
      <img src="/assets/images/fanshoot/fan-round.jpg" alt="团扇 Q版设计" style="width:100%;border-radius:10px;box-shadow:0 2px 12px rgba(0,0,0,0.12);">
      <p style="font-size:0.82rem;opacity:0.65;margin:0.5rem 0 0;line-height:1.55;"><strong>团扇。</strong>不折叠的圆形，绑在扇柄上。它走的是另一个路子——重装饰、重画面，和折扇的"可开合"是完全不同的设计语言。</p>
    </div>
  </div>
  <p style="font-size:0.85rem;opacity:0.65;margin:0.9rem 0 1rem;line-height:1.6;">
    这四类扇子对应项目里的四种"设计维度"：<strong>便携、工艺、装饰、实用</strong>。游戏里那几种颜色的棋子，就是从这几把扇子的设计稿配色里取的。
  </p>
  <img src="/assets/images/fanshoot/fan-silk.jpg" alt="绫绢扇 Q版设计" style="width:100%;border-radius:10px;box-shadow:0 2px 12px rgba(0,0,0,0.12);">
  <p style="font-size:0.85rem;opacity:0.65;margin:0.6rem 0 1rem;line-height:1.6;">
    <strong>绫绢扇。</strong>设计稿里给它的扇面画的是绫绢织物的纹理，适合书画题跋，吃墨、吃颜料——所以我在游戏里给不同关卡配了不同底纹的扇面。
  </p>
</div>

- **可运行的小游戏**：双击即玩，含主菜单、多关卡、音效、结算（这就是上面那段录屏）
- **论文**：《金陵折扇文化的保护、继承与发扬》，已被国家级期刊《丝网印刷》录用
- **四类扇子 Q 版设计图**：竹板扇 / 掌扇 / 团扇 / 绫绢扇，作为游戏棋子图案与展示材料
- **3D 打印宣传物料**：为《西游记》主题制作了 Q 版角色 3D 模型并打印成实体，在社区公益展览上展出

- **公开报道与线下活动**：公众号报道宣传、夏日古风集市志愿讲解——折扇在集市上被真正"拿起来过"，这比展板上的照片有效得多

线下活动这一段给我的触动最直接：展板前没人停留，但「摸一摸扇子、转一转模型」的位置永远围着人——这直接影响了后来做游戏的决策，与其让人「来看」，不如让人「来玩」。

## 七、复盘：这段经历真正给我的

写代码这件事，我最早以为难在"把功能做出来"。

做完这个小游戏才明白，**难在"把功能做完整"**：玩家点不动了怎么办？交换不成功怎么办？棋盘全死了怎么办？——这些你不去想，它就不存在，直到用户在你面前点了第三下没反应。

`death_map()` 那个函数我写了三遍，前两版都是我以为"三角形总会有解"就跳过了检测。真正让我把逻辑想清楚的是那个测试场景：我把棋盘摆成一个只有一种颜色的死局截图，问自己"用户这时候看到什么"。

> **从"代码能跑"到"别人玩着不卡"，中间全是边界情况。**

这条经验后来一直有用。我自己搭 NAS、写博客、配 Docker Compose 的时候，敢直接上生产、愿意做"失败保留上一版"的兜底，根子就在那一年：第一次知道一个能用的东西和能交出去的东西，是两个东西。

---

<small>项目名称：金陵流华·西游扇影（2023 年江苏省职业院校学生创新创业培育计划项目，G-2023-1314）。<br>
游戏引擎：Python 3 + pygame。运行录屏与美术设计素材均为项目原始文件。</small>
