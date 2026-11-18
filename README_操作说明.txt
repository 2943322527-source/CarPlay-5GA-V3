CarPlay 5Gᴀ 宽度修正 V3 - RootHide 编译项目（不是 DEB）
=======================================================
目标：沿用已经成功的 V1 桥接插件，仅让 CarPlay 中的 "5G" 变窄；末尾小型大写 A 维持原样。

当前状态：源码、配置、GitHub Actions 自动构建流程已准备好；未在云端编译，也未经过实机验证。
此项目不是可以直接用 Sileo 安装的文件。只有 GitHub Actions 完成编译后才会生成 DEB。

步骤：
1. 需要一个 GitHub 账号。
2. 新建一个仓库；把本项目 ZIP 解压后的所有文件和 .github/workflows/build.yml 上传到仓库。
   注意包含隐藏的 .github 目录。
3. 在仓库 Actions -> Build CarPlay 5GA WidthFix RootHide DEB -> Run workflow。
4. 完成后，在该运行页面的 Artifacts 中下载 CarPlay5GA-WidthFix-V3-RootHide-DEB。
5. 下载的 Artifact ZIP 内才是目标 .deb，复制到 iPhone 再由 Sileo 安装。

依赖：需要已经安装并正常显示的 V1 桥接 DEB：local.carplay5ga.fsbtest；以及原 FakeSignalBar。
本 V3 是独立包，卸载 V3 便可恢复 V1 的原显示行为。

注意：使用 RootHide Theos 构建需要 macOS runner；生成 DEB 可能仍受工具链/SDK 或具体字体支持的影响。
源码中的窄字体 trait 只作用于 5 和 G，A 不参与，但实际视觉效果未经设备测试。

不能直接把 ZIP 当 DEB 安装，也不要将 ZIP 改后缀为 DEB。
