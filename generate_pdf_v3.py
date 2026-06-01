# -*- coding: utf-8 -*-
"""智能小管家 精美产品功能宣传册 v3"""
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4

def hex_to_rgb(col):
    """HexColor -> (r,g,b) 浮点 0-1，兼容 0xRRGGBB 与 #RRGGBB 格式"""
    s = col.hexval()  # e.g. '0xff6b35' or '#ff6b35'
    s = s.lstrip('0x').lstrip('#')
    return tuple(int(s[i:i+2], 16)/255 for i in (0,2,4))
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, Color
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable
)
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
from reportlab.platypus import Flowable

# ── 字体注册 ───────────────────────────────────────────────────
pdfmetrics.registerFont(TTFont('HEI',  'C:/Windows/Fonts/simhei.ttf'))
pdfmetrics.registerFont(TTFont('KAI',  'C:/Windows/Fonts/simkai.ttf'))
pdfmetrics.registerFont(TTFont('FANG', 'C:/Windows/Fonts/simfang.ttf'))

# ── 调色盘 ─────────────────────────────────────────────────────
C_ORANGE  = HexColor('#FF6B35')
C_DEEP    = HexColor('#1A1A2E')
C_BLUE    = HexColor('#4361EE')
C_PURPLE  = HexColor('#7B2FBE')
C_TEAL    = HexColor('#06D6A0')
C_YELLOW  = HexColor('#FFB703')
C_PINK    = HexColor('#FF4D6D')
C_GRAY    = HexColor('#6B7280')
C_LGRAY   = HexColor('#F3F4F6')
C_WHITE   = white
C_BG      = HexColor('#FAFAFA')
C_CARD    = HexColor('#FFFFFF')
C_BORDER  = HexColor('#E5E7EB')

W, H = A4
MARGIN = 18*mm
USABLE = W - 2*MARGIN

def ps(name, font='HEI', size=10, color=C_DEEP, leading=None,
       align=TA_LEFT, sb=0, sa=0):
    return ParagraphStyle(name, fontName=font, fontSize=size,
                          textColor=color, leading=leading or size*1.6,
                          alignment=align, spaceBefore=sb, spaceAfter=sa)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 自定义 Flowable
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class CoverPage(Flowable):
    """全页封面"""
    def __init__(self, w, h):
        super().__init__()
        self.W, self.H = w, h

    def wrap(self, *_):
        return self.W, self.H

    def draw(self):
        c = self.canv
        w, h = self.W, self.H

        # 背景渐变（深色主题）
        steps = 40
        for i in range(steps):
            t = i / steps
            r = int(0x0F*(1-t) + 0x1A*t)/255
            g = int(0x0C*(1-t) + 0x1A*t)/255
            b = int(0x22*(1-t) + 0x2E*t)/255
            c.setFillColorRGB(r, g, b)
            sh = h/steps
            c.rect(0, i*sh, w, sh+1, fill=1, stroke=0)

        # 橙色渐变装饰块（右上角）
        import math
        c.saveState()
        c.setFillColor(HexColor('#FF6B35'))
        path = c.beginPath()
        path.moveTo(w*0.55, h)
        path.lineTo(w, h)
        path.lineTo(w, h*0.55)
        path.close()
        c.setFillColorRGB(1, 0.42, 0.21, 0.25)
        c.drawPath(path, fill=1, stroke=0)
        # 再画一个小一点的
        path2 = c.beginPath()
        path2.moveTo(w*0.7, h)
        path2.lineTo(w, h)
        path2.lineTo(w, h*0.7)
        path2.close()
        c.setFillColorRGB(1, 0.42, 0.21, 0.18)
        c.drawPath(path2, fill=1, stroke=0)
        c.restoreState()

        # 左下角蓝色装饰
        c.saveState()
        path3 = c.beginPath()
        path3.moveTo(0, 0)
        path3.lineTo(w*0.35, 0)
        path3.lineTo(0, h*0.25)
        path3.close()
        c.setFillColorRGB(0.26, 0.38, 0.93, 0.2)
        c.drawPath(path3, fill=1, stroke=0)
        c.restoreState()

        # 装饰圆点
        dots = [(w*0.82, h*0.78, 6), (w*0.87, h*0.72, 4),
                (w*0.78, h*0.68, 3), (w*0.15, h*0.18, 5), (w*0.1, h*0.12, 3)]
        c.setFillColorRGB(1,1,1,0.25)
        for dx, dy, dr in dots:
            c.circle(dx, dy, dr, fill=1, stroke=0)

        # 橙色横线装饰
        c.setStrokeColor(C_ORANGE)
        c.setLineWidth(3)
        c.line(MARGIN, h*0.58, MARGIN + 40, h*0.58)
        c.setLineWidth(1)
        c.line(MARGIN + 48, h*0.58, MARGIN + 100, h*0.58)
        c.setStrokeColorRGB(1,1,1,0.2)
        c.setLineWidth(0.5)
        c.line(MARGIN, h*0.565, w-MARGIN, h*0.565)

        # App 图标圆
        icon_x, icon_y, icon_r = MARGIN + 22, h*0.76, 22
        c.setFillColor(C_ORANGE)
        c.circle(icon_x, icon_y, icon_r, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont('HEI', 18)
        c.drawCentredString(icon_x, icon_y - 6, '管')

        # 主标题
        c.setFillColor(white)
        c.setFont('HEI', 40)
        c.drawString(MARGIN + 52, h*0.74, '智能小管家')
        c.setFont('Helvetica-Bold', 13)
        c.setFillColorRGB(1,1,1,0.7)
        c.drawString(MARGIN + 52, h*0.685, 'Smart Assistant')

        # 标语
        c.setFillColor(white)
        c.setFont('HEI', 16)
        c.drawString(MARGIN, h*0.615, '让 AI 成为你的专属效率管家')

        # 标签
        tags = [('AI 智能拆解', C_ORANGE, '#FF6B35'), ('可视化日历', C_BLUE, '#4361EE'),
                ('思维导图', C_PURPLE, '#7B2FBE'), ('多端云同步', C_TEAL, '#06D6A0')]
        tx = MARGIN
        for tag, col, col_hex in tags:
            tw = 74
            hx = col_hex.lstrip('#')
            r2, g2, b2 = [int(hx[i:i+2], 16)/255 for i in (0,2,4)]
            c.setFillColorRGB(r2, g2, b2, 0.28)
            c.roundRect(tx, h*0.505, tw, 20, 10, fill=1, stroke=0)
            c.setStrokeColor(col)
            c.setLineWidth(0.8)
            c.roundRect(tx, h*0.505, tw, 20, 10, fill=0, stroke=1)
            c.setFillColor(col)
            c.setFont('HEI', 8.5)
            c.drawCentredString(tx + tw/2, h*0.513, tag)
            tx += tw + 8

        # 底部版本
        c.setFillColorRGB(1,1,1,0.4)
        c.setFont('Helvetica', 9)
        c.drawString(MARGIN, h*0.04, 'v1.0  ·  2026  ·  产品功能介绍手册')
        # 底部分割线
        c.setStrokeColorRGB(1,1,1,0.15)
        c.line(MARGIN, h*0.06, w-MARGIN, h*0.06)


class SectionTitle(Flowable):
    """章节标题带装饰"""
    def __init__(self, title, subtitle='', color=C_ORANGE, w=None, h=44):
        super().__init__()
        self._title = title
        self._subtitle = subtitle
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, avW, avH):
        self._w = self._w or avW
        return self._w, self._h

    def draw(self):
        c = self.canv
        w, h = self._w, self._h
        # 左侧粗彩条
        c.setFillColor(self._color)
        c.roundRect(0, 6, 5, h-12, 3, fill=1, stroke=0)
        # 细线
        c.setStrokeColor(C_BORDER)
        c.setLineWidth(0.5)
        c.line(12, 6, w, 6)
        # 标题
        c.setFillColor(C_DEEP)
        c.setFont('HEI', 16)
        c.drawString(12, h*0.52, self._title)
        # 副标题
        if self._subtitle:
            c.setFillColor(C_GRAY)
            c.setFont('KAI', 9)
            c.drawRightString(w, h*0.55, self._subtitle)
        # 装饰点
        c.setFillColor(self._color)
        c.circle(7, h*0.88, 2.5, fill=1, stroke=0)


class FeatureBlock(Flowable):
    """带图标的功能大卡片（全宽）"""
    def __init__(self, icon, title, tag, points, color=C_ORANGE, w=None, h=130):
        super().__init__()
        self._icon = icon
        self._title = title
        self._tag = tag
        self._points = points  # list of str
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, avW, avH):
        self._w = self._w or avW
        return self._w, self._h

    def draw(self):
        from reportlab.lib.utils import simpleSplit
        c = self.canv
        w, h = self._w, self._h

        # 卡片阴影（偏移灰块）
        c.setFillColor(HexColor('#E5E7EB'))
        c.roundRect(3, 0, w-4, h-4, 12, fill=1, stroke=0)

        # 卡片主体
        c.setFillColor(C_CARD)
        c.roundRect(0, 3, w-4, h-4, 12, fill=1, stroke=0)

        # 左侧色带
        c.setFillColor(self._color)
        c.roundRect(0, 3, 6, h-4, 4, fill=1, stroke=0)
        c.rect(3, 3, 4, h-4, fill=1, stroke=0)

        # 图标圆背景
        col = self._color
        c.setFillColor(col)
        # 半透明圆
        r2, g2, b2 = hex_to_rgb(col)
        c.setFillColorRGB(r2, g2, b2, 0.12)
        c.circle(30, h-38, 20, fill=1, stroke=0)
        # 图标
        c.setFillColor(col)
        c.setFont('HEI', 18)
        c.drawCentredString(30, h-44, self._icon)

        # 标题 + 标签
        c.setFillColor(C_DEEP)
        c.setFont('HEI', 14)
        c.drawString(58, h-28, self._title)
        # 标签小胶囊
        tag_w = len(self._tag) * 9 + 14
        c.setFillColor(col)
        c.setFillColorRGB(r2, g2, b2, 0.15)
        c.roundRect(58, h-48, tag_w, 16, 8, fill=1, stroke=0)
        c.setFillColor(col)
        c.setFont('HEI', 8)
        c.drawString(62, h-43, self._tag)

        # 分割线
        c.setStrokeColor(C_BORDER)
        c.setLineWidth(0.5)
        c.line(16, h-58, w-16, h-58)

        # 功能点（两列）
        mid = w / 2 - 4
        for i, pt in enumerate(self._points):
            col_x = 20 if i % 2 == 0 else mid + 20
            row_y = h - 74 - (i // 2) * 18
            # 小圆点
            c.setFillColor(self._color)
            c.circle(col_x - 8, row_y + 4, 3, fill=1, stroke=0)
            c.setFillColor(C_DEEP)
            c.setFont('HEI', 8.5)
            # 截断超长文字
            text = pt[:18] if len(pt) > 18 else pt
            c.drawString(col_x, row_y, text)


class QuoteBlock(Flowable):
    """用户评价引用块"""
    def __init__(self, text, author, role, color=C_ORANGE, w=None, h=70):
        super().__init__()
        self._text = text
        self._author = author
        self._role = role
        self._color = color
        self._w = w
        self._h = h

    def wrap(self, avW, avH):
        self._w = self._w or avW
        return self._w, self._h

    def draw(self):
        from reportlab.lib.utils import simpleSplit
        c = self.canv
        w, h = self._w, self._h
        r2, g2, b2 = hex_to_rgb(self._color)

        # 背景
        c.setFillColorRGB(r2, g2, b2, 0.07)
        c.roundRect(0, 0, w, h, 10, fill=1, stroke=0)
        c.setStrokeColorRGB(r2, g2, b2, 0.3)
        c.setLineWidth(0.8)
        c.roundRect(0, 0, w, h, 10, fill=0, stroke=1)

        # 大引号
        c.setFillColorRGB(r2, g2, b2, 0.3)
        c.setFont('Helvetica-Bold', 36)
        c.drawString(8, h-28, '"')

        # 内容
        c.setFillColor(C_DEEP)
        c.setFont('HEI', 9)
        lines = simpleSplit(self._text, 'HEI', 9, w-30)
        y = h - 26
        for line in lines[:3]:
            c.drawString(26, y, line)
            y -= 14

        # 作者
        c.setFillColor(self._color)
        c.setFont('HEI', 8)
        c.drawRightString(w-12, 10, f'— {self._author}  ·  {self._role}')


class PricingRow(Flowable):
    """定价卡片（三列横排）"""
    def __init__(self, plans, w=None, h=190):
        super().__init__()
        self._plans = plans
        self._w = w
        self._h = h

    def wrap(self, avW, avH):
        self._w = self._w or avW
        return self._w, self._h

    def draw(self):
        c = self.canv
        w, h = self._w, self._h
        cw = (w - 12) / 3  # 每列宽

        for i, (tier, price, unit, feats, highlight, col_hex) in enumerate(self._plans):
            x = i * (cw + 6)
            col = HexColor(col_hex)
            r2, g2, b2 = hex_to_rgb(col)

            if highlight:
                # 高亮卡：彩色背景
                c.setFillColor(col)
                c.roundRect(x, 0, cw, h, 12, fill=1, stroke=0)
                tc = white
                sc = HexColor('#FFE4D4')
                sep_col = (1,1,1,0.3)
                dot_col = white
            else:
                # 普通卡：白色背景+边框
                c.setFillColor(C_CARD)
                c.roundRect(x, 0, cw, h, 12, fill=1, stroke=0)
                c.setStrokeColor(C_BORDER)
                c.setLineWidth(1)
                c.roundRect(x, 0, cw, h, 12, fill=0, stroke=1)
                tc = C_DEEP
                sc = C_GRAY
                sep_col = None
                dot_col = col

            # 顶部色块（非高亮时）
            if not highlight:
                c.setFillColorRGB(r2, g2, b2, 0.1)
                c.roundRect(x, h-36, cw, 36, 12, fill=1, stroke=0)
                c.rect(x, h-50, cw, 20, fill=1, stroke=0)

            # 套餐名
            c.setFillColor(col if not highlight else white)
            c.setFont('HEI', 12)
            c.drawCentredString(x + cw/2, h-24, tier)

            # 分割线
            lc = (1,1,1,0.3) if highlight else C_BORDER
            if highlight:
                c.setStrokeColorRGB(1,1,1,0.3)
            else:
                c.setStrokeColor(C_BORDER)
            c.setLineWidth(0.5)
            c.line(x+12, h-38, x+cw-12, h-38)

            # 价格
            c.setFillColor(white if highlight else col)
            c.setFont('HEI', 26)
            c.drawCentredString(x + cw/2 - 6, h-64, price)
            c.setFont('HEI', 8)
            c.setFillColor(HexColor('#FFE4D4') if highlight else C_GRAY)
            c.drawString(x + cw/2 + 14, h-58, unit)

            # 功能列表
            y = h - 82
            for feat in feats:
                # 对勾圆
                c.setFillColor(white if highlight else col)
                c.circle(x+16, y+4, 4, fill=1, stroke=0)
                c.setFillColor(col if highlight else white)
                c.setFont('Helvetica-Bold', 7)
                c.drawCentredString(x+16, y+1, '✓')
                # 文字
                c.setFillColor(white if highlight else C_DEEP)
                c.setFont('HEI', 8.5)
                c.drawString(x+26, y, feat)
                y -= 17

            # 推荐标签
            if highlight:
                lw = 50
                c.setFillColor(white)
                c.roundRect(x + cw/2 - lw/2, h-8, lw, 14, 7, fill=1, stroke=0)
                c.setFillColor(col)
                c.setFont('HEI', 8)
                c.drawCentredString(x+cw/2, h-3, '推荐')


class CTABlock(Flowable):
    """行动号召大块"""
    def __init__(self, w=None, h=100):
        super().__init__()
        self._w = w
        self._h = h

    def wrap(self, avW, avH):
        self._w = self._w or avW
        return self._w, self._h

    def draw(self):
        c = self.canv
        w, h = self._w, self._h

        # 深色背景
        c.setFillColor(C_DEEP)
        c.roundRect(0, 0, w, h, 14, fill=1, stroke=0)

        # 橙色装饰三角
        c.setFillColorRGB(1, 0.42, 0.21, 0.2)
        path = c.beginPath()
        path.moveTo(w*0.7, h)
        path.lineTo(w, h)
        path.lineTo(w, h*0.3)
        path.close()
        c.drawPath(path, fill=1, stroke=0)

        # 主文字
        c.setFillColor(white)
        c.setFont('HEI', 22)
        c.drawCentredString(w/2, h*0.65, '立即下载，免费体验')

        # 副文字
        c.setFont('KAI', 10)
        c.setFillColorRGB(1,1,1,0.7)
        c.drawCentredString(w/2, h*0.43, '专业版限时特惠 ¥98 起 · 一次买断 · 终身免费更新')

        # 按钮
        btn_w, btn_h = 100, 26
        bx = w/2 - btn_w/2
        by = h*0.1
        c.setFillColor(C_ORANGE)
        c.roundRect(bx, by, btn_w, btn_h, 13, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont('HEI', 10)
        c.drawCentredString(w/2, by+9, '免费下载')


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 页眉页脚
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def on_page(canvas, doc):
    canvas.saveState()
    # 顶部细线
    canvas.setStrokeColor(C_BORDER)
    canvas.setLineWidth(0.5)
    canvas.line(MARGIN, H - 12*mm, W - MARGIN, H - 12*mm)
    # 品牌名
    canvas.setFont('HEI', 8)
    canvas.setFillColor(C_GRAY)
    canvas.drawString(MARGIN, H - 10*mm, '智能小管家')
    # 页码
    canvas.drawRightString(W - MARGIN, H - 10*mm, f'{doc.page}')
    # 底部
    canvas.setStrokeColor(C_BORDER)
    canvas.line(MARGIN, 14*mm, W - MARGIN, 14*mm)
    canvas.setFont('KAI', 8)
    canvas.setFillColor(C_GRAY)
    canvas.drawCentredString(W/2, 10*mm, 'smartassistant.app  ·  让 AI 成为你的专属效率管家')
    canvas.restoreState()

def on_first_page(canvas, doc):
    pass


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 内容构建
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
def build():
    story = []

    # ── P1: 封面 ───────────────────────────────────────────────
    avail_h = H - 2*MARGIN - 4*mm
    story.append(CoverPage(USABLE, avail_h))
    story.append(PageBreak())

    # ── P2: 产品定位 ───────────────────────────────────────────
    story.append(SectionTitle('你是否正在经历这些困扰？', color=C_ORANGE))
    story.append(Spacer(1, 4*mm))

    pains = [
        ('😩', '任务越堆越多，每天睁眼不知道先做什么'),
        ('🔥', '大项目无从下手，反复拖延，截止日临近才慌神'),
        ('📅', '日程散落在备忘录、微信、便签，随时漏事'),
        ('💻', '换了台设备就找不到上次的任务进度'),
    ]
    for icon, text in pains:
        row = Table([[
            Paragraph(icon, ps('pi', size=14, align=TA_CENTER)),
            Paragraph(text, ps('pt', size=10, color=C_DEEP, leading=18)),
        ]], colWidths=[14*mm, USABLE - 16*mm])
        row.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('TOPPADDING', (0,0), (-1,-1), 4),
            ('BOTTOMPADDING', (0,0), (-1,-1), 4),
            ('BACKGROUND', (0,0), (-1,0), C_LGRAY),
            ('ROUNDEDCORNERS', [6,6,6,6]),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
        ]))
        story.append(row)
        story.append(Spacer(1, 2*mm))

    story.append(Spacer(1, 5*mm))

    # 解决方案横幅
    sol = Table([[
        Paragraph('智能小管家', ps('sp', font='HEI', size=15, color=C_ORANGE, align=TA_CENTER)),
        Paragraph('一款让 AI 帮你管理一切的效率工具\n任务拆解 · 日历规划 · 思维导图 · 多端同步',
                  ps('sd', size=10, color=C_DEEP, leading=18)),
    ]], colWidths=[38*mm, USABLE - 40*mm])
    sol.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BACKGROUND', (0,0), (-1,-1), HexColor('#FFF3EE')),
        ('LINEAFTER', (0,0), (0,-1), 2, C_ORANGE),
        ('TOPPADDING', (0,0), (-1,-1), 10),
        ('BOTTOMPADDING', (0,0), (-1,-1), 10),
        ('LEFTPADDING', (0,0), (-1,-1), 12),
        ('ROUNDEDCORNERS', [8,8,8,8]),
    ]))
    story.append(sol)
    story.append(Spacer(1, 5*mm))

    # 4 个数据卡
    stats = [
        ('6+', '核心功能', C_ORANGE),
        ('3端', '跨平台', C_BLUE),
        ('∞', 'AI 次数', C_PURPLE),
        ('0%', '数据丢失率', C_TEAL),
    ]
    scw = USABLE / 4
    stat_cells = []
    for val, label, col in stats:
        inner = Table([
            [Paragraph(val, ps(f'sv_{val}', font='HEI', size=22, color=HexColor(col) if isinstance(col, str) else col, align=TA_CENTER))],
            [Paragraph(label, ps(f'sl_{label}', size=8.5, color=C_GRAY, align=TA_CENTER))],
        ], colWidths=[scw-4], rowHeights=[30, 18])
        inner.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), C_LGRAY),
            ('TOPPADDING', (0,0), (-1,-1), 8),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
            ('ROUNDEDCORNERS', [8,8,8,8]),
        ]))
        stat_cells.append(inner)

    stat_row = Table([stat_cells], colWidths=[scw]*4)
    stat_row.setStyle(TableStyle([
        ('LEFTPADDING', (0,0), (-1,-1), 2),
        ('RIGHTPADDING', (0,0), (-1,-1), 2),
    ]))
    story.append(stat_row)
    story.append(PageBreak())

    # ── P3: 核心功能（上半） ───────────────────────────────────
    story.append(SectionTitle('六大核心功能', '一站式解决你的效率难题', color=C_BLUE))
    story.append(Spacer(1, 4*mm))

    features = [
        ('🤖', 'AI 智能任务拆解', 'DeepSeek 驱动',
         ['自然语言一句话创建任务', 'AI 自动生成 WBS 子任务树',
          '智能推导时间节点与优先级', '工作量评估与冲突预警',
          '支持自定义 AI 提醒时段', '持续学习你的工作习惯'],
         C_ORANGE),
        ('📅', '可视化日历视图', '弹性时间轴',
         ['1-15 天弹性窗口切换', '双指缩放调整时间精度',
          '长按任意时段快速新建', '拖拽调整任务时间范围',
          '跨日任务横向长条展示', '并行任务自动分列不重叠'],
         C_BLUE),
        ('🗺️', '思维导图', '可视化思考',
         ['节点无限层级，随意延伸', '拖拽重排，Ctrl+Z 随时撤销',
          '任务与导图双向实时绑定', '一键折叠/展开节点分支',
          '支持快捷键高效操作', '导出图片一键分享'],
         C_PURPLE),
    ]

    for icon, title, tag, pts, col in features:
        story.append(FeatureBlock(icon, title, tag, pts, col, w=USABLE, h=130))
        story.append(Spacer(1, 4*mm))

    story.append(PageBreak())

    # ── P4: 核心功能（下半）───────────────────────────────────
    story.append(SectionTitle('六大核心功能（续）', '', color=C_BLUE))
    story.append(Spacer(1, 4*mm))

    features2 = [
        ('☁️', '多端实时云同步', '三端无缝切换',
         ['Windows · Android · Web 三端', '网络恢复后自动合并离线变更',
          'LWW 算法确保无冲突同步', '断网也能正常工作（离线优先）',
          '数据加密存储，隐私安全', '单账号多设备随时切换'],
         C_TEAL),
        ('🔔', '智能提醒推送', '不再漏事',
         ['截止前自定义提前提醒', '重复任务自动生成提醒',
          '跨平台原生通知推送', '提醒静默时段可自定义',
          '一键推迟或完成任务', '每日晨间任务摘要推送'],
         C_YELLOW),
        ('🎨', '主题 & 无障碍', '舒适使用',
         ['亮色 / 暗色双主题自由切换', 'Material 3 流畅动效',
          '大字体与高对比度支持', '色盲友好配色方案',
          '界面布局可自定义调整', '手势操作全面优化'],
         C_PINK),
    ]

    for icon, title, tag, pts, col in features2:
        story.append(FeatureBlock(icon, title, tag, pts, col, w=USABLE, h=130))
        story.append(Spacer(1, 4*mm))

    story.append(PageBreak())

    # ── P5: 适合人群 + 用户声音 ────────────────────────────────
    story.append(SectionTitle('谁会爱上它？', '适合每一位想要高效生活的你', color=C_PURPLE))
    story.append(Spacer(1, 4*mm))

    personas = [
        ('🧑‍💻', '开发者 & 项目经理', 'AI 拆解需求、WBS 管理迭代任务，日历可视化 Sprint 计划'),
        ('📚', '学生 & 考研备考者', '可视化学习计划，每日打卡日历，AI 帮你把备考拆成可执行小步骤'),
        ('👔', '职场打工人', '日程整合所有待办，智能提醒不漏会议，告别"今天忘了什么"的焦虑'),
        ('🏠', '自由职业者', '多项目并行管理，思维导图梳理创意，云同步随时随地切换设备继续工作'),
    ]
    p2 = USABLE / 2 - 3*mm
    p_rows = []
    for i in range(0, len(personas), 2):
        row_cells = []
        for j in range(2):
            if i+j < len(personas):
                icon, name, desc = personas[i+j]
                cell = Table([[
                    Paragraph(icon, ps(f'poi{i}{j}', size=20, align=TA_CENTER)),
                    Table([[
                        Paragraph(name, ps(f'pn{i}{j}', font='HEI', size=10, color=C_DEEP)),
                        Paragraph(desc, ps(f'pd{i}{j}', size=8.5, color=C_GRAY, leading=14)),
                    ]], colWidths=[p2 - 20*mm]),
                ]], colWidths=[14*mm, p2-16*mm])
                cell.setStyle(TableStyle([
                    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
                    ('BACKGROUND', (0,0), (-1,-1), C_LGRAY),
                    ('TOPPADDING', (0,0), (-1,-1), 8),
                    ('BOTTOMPADDING', (0,0), (-1,-1), 8),
                    ('LEFTPADDING', (0,0), (-1,-1), 6),
                    ('ROUNDEDCORNERS', [8,8,8,8]),
                ]))
                row_cells.append(cell)
            else:
                row_cells.append(Spacer(p2, 1))
        p_rows.append(row_cells)

    pt = Table(p_rows, colWidths=[p2, p2])
    pt.setStyle(TableStyle([
        ('LEFTPADDING', (0,0), (-1,-1), 2),
        ('RIGHTPADDING', (0,0), (-1,-1), 2),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
    ]))
    story.append(pt)
    story.append(Spacer(1, 5*mm))

    story.append(SectionTitle('用户声音', '', color=C_TEAL, h=36))
    story.append(Spacer(1, 3*mm))

    quotes = [
        ('AI 自动帮我把一个"做完项目"拆成了 23 个具体步骤，每步都有截止日期，效率直接翻倍！', '李明 · 产品经理', C_ORANGE),
        ('考研期间用日历视图规划每天的复习时段，拖拽功能太好用了，再也不用重新手写计划表。', '王晓雯 · 考研学生', C_BLUE),
        ('三台设备无缝切换，在公司做了一半的任务，坐地铁掏出手机接着做，数据一秒同步。', '陈浩 · 自由设计师', C_PURPLE),
    ]
    q3 = USABLE / 3 - 2*mm
    q_cells = [[QuoteBlock(t, a, col, w=q3, h=80) for t, a, col in quotes]]
    qt = Table(q_cells, colWidths=[q3]*3)
    qt.setStyle(TableStyle([
        ('LEFTPADDING', (0,0), (-1,-1), 2),
        ('RIGHTPADDING', (0,0), (-1,-1), 2),
    ]))
    story.append(qt)
    story.append(PageBreak())

    # ── P6: 定价 + CTA ─────────────────────────────────────────
    story.append(SectionTitle('定价方案', '一次买断，终身使用', color=C_YELLOW))
    story.append(Spacer(1, 4*mm))

    story.append(Paragraph(
        '无订阅陷阱，无隐性收费。买了就是你的，所有后续版本永久免费更新。',
        ps('pi_text', font='KAI', size=10, color=C_GRAY, align=TA_CENTER)
    ))
    story.append(Spacer(1, 5*mm))

    plans = [
        ('免费版', '¥0', '永久免费',
         ['核心任务管理', 'AI 拆解每日 10 次', '本地日历视图', '思维导图基础版'],
         False, '#6B7280'),
        ('专业版', '¥128', '限时 ¥98',
         ['全部功能无限制', 'AI 无限次调用', '云端同步 1 GB', '优先技术支持'],
         True, '#FF6B35'),
        ('团队版', '¥688', '5 席位起',
         ['专业版全部权益', '团队协作空间', '管理员控制台', '专属部署支持'],
         False, '#4361EE'),
    ]
    story.append(PricingRow(plans, w=USABLE, h=195))
    story.append(Spacer(1, 6*mm))

    # 平台下载
    story.append(SectionTitle('下载渠道', '', color=C_BLUE, h=32))
    story.append(Spacer(1, 3*mm))

    platforms = [
        ('🪟', 'Windows', 'Microsoft Store / 官网直链', C_BLUE),
        ('🤖', 'Android', 'Google Play / APK 直装', C_TEAL),
        ('🌐', 'Web 版', 'app.smartassistant.app', C_PURPLE),
        ('📦', '开源版', 'github.com/xxx/smart_assistant', C_GRAY),
    ]
    pl4 = USABLE / 4
    plat_cells = []
    for icon, name, link, col in platforms:
        cell = Table([[
            Paragraph(icon, ps(f'pli{name}', size=16, align=TA_CENTER)),
            Table([[
                Paragraph(name, ps(f'pln{name}', font='HEI', size=9, color=HexColor(col) if isinstance(col, str) else col)),
                Paragraph(link, ps(f'pll{name}', font='KAI', size=7.5, color=C_GRAY)),
            ]], colWidths=[pl4-16*mm]),
        ]], colWidths=[12*mm, pl4-14*mm])
        cell.setStyle(TableStyle([
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('BACKGROUND', (0,0), (-1,-1), C_LGRAY),
            ('TOPPADDING', (0,0), (-1,-1), 7),
            ('BOTTOMPADDING', (0,0), (-1,-1), 7),
            ('LEFTPADDING', (0,0), (-1,-1), 6),
            ('ROUNDEDCORNERS', [8,8,8,8]),
        ]))
        plat_cells.append(cell)

    plat_t = Table([plat_cells], colWidths=[pl4]*4)
    plat_t.setStyle(TableStyle([
        ('LEFTPADDING', (0,0), (-1,-1), 2),
        ('RIGHTPADDING', (0,0), (-1,-1), 2),
    ]))
    story.append(plat_t)
    story.append(Spacer(1, 6*mm))

    # CTA 大块
    story.append(CTABlock(w=USABLE, h=95))
    story.append(Spacer(1, 5*mm))

    # 版权
    story.append(HRFlowable(width=USABLE, thickness=0.5, color=C_BORDER))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '© 2026 智能小管家团队  ·  保留所有权利  ·  本手册仅供产品宣发使用',
        ps('copy', font='KAI', size=8, color=C_GRAY, align=TA_CENTER)
    ))

    return story


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 主入口
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT = 'E:/claude/project2/smart_assistant/智能小管家_产品手册_v3.pdf'

doc = SimpleDocTemplate(
    OUTPUT, pagesize=A4,
    leftMargin=MARGIN, rightMargin=MARGIN,
    topMargin=16*mm, bottomMargin=18*mm,
    title='智能小管家 产品功能手册',
    author='Smart Assistant Team',
)
doc.build(build(), onFirstPage=on_first_page, onLaterPages=on_page)
print('完成:', OUTPUT)
