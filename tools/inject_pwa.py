#!/usr/bin/env python3
"""Flutter Web 构建后处理：为 iPhone/Android「添加到主屏幕」注入 PWA 标签。

用法：python3 tools/inject_pwa.py
前置：先执行 `flutter build web`（生成 build/web/index.html）。

- 将自定义 PWA manifest 写入 build/web/manifest.json（内嵌，避免被 flutter create 冲掉）
- 把 web/icons/ 复制到 build/web/
- 向 build/web/index.html 的 <head> 注入：
  apple-mobile-web-app-capable / apple-touch-icon / theme-color / manifest 等
  幂等：已存在的标签不会重复注入。
"""
import os
import shutil
import sys
import json
import argparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_WEB = os.path.join(ROOT, "web")

parser = argparse.ArgumentParser()
parser.add_argument("--dir", default=os.path.join(ROOT, "build", "web"),
                    help="Flutter web 构建产物目录（如 build/cf、build/gp）")
args = parser.parse_args()
BUILD = args.dir

# 内嵌自定义 manifest（不依赖仓库里的 web/manifest.json，避免被 flutter create 覆盖）
MANIFEST = {
    "name": "记账同步",
    "short_name": "记账",
    "description": "跨平台记账应用，数据加密同步至私有 GitHub 仓库。",
    "start_url": ".",
    "display": "standalone",
    "background_color": "#ffffff",
    "theme_color": "#00897b",
    "orientation": "portrait",
    "icons": [
        {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
        {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
        {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
    ],
}

META_TAGS = [
    '<meta name="apple-mobile-web-app-capable" content="yes">',
    '<meta name="mobile-web-app-capable" content="yes">',
    '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">',
    '<meta name="apple-mobile-web-app-title" content="记账同步">',
    '<meta name="theme-color" content="#00897b">',
    '<link rel="manifest" href="manifest.json">',
    '<link rel="apple-touch-icon" href="icons/Icon-192.png">',
    '<link rel="icon" type="image/png" href="icons/Icon-192.png">',
]


def write_manifest() -> None:
    with open(os.path.join(BUILD, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(MANIFEST, f, ensure_ascii=False, indent=2)


def copy_icons() -> None:
    src_icons = os.path.join(SRC_WEB, "icons")
    if os.path.isdir(src_icons):
        dst = os.path.join(BUILD, "icons")
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src_icons):
            shutil.copy(os.path.join(src_icons, f), os.path.join(dst, f))


def inject() -> bool:
    idx = os.path.join(BUILD, "index.html")
    if not os.path.exists(idx):
        print("ERROR: build/web/index.html 不存在，请先执行 `flutter build web`。",
              file=sys.stderr)
        sys.exit(1)
    with open(idx, "r", encoding="utf-8") as f:
        html = f.read()
    changed = False
    for tag in META_TAGS:
        if tag not in html:
            html = html.replace("</head>", f"  {tag}\n  </head>", 1)
            changed = True
    with open(idx, "w", encoding="utf-8") as f:
        f.write(html)
    return changed


if __name__ == "__main__":
    if not os.path.isdir(BUILD):
        print("ERROR: build/web 目录不存在。", file=sys.stderr)
        sys.exit(1)
    write_manifest()
    copy_icons()
    inject()
    print("PWA 安装标签已注入 build/web/index.html")
