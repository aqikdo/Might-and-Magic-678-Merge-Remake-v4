# 如何在游戏里加入自己的 BMP 贴图

## 为什么不能直接把 BMP 放进 LOD“文件夹”？

**LOD 是二进制压缩包，不是普通文件夹。**  
游戏启动时从 `Data/*.lod` 读入资源，不会去扫描某个目录里的零散 BMP。所以：

- 不能：在 `Data` 下新建一个文件夹、把 BMP 丢进去就指望游戏加载。
- 可以：用 **MMArchive** 打开某个 **bitmaps 类 LOD**，把你的 BMP（和调色板）**添加进**这个 LOD，游戏就会从该 LOD 里加载。

---

## 应该把 BMP 放在哪儿、怎么让游戏加载？

### 1. 准备你的 BMP 文件（放在任意工作目录即可）

- 格式：**256 色索引 BMP**（游戏只认这种）。
- 用 GIMP 等：先画图 → **图像 → 模式 → 索引色**，最大颜色数 **256** → 导出为 `.bmp`。
- 文件名即资源名，例如：`StaminaBar.bmp`（在 LOD 里会按“无扩展名”的名字查找，如 `StaminaBar`）。

### 2. 准备调色板文件（pal）

- 游戏要求：**每个 bitmap 在 LOD 里都要对应一个调色板条目**。
- 做法：用 MMArchive 打开一个 bitmaps LOD，找到最后一个 `palXXXX`（如 `pal721`），**复制一份**，改名为下一个编号（如 `pal722`），**去掉扩展名**（不要 .bmp）。
- 在 MMArchive 里：**先 Add 这个 pal 文件，再 Add 你的 BMP**，顺序不能反。
- 添加时注意窗口左下角索引：**BMP 的索引要对应到你刚加进去的那个 pal**（详见 MM6 Wiki: [Editing Bitmaps](https://mm6.wiki/w/Editing_Bitmaps)）。

### 3. 选哪个 LOD 来加？

推荐用 **补丁 LOD**，不直接改合并包，方便维护和更新：

| 文件位置 | 说明 |
|----------|------|
| **Data/00 patch.bitmaps.lod** | 补丁 bitmaps，优先使用这个添加你的 BMP |
| Data/bitmaps.lod、mmmerge.bitmaps.lod 等 | 主/合并包，一般不要直接改 |

若 `00 patch.bitmaps.lod` 不存在，用 MMArchive 新建一个同名 LOD 放在 `Data` 下，再按上面步骤添加 pal + BMP。

### 4. 在 Lua 里加载你的 BMP

贴图加入 LOD 后，按**名字**加载（不带扩展名）：

```lua
-- 按名字加载，返回 BitmapsLod 里的索引
local idx = Game.BitmapsLod:LoadBitmap("StaminaBar")
if idx and idx > 0 then
    -- 若用于 D3D 或需要正确颜色，通常还要加载调色板
    Game.BitmapsLod.Bitmaps[idx]:LoadBitmapPalette()
    -- 然后用 idx 或 Game.BitmapsLod.D3D_Textures[idx] 做绘制
end
```

- **不能**“要求游戏去加载某个路径下的单独 BMP 文件”：游戏只认已打包进 LOD 的资源，通过 `LoadBitmap("名字")` 加载。

---

## 小结

| 问题 | 答案 |
|------|------|
| 为什么不能直接在 LOD“里”加自己的 BMP？ | LOD 是二进制包，必须用 MMArchive 等工具添加。 |
| BMP 文件放在哪儿？ | 先放在任意目录，用 MMArchive 的 **Edit → Add** 把 **pal + BMP** 按顺序加进 **Data/00 patch.bitmaps.lod**（或你选定的 bitmaps LOD）。 |
| 怎么在脚本里用？ | `Game.BitmapsLod:LoadBitmap("文件名")`，文件名无扩展名；需要时再对 `Bitmaps[idx]` 调 `LoadBitmapPalette()`。 |

更多细节见：  
[MM6 Wiki - Editing Bitmaps](https://mm6.wiki/w/Editing_Bitmaps)、  
[GrayFace MMArchive](https://grayface.github.io/mm/#MMArchive)。
