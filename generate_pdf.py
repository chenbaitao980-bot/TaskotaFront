# -*- coding: utf-8 -*-
"""智能小管家 产品宣发手册 PDF 生成脚本"""
import os
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether
)
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
from reportlab.platypus import Flowable
from reportlab.lib import colors
import reportlab.platypus as platypus

# ──────────────────────────────────────────────────────────────
# 注册中文字体
# ──────────────────────────────────────────────────────────────
FONT_REGULAR = 'SimHei'
FONT_BOLD    = 'SimHei'
FONT_ITALIC  = 'SimKai'

pdfmetrics.registerFont(TTFont('SimHei', 'C:/Windows/Fonts/simhei.ttf'))
pdfmetrics.registerFont(TTFont('SimKai', 'C:/Windows/Fonts/simkai.ttf'))
pdfmetrics.registerFont(TTFont('SimFang', 'C:/Windows/Fonts/simfang.ttf'))

# ──────────────────────────────────────────────────────────────
# 调色板
# ──────────────────────────────────────────────────────────────
PRIMARY    = HexColor('#E8632A')   # 主橙
SECONDARY  = HexColor('#2A6AE8')   # 辅蓝
ACCENT     = HexColor('#8B5CF6')   # 紫
SUCCESS    = HexColor('#10B981')   # 绿
WARNING    = HexColor('#F59E0B')   # 黄
DANGER     = HexColor('#EF4444')   # 红
BG_LIGHT   = HexColor('#FFF8F5')   # 浅背景
BG_CARD    = HexColor('#FFFFFF')
DIVIDER    = HexColor('#F0E8E0')
TEXT_MAIN  = HexColor('#1A1A2E')
TEXT_MUTED = HexColor('#6B7280')
TEXT_LIGHT = HexColor('#9CA3AF')

# ──────────────────────────────────────────────────────────────
# 通用样式工厂
# ──────────────────────────────────────────────────────────────
def S(name, font=FONT_REGULAR, size=10, color=TEXT_MAIN, leading=None,
      align=TA_LEFT, spBefore=0, spAfter=0, bold=False):
    fn = FONT_BOLD if bold else font
    return ParagraphStyle(
        name, fontName=fn, fontSize=size,
        textColor=color, leading=leading or size * 1.5,
        alignment=align, spaceBefore=spBefore, spaceAfter=spAfter
    )

# ──────────────────────────────────────────────────────────────
# 自定义 Flowable：圆角色块标题
# ──────────────────────────────────────────────────────────────
from reportlab.platypus import Flowable as _Flowable

class ColorBar(_Flowable):
    """左边彩条 + 大标题行"""
    def __init__(self, title, subtitle='', bar_color=PRIMARY, width=None, height=36):
        super().__init__()
        self._title = title
        self._subtitle = subtitle
        self._bar_color = bar_color
        self._w = width
        self._h = height

    def wrap(self, availW, availH):
        self._w = self._w or availW
        return (self._w, self._h)

    def draw(self):
        c = self.canv
        w, h = self._w, self._h
        # 背景
        c.setFillColor(BG_LIGHT)
        c.roundRect(0, 0, w, h, 6, fill=1, stroke=0)
        # 左彩条
        c.setFillColor(self._bar_color)
        c.roundRect(0, 0, 8, h, 4, fill=1, stroke=0)
        # 标题
        c.setFillColor(TEXT_MAIN)
        c.setFont(FONT_BOLD, 15)
        c.drawString(18, h/2 - 2, self._title)
        # 副标题
        if self._subtitle:
            c.setFillColor(TEXT_MUTED)
            c.setFont(FONT_REGULAR, 9)
            c.drawRightString(w - 8, h/2 - 2, self._subtitle)


class HeroBlock(_Flowable):
    """封面大色块"""
    def __init__(self, width, height):
        super().__init__()
        self._w = width
        self._h = height

    def wrap(self, availW, availH):
        return (self._w, self._h)

    def draw(self):
        from reportlab.graphics.shapes import Drawing, Rect, Circle, String
        c = self.canv
        w, h = self._w, self._h
        # 渐变背景（用矩形叠加模拟）
        steps = 30
        for i in range(steps):
            t = i / steps
            r = int(0xE8 * (1-t) + 0xFF * t) / 255
            g = int(0x63 * (1-t) + 0x99 * t) / 255
            b = int(0x2A * (1-t) + 0x66 * t) / 255
            c.setFillColorRGB(r, g, b)
            stripe_h = h / steps
            c.rect(0, i * stripe_h, w, stripe_h + 1, fill=1, stroke=0)

        # 装饰圆
        for cx, cy, cr, alpha in [
            (w*0.88, h*0.82, 90, 0.15),
            (w*0.08, h*0.65, 55, 0.12),
            (w*0.55, h*0.92, 40, 0.10),
        ]:
            c.setFillColorRGB(1, 1, 1, alpha)
            c.circle(cx, cy, cr, fill=1, stroke=0)

        # 主标题
        c.setFillColor(white)
        c.setFont(FONT_BOLD, 38)
        c.drawCentredString(w/2, h*0.62, '智能小管家')

        # 英文副标题
        c.setFont('Helvetica', 13)
        c.setFillColorRGB(1, 1, 1, 0.85)
        c.drawCentredString(w/2, h*0.52, 'Smart Assistant · AI-Powered Task Manager')

        # 标语
        c.setFont(FONT_BOLD, 14)
        c.setFillColor(white)
        c.drawCentredString(w/2, h*0.40, '让 AI 成为你的专属效率管家')

        # 标签行
        tags = ['AI 智能拆解', '日历视图', '多端同步', '离线可用']
        tag_w = 78
        total = len(tags) * tag_w + (len(tags)-1) * 10
        sx = (w - total) / 2
        for i, tag in enumerate(tags):
            tx = sx + i * (tag_w + 10)
            ty = h * 0.22
            c.setFillColorRGB(1, 1, 1, 0.25)
            c.roundRect(tx, ty, tag_w, 22, 11, fill=1, stroke=0)
            c.setFillColor(white)
            c.setFont(FONT_BOLD, 9)
            c.drawCentredString(tx + tag_w/2, ty + 7, tag)

        # 版本标记
        c.setFont('Helvetica', 9)
        c.setFillColorRGB(1, 1, 1, 0.6)
        c.drawCentredString(w/2, h*0.08, 'v1.0  ·  2026 产品宣发手册')


class MetricCard(_Flowable):
    """单个指标卡片"""
    def __init__(self, value, label, color=PRIMARY, w=90, h=60):
        super().__init__()
        self._value = value
        self._label = label
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, a, b):
        return (self._w, self._h)

    def draw(self):
        c = self.canv
        w, h = self._w, self._h
        # 卡片背景
        c.setFillColor(BG_CARD)
        c.roundRect(2, 2, w-4, h-4, 8, fill=1, stroke=0)
        # 顶部色条
        c.setFillColor(self._color)
        c.roundRect(2, h-10, w-4, 10, 4, fill=1, stroke=0)
        c.rect(2, h-14, w-4, 8, fill=1, stroke=0)
        # 数值
        c.setFillColor(self._color)
        c.setFont(FONT_BOLD, 20)
        c.drawCentredString(w/2, h*0.38, self._value)
        # 标签
        c.setFillColor(TEXT_MUTED)
        c.setFont(FONT_REGULAR, 8)
        c.drawCentredString(w/2, h*0.16, self._label)


class FeatureCard(_Flowable):
    """功能特性卡片"""
    def __init__(self, icon, title, desc, color=PRIMARY, w=240, h=110):
        super().__init__()
        self._icon = icon
        self._title = title
        self._desc = desc
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, a, b):
        return (self._w, self._h)

    def draw(self):
        from reportlab.lib.utils import simpleSplit
        c = self.canv
        w, h = self._w, self._h
        # 卡片
        c.setFillColor(BG_CARD)
        c.roundRect(3, 3, w-6, h-6, 10, fill=1, stroke=0)
        # 顶部色带
        c.setFillColor(self._color)
        c.roundRect(3, h-12, w-6, 12, 6, fill=1, stroke=0)
        c.rect(3, h-18, w-6, 10, fill=1, stroke=0)
        # 图标圆
        c.setFillColor(self._color)
        c.circle(26, h-32, 14, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont(FONT_BOLD, 13)
        c.drawCentredString(26, h-36, self._icon)
        # 标题
        c.setFillColor(TEXT_MAIN)
        c.setFont(FONT_BOLD, 12)
        c.drawString(46, h-30, self._title)
        # 分割线
        c.setStrokeColor(DIVIDER)
        c.setLineWidth(0.5)
        c.line(12, h-44, w-12, h-44)
        # 描述文字（自动换行）
        c.setFillColor(TEXT_MUTED)
        c.setFont(FONT_REGULAR, 8.5)
        lines = simpleSplit(self._desc, FONT_REGULAR, 8.5, w - 24)
        y = h - 58
        for line in lines[:4]:
            c.drawString(12, y, line)
            y -= 13


class PricingCard(_Flowable):
    """定价卡片"""
    def __init__(self, tier, price, unit, features, highlight=False, color=PRIMARY, w=155, h=200):
        super().__init__()
        self._tier = tier
        self._price = price
        self._unit = unit
        self._features = features
        self._highlight = highlight
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, a, b):
        return (self._w, self._h)

    def draw(self):
        c = self.canv
        w, h = self._w, self._h
        # 卡片底色
        if self._highlight:
            c.setFillColor(self._color)
            c.roundRect(2, 2, w-4, h-4, 12, fill=1, stroke=0)
            text_main = white
            text_sub = HexColor('#FFE4D4')
            badge_bg = HexColor('#FFFFFF')
            badge_fg = self._color
        else:
            c.setFillColor(BG_CARD)
            c.roundRect(2, 2, w-4, h-4, 12, fill=1, stroke=0)
            c.setStrokeColor(DIVIDER)
            c.setLineWidth(1)
            c.roundRect(2, 2, w-4, h-4, 12, fill=0, stroke=1)
            text_main = TEXT_MAIN
            text_sub = TEXT_MUTED
            badge_bg = self._color
            badge_fg = white

        # 套餐名
        c.setFillColor(text_main)
        c.setFont(FONT_BOLD, 13)
        c.drawCentredString(w/2, h-26, self._tier)

        # 分割线
        lc = HexColor('#FFFFFF') if self._highlight else DIVIDER
        c.setStrokeColor(lc)
        c.setLineWidth(0.5)
        c.line(16, h-36, w-16, h-36)

        # 价格
        c.setFillColor(text_main)
        c.setFont(FONT_BOLD, 28)
        c.drawCentredString(w/2 - 8, h-64, self._price)
        c.setFont(FONT_REGULAR, 9)
        c.setFillColor(text_sub)
        c.drawString(w/2 + 14, h-58, self._unit)

        # 功能列表
        c.setFont(FONT_REGULAR, 8.5)
        y = h - 82
        for feat in self._features:
            c.setFillColor(self._color if self._highlight else SUCCESS)
            c.circle(20, y + 3, 3, fill=1, stroke=0)
            c.setFillColor(text_main)
            c.drawString(28, y, feat)
            y -= 16


# ──────────────────────────────────────────────────────────────
# 页眉 / 页脚 回调
# ──────────────────────────────────────────────────────────────
def on_page(canvas, doc):
    w, h = A4
    canvas.saveState()
    # 页脚左
    canvas.setFont(FONT_REGULAR, 8)
    canvas.setFillColor(TEXT_LIGHT)
    canvas.drawString(20*mm, 10*mm, '智能小管家 · Smart Assistant')
    # 页脚右
    canvas.drawRightString(w - 20*mm, 10*mm, f'第 {doc.page} 页')
    # 页脚分割线
    canvas.setStrokeColor(DIVIDER)
    canvas.setLineWidth(0.5)
    canvas.line(20*mm, 14*mm, w - 20*mm, 14*mm)
    canvas.restoreState()


def on_first_page(canvas, doc):
    pass  # 封面无页眉页脚


# ──────────────────────────────────────────────────────────────
# 正文构建
# ──────────────────────────────────────────────────────────────
def build_story(W, H):
    usable = W - 40*mm
    story = []

    # ── PAGE 1: 封面 ──────────────────────────────────────────
    story.append(HeroBlock(usable, 200*mm))
    story.append(Spacer(1, 8*mm))

    # 痛点行
    pain_data = [
        ['😩', '任务越积越多，不知从哪下手？'],
        ['📅', '日程分散各处，总在救火而非规划？'],
        ['🤯', '大项目无从拆解，拖延症反复发作？'],
        ['🌐', '换台设备就找不到上次的进度？'],
    ]
    for icon, text in pain_data:
        t = Table([[
            Paragraph(icon, S('pi', size=13, align=TA_CENTER)),
            Paragraph(text, S('pt', size=10, color=TEXT_MAIN, leading=16)),
        ]], colWidths=[18*mm, usable - 20*mm])
        t.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('TOPPADDING', (0,0), (-1,-1), 4),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
            ('LEFTPADDING', (0,0), (-1,-1), 4),
        ]))
        story.append(t)

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        '智能小管家用 AI 帮你一键拆解任务、智能排期、多端同步，\n让效率管理真正融入日常。',
        S('slogan', font=FONT_BOLD, size=12, color=PRIMARY, align=TA_CENTER, leading=20)
    ))
    story.append(PageBreak())

    # ── PAGE 2: 产品概述 ──────────────────────────────────────
    story.append(ColorBar('产品概述', '一款真正懂你的 AI 效率工具', bar_color=PRIMARY))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph(
        '智能小管家（Smart Assistant）是一款基于 Flutter 构建、搭载 DeepSeek AI 的跨平台任务管理应用。'
        '它将 AI 任务拆解、可视化日历、思维导图、云端协作融为一体，帮助个人和团队从混乱走向清晰。',
        S('body', size=10, color=TEXT_MAIN, leading=18)
    ))
    story.append(Spacer(1, 5*mm))

    # 核心数据卡
    metrics = [
        ('6+', '核心功能模块', PRIMARY),
        ('3端', 'Windows / Android / Web', SECONDARY),
        ('实时', 'AI 智能排程', ACCENT),
        ('离线', '本地数据安全', SUCCESS),
    ]
    mc_row = [[MetricCard(v, l, HexColor(c) if isinstance(c, str) else c, w=int(usable/4)-4, h=62)
               for v, l, c in metrics]]
    mt = Table(mc_row, colWidths=[usable/4]*4)
    mt.setStyle(TableStyle([('VALIGN', (0,0), (-1,-1), 'TOP'), ('LEFTPADDING', (0,0), (-1,-1), 2), ('RIGHTPADDING', (0,0), (-1,-1), 2)]))
    story.append(mt)
    story.append(Spacer(1, 5*mm))

    # 适合人群
    story.append(ColorBar('适合人群', '', bar_color=SECONDARY, height=30))
    story.append(Spacer(1, 3*mm))
    personas = [
        ('🧑‍💻', '开发者 & 项目经理', '用 WBS 拆解复杂需求，AI 自动生成子任务'),
        ('📚', '学生 & 考研党', '可视化学习计划，日历追踪每日打卡'),
        ('👔', '职场人士', '日程整合、提醒推送，告别"忘事"尴尬'),
        ('🏠', '自由职业者', '多项目并行，思维导图梳理创意脉络'),
    ]
    p_data = [[
        Paragraph(ic, S('pi2', size=16, align=TA_CENTER)),
        Paragraph(f'<b>{name}</b>\n{desc}',
                  S('pd', size=9, color=TEXT_MAIN, leading=15)),
    ] for ic, name, desc in personas]

    pt = Table(p_data, colWidths=[14*mm, usable - 16*mm])
    pt.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LINEBELOW', (0,0), (-1,-1), 0.5, DIVIDER),
    ]))
    story.append(pt)
    story.append(PageBreak())

    # ── PAGE 3: 核心功能 ──────────────────────────────────────
    story.append(ColorBar('六大核心功能', 'Core Features', bar_color=ACCENT))
    story.append(Spacer(1, 5*mm))

    features = [
        ('🤖', 'AI 智能拆解', 'DeepSeek 接入，一句话生成 WBS 任务树。支持自然语言输入，自动推导子任务、时间节点与优先级，工作量评估智能对齐。提醒窗口 09:00–21:00 可自定义。', PRIMARY),
        ('📅', '日历视图', '1-15 天弹性窗口，支持长按编辑、拖动调整时间范围、双指缩放。任务横跨多日时显示为跨列长条，单日任务为竖向时间块，并行任务自动分列展示。', SECONDARY),
        ('🗺️', '思维导图', '节点无限层级，支持拖拽重排、Ctrl+Z 撤销。任务与思维导图双向绑定，在导图中编辑即同步到任务列表，帮你把想法快速结构化。', ACCENT),
        ('☁️', '多端同步', 'Supabase 云端 + LWW 冲突解决算法，Windows、Android、Web 三端实时同步，网络恢复后自动合并离线变更，数据不丢失。', SUCCESS),
        ('🔔', '智能提醒', 'Flutter local_notifications 驱动，支持单次与重复提醒，跨平台通知推送。任务截止前自动提醒，告别拖延。', WARNING),
        ('🎨', '主题 & UI', '亮/暗模式双主题，Material 3 设计语言，动效流畅。界面元素可自定义，支持大字体与高对比度无障碍模式。', DANGER),
    ]

    # 双列布局
    row = []
    rows = []
    fw = (usable - 8*mm) / 2
    for i, (icon, title, desc, color) in enumerate(features):
        row.append(FeatureCard(icon, title, desc, HexColor(color.hexval() if hasattr(color, 'hexval') else '#E8632A'), w=int(fw), h=115))
        if len(row) == 2:
            rows.append(row)
            row = []
    if row:
        rows.append(row + [Spacer(int(fw), 115)])

    ft = Table(rows, colWidths=[fw, fw])
    ft.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 2),
        ('RIGHTPADDING', (0,0), (-1,-1), 2),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(ft)
    story.append(PageBreak())

    # ── PAGE 4: 技术架构 ──────────────────────────────────────
    story.append(ColorBar('技术架构', 'Tech Stack', bar_color=SECONDARY))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph(
        '智能小管家采用现代化 Flutter 全栈架构，前后端分离、离线优先，保证数据安全与跨平台一致体验。',
        S('body2', size=10, color=TEXT_MUTED, leading=16)
    ))
    story.append(Spacer(1, 4*mm))

    arch_layers = [
        ('表现层', 'Flutter 3.x · Material 3 · BLoC 状态管理', PRIMARY),
        ('AI 层', 'DeepSeek API · 任务拆解 · WBS 生成 · 智能排期', ACCENT),
        ('业务逻辑层', 'BLoC Cubit · 任务/日历/思维导图/提醒 · 冲突解决', SECONDARY),
        ('数据层', 'Drift (SQLite) · Supabase 云同步 · LWW 算法', SUCCESS),
        ('通知层', 'flutter_local_notifications · 平台原生推送', WARNING),
        ('构建 & 发布', 'Flutter Windows/Android/Web · GitHub CI/CD', DANGER),
    ]

    arch_data = []
    for i, (layer, detail, color) in enumerate(arch_layers):
        bg = BG_LIGHT if i % 2 == 0 else BG_CARD
        arch_data.append([
            Paragraph(f'<b>{layer}</b>', S(f'al{i}', font=FONT_BOLD, size=9, color=color)),
            Paragraph(detail, S(f'ad{i}', size=9, color=TEXT_MAIN, leading=14)),
        ])

    at = Table(arch_data, colWidths=[35*mm, usable - 37*mm])
    row_styles = []
    for i in range(len(arch_data)):
        bg = BG_LIGHT if i % 2 == 0 else BG_CARD
        row_styles.append(('BACKGROUND', (0,i), (-1,i), bg))
    at.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 7),
        ('BOTTOMPADDING', (0,0), (-1,-1), 7),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('LINEBELOW', (0,0), (-1,-1), 0.5, DIVIDER),
        ('ROWBACKGROUNDS', (0,0), (-1,-1), [BG_LIGHT, BG_CARD]),
    ]))
    story.append(at)
    story.append(Spacer(1, 5*mm))

    # 主要依赖表
    story.append(ColorBar('主要依赖', 'Key Dependencies', bar_color=ACCENT, height=28))
    story.append(Spacer(1, 3*mm))

    deps = [
        ('flutter_bloc', '状态管理', 'BLoC/Cubit 模式'),
        ('drift', '本地数据库', 'SQLite ORM，类型安全查询'),
        ('supabase_flutter', '云同步', '实时数据库 + Auth + Storage'),
        ('flutter_local_notifications', '本地通知', '跨平台推送，支持定时重复'),
        ('http / dio', '网络请求', 'DeepSeek API 调用'),
        ('flutter_markdown', 'Markdown 渲染', 'AI 回复富文本展示'),
    ]
    dep_header = [
        Paragraph('<b>依赖包</b>', S('dh0', font=FONT_BOLD, size=9, color=white, align=TA_CENTER)),
        Paragraph('<b>用途</b>', S('dh1', font=FONT_BOLD, size=9, color=white, align=TA_CENTER)),
        Paragraph('<b>说明</b>', S('dh2', font=FONT_BOLD, size=9, color=white, align=TA_CENTER)),
    ]
    dep_data = [dep_header]
    for pkg, use, note in deps:
        dep_data.append([
            Paragraph(pkg, S('dp0', font='Helvetica', size=8.5, color=SECONDARY)),
            Paragraph(use, S('dp1', size=8.5, color=TEXT_MAIN)),
            Paragraph(note, S('dp2', size=8.5, color=TEXT_MUTED)),
        ])

    dt = Table(dep_data, colWidths=[38*mm, 28*mm, usable - 68*mm])
    dt.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [BG_CARD, BG_LIGHT]),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('LINEBELOW', (0,0), (-1,-1), 0.3, DIVIDER),
    ]))
    story.append(dt)
    story.append(PageBreak())

    # ── PAGE 5: 定价方案 ──────────────────────────────────────
    story.append(ColorBar('定价方案', 'Pricing', bar_color=SUCCESS))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph(
        '一次买断，终身使用。无订阅，无隐性收费，买了就是你的。',
        S('price_intro', font=FONT_BOLD, size=11, color=TEXT_MAIN, align=TA_CENTER)
    ))
    story.append(Spacer(1, 6*mm))

    pricing = [
        ('入门版', '¥0', '永久免费', ['核心任务管理', 'AI 拆解（每日10次）', '本地日历视图', '思维导图（基础）'], False, '#6B7280'),
        ('专业版', '¥128', '一次买断', ['全功能无限制', 'AI 无限次调用', '云端同步 1GB', '优先客服支持'], True, '#E8632A'),
        ('团队版', '¥688', '5席位起', ['专业版全部权益', '团队协作空间', '管理员控制台', '专属部署方案'], False, '#2A6AE8'),
    ]

    pc_cw = usable / 3 - 3*mm
    pc_row = [[PricingCard(tier, price, unit, feats, hi, HexColor(col), w=int(pc_cw), h=210)
               for tier, price, unit, feats, hi, col in pricing]]
    pt2 = Table(pc_row, colWidths=[pc_cw]*3)
    pt2.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('LEFTPADDING', (0,0), (-1,-1), 3),
        ('RIGHTPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(pt2)
    story.append(Spacer(1, 6*mm))

    # 发布渠道
    story.append(ColorBar('发布渠道', 'Distribution', bar_color=WARNING, height=28))
    story.append(Spacer(1, 3*mm))

    channels = [
        ('GitHub', '#1F2937', 'github.com/xxx/smart_assistant — 开源社区版，持续迭代，接受 PR 与 Issue'),
        ('Windows Store', '#0078D4', 'Microsoft Store 上架，一键安装，自动更新，无需手动管理版本'),
        ('Google Play', '#34A853', 'Android 正式渠道，支持应用内购，适配 Android 8.0+'),
        ('官网直售', '#E8632A', 'smartassistant.app — 支持支付宝/微信，提供授权管理后台'),
        ('企业采购', '#8B5CF6', '邮件联系 biz@smartassistant.app，提供私有部署与定制报价'),
    ]

    for name, color, desc in channels:
        ch_t = Table([[
            Paragraph(f'<b>{name}</b>', S(f'cn_{name}', font=FONT_BOLD, size=9,
                                          color=HexColor(color), align=TA_CENTER)),
            Paragraph(desc, S(f'cd_{name}', size=9, color=TEXT_MUTED, leading=14)),
        ]], colWidths=[30*mm, usable - 32*mm])
        ch_t.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('TOPPADDING', (0,0), (-1,-1), 5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 5),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
            ('LINEBELOW', (0,0), (-1,-1), 0.5, DIVIDER),
        ]))
        story.append(ch_t)

    story.append(PageBreak())

    # ── PAGE 6: CTA 结尾 ──────────────────────────────────────
    story.append(Spacer(1, 20*mm))

    # 大 CTA 色块（用 Table 模拟）
    cta_inner = Table([[
        Paragraph('立即体验', S('cta1', font=FONT_BOLD, size=28, color=white, align=TA_CENTER)),
    ]], colWidths=[usable])
    cta_inner.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), PRIMARY),
        ('TOPPADDING', (0,0), (-1,-1), 20),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('ROUNDEDCORNERS', [12, 12, 12, 12]),
    ]))
    story.append(cta_inner)

    cta_sub = Table([[
        Paragraph('智能小管家 · 让 AI 成为你的专属效率管家', S('cta2', font=FONT_BOLD, size=12, color=white, align=TA_CENTER)),
    ]], colWidths=[usable])
    cta_sub.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), PRIMARY),
        ('TOPPADDING', (0,0), (-1,-1), 0),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(cta_sub)

    cta_url = Table([[
        Paragraph('🌐  smartassistant.app  ·  📧  hello@smartassistant.app',
                  S('cta3', size=10, color=white, align=TA_CENTER)),
    ]], colWidths=[usable])
    cta_url.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), HexColor('#C8541F')),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 12),
    ]))
    story.append(cta_url)

    story.append(Spacer(1, 10*mm))
    story.append(HRFlowable(width=usable, thickness=0.5, color=DIVIDER))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '© 2026 智能小管家团队 · 保留所有权利\n'
        '本手册仅供产品宣发使用，技术规格以正式发布版本为准。',
        S('footer', size=8, color=TEXT_LIGHT, align=TA_CENTER, leading=14)
    ))

    return story


# ──────────────────────────────────────────────────────────────
# 主函数
# ──────────────────────────────────────────────────────────────
def main():
    OUTPUT = 'E:/claude/project2/smart_assistant/智能小管家_宣发手册_v2.pdf'
    W, H = A4
    margin = 20*mm

    doc = SimpleDocTemplate(
        OUTPUT,
        pagesize=A4,
        leftMargin=margin, rightMargin=margin,
        topMargin=margin, bottomMargin=18*mm,
        title='智能小管家 产品宣发手册',
        author='Smart Assistant Team',
    )

    story = build_story(W, H)
    doc.build(story, onFirstPage=on_first_page, onLaterPages=on_page)
    print(f'生成完成: {OUTPUT}')


if __name__ == '__main__':
    main()
