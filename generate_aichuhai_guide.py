# -*- coding: utf-8 -*-
"""
AI出海新手实操指南 PDF 生成器
基于 aichuhai.dev 217篇文章整理
"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
    Table, TableStyle, ListFlowable, ListItem, KeepTogether
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import os

# ============================================================
# 字体注册
# ============================================================
FONT_PATHS = [
    ("msyh", "C:/Windows/Fonts/msyh.ttc", 0),
    ("msyhbd", "C:/Windows/Fonts/msyhbd.ttc", 0),
]

FONT_REGULAR = "msyh"
FONT_BOLD = "msyhbd"

for name, path, idx in FONT_PATHS:
    if os.path.exists(path):
        pdfmetrics.registerFont(TTFont(name, path, subfontIndex=idx))

# ============================================================
# 颜色定义
# ============================================================
C_PRIMARY = HexColor("#1a56db")
C_SECONDARY = HexColor("#6b7280")
C_ACCENT = HexColor("#059669")
C_WARNING = HexColor("#d97706")
C_DANGER = HexColor("#dc2626")
C_BG_LIGHT = HexColor("#f0f5ff")
C_BG_GREEN = HexColor("#ecfdf5")
C_BG_YELLOW = HexColor("#fffbeb")
C_BG_RED = HexColor("#fef2f2")
C_BORDER = HexColor("#e5e7eb")
C_DARK = HexColor("#111827")

# ============================================================
# 样式
# ============================================================
styles = getSampleStyleSheet()

S_COVER_TITLE = ParagraphStyle(
    "CoverTitle", fontName=FONT_BOLD, fontSize=28, leading=40,
    textColor=C_DARK, alignment=TA_CENTER, spaceAfter=10
)
S_COVER_SUB = ParagraphStyle(
    "CoverSub", fontName=FONT_REGULAR, fontSize=14, leading=22,
    textColor=C_SECONDARY, alignment=TA_CENTER, spaceAfter=6
)
S_H1 = ParagraphStyle(
    "H1", fontName=FONT_BOLD, fontSize=22, leading=32,
    textColor=C_PRIMARY, spaceBefore=20, spaceAfter=12
)
S_H2 = ParagraphStyle(
    "H2", fontName=FONT_BOLD, fontSize=16, leading=24,
    textColor=C_DARK, spaceBefore=16, spaceAfter=8
)
S_H3 = ParagraphStyle(
    "H3", fontName=FONT_BOLD, fontSize=13, leading=20,
    textColor=HexColor("#374151"), spaceBefore=12, spaceAfter=6
)
S_BODY = ParagraphStyle(
    "Body", fontName=FONT_REGULAR, fontSize=10.5, leading=18,
    textColor=C_DARK, spaceAfter=6, alignment=TA_JUSTIFY
)
S_BODY_SMALL = ParagraphStyle(
    "BodySmall", fontName=FONT_REGULAR, fontSize=9.5, leading=16,
    textColor=C_SECONDARY, spaceAfter=4
)
S_LINK = ParagraphStyle(
    "Link", fontName=FONT_REGULAR, fontSize=9, leading=14,
    textColor=C_PRIMARY, spaceAfter=2
)
S_BULLET = ParagraphStyle(
    "Bullet", fontName=FONT_REGULAR, fontSize=10.5, leading=18,
    textColor=C_DARK, spaceAfter=4, leftIndent=12, bulletIndent=0
)
S_NUM = ParagraphStyle(
    "Num", fontName=FONT_REGULAR, fontSize=10.5, leading=18,
    textColor=C_DARK, spaceAfter=4, leftIndent=16, bulletIndent=0
)
S_TIP_TITLE = ParagraphStyle(
    "TipTitle", fontName=FONT_BOLD, fontSize=10.5, leading=16,
    textColor=C_ACCENT, spaceAfter=2
)
S_TIP_BODY = ParagraphStyle(
    "TipBody", fontName=FONT_REGULAR, fontSize=10, leading=16,
    textColor=HexColor("#065f46"), spaceAfter=2
)
S_WARN_TITLE = ParagraphStyle(
    "WarnTitle", fontName=FONT_BOLD, fontSize=10.5, leading=16,
    textColor=C_WARNING, spaceAfter=2
)
S_WARN_BODY = ParagraphStyle(
    "WarnBody", fontName=FONT_REGULAR, fontSize=10, leading=16,
    textColor=HexColor("#92400e"), spaceAfter=2
)
S_TABLE_HEADER = ParagraphStyle(
    "TH", fontName=FONT_BOLD, fontSize=10, leading=14,
    textColor=white, alignment=TA_CENTER
)
S_TABLE_CELL = ParagraphStyle(
    "TC", fontName=FONT_REGULAR, fontSize=9.5, leading=14,
    textColor=C_DARK
)
S_PHASE_TAG = ParagraphStyle(
    "PhaseTag", fontName=FONT_BOLD, fontSize=11, leading=16,
    textColor=white
)


# ============================================================
# 辅助函数
# ============================================================
def tip_box(title, body_lines, bg=C_BG_GREEN, title_style=S_TIP_TITLE, body_style=S_TIP_BODY):
    """创建提示框"""
    content = [[Paragraph(title, title_style)]]
    for line in body_lines:
        content.append([Paragraph(line, body_style)])
    t = Table(content, colWidths=[460])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING", (0, 0), (-1, -1), 12),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ]))
    return t


def warn_box(title, body_lines):
    return tip_box(title, body_lines, bg=C_BG_YELLOW, title_style=S_WARN_TITLE, body_style=S_WARN_BODY)


def phase_header(num, title, color, desc):
    """阶段标题"""
    tag_data = [[Paragraph(f"阶段 {num}", S_PHASE_TAG), Paragraph(title, ParagraphStyle(
        "PT", fontName=FONT_BOLD, fontSize=15, leading=22, textColor=white
    ))]]
    tag = Table(tag_data, colWidths=[60, 400])
    tag.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), color),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    return [tag, Spacer(1, 4), Paragraph(desc, S_BODY_SMALL), Spacer(1, 8)]


def article_table(articles):
    """文章推荐表格"""
    header = [
        Paragraph("序号", S_TABLE_HEADER),
        Paragraph("文章标题", S_TABLE_HEADER),
        Paragraph("分类", S_TABLE_HEADER),
        Paragraph("优先级", S_TABLE_HEADER),
    ]
    data = [header]
    for i, (title, tag, priority) in enumerate(articles, 1):
        data.append([
            Paragraph(str(i), S_TABLE_CELL),
            Paragraph(title, S_TABLE_CELL),
            Paragraph(tag, S_TABLE_CELL),
            Paragraph(priority, S_TABLE_CELL),
        ])
    t = Table(data, colWidths=[30, 280, 60, 60])
    style = [
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("ALIGN", (0, 0), (0, -1), "CENTER"),
        ("ALIGN", (3, 0), (3, -1), "CENTER"),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            style.append(("BACKGROUND", (0, i), (-1, i), C_BG_LIGHT))
    t.setStyle(TableStyle(style))
    return t


def step_list(steps):
    """编号步骤列表"""
    items = []
    for i, step in enumerate(steps, 1):
        items.append(Paragraph(f"<b>{i}.</b> {step}", S_NUM))
    return items


def bullet_list(items_text):
    items = []
    for txt in items_text:
        items.append(Paragraph(f"\xe2\x80\xa2 {txt}", S_BULLET))
    return items


# ============================================================
# 构建文档
# ============================================================
def build_pdf():
    output_path = "E:/claude/project2/smart_assistant/AI出海新手实操指南.pdf"
    doc = SimpleDocTemplate(
        output_path, pagesize=A4,
        topMargin=2*cm, bottomMargin=2*cm,
        leftMargin=2.2*cm, rightMargin=2.2*cm,
        title="AI出海新手实操指南",
        author="基于 aichuhai.dev 整理"
    )

    story = []

    # ==================== 封面 ====================
    story.append(Spacer(1, 80))
    story.append(Paragraph("AI 网站出海", S_COVER_TITLE))
    story.append(Paragraph("新手实操指南", S_COVER_TITLE))
    story.append(Spacer(1, 20))
    story.append(Paragraph("从零到变现的完整路径", S_COVER_SUB))
    story.append(Paragraph("基于 aichuhai.dev 社区 241 篇文章精选整理", S_COVER_SUB))
    story.append(Spacer(1, 30))

    cover_info = [
        ["适用人群", "零基础想做海外 AI 工具站的开发者/创业者"],
        ["内容来源", "aichuhai.dev  AI 网站出海开发者社区"],
        ["文章总量", "241 篇（217 篇已索引），覆盖 13 个专题"],
        ["整理日期", "2026 年 6 月"],
    ]
    cover_data = []
    for k, v in cover_info:
        cover_data.append([
            Paragraph(k, ParagraphStyle("ck", fontName=FONT_BOLD, fontSize=10, textColor=C_PRIMARY)),
            Paragraph(v, ParagraphStyle("cv", fontName=FONT_REGULAR, fontSize=10, textColor=C_DARK)),
        ])
    ct = Table(cover_data, colWidths=[80, 350])
    ct.setStyle(TableStyle([
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("LINEBELOW", (0, 0), (-1, -2), 0.3, C_BORDER),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(ct)
    story.append(Spacer(1, 40))
    story.append(tip_box(
        "使用说明",
        [
            "本指南将 241 篇文章按新手变现路径重新编排为 7 个阶段。",
            "每个阶段包含：核心文章推荐、实操步骤、避坑提醒。",
            "建议按阶段顺序阅读，每完成一个阶段再进入下一个。",
            "所有文章均可在 aichuhai.dev 网站搜索标题找到原文。",
        ]
    ))

    story.append(PageBreak())

    # ==================== 目录 ====================
    story.append(Paragraph("目录", S_H1))
    story.append(Spacer(1, 8))
    toc_items = [
        ("一", "全景地图：7 阶段变现路径总览"),
        ("二", "阶段 1 — 认知建立（1-2 天）"),
        ("三", "阶段 2 — 需求挖掘（3-5 天）"),
        ("四", "阶段 3 — 开发上线（1-2 周）"),
        ("五", "阶段 4 — SEO 与流量获取（持续）"),
        ("六", "阶段 5 — 收款变现（1-3 天）"),
        ("七", "阶段 6 — 数据分析与优化（持续）"),
        ("八", "阶段 7 — 增长放大（持续）"),
        ("九", "2026 年补充：AI 搜索时代的新打法"),
        ("十", "工具速查表"),
        ("附", "完整文章索引（按阶段排列）"),
    ]
    for num, title in toc_items:
        story.append(Paragraph(f"{num}、{title}", ParagraphStyle(
            "toc", fontName=FONT_REGULAR, fontSize=11, leading=22,
            textColor=C_DARK, leftIndent=20
        )))
    story.append(PageBreak())

    # ==================== 一、全景地图 ====================
    story.append(Paragraph("一、全景地图：7 阶段变现路径总览", S_H1))
    story.append(Paragraph(
        "下表展示了从零开始到稳定变现的完整路径。作为新手，你不需要一次读完所有文章，"
        "而是按阶段推进，每完成一个阶段的核心动作后再进入下一个。", S_BODY
    ))
    story.append(Spacer(1, 8))

    roadmap_header = [
        Paragraph("阶段", S_TABLE_HEADER),
        Paragraph("核心目标", S_TABLE_HEADER),
        Paragraph("时间", S_TABLE_HEADER),
        Paragraph("关键文章数", S_TABLE_HEADER),
    ]
    roadmap_data = [roadmap_header]
    roadmap_rows = [
        ("1. 认知建立", "理解出海生意模型", "1-2 天", "8 篇"),
        ("2. 需求挖掘", "找到值得做的细分方向", "3-5 天", "12 篇"),
        ("3. 开发上线", "用最低成本上线 MVP", "1-2 周", "15 篇"),
        ("4. SEO+流量", "获取第一批自然流量", "持续", "25 篇"),
        ("5. 收款变现", "接入支付，开始赚钱", "1-3 天", "10 篇"),
        ("6. 数据优化", "用数据驱动改进", "持续", "12 篇"),
        ("7. 增长放大", "扩大收入规模", "持续", "15 篇"),
    ]
    for row in roadmap_rows:
        roadmap_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    rt = Table(roadmap_data, colWidths=[100, 180, 60, 80])
    rt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("ALIGN", (2, 0), (3, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("BACKGROUND", (0, 1), (-1, 1), C_BG_LIGHT),
        ("BACKGROUND", (0, 3), (-1, 3), C_BG_LIGHT),
        ("BACKGROUND", (0, 5), (-1, 5), C_BG_LIGHT),
        ("BACKGROUND", (0, 7), (-1, 7), C_BG_LIGHT),
    ]))
    story.append(rt)
    story.append(Spacer(1, 12))
    story.append(tip_box("核心原则", [
        "先验证需求，再动手开发。不要一上来就写代码。",
        "用最简单的方案跑通全链路（需求 > 建站 > SEO > 收款），再优化细节。",
        "一个人完全可以做，关键是选对方向和控制成本。",
    ]))

    story.append(PageBreak())

    # ==================== 二、阶段 1 — 认知建立 ====================
    story.extend(phase_header(1, "认知建立", HexColor("#6366f1"),
        "目标：理解 AI 网站出海的商业模型、赚钱逻辑和成功案例。花 1-2 天建立全局认知。"))

    story.append(Paragraph("必读文章（按顺序）", S_H3))
    story.append(article_table([
        ("第一次赚美元！纯新手深度复盘网站出海，一文掌握全流程", "复盘", "必读"),
        ("AI 网站出海的学习路线", "复盘", "必读"),
        ("网站出海的学习方式", "复盘", "必读"),
        ("聊聊网站出海这个生意", "复盘", "必读"),
        ("凭什么一个人就能月入21万美元", "复盘", "推荐"),
        ("出海一周年，网站出海内容整理", "复盘", "推荐"),
        ("出海创业的熵减思维", "复盘", "推荐"),
        ("技术重要，思维更关键", "复盘", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("这个阶段你要搞清楚的事", S_H3))
    story.extend(bullet_list([
        "<b>商业模型</b>：找到海外用户的痛点 > 做一个 AI 工具网站 > 通过 SEO 获取免费流量 > 用 Stripe/PayPal 收费",
        "<b>为什么是 AI 套壳？</b>：调用 API 即可，不需要训练模型，一个人就能搞定全栈",
        "<b>为什么做海外？</b>：付费意愿高、市场大、SEO 生态成熟、美元定价",
        "<b>典型收入周期</b>：上线 1-3 个月开始有流量，3-6 个月开始有收入，持续优化后月入千刀到万刀不等",
        "<b>成本多低？</b>：域名 + 服务器 + API 调用，前期月成本可以控制在 100 元人民币以内",
    ]))
    story.append(Spacer(1, 8))
    story.append(warn_box("新手常见误区", [
        "误区 1：上来就写代码。正确做法是先花几天研究需求和竞品。",
        "误区 2：追求完美再上线。应该 MVP 先跑起来，再迭代。",
        "误区 3：只盯着热门方向。竞争激烈的大词打不过，应该找细分长尾。",
    ]))

    story.append(PageBreak())

    # ==================== 三、阶段 2 — 需求挖掘 ====================
    story.extend(phase_header(2, "需求挖掘", HexColor("#8b5cf6"),
        "目标：找到一个竞争小、有搜索量、能用 AI 解决的细分需求。这是最关键的一步。"))

    story.append(Paragraph("必读文章", S_H3))
    story.append(article_table([
        ("找需求的一些方法", "需求挖掘", "必读"),
        ("基于人群找细分需求", "需求挖掘", "必读"),
        ("需求的痛点决定了转化率", "需求挖掘", "必读"),
        ("如何看对标网站", "需求挖掘", "必读"),
        ("卖空气验证需求", "需求挖掘", "必读"),
        ("如何分析榜单和竞品", "需求挖掘", "推荐"),
        ("Similarweb 需求分析", "需求挖掘", "推荐"),
        ("常见的收入榜单", "需求挖掘", "推荐"),
        ("批量查看 Google trends 开源项目", "需求挖掘", "推荐"),
        ("收集插件抱怨找需求", "需求挖掘", "推荐"),
        ("用 Discord 挖掘需求、推广产品", "需求挖掘", "推荐"),
        ("高级搜索找需求", "需求挖掘", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("实操步骤", S_H3))
    story.extend(step_list([
        "<b>逛收入榜单找灵感</b>：去 IndieHackers、MRR.dev、TrustMRR 看别人在做什么赚钱",
        "<b>用 Google Trends 验证趋势</b>：输入关键词看搜索量趋势，上升 = 机会",
        "<b>用 ahrefs/semrush 查竞争度</b>：找 KD (Keyword Difficulty) < 20 的关键词",
        "<b>去 Reddit/Discord 看用户在抱怨什么</b>：真实痛点 = 真实需求",
        "<b>看竞品做了什么没做什么</b>：用 Similarweb 分析流量来源和规模",
        "<b>快速验证</b>：先做一个落地页，看是否有人搜索到并点击，再决定是否开发",
    ]))
    story.append(Spacer(1, 8))
    story.append(tip_box("找需求的黄金公式", [
        "好需求 = 有搜索量（月搜 1000+）+ 低竞争（KD<20）+ 能用 AI 解决 + 用户愿意付费",
        "推荐方向：AI 写作工具、图片处理、PDF 工具、提示词模板、特定行业的 AI 助手",
        "避开方向：通用聊天机器人（打不过官方）、纯信息聚合（没有壁垒）",
    ]))

    story.append(PageBreak())

    # ==================== 四、阶段 3 — 开发上线 ====================
    story.extend(phase_header(3, "开发上线", HexColor("#0891b2"),
        "目标：用最低成本、最快速度上线一个能用的 MVP 网站。"))

    story.append(Paragraph("必读文章", S_H3))
    story.append(article_table([
        ("跟着免费的保姆级教程，上线自己的网站", "部署上线", "必读"),
        ("前期上线网站成本有多低", "部署上线", "必读"),
        ("域名选择优先级", "部署上线", "必读"),
        ("只靠聊天，做高颜值网站，你也行！", "开发", "必读"),
        ("用 CMS 提升上站效率", "开发", "必读"),
        ("一键部署上线", "部署上线", "必读"),
        ("基于模板的上站 SOP", "部署上线", "推荐"),
        ("cloudflare 自动化部署", "部署上线", "推荐"),
        ("白嫖 neon 数据库", "开发", "推荐"),
        ("使用 claude design 设计你的网站", "产品设计", "推荐"),
        ("Google One Tap 丝滑登录", "开发", "推荐"),
        ("怎么提升 AI 的审美", "产品设计", "推荐"),
        ("注意后端渲染", "开发", "推荐"),
        ("如何制作网站的 OG 图", "产品设计", "推荐"),
        ("多语言适配", "开发", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("技术栈推荐（新手友好）", S_H3))
    tech_header = [Paragraph(h, S_TABLE_HEADER) for h in ["层级", "推荐方案", "说明"]]
    tech_data = [tech_header]
    tech_rows = [
        ("前端框架", "Next.js / Nuxt.js", "SSR 对 SEO 友好"),
        ("UI 组件", "Tailwind CSS + shadcn/ui", "快速出页面"),
        ("数据库", "Supabase / Neon (免费)", "PostgreSQL 托管"),
        ("AI 接入", "OpenAI / Claude API", "按调用付费"),
        ("部署", "Vercel / Cloudflare Pages", "免费额度足够起步"),
        ("域名", ".com 优先，短好记", "Namecheap / Cloudflare"),
        ("登录", "Google One Tap + NextAuth", "降低注册摩擦"),
        ("设计", "Claude Design / v0.dev", "AI 生成 UI"),
    ]
    for row in tech_rows:
        tech_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    tt = Table(tech_data, colWidths=[80, 170, 170])
    tt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(tt)
    story.append(Spacer(1, 10))

    story.append(Paragraph("上线 Checklist", S_H3))
    story.extend(step_list([
        "注册域名（.com 优先，包含核心关键词更好）",
        "用 Next.js 模板 + AI 编程搭建网站",
        "接入 AI API（先用 OpenAI，后期可切换）",
        "配置 Google Analytics + Search Console",
        "添加 sitemap.xml 和 robots.txt",
        "手动请求 Google 索引，加快收录",
        "部署到 Vercel / Cloudflare（免费）",
        "测试核心功能 + 移动端适配",
    ]))
    story.append(Spacer(1, 8))
    story.append(warn_box("避坑提醒", [
        "Vercel 免费额度有上限，流量大了可能账单爆炸（见文章：vercel 账单暴涨）",
        "一定要做后端渲染 (SSR)，否则 Google 爬不到你的内容",
        "Next.js 有过安全漏洞，及时更新版本",
    ]))

    story.append(PageBreak())

    # ==================== 五、阶段 4 — SEO ====================
    story.extend(phase_header(4, "SEO 与流量获取", HexColor("#059669"),
        "目标：让 Google 收录你的网站，获取免费的搜索流量。这是出海站的核心增长引擎。"))

    story.append(Paragraph("SEO 基础必读", S_H3))
    story.append(article_table([
        ("推荐大家都看看 Google 官方的 SEO 文档", "SEO", "必读"),
        ("理解用户搜索意图", "SEO", "必读"),
        ("Google 排名的影响因素", "SEO", "必读"),
        ("低 KD 多内页打法", "SEO", "必读"),
        ("基于 GSC 的出词数据反向新增内页", "SEO", "必读"),
        ("ahrefs 免费帮你诊断 SEO 问题", "SEO", "推荐"),
        ("AITDK SEO 内容的生成和重写", "SEO", "推荐"),
        ("SEO 问题一键扫描", "SEO", "推荐"),
    ]))
    story.append(Spacer(1, 8))

    story.append(Paragraph("SEO 实操核心", S_H3))
    story.extend(step_list([
        "<b>选词</b>：用 ahrefs/semrush 免费工具找 KD<20、月搜 500+ 的长尾关键词",
        "<b>做内页</b>：每个关键词做一个专门的落地页，标题包含关键词",
        "<b>写内容</b>：用 AI 辅助生成，但必须人工审核确保质量和准确性",
        "<b>提交索引</b>：在 GSC 手动请求索引，加快收录",
        "<b>监控排名</b>：GSC 看哪些词在上升，加大投入",
        "<b>反向操作</b>：GSC 出词数据 > 发现用户在搜什么 > 新增对应页面",
    ]))
    story.append(Spacer(1, 8))

    story.append(Paragraph("外链建设", S_H3))
    story.append(article_table([
        ("20 个免费高质量外链资源", "外链", "必读"),
        ("什么是好的外链", "外链", "必读"),
        ("如何上架 chrome 插件带来高质量外链", "外链", "推荐"),
        ("Notion site 添加一个高权重的外链", "外链", "推荐"),
        ("搜索语法找外链", "外链", "推荐"),
    ]))
    story.append(Spacer(1, 8))

    story.append(Paragraph("社交媒体流量", S_H3))
    story.append(article_table([
        ("推荐 10 个 reddit 子社区", "流量获取", "必读"),
        ("reddit 营销，8 小时 280 karma 值分享", "流量获取", "必读"),
        ("推特营销起号", "流量获取", "推荐"),
        ("youtube 营销推广网站", "流量获取", "推荐"),
        ("邮件营销小技巧", "流量获取", "推荐"),
        ("产品自传播", "流量获取", "推荐"),
    ]))
    story.append(Spacer(1, 8))
    story.append(tip_box("SEO 心法", [
        "SEO 是长期投资，通常需要 2-3 个月才能看到效果。",
        "低竞争小词的魅力：8 条外链就能拿下 41K 月访问量（参考同名文章）。",
        "不要只做 Google，Bing 搜索量虽小但竞争也小，更容易出结果。",
    ]))

    story.append(PageBreak())

    # ==================== 六、阶段 5 — 收款 ====================
    story.extend(phase_header(5, "收款变现", HexColor("#d97706"),
        "目标：接入国际支付，让用户能付费。这一步其实比想象中简单。"))

    story.append(Paragraph("必读文章", S_H3))
    story.append(article_table([
        ("Stripe 注册到提现全流程", "收款", "必读"),
        ("Stripe、Paypal、Creem 政策对比", "收款", "必读"),
        ("Paypal 接入网站进行收款", "收款", "必读"),
        ("香港个人账户注册 Stripe", "stripe", "必读"),
        ("如何海外挣美刀内地花", "收款", "必读"),
        ("定价策略", "产品设计", "必读"),
        ("stripe 收款设置，避免不必要的损耗", "stripe", "推荐"),
        ("雷达设置，防止 stripe 封号", "stripe", "推荐"),
        ("防止用户薅羊毛", "stripe", "推荐"),
        ("定价时需要考虑 stripe 的手续费", "stripe", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("收款方案对比", S_H3))
    pay_header = [Paragraph(h, S_TABLE_HEADER) for h in ["方案", "门槛", "手续费", "适合谁"]]
    pay_data = [pay_header]
    pay_rows = [
        ("Stripe", "需要海外主体/香港银行卡", "2.9% + $0.30", "首选，最专业"),
        ("PayPal", "个人即可开通", "3.49% + $0.49", "门槛低，适合起步"),
        ("Creem", "中国大陆可用", "5% 左右", "无海外主体的备选"),
        ("Lemonsqueezy", "无需海外主体", "5% + $0.50", "一站式方案"),
    ]
    for row in pay_rows:
        pay_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    pt = Table(pay_data, colWidths=[90, 140, 100, 100])
    pt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(pt)
    story.append(Spacer(1, 8))

    story.append(Paragraph("定价建议", S_H3))
    story.extend(bullet_list([
        "月付 $9-29 是最常见的价格区间，新手建议从低价起步",
        "提供免费试用或 Freemium 模式，降低用户决策门槛",
        "年付打折（通常 8 折）可以提升客单价和留存",
        "定价时加上 Stripe 手续费，不要让手续费吃掉利润",
        "同一产品可以做不同定价（基础版/专业版/企业版）",
    ]))

    story.append(PageBreak())

    # ==================== 七、阶段 6 — 数据分析 ====================
    story.extend(phase_header(6, "数据分析与优化", HexColor("#0284c7"),
        "目标：用数据驱动决策，持续优化转化率和用户体验。"))

    story.append(Paragraph("必读文章", S_H3))
    story.append(article_table([
        ("热力图分析用户的行为", "数据分析", "必读"),
        ("复盘一个网站的转化链路", "复盘", "必读"),
        ("核心链路转化", "产品设计", "必读"),
        ("clarity 看网站错误信息", "数据分析", "必读"),
        ("Google Analysis 的官方教程", "数据分析", "必读"),
        ("AI 帮你查看分析网站数据", "数据分析", "推荐"),
        ("分析对标网站流量来源，补齐流量渠道", "数据分析", "推荐"),
        ("你的用户到底值不值钱", "数据分析", "推荐"),
        ("计算网站的获客成本", "ads", "推荐"),
        ("付费用户追踪", "数据分析", "推荐"),
        ("GSC 数据筛选", "SEO", "推荐"),
        ("Stripe API 分析数据", "stripe", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("必须关注的核心指标", S_H3))
    metric_header = [Paragraph(h, S_TABLE_HEADER) for h in ["指标", "工具", "健康值"]]
    metric_data = [metric_header]
    metric_rows = [
        ("日 UV（独立访客）", "Google Analytics", "起步阶段 >100"),
        ("跳出率", "Google Analytics", "<60%"),
        ("平均停留时长", "Google Analytics", ">2 分钟"),
        ("转化率（访客>付费）", "Stripe + GA", "1-3% 算正常"),
        ("关键词排名", "GSC / ahrefs", "前 10 为目标"),
        ("MRR（月经常性收入）", "Stripe Dashboard", "持续增长"),
        ("用户行为热力图", "Microsoft Clarity（免费）", "发现点击盲区"),
    ]
    for row in metric_rows:
        metric_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    mt = Table(metric_data, colWidths=[130, 140, 150])
    mt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(mt)

    story.append(PageBreak())

    # ==================== 八、阶段 7 — 增长 ====================
    story.extend(phase_header(7, "增长放大", HexColor("#dc2626"),
        "目标：从月入百刀到月入千刀甚至万刀。扩大流量渠道、优化产品、提升客单价。"))

    story.append(Paragraph("必读文章", S_H3))
    story.append(article_table([
        ("网站从 0 到 1 后怎么放大", "复盘", "必读"),
        ("如何从 0 做到 2w+ 付费用户的", "复盘", "必读"),
        ("月入 3 千美刀达成，每日分享梳理", "复盘", "必读"),
        ("stripe 向上销售，提升客单价", "stripe", "必读"),
        ("涨价策略", "产品设计", "必读"),
        ("提升用户留存", "产品设计", "必读"),
        ("分享裂变，让你的网站可持续", "流量获取", "推荐"),
        ("同一个产品做不同定价", "产品设计", "推荐"),
        ("AppSumo 为了你的终身产品获取大量用户", "流量获取", "推荐"),
        ("投流的作用", "ads", "推荐"),
        ("系统学习 Google 投流", "ads", "推荐"),
        ("自己也能做联盟推广", "流量获取", "推荐"),
        ("让用户先看到，再付费", "产品设计", "推荐"),
        ("用弹窗来提升体验和转化", "产品设计", "推荐"),
        ("网站变现效率", "收款", "推荐"),
    ]))
    story.append(Spacer(1, 10))

    story.append(Paragraph("增长杠杆（按优先级）", S_H3))
    story.extend(step_list([
        "<b>持续做内页 SEO</b>：每个新关键词 = 一个新的流量入口",
        "<b>优化转化率</b>：改定价页面、加社会证明、减少注册摩擦",
        "<b>向上销售 (Upsell)</b>：现有用户升级更贵的套餐",
        "<b>多渠道引流</b>：Reddit + 推特 + YouTube + Newsletter",
        "<b>产品自传播</b>：让用户主动分享（水印、分享按钮、推荐奖励）",
        "<b>付费投流</b>：确认 ROI 为正后，用 Google Ads 放大",
        "<b>联盟推广</b>：让别人帮你推广，按成交付佣金",
    ]))

    story.append(PageBreak())

    # ==================== 九、2026 补充 ====================
    story.append(Paragraph("九、2026 年补充：AI 搜索时代的新打法", S_H1))
    story.append(Paragraph(
        "aichuhai.dev 的内容主要写于 2024-2025 年，以传统 Google SEO 为核心。"
        "但 2026 年 AI 搜索已经深刻改变了流量分发格局，以下是必须补充的认知：", S_BODY
    ))
    story.append(Spacer(1, 8))

    story.append(Paragraph("传统 SEO vs AI 搜索", S_H3))
    vs_header = [Paragraph(h, S_TABLE_HEADER) for h in ["维度", "传统 Google SEO", "AI 搜索 (GEO)"]]
    vs_data = [vs_header]
    vs_rows = [
        ("流量来源", "Google 搜索结果页点击", "ChatGPT/Perplexity/Gemini 引用"),
        ("排名因素", "外链、内容质量、技术 SEO", "内容被 AI 引用的概率"),
        ("用户行为", "点击链接进入网站", "直接在 AI 中获取答案"),
        ("对策", "做排名、抢点击", "做权威内容，争取被 AI 引用"),
        ("趋势", "流量缓慢下降", "快速增长，但变现难度更大"),
    ]
    for row in vs_rows:
        vs_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    vt = Table(vs_data, colWidths=[70, 180, 180])
    vt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(vt)
    story.append(Spacer(1, 10))

    story.append(Paragraph("2026 年新手应该怎么做", S_H3))
    story.extend(step_list([
        "<b>SEO 仍然要做</b>：Google 搜索量虽下降，但仍是最大的免费流量来源",
        "<b>同时布局 GEO</b>：让你的网站内容容易被 AI 引用（结构化、权威、有数据支撑）",
        "<b>关注 AI 流量</b>：用 Clarity 看 AI 爬虫访问情况（参考文章：clarity 看 AI 访问引用情况）",
        "<b>做工具而不是内容</b>：纯内容站容易被 AI 替代，工具站提供的是功能，更难替代",
        "<b>多渠道不依赖单一流量源</b>：社交媒体 + SEO + AI 引用 + 邮件列表，组合打法",
        "<b>套壳要有差异化</b>：纯 API 套壳已内卷，必须在产品体验、垂直场景上做出差异",
    ]))
    story.append(Spacer(1, 8))
    story.append(warn_box("最重要的变化", [
        "2024 年，一个人做个 AI 套壳站，SEO 做起来就能月入千刀。",
        "2026 年，这条路依然可行但更难了。你需要更细分的需求、更好的产品体验、",
        "以及 SEO + 社交 + AI 搜索的多渠道布局。好消息是：门槛提高意味着竞争者减少。",
    ]))

    story.append(PageBreak())

    # ==================== 十、工具速查 ====================
    story.append(Paragraph("十、工具速查表", S_H1))
    story.append(Spacer(1, 8))

    tools_header = [Paragraph(h, S_TABLE_HEADER) for h in ["用途", "工具", "费用", "推荐文章"]]
    tools_data = [tools_header]
    tools_rows = [
        ("关键词研究", "ahrefs / semrush", "有免费版", "ahrefs 免费帮你诊断 SEO"),
        ("关键词研究", "Google Trends", "免费", "批量查看 Google trends"),
        ("竞品分析", "Similarweb", "有免费版", "Similarweb 需求分析"),
        ("SEO 诊断", "AITDK / SEO 插件", "免费", "SEO 插件分享"),
        ("网站分析", "Google Analytics", "免费", "GA 的官方教程"),
        ("搜索表现", "Google Search Console", "免费", "GSC 数据筛选"),
        ("热力图", "Microsoft Clarity", "免费", "热力图分析用户的行为"),
        ("收款", "Stripe", "2.9%+$0.30", "Stripe 注册到提现全流程"),
        ("收款", "PayPal", "3.49%+$0.49", "Paypal 接入网站进行收款"),
        ("部署", "Vercel / Cloudflare", "有免费版", "一键部署上线"),
        ("数据库", "Supabase / Neon", "有免费版", "白嫖 neon 数据库"),
        ("AI 编程", "Claude Code / Cursor", "付费", "用嘴编程提效"),
        ("设计", "Claude Design / v0", "免费/付费", "使用 claude design 设计"),
        ("外链查询", "DR 查询工具", "免费", "查看网站 DR 神器"),
        ("广告投放", "Google Ads", "按点击付费", "系统学习 Google 投流"),
    ]
    for row in tools_rows:
        tools_data.append([Paragraph(r, S_TABLE_CELL) for r in row])
    tlt = Table(tools_data, colWidths=[80, 120, 80, 150])
    tlt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), C_PRIMARY),
        ("GRID", (0, 0), (-1, -1), 0.5, C_BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    for i in range(1, len(tools_data)):
        if i % 2 == 0:
            tlt.setStyle(TableStyle([("BACKGROUND", (0, i), (-1, i), C_BG_LIGHT)]))
    story.append(tlt)

    story.append(PageBreak())

    # ==================== 附录 ====================
    story.append(Paragraph("附录：完整文章索引（按阶段排列）", S_H1))
    story.append(Paragraph(
        "以下是 aichuhai.dev 全部 240 篇文章，按本指南的 7 个阶段重新归类。"
        "在 aichuhai.dev 网站搜索文章标题即可找到原文。", S_BODY
    ))
    story.append(Spacer(1, 8))

    appendix_phases = [
        ("阶段 1：认知建立", [
            "第一次赚美元！纯新手深度复盘网站出海",
            "AI 网站出海的学习路线",
            "网站出海的学习方式",
            "聊聊网站出海这个生意",
            "凭什么一个人就能月入21万美元",
            "出海一周年，网站出海内容整理",
            "出海创业的熵减思维",
            "不要给自己设限",
            "技术重要，思维更关键",
            "网站出海就是一个种树的故事",
            "这一年，感谢自己选择了网站出海",
            "2025 年度总结",
            "哥飞年终分享会总结",
            "分享5篇很有价值的复盘贴",
            "最值得关注的网站出海博主大合集",
            "网站出海公众号推荐",
            "一场高质量直播",
            "build in public",
        ]),
        ("阶段 2：需求挖掘", [
            "找需求的一些方法",
            "基于人群找细分需求",
            "需求的痛点决定了转化率",
            "如何看对标网站",
            "卖空气验证需求",
            "如何分析榜单和竞品",
            "Similarweb 需求分析",
            "常见的收入榜单",
            "批量查看Google trends开源项目",
            "新版Google trends，用AI扩词根",
            "收集插件抱怨找需求",
            "用 Discord 挖掘需求",
            "高级搜索找需求",
            "外链找需求",
            "通过词根找需求",
            "grok 上奏折,监测新词",
            "HeyGen找需求示例分享",
            "找到一个人做的所有网站",
            "一眼看出网站如何实现的",
            "信息溯源，快速找到新词",
            "出站流量找到受关注的产品",
        ]),
        ("阶段 3：开发上线", [
            "跟着免费的保姆级教程，上线自己的网站",
            "前期上线网站成本有多低",
            "域名选择优先级",
            "只靠聊天，做高颜值网站",
            "用CMS 提升上站效率",
            "一键部署上线",
            "基于模板的上站SOP",
            "cloudflare 自动化部署",
            "白嫖neon 数据库",
            "使用claude design 设计你的网站",
            "Google One Tap丝滑登录",
            "怎么提升AI的审美",
            "怎么提升AI审美 - Stitch",
            "怎么提升AI的审美 - 所见即所得",
            "注意后端渲染",
            "如何制作网站的OG图",
            "多语言适配",
            "多语言自动检测提醒",
            "ico 一键多平台适配",
            "cloudflare R2 白嫖存储",
            "cloudflare 绑定域名邮箱",
            "如何配置子域名",
            "快捷拾取网站配色",
            "网页性能分析检测",
            "数据库小技巧",
            "API调试",
            "重大 Next.js 漏洞问题",
            "用嘴编程提效",
            "用嘴编程一些技巧",
            "让AI 了解你的项目",
            "Claude Code 真正的玩法",
            "创建一个claude skill 减少重复操作",
            "创建claude code命令，减少重复操作",
            "快速集成客服聊天框",
            "跟着AI快速部署服务器",
        ]),
        ("阶段 4：SEO 与流量", [
            "推荐大家都看看Google 官方的SEO文档",
            "理解用户搜索意图",
            "Google 排名的影响因素",
            "低kd 多内页打法",
            "基于gsc 的出词数据反向新增内页",
            "ahrefs免费帮你诊断SEO问题",
            "AITDK SEO 内容的生成和重写",
            "SEO 问题一键扫描",
            "Canonical 标签",
            "typo词的妙用",
            "图片优化",
            "图片也能做SEO",
            "避免无关词影响核心关键词",
            "手动请求索引加快收录速度",
            "GSC 自动提交",
            "GSC 数据筛选",
            "Bing 关键词研究",
            "搜索引擎思维做网站",
            "搜索引擎爬虫访问说明书",
            "搜索语法",
            "查看不同国家的搜索结果",
            "利用youtube生成内页",
            "多平台收录网站",
            "sitemap使用小技巧",
            "sitelink",
            "semrush 创作SEO内容",
            "semrush 查看主要页面",
            "Similarweb 着落页找词",
            "记录一次下线有流量页面的过程",
            "网站内容检查",
            "布局AI搜索",
            "如何查看AI流量，做好GEO",
            "用搜索数据评估一个词是否值得做",
            "低竞争小词的魅力",
            "SEO 插件分享",
            "SEO查词插件",
            "SEO 插件看关键词",
            "推荐一个SEO skill",
            "快捷查看KGR",
            "如何查看成功网站的来时路",
            "使用爬虫参考SEO内容",
            "对标分析自己网站的heading",
            "20个免费高质量外链资源",
            "什么是好的外链",
            "如何上架chrome插件带来高质量外链",
            "Notion site 添加一个高权重的外链",
            "搜索语法找外链",
            "图片外链",
            "外链聚合的网站",
            "站找站发现新外链",
            "adsy 购买客座博客外链",
            "stripe 高质量外链",
            "Trustpilot 三个用法",
            "一次提交十条外链",
            "推荐10个reddit 子社区",
            "reddit营销",
            "reddit营销注意事项",
            "推特营销起号",
            "推特社区给新号带来流量",
            "推特营销找对标的4种方式",
            "邪修获取推特流量",
            "自动发推营销",
            "youtube营销推广网站",
            "邮件营销小技巧",
            "圣诞节邮件营销",
            "Newsletter",
            "产品自传播",
            "分享裂变",
            "gpts 给网站引流",
            "和用户沟通的渠道",
            "创建discard 聊天群",
            "AppSumo",
        ]),
        ("阶段 5：收款变现", [
            "Stripe注册到提现全流程",
            "Stripe、Paypal、Creem政策对比",
            "Paypal 接入网站进行收款",
            "香港个人账户注册Stripe",
            "Paypal 个人开通收款",
            "paypal 收款提现",
            "办理水星银行用于收款",
            "如何海外挣美刀内地花",
            "推荐一个办理美国公司的方式",
            "香港办理银行卡流程",
            "无需登录支付也能收款",
            "stripe 收款设置",
            "Stripe 重复接入新网站",
            "Stripe 产品配置",
            "stripe cli 帮你快速创建产品",
            "雷达设置，防止stripe封号",
            "stripe 测试续费逻辑小技巧",
            "stripe自动设置优惠",
            "防止用户薅羊毛",
            "定价时需要考虑stripe 的手续费",
            "做好积分控制",
            "年度会员为啥没给积分",
            "定价策略",
            "定价小技巧",
            "同一个产品做不同定价",
        ]),
        ("阶段 6：数据分析", [
            "热力图分析用户的行为",
            "复盘一个网站的转化链路",
            "核心链路转化",
            "clarity 看网站错误信息",
            "Google Analysis 的官方教程",
            "Google Analysis 事件上报",
            "Google Analysis 对比查看不同用户群",
            "AI 帮你查看分析网站数据",
            "分析对标网站流量来源",
            "你的用户到底值不值钱",
            "计算网站的获客成本",
            "付费用户追踪",
            "Stripe API 分析数据",
            "通过 gsc api 让AI帮你分析数据",
            "clarity API获取分析网站数据",
            "clarity 看AI访问引用情况",
            "常见的数据分析工具",
            "查看网站DR神器",
            "制作书签看外链",
            "AI 看录屏，发现网站优化点",
        ]),
        ("阶段 7：增长放大", [
            "网站从0到1后怎么放大",
            "如何从0做到2w+付费用户的",
            "月入3千美刀达成",
            "AI网站出海终于达成阶段性目标",
            "stripe 向上销售，提升客单价",
            "涨价策略",
            "提升用户留存",
            "提升网站停留时长小技巧",
            "让用户先看到，再付费",
            "用弹窗来提升体验和转化",
            "损失厌恶在网站设计上的运用",
            "网站变现效率",
            "网站如何获取海量提示词模板",
            "借鉴生活中的例子做产品",
            "产品设计要点",
            "用户为什么要用套壳不用官方",
            "投流的作用",
            "ads投流总结",
            "ads 的一些基础知识",
            "系统学习Google 投流",
            "官方给ads 投流的12条建议",
            "投流前必做的一件事",
            "投流如何选择关键词",
            "ads 设置目标",
            "复制广告，做对比测试",
            "ads 广告不是你价高就投你的广告",
            "ads 监控通知和标题获取",
            "ads 查看关键词搜索量",
            "官方查询网站和广告主投放的广告",
            "找到投流的网站和关键词",
            "自己也能做联盟推广",
            "其他广告变现方式",
            "群友拿下trustmrr 周榜第一",
            "出海半年复盘分享，终于要月入千刀了",
            "英文差，宣传推广时如何交流",
            "蹭词的新玩法",
            "只需要网址就能生成演示视频",
        ]),
    ]

    for phase_title, articles in appendix_phases:
        story.append(Paragraph(phase_title, S_H2))
        for j, art in enumerate(articles, 1):
            story.append(Paragraph(f"{j}. {art}", ParagraphStyle(
                "idx", fontName=FONT_REGULAR, fontSize=9.5, leading=15,
                textColor=C_DARK, leftIndent=12, spaceAfter=2
            )))
        story.append(Spacer(1, 8))

    # ==================== 尾页 ====================
    story.append(PageBreak())
    story.append(Spacer(1, 100))
    story.append(Paragraph("祝你出海顺利！", ParagraphStyle(
        "end", fontName=FONT_BOLD, fontSize=20, leading=30,
        textColor=C_PRIMARY, alignment=TA_CENTER
    )))
    story.append(Spacer(1, 16))
    story.append(Paragraph(
        "记住：选对方向 > 快速上线 > 持续优化",
        ParagraphStyle("end2", fontName=FONT_REGULAR, fontSize=13, leading=20,
                       textColor=C_SECONDARY, alignment=TA_CENTER)
    ))
    story.append(Spacer(1, 10))
    story.append(Paragraph(
        "内容来源：aichuhai.dev  |  整理日期：2026 年 6 月",
        ParagraphStyle("end3", fontName=FONT_REGULAR, fontSize=10, leading=16,
                       textColor=C_SECONDARY, alignment=TA_CENTER)
    ))

    # ==================== 构建 ====================
    doc.build(story)
    print(f"PDF 生成成功: {output_path}")
    return output_path


if __name__ == "__main__":
    build_pdf()
