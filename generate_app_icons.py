#!/usr/bin/env python3
"""
Gotify 应用图标生成器
从 SVG 生成适合 iOS 和 macOS 的应用图标,支持自定义背景色和圆角
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

# 需要生成的图标尺寸 (基于 Contents.json)
ICON_SIZES = [
    # iPhone
    (40, "icon_40.png"),      # 20pt @2x
    (60, "icon_60.png"),      # 20pt @3x
    (58, "icon_58.png"),      # 29pt @2x
    (87, "icon_87.png"),      # 29pt @3x
    (80, "icon_80.png"),      # 40pt @2x
    (120, "icon_120.png"),    # 40pt @3x / 60pt @2x
    (180, "icon_180.png"),    # 60pt @3x
    # iPad
    (20, "icon_20.png"),      # 20pt @1x
    (29, "icon_29.png"),      # 29pt @1x
    (76, "icon_76.png"),      # 76pt @1x
    (152, "icon_152.png"),    # 76pt @2x
    (167, "icon_167.png"),    # 83.5pt @2x
    # iOS Marketing
    (1024, "icon_1024.png"),  # 1024pt @1x
    # macOS
    (16, "icon_16.png"),      # 16pt @1x
    (32, "icon_32.png"),      # 16pt @2x / 32pt @1x
    (64, "icon_64.png"),      # 32pt @2x
    (128, "icon_128.png"),    # 128pt @1x
    (256, "icon_256.png"),    # 128pt @2x / 256pt @1x
    (512, "icon_512.png"),    # 256pt @2x / 512pt @1x
]


def hex_to_rgb(hex_color):
    """将十六进制颜色转换为 RGB 元组"""
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))


def create_rounded_rectangle_mask(size, radius_ratio=0.2237):
    """
    创建圆角矩形遮罩
    radius_ratio: 圆角半径占尺寸的比例
    - iOS 使用系统圆角,不需要我们处理
    - macOS 建议使用 22.37% 的圆角比例 (类似 macOS Big Sur 图标)
    """
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    radius = int(size * radius_ratio)
    draw.rounded_rectangle([(0, 0), (size, size)], radius=radius, fill=255)
    return mask


def convert_svg_to_png(svg_path, output_path, size):
    """使用 rsvg-convert 将 SVG 转换为 PNG"""
    try:
        subprocess.run([
            'rsvg-convert',
            '-w', str(size),
            '-h', str(size),
            svg_path,
            '-o', output_path
        ], check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ 转换失败: {e.stderr.decode()}")
        return False
    except FileNotFoundError:
        print("❌ 未找到 rsvg-convert 命令")
        print("请安装: brew install librsvg")
        return False


def generate_icon(svg_path, output_path, size, bg_color, padding_ratio=0.15, scale_ratio=1.0,
                  add_rounded_corners=True, corner_padding_ratio=0.0,
                  add_shadow=False, shadow_offset_x=0.0, shadow_offset_y=0.02,
                  shadow_blur=0.05, shadow_opacity=0.9):
    """
    生成单个图标

    Args:
        svg_path: SVG 源文件路径
        output_path: 输出 PNG 路径
        size: 图标尺寸
        bg_color: 背景色 (RGB 元组)
        padding_ratio: 内边距比例 (0.15 = 15%)
        scale_ratio: 图标内容缩放比例 (1.0 = 100%, 0.8 = 80%)
        add_rounded_corners: 是否添加圆角 (macOS 需要)
        corner_padding_ratio: 圆角图标的外边距比例 (0.05 = 5% - 基于整个图标尺寸)
        add_shadow: 是否添加阴影
        shadow_offset_x: 阴影水平偏移比例 (0.0 = 居中)
        shadow_offset_y: 阴影垂直偏移比例 (0.02 = 向下2%)
        shadow_blur: 阴影模糊半径比例 (0.05 = 5%)
        shadow_opacity: 阴影透明度 (0.3 = 30%)
    """
    # 如果需要圆角且设置了外边距，先计算圆角图标的实际尺寸
    if add_rounded_corners and corner_padding_ratio > 0:
        # 圆角图标的实际尺寸 (缩小后的尺寸)
        rounded_icon_size = int(size * (1 - 2 * corner_padding_ratio))
        # 圆角图标在最终图片中的偏移量
        rounded_icon_offset = int(size * corner_padding_ratio)
    else:
        rounded_icon_size = size
        rounded_icon_offset = 0

    # 计算内容尺寸 (基于圆角图标尺寸留出边距)
    content_size = int(rounded_icon_size * (1 - 2 * padding_ratio))

    # 应用缩放比例 (在内边距基础上再缩小)
    scaled_content_size = int(content_size * scale_ratio)

    # 先将 SVG 转换为临时 PNG
    temp_svg_png = f"/tmp/temp_icon_{size}.png"
    if not convert_svg_to_png(svg_path, temp_svg_png, scaled_content_size):
        return False

    # 创建背景 (基于圆角图标尺寸)
    icon = Image.new('RGBA', (rounded_icon_size, rounded_icon_size), bg_color + (255,))

    # 加载 SVG 内容
    content = Image.open(temp_svg_png).convert('RGBA')

    # 计算居中位置 (基于缩放后的尺寸，相对于圆角图标)
    offset = (rounded_icon_size - scaled_content_size) // 2

    # 将内容粘贴到背景上
    icon.paste(content, (offset, offset), content)

    # 添加圆角 (macOS 风格)
    if add_rounded_corners:
        mask = create_rounded_rectangle_mask(rounded_icon_size)
        rounded_output = Image.new('RGBA', (rounded_icon_size, rounded_icon_size), (0, 0, 0, 0))
        rounded_output.paste(icon, (0, 0))
        rounded_output.putalpha(mask)

        # 如果设置了外边距或需要阴影，创建最终的透明背景图片
        if corner_padding_ratio > 0 or add_shadow:
            final_output = Image.new('RGBA', (size, size), (0, 0, 0, 0))

            # 添加阴影 - 基于完整尺寸，这样阴影可以利用整个透明区域
            if add_shadow:
                # 创建阴影层 - 使用完整尺寸
                shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))

                # 在阴影层上绘制圆角矩形（位置和大小与圆角图标一致）
                shadow_draw = ImageDraw.Draw(shadow)

                # 使用与图标相同的圆角半径
                radius = int(rounded_icon_size * 0.2237)

                # 计算阴影的圆角矩形位置（考虑阴影偏移）
                shadow_offset_x_px = int(size * shadow_offset_x)
                shadow_offset_y_px = int(size * shadow_offset_y)

                shadow_left = rounded_icon_offset + shadow_offset_x_px
                shadow_top = rounded_icon_offset + shadow_offset_y_px
                shadow_right = shadow_left + rounded_icon_size
                shadow_bottom = shadow_top + rounded_icon_size

                shadow_draw.rounded_rectangle(
                    [(shadow_left, shadow_top), (shadow_right, shadow_bottom)],
                    radius=radius,
                    fill=(0, 0, 0, int(255 * shadow_opacity))
                )

                # 应用高斯模糊 - 基于完整尺寸
                blur_radius = int(size * shadow_blur)
                if blur_radius > 0:
                    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur_radius))

                # 先粘贴阴影（阴影已经包含了偏移）
                final_output.paste(shadow, (0, 0), shadow)

            # 再粘贴圆角图标
            final_output.paste(rounded_output, (rounded_icon_offset, rounded_icon_offset), rounded_output)
            icon = final_output
        else:
            icon = rounded_output

    # 保存
    icon.save(output_path, 'PNG')

    # 清理临时文件
    os.remove(temp_svg_png)

    return True


def main():
    parser = argparse.ArgumentParser(description='生成 Gotify 应用图标')
    parser.add_argument('svg_file', help='SVG 源文件路径')
    parser.add_argument('-o', '--output-dir', default='generated-icons',
                        help='输出目录 (默认: generated-icons)')
    parser.add_argument('-c', '--color', default='#71CAEE',
                        help='背景颜色 (默认: #71CAEE - Gotify 品牌色)')
    parser.add_argument('-p', '--padding', type=float, default=0.15,
                        help='内边距比例 (默认: 0.15 = 15%%)')
    parser.add_argument('-s', '--scale', type=float, default=1.0,
                        help='图标内容缩放比例 (默认: 1.0 = 100%%, 0.8 = 80%% - 图标会更小)')
    parser.add_argument('--corner-padding', type=float, default=0.0,
                        help='圆角图标外边距比例 (默认: 0.0 = 0%%, 0.05 = 5%% - 基于整个图标尺寸，在四周留出透明区域)')
    parser.add_argument('--no-rounded-corners', action='store_true',
                        help='不添加圆角 (iOS 会自动添加)')

    # 阴影相关参数
    parser.add_argument('--shadow', action='store_true',
                        help='添加阴影效果 (macOS 风格)')
    parser.add_argument('--shadow-offset-x', type=float, default=0.0,
                        help='阴影水平偏移比例 (默认: 0.0 = 居中)')
    parser.add_argument('--shadow-offset-y', type=float, default=0.02,
                        help='阴影垂直偏移比例 (默认: 0.02 = 向下2%%)')
    parser.add_argument('--shadow-blur', type=float, default=0.05,
                        help='阴影模糊半径比例 (默认: 0.05 = 5%%)')
    parser.add_argument('--shadow-opacity', type=float, default=0.3,
                        help='阴影透明度 (默认: 0.3 = 30%%)')

    args = parser.parse_args()

    # 检查 SVG 文件
    svg_path = Path(args.svg_file)
    if not svg_path.exists():
        print(f"❌ SVG 文件不存在: {svg_path}")
        sys.exit(1)

    # 创建输出目录
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # 解析背景色
    bg_color = hex_to_rgb(args.color)

    print(f"🎨 开始生成应用图标...")
    print(f"📁 SVG 源文件: {svg_path}")
    print(f"📁 输出目录: {output_dir}")
    print(f"🎨 背景颜色: {args.color} {bg_color}")
    print(f"📏 内边距: {args.padding * 100}%")
    print(f"📐 缩放比例: {args.scale * 100}%")
    print(f"🔲 圆角: {'否' if args.no_rounded_corners else '是'}")
    if not args.no_rounded_corners and args.corner_padding > 0:
        print(f"📦 圆角外边距: {args.corner_padding * 100}%")
    if args.shadow:
        print(f"🌑 阴影: 是")
        print(f"   ↔️  水平偏移: {args.shadow_offset_x * 100}%")
        print(f"   ↕️  垂直偏移: {args.shadow_offset_y * 100}%")
        print(f"   🌫️  模糊半径: {args.shadow_blur * 100}%")
        print(f"   💧 透明度: {args.shadow_opacity * 100}%")
    print()

    # 生成所有尺寸
    success_count = 0
    for size, filename in ICON_SIZES:
        output_path = output_dir / filename
        print(f"生成 {size}x{size} -> {filename}...", end=' ')

        if generate_icon(
            str(svg_path),
            str(output_path),
            size,
            bg_color,
            args.padding,
            args.scale,
            not args.no_rounded_corners,
            args.corner_padding,
            args.shadow,
            args.shadow_offset_x,
            args.shadow_offset_y,
            args.shadow_blur,
            args.shadow_opacity
        ):
            print("✅")
            success_count += 1
        else:
            print("❌")

    print()
    print(f"✅ 完成! 成功生成 {success_count}/{len(ICON_SIZES)} 个图标")
    print()
    print("📝 下一步:")
    print(f"   cp {output_dir}/*.png GotifyClient/Assets.xcassets/AppIcon.appiconset/")


if __name__ == '__main__':
    main()

