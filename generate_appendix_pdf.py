"""
Generate APPENDIX_A_DETAILED.pdf from APPENDIX_A_DETAILED.md
Produces proper graphical flowcharts (shapes + arrows) for all 7 process flows.
Run:  python generate_appendix_pdf.py
"""

import re
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib.colors import HexColor, black, white
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether, Preformatted
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.graphics.shapes import (
    Drawing, Rect, Polygon, Line, String, Ellipse
)
from reportlab.graphics import renderPDF
from reportlab.platypus.flowables import Flowable

# ── Palette ────────────────────────────────────────────────────────────────────
C_DARK    = HexColor("#1a1a2e")
C_PRIMARY = HexColor("#16213e")
C_ACCENT  = HexColor("#0f3460")
C_LIGHT   = HexColor("#e94560")
C_GRAY    = HexColor("#f4f4f4")
C_BORDER  = HexColor("#cccccc")
C_WHITE   = white
C_TH_BG   = HexColor("#16213e")
C_EVEN    = HexColor("#f8f9fa")
C_CODE_BG = HexColor("#1e1e1e")
C_CODE_FG = HexColor("#d4d4d4")

FC_TERMINAL = HexColor("#c0392b")
FC_PROCESS  = HexColor("#0f3460")
FC_DECISION = HexColor("#2c3e7a")
FC_IO       = HexColor("#1a6b4a")
FC_ALT      = HexColor("#2d5016")
FC_NO_BOX   = HexColor("#922b21")
FC_ARROW    = HexColor("#2c3e50")
FC_YES      = HexColor("#27ae60")
FC_NO_CLR   = HexColor("#c0392b")

PAGE_W, PAGE_H = A4
MARGIN = 2.2 * cm
CHART_W = PAGE_W - 2 * MARGIN   # ≈ 552 pt

# ── Styles ─────────────────────────────────────────────────────────────────────
base = getSampleStyleSheet()

def _ms(name, parent=None, **kw):
    return ParagraphStyle(name, parent=parent or base["Normal"], **kw)

STYLES = {
    "h1":  _ms("h1",  base["Heading1"], fontSize=18, textColor=C_DARK,
               spaceAfter=10, spaceBefore=20, fontName="Helvetica-Bold"),
    "h2":  _ms("h2",  base["Heading2"], fontSize=14, textColor=C_ACCENT,
               spaceAfter=6, spaceBefore=14, fontName="Helvetica-Bold"),
    "h3":  _ms("h3",  base["Heading3"], fontSize=11, textColor=C_PRIMARY,
               spaceAfter=4, spaceBefore=10, fontName="Helvetica-Bold"),
    "h4":  _ms("h4",  base["Heading4"], fontSize=10, textColor=C_ACCENT,
               spaceAfter=3, spaceBefore=8,  fontName="Helvetica-Bold"),
    "body":_ms("body",base["Normal"],   fontSize=9, leading=14, spaceAfter=4,
               fontName="Helvetica", alignment=TA_JUSTIFY),
    "code":_ms("code",base["Code"],     fontSize=7.5, leading=11,
               fontName="Courier", textColor=C_CODE_FG, backColor=C_CODE_BG,
               leftIndent=6, rightIndent=6, spaceBefore=4, spaceAfter=4),
    "bullet":_ms("bullet",base["Normal"], fontSize=9, leading=13,
                 leftIndent=16, firstLineIndent=-8, spaceAfter=2,
                 fontName="Helvetica"),
    "th":  _ms("th",  base["Normal"],   fontSize=8, fontName="Helvetica-Bold",
               textColor=C_WHITE, alignment=TA_CENTER, leading=11),
    "td":  _ms("td",  base["Normal"],   fontSize=8, fontName="Helvetica",
               leading=11, alignment=TA_LEFT),
    "tdc": _ms("tdc", base["Normal"],   fontSize=8, fontName="Helvetica",
               leading=11, alignment=TA_CENTER),
    "cap": _ms("cap", base["Normal"],   fontSize=8.5, fontName="Helvetica-Bold",
               textColor=C_ACCENT, spaceAfter=6, spaceBefore=2,
               alignment=TA_CENTER),
    "figc":_ms("figc",base["Normal"],   fontSize=9, fontName="Helvetica-Bold",
               textColor=C_PRIMARY, spaceAfter=8, spaceBefore=4,
               alignment=TA_CENTER),
}

# ── Basic helpers ──────────────────────────────────────────────────────────────

def ex(t):
    return (t.replace("&","&amp;").replace("<","&lt;")
             .replace(">","&gt;").replace('"',"&quot;"))

def para(text, sk="body"):
    s = ex(text)
    s = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', s)
    s = re.sub(r'`([^`]+)`', r'<font name="Courier" size="8">\1</font>', s)
    return Paragraph(s, STYLES[sk])

def hr():
    return HRFlowable(width="100%", thickness=1, color=C_BORDER,
                      spaceAfter=6, spaceBefore=6)

def sp(h=0.2):
    return Spacer(1, h * cm)

# ── Table builder ──────────────────────────────────────────────────────────────

def make_table(rows, col_widths=None, has_header=True):
    uw = PAGE_W - 2 * MARGIN
    fmt = []
    for ri, row in enumerate(rows):
        fr = []
        for cell in row:
            t = str(cell)
            if ri == 0 and has_header:
                fr.append(Paragraph(ex(t), STYLES["th"]))
            else:
                s = ex(t)
                s = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', s)
                s = re.sub(r'`([^`]+)`',
                            r'<font name="Courier" size="7.5">\1</font>', s)
                st = STYLES["tdc"] if re.match(r'^\s*[\d\-]\s*$', t) else STYLES["td"]
                fr.append(Paragraph(s, st))
        fmt.append(fr)

    nc = max(len(r) for r in fmt) if fmt else 1
    cw = col_widths or [uw / nc] * nc
    t = Table(fmt, colWidths=cw, repeatRows=1 if has_header else 0)
    cmds = [
        ("BACKGROUND", (0,0),(-1,0), C_TH_BG),
        ("TEXTCOLOR",  (0,0),(-1,0), C_WHITE),
        ("FONTNAME",   (0,0),(-1,0), "Helvetica-Bold"),
        ("FONTSIZE",   (0,0),(-1,-1), 8),
        ("ROWBACKGROUNDS",(0,1),(-1,-1),[C_WHITE, C_EVEN]),
        ("GRID",       (0,0),(-1,-1), 0.4, C_BORDER),
        ("VALIGN",     (0,0),(-1,-1), "TOP"),
        ("TOPPADDING", (0,0),(-1,-1), 4),
        ("BOTTOMPADDING",(0,0),(-1,-1), 4),
        ("LEFTPADDING",(0,0),(-1,-1), 5),
        ("RIGHTPADDING",(0,0),(-1,-1), 5),
    ]
    if not has_header:
        cmds = [c for c in cmds if c[0] not in
                ("BACKGROUND","TEXTCOLOR","FONTNAME")]
    t.setStyle(TableStyle(cmds))
    return t


# ══════════════════════════════════════════════════════════════════════════════
# ── FLOWCHART ENGINE ──────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

class FC:
    """Builds a ReportLab Drawing with flowchart shapes."""
    FONT  = "Helvetica"
    FONTB = "Helvetica-Bold"
    FS    = 7.5
    AH    = 7   # arrowhead half-size

    # default box dims
    TW, TH = 120, 26   # terminal
    PW, PH = 150, 32   # process
    DW, DH = 130, 44   # decision
    IW, IH = 150, 30   # I/O

    def __init__(self, w, h):
        self.d  = Drawing(w, h)
        self.W  = w
        self.H  = h

    # ── text renderer (auto word-wrap inside box) ─────────────────────────

    def _txt(self, label, cx, cy, box_w, color=C_WHITE, bold=False, fsize=None):
        sz = fsize or self.FS
        fn = self.FONTB if bold else self.FONT
        cpl = max(int(box_w / (sz * 0.58)), 6)
        words = label.split(); lines = []; cur = ""
        for w in words:
            test = (cur + " " + w).strip()
            if len(test) <= cpl:
                cur = test
            else:
                if cur: lines.append(cur)
                cur = w
        if cur: lines.append(cur)
        lh = sz + 2.5
        base_y = cy + (len(lines) - 1) * lh / 2
        for i, txt in enumerate(lines):
            self.d.add(String(cx, base_y - i * lh, txt,
                              fontName=fn, fontSize=sz,
                              fillColor=color, textAnchor="middle"))

    # ── shapes ────────────────────────────────────────────────────────────

    def terminal(self, cx, cy, label, fill=None, w=None, h=None):
        w = w or self.TW; h = h or self.TH
        fill = fill or FC_TERMINAL
        r = h // 2
        self.d.add(Rect(cx - w/2, cy - h/2, w, h,
                        rx=r, ry=r, fillColor=fill,
                        strokeColor=C_WHITE, strokeWidth=0.8))
        self._txt(label, cx, cy, w - 10, bold=True)
        return cy - h/2   # bottom y

    def process(self, cx, cy, label, fill=None, w=None, h=None):
        w = w or self.PW; h = h or self.PH
        fill = fill or FC_PROCESS
        self.d.add(Rect(cx - w/2, cy - h/2, w, h,
                        fillColor=fill,
                        strokeColor=C_WHITE, strokeWidth=0.6))
        self._txt(label, cx, cy, w - 10)
        return cy - h/2

    def decision(self, cx, cy, label, fill=None, w=None, h=None):
        w = w or self.DW; h = h or self.DH
        fill = fill or FC_DECISION
        pts = [cx, cy+h/2,  cx+w/2, cy,  cx, cy-h/2,  cx-w/2, cy]
        self.d.add(Polygon(pts, fillColor=fill,
                           strokeColor=C_WHITE, strokeWidth=0.6))
        self._txt(label, cx, cy, w * 0.65)
        return cy - h/2

    def io_box(self, cx, cy, label, fill=None, w=None, h=None):
        w = w or self.IW; h = h or self.IH
        fill = fill or FC_IO
        sk = 10
        pts = [cx-w/2+sk, cy+h/2,  cx+w/2+sk, cy+h/2,
               cx+w/2-sk, cy-h/2,  cx-w/2-sk, cy-h/2]
        self.d.add(Polygon(pts, fillColor=fill,
                           strokeColor=C_WHITE, strokeWidth=0.6))
        self._txt(label, cx, cy, w - 16)
        return cy - h/2

    # ── arrows ────────────────────────────────────────────────────────────

    def _arrowhead_down(self, x, y):
        a = self.AH
        self.d.add(Polygon([x-a, y+a, x+a, y+a, x, y],
                           fillColor=FC_ARROW, strokeColor=FC_ARROW, strokeWidth=0))

    def _arrowhead_right(self, x, y):
        a = self.AH
        self.d.add(Polygon([x-a, y+a, x-a, y-a, x, y],
                           fillColor=FC_ARROW, strokeColor=FC_ARROW, strokeWidth=0))

    def _arrowhead_left(self, x, y):
        a = self.AH
        self.d.add(Polygon([x+a, y+a, x+a, y-a, x, y],
                           fillColor=FC_ARROW, strokeColor=FC_ARROW, strokeWidth=0))

    def arrow_down(self, x, y, length, label="", label_side="right", lcolor=None):
        lcolor = lcolor or FC_ARROW
        self.d.add(Line(x, y, x, y - length + self.AH,
                        strokeColor=FC_ARROW, strokeWidth=1.2))
        self._arrowhead_down(x, y - length)
        if label:
            lx = x + 4 if label_side == "right" else x - 4
            an = "start" if label_side == "right" else "end"
            self.d.add(String(lx, y - length/2 - 3, label,
                              fontName=self.FONT, fontSize=6.5,
                              fillColor=lcolor, textAnchor=an))

    def arrow_right(self, x, y, length, label="", lcolor=None):
        lcolor = lcolor or FC_ARROW
        self.d.add(Line(x, y, x + length - self.AH, y,
                        strokeColor=FC_ARROW, strokeWidth=1.2))
        self._arrowhead_right(x + length, y)
        if label:
            self.d.add(String(x + 4, y + 3, label,
                              fontName=self.FONT, fontSize=6.5, fillColor=lcolor))

    def arrow_left(self, x, y, length, label="", lcolor=None):
        lcolor = lcolor or FC_ARROW
        self.d.add(Line(x, y, x - length + self.AH, y,
                        strokeColor=FC_ARROW, strokeWidth=1.2))
        self._arrowhead_left(x - length, y)
        if label:
            self.d.add(String(x - length/2, y + 3, label,
                              fontName=self.FONT, fontSize=6.5,
                              fillColor=lcolor, textAnchor="middle"))

    def vline(self, x, y1, y2):
        self.d.add(Line(x, y1, x, y2,
                        strokeColor=FC_ARROW, strokeWidth=1.2))

    def hline(self, x1, y, x2):
        self.d.add(Line(x1, y, x2, y,
                        strokeColor=FC_ARROW, strokeWidth=1.2))

    def lbl(self, x, y, text, color=None, size=6.5, anchor="start"):
        self.d.add(String(x, y, text,
                          fontName=self.FONT, fontSize=size,
                          fillColor=color or FC_ARROW, textAnchor=anchor))

    def legend_box(self, x=6, y=80):
        items = [
            (FC_TERMINAL, "Terminal (Start/End)"),
            (FC_PROCESS,  "Process Step"),
            (FC_DECISION, "Decision / Branch"),
            (FC_IO,       "Input / Output"),
        ]
        for i, (c, lbl) in enumerate(items):
            by = y - i * 15
            self.d.add(Rect(x, by - 5, 14, 10, fillColor=c,
                            strokeColor=C_WHITE, strokeWidth=0.4))
            self.d.add(String(x + 17, by - 3.5, lbl,
                              fontName=self.FONT, fontSize=6,
                              fillColor=C_DARK))

    def get(self):
        return self.d


# ══════════════════════════════════════════════════════════════════════════════
# ── PER-FLOWCHART BUILDERS ────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# FLOWCHART LAYOUT CONSTANTS
# All offshoot (Yes/No branch) boxes are placed to the RIGHT of the main spine
# at a fixed x so they never overflow the canvas.
# Main spine is at cx = CHART_W / 2 ≈ 276 pt.
# Right branch column: RBX  (right side, inside canvas)
# Left  branch column: LBX  (left  side, inside canvas)
# ─────────────────────────────────────────────────────────────────────────────
_CX  = CHART_W / 2
_RBX = CHART_W - 70     # right branch box center  (fits ~120 pt box)
_LBX = 70               # left  branch box center  (fits ~120 pt box)
_BW  = 124              # branch box width
_BH  = 30               # branch box height
_GAP = 18               # vertical gap between shapes
_PW  = 200              # default main-spine process width


def _branch_right(fc, dy, label_yes, label_no, text, fill=None):
    """Draw a 'No → right side box' offshoot from a decision at vertical y=dy.
    Returns nothing; caller uses arrow_down on cx to continue main spine."""
    fill = fill or FC_NO_BOX
    # horizontal arrow right from diamond edge to branch box
    fc.arrow_right(_CX + 65, dy, _RBX - _CX - 65 - _BW/2 - 2, label=label_no, lcolor=FC_NO_CLR)
    fc.terminal(_RBX, dy, text, fill=fill, w=_BW, h=_BH)
    # yes label on main down arrow
    fc.lbl(_CX + 4, dy - 22 - 8, label_yes, color=FC_YES)


def _branch_left(fc, dy, label_yes, label_no, text, fill=None):
    """Draw a 'No → left side box' offshoot from a decision at vertical y=dy."""
    fill = fill or FC_NO_BOX
    fc.arrow_left(_CX - 65, dy, _CX - 65 - _LBX - _BW/2 - 2, label=label_no)
    fc.terminal(_LBX, dy, text, fill=fill, w=_BW, h=_BH)
    fc.lbl(_CX + 4, dy - 22 - 8, label_yes, color=FC_YES)


def _fc1_login():
    H = 680; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");              fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.process(cx, y, "Access Login Page (/home)", w=PW)
    fc.arrow_down(cx, y-16, G);              y -= 16+G
    fc.io_box(cx, y, "Input: Email & Password",   w=PW)
    fc.arrow_down(cx, y-15, G);              y -= 15+G

    # Decision 1: Locked?
    dy = y
    fc.decision(cx, dy, "Account\nLocked?", w=130, h=44)
    _branch_right(fc, dy, "No", "Yes →", "Show Lockout\nMessage")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Validate Password  (SHA-256 hash)", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G

    # Decision 2: Valid?
    dy = y
    fc.decision(cx, dy, "Credentials\nValid?", w=130, h=44)
    _branch_left(fc, dy, "Yes", "No →", "Flash Error\n(5 fails = 30-min lock)")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    # Decision 3: Role?
    dy = y
    fc.decision(cx, dy, "User Role?", w=130, h=44)

    # Super User branch → left column
    fc.arrow_left(cx-65, dy, cx-65-_LBX-_BW/2-2, label="Super User")
    su_y = dy
    fc.process(_LBX, su_y, "Create SuperUser Session\n(5-token array, Firestore)", w=_BW, h=36)
    fc.arrow_down(_LBX, su_y-18, G)
    fc.terminal(_LBX, su_y-18-G, "Redirect /dashboard", fill=FC_PROCESS, w=_BW, h=26)

    # Admin branch → right column
    fc.arrow_right(cx+65, dy, _RBX-cx-65-_BW/2-2, label="Admin")
    fc.process(_RBX, dy, "Create Admin Session\n(token_urlsafe(32))", w=_BW, h=36)
    fc.arrow_down(_RBX, dy-18, G)
    fc.terminal(_RBX, dy-18-G, "Redirect /dashboard", fill=FC_PROCESS, w=_BW, h=26)

    # Merge both branch feet down to END
    lfoot = su_y - 18 - G - 13   # bottom of left terminal
    rfoot = dy   - 18 - G - 13   # bottom of right terminal
    merge_y = min(lfoot, rfoot) - G
    fc.vline(_LBX, lfoot, merge_y)
    fc.vline(_RBX, rfoot, merge_y)
    fc.hline(_LBX, merge_y, _RBX)
    fc.arrow_down(cx, merge_y, G)
    fc.terminal(cx, merge_y-G, "END")

    fc.legend_box(6, H - 580)
    return fc.get()


def _fc2_bottle():
    H = 780; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");              fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.io_box(cx, y, "Student Scans QR Code at Vending Machine", w=PW)
    fc.arrow_down(cx, y-15, G);              y -= 15+G
    fc.process(cx, y, "QR Arduino Sends  QR:<uid>  via Serial (9600 baud)", w=230)
    fc.arrow_down(cx, y-16, G);              y -= 16+G
    fc.process(cx, y, "bridge.py: Firestore Lookup\n db.collection('students').document(uid)", w=230)
    fc.arrow_down(cx, y-16, G);              y -= 16+G

    # Decision 1
    dy = y
    fc.decision(cx, dy, "Student\nFound?", w=130, h=44)
    _branch_right(fc, dy, "Yes", "No →", "Send REJECTED\nto Machine LCD")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Send  STUDENT:<name>:<id>  to LCD", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.io_box(cx, y, "Student Inserts Bottle into Machine", w=PW)
    fc.arrow_down(cx, y-15, G); y -= 15+G
    fc.process(cx, y, "bridge.py Sends SCAN_MATERIAL\nto Capacitive Sensor Arduino", w=230)
    fc.arrow_down(cx, y-16, G); y -= 16+G

    # Decision 2
    dy = y
    fc.decision(cx, dy, "Material\nType?", w=130, h=44)
    _branch_left(fc, dy, "PET", "Non-PET →", "Send REJECTED\nto Machine Sensor")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Atomic Firestore Update:\npoints++  bottles++  totalBottlesLifetime++", w=240, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.process(cx, y, "Create Transaction  (type='deposit', status='pending')\nNotify Admin via Panel", w=250, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.process(cx, y, "Admin: POST /api/transactions/verify/<id>", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G

    # Decision 3
    dy = y
    fc.decision(cx, dy, "Admin\nDecision?", w=130, h=44)
    _branch_left(fc, dy, "Approve", "Reject →", "status='cancelled'\nPoints Refunded")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "status='completed'  |  Points Confirmed\nStudent Notified via Flutter App", w=240, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.terminal(cx, y, "END")

    fc.legend_box(6, H-690)
    return fc.get()


def _fc3_reward():
    H = 720; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");             fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.io_box(cx, y, "Student Browses Reward Catalogue (Flutter App)", w=PW)
    fc.arrow_down(cx, y-15, G);             y -= 15+G
    fc.process(cx, y, "Student Selects Reward  (name, cost in points shown)", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G

    # Decision 1
    dy = y
    fc.decision(cx, dy, "Sufficient\nPoints?", w=130, h=44)
    _branch_right(fc, dy, "Yes", "No →", "Show 'Insufficient\nPoints' Error")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Deduct Points:  student.points -= cost\ntotalPointsSpent += cost", w=240, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.process(cx, y, "Generate Unique Ticket Code  (secrets.token_urlsafe())", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.process(cx, y, "Create Transaction:  type='redeem',\nstatus='pending', ticketCode stored", w=240, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.io_box(cx, y, "Student Receives Ticket Code in Flutter App", w=PW)
    fc.arrow_down(cx, y-15, G); y -= 15+G
    fc.process(cx, y, "Admin Locates Pending Redemption & Verifies Ticket Code", w=260)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.process(cx, y, "POST /api/transactions/verify/<id>", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G

    # Decision 2
    dy = y
    fc.decision(cx, dy, "Transaction\nValid?", w=130, h=44)
    _branch_right(fc, dy, "Yes", "No →", "Return 400\nBad Request Error")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "status='completed'  |  reward.stock -= 1\nActivity Notification Created", w=240, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.terminal(cx, y, "END")

    fc.legend_box(6, H-640)
    return fc.get()


def _fc4_reports():
    H = 580; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");             fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.io_box(cx, y, "Login & Navigate to Reports Page (/reports)", w=PW)
    fc.arrow_down(cx, y-15, G);             y -= 15+G
    fc.io_box(cx, y, "Select Filters:  Date Range, Department, Report Type", w=PW)
    fc.arrow_down(cx, y-15, G);             y -= 15+G
    fc.process(cx, y, "Query Firestore:  students, transactions,\ndepartments, rewards collections", w=240, h=34)
    fc.arrow_down(cx, y-17, G);             y -= 17+G
    fc.process(cx, y, "Aggregate & Join Data\n(dept totals, top recyclers, reward stats)", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G
    fc.process(cx, y, "Render reports.html via Jinja2\n(Charts + Summary Tables)", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G

    # Decision
    dy = y
    fc.decision(cx, dy, "Export\nRequested?", w=130, h=44)
    _branch_left(fc, dy, "Yes", "No →", "View Report\non Screen")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "GET /api/reports/export  →  openpyxl\nBuild .xlsx  (Summary, Students, Depts, Rewards sheets)", w=270, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.io_box(cx, y, "File Streamed to Browser  →  Downloaded by User", w=PW)
    fc.arrow_down(cx, y-15, G); y -= 15+G
    fc.terminal(cx, y, "END")

    fc.legend_box(6, H-490)
    return fc.get()


def _fc5_admin_mgmt():
    H = 640; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");             fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.process(cx, y, "Login as Super User  →  Navigate to /users", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G
    fc.process(cx, y, "Query Firestore 'admins' Collection\n→ Display Admin List", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G

    # Decision: Action?
    dy = y
    fc.decision(cx, dy, "Select\nAction?", w=130, h=44)

    # CREATE → left branch
    fc.arrow_left(cx-65, dy, cx-65-_LBX-_BW/2-2, label="Create")
    cr_y = dy
    fc.process(_LBX, cr_y, "Fill Admin Form\n(Name, Email, Dept, Password)", w=_BW, h=34)
    fc.arrow_down(_LBX, cr_y-17, G)
    cr_y2 = cr_y-17-G
    fc.process(_LBX, cr_y2, "Validate & Check\nEmail Uniqueness", w=_BW, h=32)
    fc.arrow_down(_LBX, cr_y2-16, G)
    cr_y3 = cr_y2-16-G
    fc.process(_LBX, cr_y3, "Save to Firestore\n'admins' Collection", w=_BW, h=32)
    fc.arrow_down(_LBX, cr_y3-16, G)
    cr_y4 = cr_y3-16-G
    fc.process(_LBX, cr_y4, "_notify_admins()\nActivity Log Created", w=_BW, h=32)

    # EDIT → right branch
    fc.arrow_right(cx+65, dy, _RBX-cx-65-_BW/2-2, label="Edit")
    ed_y = dy
    fc.process(_RBX, ed_y, "Load Admin Data\n→ Modify Fields", w=_BW, h=32)
    fc.arrow_down(_RBX, ed_y-16, G)
    ed_y2 = ed_y-16-G
    fc.process(_RBX, ed_y2, "POST /api/users/edit/<id>\nUpdate Firestore Doc", w=_BW, h=32)

    # DEACTIVATE → straight down
    fc.lbl(cx+4, dy-22-8, "Deactivate", color=FC_NO_CLR)
    fc.arrow_down(cx, dy-22, G); dact_y = dy-22-G
    fc.process(cx, dact_y, "Toggle status: 'inactive' / 'suspended'\n→ Admin Login Blocked", w=PW, h=34, fill=FC_NO_BOX)

    # Merge all three paths
    lfoot = cr_y4-16;   rfoot = ed_y2-16;   cfoot = dact_y-17
    merge_y = min(lfoot, rfoot, cfoot) - G
    fc.vline(_LBX, lfoot, merge_y)
    fc.vline(_RBX, rfoot, merge_y)
    fc.vline(cx,   cfoot, merge_y)
    fc.hline(_LBX, merge_y, _RBX)
    fc.arrow_down(cx, merge_y, G)
    fc.terminal(cx, merge_y-G, "Redirect to Users List  →  END", fill=FC_PROCESS, w=220, h=26)

    fc.legend_box(6, H-560)
    return fc.get()


def _fc6_registration():
    H = 660; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");             fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.io_box(cx, y, "Student Opens T2T Flutter App\n→ Navigate to Register Screen", w=PW)
    fc.arrow_down(cx, y-15, G);             y -= 15+G
    fc.io_box(cx, y, "Enter: Student ID, Name, Email,\nCourse, Year, Department, Password", w=PW, h=34)
    fc.arrow_down(cx, y-17, G);             y -= 17+G
    fc.process(cx, y, "Validate Input Fields  (required, format, length)", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G

    # Decision 1
    dy = y
    fc.decision(cx, dy, "Email Already\nRegistered?", w=135, h=44)
    _branch_right(fc, dy, "No", "Yes →", "Error: Email\nAlready Taken")
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Register with Firebase Authentication\n→ Firebase Auth UID Generated", w=250, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.process(cx, y, "Create Firestore 'students' Document\n(UID as Doc ID)  points:0  bottles:0  status:'pending'", w=270, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.io_box(cx, y, "Admin Receives Notification in Web Panel", w=PW)
    fc.arrow_down(cx, y-15, G); y -= 15+G
    fc.process(cx, y, "Admin Activates Account  (status → 'active')", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.io_box(cx, y, "Student Can Login & Use QR at Machines", w=PW)
    fc.arrow_down(cx, y-15, G); y -= 15+G
    fc.terminal(cx, y, "END")

    fc.legend_box(6, H-580)
    return fc.get()


def _fc7_machine():
    H = 560; fc = FC(CHART_W, H); cx = _CX; y = H - 30
    G = _GAP; PW = _PW

    fc.terminal(cx, y, "START");             fc.arrow_down(cx, y-13, G); y -= 13+G
    fc.process(cx, y, "Navigate to /machine_monitor\nQuery Firestore 'machines' Collection", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G
    fc.process(cx, y, "Display Machine Cards:\nname, location, status, fill%, last_online", w=260)
    fc.arrow_down(cx, y-16, G);             y -= 16+G
    fc.process(cx, y, "Calculate Fill%:  (current_bottles / capacity) × 100", w=PW)
    fc.arrow_down(cx, y-16, G);             y -= 16+G

    # Decision
    dy = y
    fc.decision(cx, dy, "Machine Full\nor Offline?", w=135, h=44)
    _branch_right(fc, dy, "Yes", "No →", "No Action\nRequired")
    fc.lbl(_CX+4, dy-22-8, "Yes", color=FC_NO_CLR)   # override: Yes = warning
    fc.arrow_down(cx, dy-22, G); y = dy-22-G

    fc.process(cx, y, "Admin Updates Machine Status\n(active / offline / full / maintenance / error)", w=270, h=34)
    fc.arrow_down(cx, y-17, G); y -= 17+G
    fc.process(cx, y, "POST /api/machine/update/<id>\nFirestore 'machines' Document Updated", w=PW)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.process(cx, y, "Maintenance Logged  |  Notification Sent to All Admins", w=270)
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.process(cx, y, "bridge.py Auto-Update:\nsession end  →  last_online = SERVER_TIMESTAMP",
               w=PW, fill=HexColor("#2d5016"))
    fc.arrow_down(cx, y-16, G); y -= 16+G
    fc.terminal(cx, y, "END")

    fc.legend_box(6, H-480)
    return fc.get()


# ── Wraps Drawing as a Platypus Flowable ──────────────────────────────────────

class DrawingFlowable(Flowable):
    MAX_H = 700   # hard cap to keep drawings on one page

    def __init__(self, drawing):
        super().__init__()
        self.drawing = drawing
        dw = drawing.width; dh = drawing.height
        scale = min(1.0, self.MAX_H / dh) if dh > self.MAX_H else 1.0
        self.scale  = scale
        self.width  = dw * scale
        self.height = dh * scale

    def draw(self):
        if self.scale != 1.0:
            self.canv.saveState()
            self.canv.scale(self.scale, self.scale)
        renderPDF.draw(self.drawing, self.canv, 0, 0)
        if self.scale != 1.0:
            self.canv.restoreState()

    def wrap(self, aW, aH):
        return self.width, self.height


# ── Section assembler ─────────────────────────────────────────────────────────

CHARTS = [
    ("Figure 1", "Login and Authentication",
     "Process Flow for T2T System Login, Password Validation, and Session Creation",
     _fc1_login),
    ("Figure 2", "Student Bottle Deposit and Transaction Verification",
     "Process Flow for QR Scanning, Material Detection, Firestore Update, and Admin Verification",
     _fc2_bottle),
    ("Figure 3", "Student Reward Redemption and Admin Verification",
     "Process Flow for Browsing Rewards, Point Deduction, Ticket Generation, and Admin Approval",
     _fc3_reward),
    ("Figure 4", "Generating and Exporting T2T System Reports",
     "Process Flow for Report Data Aggregation, Rendering, and Excel Export",
     _fc4_reports),
    ("Figure 5", "Super User Management of Admin Accounts",
     "Process Flow for Creating, Editing, and Deactivating Admin Accounts",
     _fc5_admin_mgmt),
    ("Figure 6", "Student Registration through the Flutter Application",
     "Process Flow for New Student Onboarding via Firebase Auth and Admin Activation",
     _fc6_registration),
    ("Figure 7", "Machine Maintenance and Status Monitoring",
     "Process Flow for Machine Status Review, Maintenance Logging, and bridge.py Auto-Updates",
     _fc7_machine),
]


def build_flowchart_section():
    items = []
    items.append(sp(0.3))
    items.append(para("PROCESS FLOWCHARTS", "h1"))
    items.append(hr())
    items.append(para(
        "The following process flowcharts document the step-by-step flows for the key "
        "system operations of Trash 2 Treasure (T2T). Standard flowchart symbols are "
        "used throughout: rounded rectangles (Start/End), rectangles (Process), "
        "diamonds (Decision), and parallelograms (Input/Output).",
        "body"))
    items.append(sp(0.4))

    leg = [
        ["Symbol", "Shape", "Meaning"],
        ["Terminal", "Rounded Rectangle (Red)",   "Start or End of process"],
        ["Process",  "Rectangle (Navy)",           "Processing step or computation"],
        ["Decision", "Diamond (Dark Blue)",         "Conditional Yes/No branch"],
        ["I/O",      "Parallelogram (Green)",       "User input or system output"],
    ]
    items.append(make_table(leg, col_widths=[
        CHART_W * 0.16, CHART_W * 0.36, CHART_W * 0.48]))
    items.append(sp(0.5))

    for fig, title, subtitle, fn in CHARTS:
        items.append(sp(0.3))
        items.append(para(f"{fig}. {title}", "h3"))
        items.append(para(subtitle, "figc"))
        try:
            items.append(DrawingFlowable(fn()))
        except Exception as e:
            items.append(para(f"[Flowchart error: {e}]", "body"))
        items.append(sp(0.4))
        items.append(PageBreak())

    return items


# ══════════════════════════════════════════════════════════════════════════════
# ── DFD DRAWING ENGINE ────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

DFD_ENT  = HexColor("#1a3a5c")   # external entity fill
DFD_PROC = HexColor("#0d6b6b")   # process fill
DFD_DS_B = HexColor("#eef2f7")   # data store background
DFD_DS_L = HexColor("#555577")   # data store border line
DFD_ARR  = HexColor("#2c3e50")   # arrow / flow colour
DFD_CENT = HexColor("#0f3460")   # centre system box


class DFDHelper:
    """Builds DFD-style diagrams on a ReportLab Drawing."""
    FONT  = "Helvetica"
    FONTB = "Helvetica-Bold"
    FS    = 7.5

    def __init__(self, w, h):
        self.d = Drawing(w, h)

    def _txt(self, lbl, cx, cy, bw, color=C_WHITE, bold=False, fsize=None):
        sz = fsize or self.FS
        fn = self.FONTB if bold else self.FONT
        cpl = max(int(bw / (sz * 0.58)), 5)
        words = lbl.split(); lines = []; cur = ""
        for w in words:
            t = (cur + " " + w).strip()
            if len(t) <= cpl: cur = t
            else:
                if cur: lines.append(cur)
                cur = w
        if cur: lines.append(cur)
        n = len(lines); lh = sz + 2.5
        base_y = cy + (n-1)*lh/2
        for i, txt in enumerate(lines):
            self.d.add(String(cx, base_y - i*lh, txt,
                              fontName=fn, fontSize=sz,
                              fillColor=color, textAnchor="middle"))

    def entity(self, cx, cy, label, w=100, h=40):
        """External entity: double-border rectangle."""
        self.d.add(Rect(cx-w/2, cy-h/2, w, h,
                        fillColor=DFD_ENT, strokeColor=C_WHITE, strokeWidth=1.5))
        self.d.add(Rect(cx-w/2+3, cy-h/2+3, w-6, h-6,
                        fillColor=None, strokeColor=C_WHITE, strokeWidth=0.6))
        self._txt(label, cx, cy, w-10, bold=True)

    def process(self, cx, cy, num, label, rw=50, rh=36):
        """Process: ellipse with process number at top."""
        self.d.add(Ellipse(cx-rw, cy-rh/2, rw*2, rh,
                           fillColor=DFD_PROC, strokeColor=C_WHITE, strokeWidth=1))
        self.d.add(String(cx, cy + rh/2 - 10, num,
                          fontName=self.FONTB, fontSize=8,
                          fillColor=C_WHITE, textAnchor="middle"))
        self._txt(label, cx, cy - 4, rw*1.7, fsize=7)

    def system_box(self, cx, cy, title, lines_text, w=200, h=130):
        """Central system box (Level 0 only)."""
        self.d.add(Rect(cx-w/2, cy-h/2, w, h,
                        fillColor=DFD_CENT, strokeColor=C_WHITE, strokeWidth=2))
        self.d.add(String(cx, cy + h/2 - 16, title,
                          fontName=self.FONTB, fontSize=9,
                          fillColor=C_WHITE, textAnchor="middle"))
        for i, ln in enumerate(lines_text):
            self.d.add(String(cx, cy + h/2 - 30 - i*13, ln,
                              fontName=self.FONT, fontSize=7,
                              fillColor=HexColor("#aaddff"), textAnchor="middle"))

    def datastore(self, cx, cy, label, w=140, h=24):
        """Data store: open-sided rectangle (two horizontal lines)."""
        self.d.add(Rect(cx-w/2, cy-h/2, w, h,
                        fillColor=DFD_DS_B, strokeColor=None))
        # top line
        self.d.add(Line(cx-w/2, cy+h/2, cx+w/2, cy+h/2,
                        strokeColor=DFD_DS_L, strokeWidth=1.5))
        # bottom line
        self.d.add(Line(cx-w/2, cy-h/2, cx+w/2, cy-h/2,
                        strokeColor=DFD_DS_L, strokeWidth=1.5))
        # left cap
        self.d.add(Line(cx-w/2, cy-h/2, cx-w/2, cy+h/2,
                        strokeColor=DFD_DS_L, strokeWidth=1.5))
        self._txt(label, cx, cy, w-12, color=C_DARK)

    def _arrowhead(self, x, y, dx, dy):
        """Draw arrowhead at (x,y) pointing in direction (dx,dy)."""
        import math
        length = math.sqrt(dx*dx + dy*dy)
        if length == 0: return
        ux, uy = dx/length, dy/length
        px, py = -uy, ux
        a = 6
        pts = [x - a*ux + a/2*px, y - a*uy + a/2*py,
               x - a*ux - a/2*px, y - a*uy - a/2*py,
               x, y]
        self.d.add(Polygon(pts, fillColor=DFD_ARR, strokeColor=DFD_ARR, strokeWidth=0))

    def flow(self, x1, y1, x2, y2, label="", dashed=False, bend_x=None):
        """Labeled data flow arrow from (x1,y1) to (x2,y2)."""
        import math
        color = DFD_ARR
        sw = 1.1

        def _dash_line(ax1, ay1, ax2, ay2):
            ddx = ax2-ax1; ddy = ay2-ay1
            ln = math.sqrt(ddx*ddx+ddy*ddy)
            steps = max(int(ln/7), 1)
            for j in range(steps):
                t0 = j/steps; t1 = min((j+0.5)/steps, 1.0)
                self.d.add(Line(ax1+ddx*t0, ay1+ddy*t0,
                                ax1+ddx*t1, ay1+ddy*t1,
                                strokeColor=color, strokeWidth=sw))

        def _solid_line(ax1, ay1, ax2, ay2):
            self.d.add(Line(ax1, ay1, ax2, ay2, strokeColor=color, strokeWidth=sw))

        draw_line = _dash_line if dashed else _solid_line

        if bend_x is not None:
            # L-shape: horizontal then vertical
            draw_line(x1, y1, bend_x, y1)
            draw_line(bend_x, y1, bend_x, y2)
            self._arrowhead(bend_x, y2, 0, y2 - y1)
            if label:
                # label above/below the horizontal segment
                lx = (x1 + bend_x) / 2
                ly = y1 + (6 if y1 > y2 else -10)
                self.d.add(String(lx, ly, label,
                                  fontName=self.FONT, fontSize=6.5,
                                  fillColor=color, textAnchor="middle"))
        else:
            dx = x2 - x1; dy = y2 - y1
            length = math.sqrt(dx*dx + dy*dy)
            if length > 0:
                ux, uy = dx/length, dy/length
                ex2 = x2 - ux*7; ey2 = y2 - uy*7
                draw_line(x1, y1, ex2, ey2)
                self._arrowhead(x2, y2, dx, dy)
            if label:
                # offset label perpendicular to arrow direction
                mx = (x1 + x2) / 2; my = (y1 + y2) / 2
                if length > 0:
                    # perp unit vector
                    px = -dy/length; py = dx/length
                    ox = px * 9; oy = py * 9
                else:
                    ox = 0; oy = 8
                self.d.add(String(mx + ox, my + oy, label,
                                  fontName=self.FONT, fontSize=6.5,
                                  fillColor=color, textAnchor="middle"))

    def biflow(self, x1, y1, x2, y2, lbl1="", lbl2="", offset=5):
        """Bidirectional flow: two parallel arrows."""
        dx = x2-x1; dy = y2-y1
        import math
        length = math.sqrt(dx*dx+dy*dy)
        if length == 0: return
        px = -dy/length*offset; py = dx/length*offset
        self.flow(x1+px, y1+py, x2+px, y2+py, label=lbl1)
        self.flow(x2-px, y2-py, x1-px, y1-py, label=lbl2)

    def flow_lr(self, x1, y1, x2, y2, label="", dashed=False):
        """Strictly horizontal arrow (left→right or right→left) with label above the line."""
        import math
        color = DFD_ARR; sw = 1.1
        dx = x2 - x1; dy = y2 - y1
        length = math.sqrt(dx*dx + dy*dy)
        if length == 0: return

        def seg(ax1, ay1, ax2, ay2):
            ddx = ax2-ax1; ddy = ay2-ay1
            ln = math.sqrt(ddx*ddx+ddy*ddy)
            if dashed:
                steps = max(int(ln/7), 1)
                for j in range(steps):
                    t0 = j/steps; t1 = min((j+0.5)/steps, 1.0)
                    self.d.add(Line(ax1+ddx*t0, ay1+ddy*t0,
                                   ax1+ddx*t1, ay1+ddy*t1,
                                   strokeColor=color, strokeWidth=sw))
            else:
                self.d.add(Line(ax1, ay1, ax2, ay2, strokeColor=color, strokeWidth=sw))

        ux, uy = dx/length, dy/length
        ex2 = x2 - ux*7; ey2 = y2 - uy*7
        seg(x1, y1, ex2, ey2)
        self._arrowhead(x2, y2, dx, dy)
        if label:
            self.d.add(String((x1+x2)/2, y1+7, label,
                              fontName=self.FONT, fontSize=6.5,
                              fillColor=color, textAnchor="middle"))

    def get(self): return self.d


# ── DFD Builder Functions ─────────────────────────────────────────────────────

def _dfd8_context():
    """Figure 8 – DFD Level 0 System Context."""
    W = CHART_W; H = 480
    d = DFDHelper(W, H)
    cx = W/2; cy = 260

    # Central T2T system box
    d.system_box(cx, cy, "T2T: Trash 2 Treasure",
                 ["Python 3.10+ / Flask 3.0+",
                  "Firebase Firestore (NoSQL DB)",
                  "Firebase Authentication",
                  "Firebase Cloud Messaging",
                  "Google Cloud Run / Gunicorn"],
                 w=220, h=150)

    # External entities
    d.entity(80,  430, "Super User\n(Web Panel)", w=100, h=40)
    d.entity(460, 430, "Arduino Machine\n+ bridge.py", w=110, h=40)
    d.entity(80,  90,  "Admin Flutter\nApp", w=100, h=40)
    d.entity(460, 90,  "Student Flutter\nApp", w=110, h=40)
    d.entity(cx,  30,  "Firebase Cloud\nPlatform", w=130, h=36)

    # Flows
    d.biflow(130, 430, cx-110, cy+55, "CRUD / Reports", "HTML / JSON")
    d.biflow(130, 90,  cx-110, cy-45, "REST Calls", "Push / FCM")
    d.biflow(406, 90,  cx+110, cy-45, "REST Calls", "Push / FCM")
    d.biflow(405, 430, cx+110, cy+55, "Serial / Firestore SDK", "Responses")
    d.biflow(cx,  51,  cx,     cy+75, "Firebase SDK", "Real-time updates")

    return d.get()


def _dfd9_auth():
    """Figure 9 – DFD Level 1 Authentication."""
    W = CHART_W; H = 560
    d = DFDHelper(W, H)

    # ── Grid columns ──
    EX  = 95          # entity center x
    PX  = W / 2       # process center x  ≈ 276
    DSX = W - 95      # data-store center x  ≈ 457
    DSW = 155         # data-store width  (right edge ≈ 534)
    DSH = 26

    # entity right edge → process left edge gap is clean
    # ── Row heights ──
    R1 = 460   # entity + process 1.0
    R2 = 310   # process 2.0
    R3 = 160   # process 3.0

    # ── Data-store rows (aligned to processes) ──
    DS_SU  = 490   # super_users
    DS_ADM = 440   # admins
    DS_SES = 310   # session store
    DS_NOT = 160   # notifications

    # Draw entities
    d.entity(EX, R1, "User / Admin /\nSuper User", w=115, h=48)

    # Draw processes
    d.process(PX, R1, "1.0", "Validate\nCredentials", rw=65, rh=44)
    d.process(PX, R2, "2.0", "Check Role\n& Scope",   rw=65, rh=44)
    d.process(PX, R3, "3.0", "Log Activity\n& Lockout", rw=65, rh=44)

    # Draw data stores
    d.datastore(DSX, DS_SU,  "super_users Collection", w=DSW, h=DSH)
    d.datastore(DSX, DS_ADM, "admins Collection",       w=DSW, h=DSH)
    d.datastore(DSX, DS_SES, "Flask Session Store",     w=DSW, h=DSH)
    d.datastore(DSX, DS_NOT, "notifications Collection", w=DSW, h=DSH)

    proc_r = PX + 65   # right edge of process ellipse
    ds_l   = DSX - DSW/2  # left edge of data stores

    # Entity → Process 1.0  (horizontal)
    d.flow_lr(EX + 57, R1, PX - 65, R1, "email + password")

    # Process 1.0 → super_users  (horizontal)
    d.flow_lr(proc_r, R1 + 10, ds_l, DS_SU, "query email")
    # super_users → Process 1.0  (dashed, horizontal, slightly lower)
    d.flow_lr(ds_l, DS_SU - 10, proc_r, R1 - 8, "SuperUser doc", dashed=True)

    # Process 1.0 → admins
    d.flow_lr(proc_r, R1 - 10, ds_l, DS_ADM + 10, "query email")
    # admins → Process 1.0
    d.flow_lr(ds_l, DS_ADM, proc_r, R1 - 20, "Admin doc", dashed=True)

    # Process 1.0 → Process 2.0  (vertical, center spine)
    d.flow(PX, R1 - 44, PX, R2 + 44, "auth token + role")

    # Process 2.0 → Session Store
    d.flow_lr(proc_r, R2, ds_l, DS_SES, "store session_tokens")

    # Process 2.0 → Process 3.0  (vertical)
    d.flow(PX, R2 - 44, PX, R3 + 44, "login event")

    # Process 3.0 → notifications
    d.flow_lr(proc_r, R3, ds_l, DS_NOT, "write notification")

    # Session cookie back to entity  (left side vertical run)
    d.flow_lr(PX - 65, R2, EX + 57, R2, "session cookie", dashed=True)

    return d.get()


def _dfd10_bottle():
    """Figure 10 – DFD Level 1 Bottle Deposit."""
    W = CHART_W; H = 560
    d = DFDHelper(W, H)

    EX  = 95
    PX  = W / 2
    DSX = W - 95
    DSW = 155; DSH = 26

    # Row heights
    R_ARD  = 470   # Arduino entity
    R_P1   = 400   # Submit Deposit
    R_P2   = 220   # Admin Verification
    R_ADM  = 220   # Admin entity (same row as P2)

    DS_MACH = 470
    DS_TXN  = 340
    DS_STU  = 160

    d.entity(EX, R_ARD,  "Arduino Machine\n+ bridge.py", w=115, h=48)
    d.entity(EX, R_ADM,  "Admin User\n(Web Panel)",       w=115, h=44)

    d.process(PX, R_P1, "1.0", "Submit\nDeposit",     rw=65, rh=44)
    d.process(PX, R_P2, "2.0", "Admin\nVerification", rw=65, rh=44)

    d.datastore(DSX, DS_MACH, "machines Collection",     w=DSW, h=DSH)
    d.datastore(DSX, DS_TXN,  "transactions Collection", w=DSW, h=DSH)
    d.datastore(DSX, DS_STU,  "students Collection",      w=DSW, h=DSH)

    proc_r = PX + 65
    ds_l   = DSX - DSW/2

    # Arduino → P1
    d.flow_lr(EX + 57, R_ARD, PX - 65, R_P1 + 8, "QR:<uid>,  MATERIAL:PET")

    # P1 → machines
    d.flow_lr(proc_r, R_P1 + 12, ds_l, DS_MACH, "update last_online")

    # P1 → transactions (create)
    d.flow_lr(proc_r, R_P1 - 12, ds_l, DS_TXN + 10, "create deposit txn (status:pending)")

    # P1 → P2  (vertical)
    d.flow(PX, R_P1 - 44, PX, R_P2 + 44, "txn id  →  notify admin")

    # Admin → P2
    d.flow_lr(EX + 57, R_ADM, PX - 65, R_P2, "POST /verify/<id>")

    # P2 → transactions (update status)
    d.flow_lr(proc_r, R_P2 + 12, ds_l, DS_TXN - 10, "status = completed")

    # P2 → students (update points)
    d.flow_lr(proc_r, R_P2 - 12, ds_l, DS_STU + 10,
              "points++  bottles++  totalBottlesLifetime++")

    # students → P2 (read back, dashed)
    d.flow_lr(ds_l, DS_STU - 10, proc_r, R_P2 - 20, "updated doc", dashed=True)

    # P2 → Admin (result, dashed)
    d.flow_lr(PX - 65, R_P2, EX + 57, R_ADM - 10, "result", dashed=True)

    return d.get()


def _dfd11_reward():
    """Figure 11 – DFD Level 1 Reward Creation & Redemption."""
    W = CHART_W; H = 560
    d = DFDHelper(W, H)

    EX  = 95
    PX  = W / 2
    DSX = W - 95
    DSW = 155; DSH = 26

    R_SU  = 470
    R_P1  = 400
    R_P2  = 220
    R_STU = 220

    DS_REW = 470
    DS_TXN = 340
    DS_STU = 160

    d.entity(EX, R_SU,  "Super User /\nAdmin (Web)",  w=115, h=48)
    d.entity(EX, R_STU, "Student\n(Flutter App)",      w=115, h=44)

    d.process(PX, R_P1, "1.0", "Manage\nRewards", rw=65, rh=44)
    d.process(PX, R_P2, "2.0", "Redeem\nReward",  rw=65, rh=44)

    d.datastore(DSX, DS_REW, "rewards Collection",       w=DSW, h=DSH)
    d.datastore(DSX, DS_TXN, "transactions Collection",  w=DSW, h=DSH)
    d.datastore(DSX, DS_STU, "students Collection",       w=DSW, h=DSH)

    proc_r = PX + 65
    ds_l   = DSX - DSW/2

    # Super User → P1
    d.flow_lr(EX + 57, R_SU, PX - 65, R_P1 + 8, "POST /rewards/add  (name, cost, stock)")

    # P1 → rewards
    d.flow_lr(proc_r, R_P1 + 8, ds_l, DS_REW, "save reward doc")
    # rewards → P1 (dashed)
    d.flow_lr(ds_l, DS_REW - 10, proc_r, R_P1 - 8, "reward data", dashed=True)

    # P1 → P2  (vertical)
    d.flow(PX, R_P1 - 44, PX, R_P2 + 44, "reward list  →  student browse")

    # Student → P2
    d.flow_lr(EX + 57, R_STU, PX - 65, R_P2, "confirm redeem  (reward_id)")

    # P2 → transactions
    d.flow_lr(proc_r, R_P2 + 12, ds_l, DS_TXN + 10,
              "create txn  type=redeem  status=pending  ticketCode")

    # P2 → students
    d.flow_lr(proc_r, R_P2 - 12, ds_l, DS_STU + 10,
              "student.points -= cost   totalPointsSpent += cost")
    # students → P2 (dashed)
    d.flow_lr(ds_l, DS_STU - 10, proc_r, R_P2 - 22, "points balance", dashed=True)

    # P2 → Student (ticket code, dashed)
    d.flow_lr(PX - 65, R_P2, EX + 57, R_STU - 10, "ticketCode response", dashed=True)

    return d.get()


def _dfd12_reports():
    """Figure 12 – DFD Level 1 Report Generation."""
    W = CHART_W; H = 560
    d = DFDHelper(W, H)

    EX  = 95
    PX  = W / 2
    DSX = W - 95
    DSW = 155; DSH = 26

    R_ENT = 450
    R_P1  = 380
    R_P2  = 180

    DS_STU  = 490
    DS_TXN  = 450
    DS_DEPT = 410
    DS_REW  = 370

    d.entity(EX, R_ENT, "Super User /\nAdmin (Web)", w=115, h=48)

    d.process(PX, R_P1, "1.0", "Aggregate\nReport Data", rw=65, rh=44)
    d.process(PX, R_P2, "2.0", "Render /\nExport",        rw=65, rh=44)

    d.datastore(DSX, DS_STU,  "students Collection",     w=DSW, h=DSH)
    d.datastore(DSX, DS_TXN,  "transactions Collection", w=DSW, h=DSH)
    d.datastore(DSX, DS_DEPT, "departments Collection",  w=DSW, h=DSH)
    d.datastore(DSX, DS_REW,  "rewards Collection",       w=DSW, h=DSH)

    proc_r = PX + 65
    ds_l   = DSX - DSW/2

    # Entity → P1
    d.flow_lr(EX + 57, R_ENT, PX - 65, R_P1 + 8, "filters:  date / dept / type")

    # P1 → each data store (horizontal arrows, staggered slightly)
    d.flow_lr(proc_r, R_P1 + 18, ds_l, DS_STU,  "query students")
    d.flow_lr(proc_r, R_P1 + 6,  ds_l, DS_TXN,  "query transactions")
    d.flow_lr(proc_r, R_P1 - 6,  ds_l, DS_DEPT, "query departments")
    d.flow_lr(proc_r, R_P1 - 18, ds_l, DS_REW,  "query rewards")

    # data stores → P1 (single combined return, dashed)
    d.flow_lr(ds_l, DS_DEPT - 10, proc_r, R_P1 - 28, "collection docs", dashed=True)

    # P1 → P2  (vertical)
    d.flow(PX, R_P1 - 44, PX, R_P2 + 44, "aggregated data  (totals, rankings)")

    # P2 → Entity (result, dashed)
    d.flow_lr(PX - 65, R_P2, EX + 57, R_ENT - 24, "HTML report / .xlsx file", dashed=True)

    # P2 → departments (openpyxl export)
    d.flow_lr(proc_r, R_P2, ds_l, DS_DEPT - 20, "openpyxl export")

    return d.get()
    cx = W / 2
    # Column positions
    ent_x = 72          # left entity column
    proc_x = cx         # center process column
    ds_x = W - 88       # right data-store column (88 from right edge)

    # External entity
    d.entity(ent_x, 440, "User / Admin /\nSuper User", w=110, h=44)

    # Processes  (spread vertically: 390, 260, 130)
    d.process(proc_x, 390, "1.0", "Validate\nCredentials", rw=60, rh=40)
    d.process(proc_x, 260, "2.0", "Check Role\n& Scope",   rw=60, rh=40)
    d.process(proc_x, 130, "3.0", "Log Activity\n& Lockout", rw=60, rh=40)

    # Data stores – right column, spread to match processes
    dw = 148
    d.datastore(ds_x, 410, "super_users Collection", w=dw, h=26)
    d.datastore(ds_x, 370, "admins Collection",       w=dw, h=26)
    d.datastore(ds_x, 260, "Flask Session Store",     w=dw, h=26)
    d.datastore(ds_x, 130, "notifications Collection", w=dw, h=26)

    ds_left = ds_x - dw / 2   # left edge of data-store boxes

    # Flows: entity → process 1.0
    d.flow(ent_x + 55, 440, proc_x - 60, 400, "email + password")

    # process 1.0 ↔ super_users
    d.flow(proc_x + 60, 390, ds_left, 410, "query email")
    d.flow(ds_left, 410, proc_x + 60, 390, "SuperUser doc", dashed=True)

    # process 1.0 ↔ admins
    d.flow(proc_x + 60, 380, ds_left, 370, "query email")
    d.flow(ds_left, 370, proc_x + 60, 380, "Admin doc", dashed=True)

    # process 1.0 → process 2.0
    d.flow(proc_x, 370, proc_x, 300, "auth token + role")

    # process 2.0 → session store
    d.flow(proc_x + 60, 260, ds_left, 260, "store session_tokens")

    # process 2.0 → process 3.0
    d.flow(proc_x, 240, proc_x, 170, "login event")

    # process 3.0 → notifications
    d.flow(proc_x + 60, 130, ds_left, 130, "write notification")

    # session cookie back to entity (left side, vertical run)
    d.flow(proc_x - 60, 260, ent_x + 55, 260, "session cookie")
    d.flow(ent_x + 55, 260, ent_x + 55, 418, "")

    return d.get()


# ── DFD Section Builder ───────────────────────────────────────────────────────

DFD_CHARTS = [
    ("Figure 8",  "DFD Level 0 — T2T System Context (Overview)",
     "Shows all external entities interacting with the T2T system and the Firebase Cloud Platform",
     _dfd8_context),
    ("Figure 9",  "DFD Level 1 — Authentication and Session Management",
     "Data flows for credential validation, role checking, session storage, and activity logging",
     _dfd9_auth),
    ("Figure 10", "DFD Level 1 — Bottle Deposit Transaction Processing",
     "Data flows for QR scanning, Firestore student lookup, atomic point update, and admin verification",
     _dfd10_bottle),
    ("Figure 11", "DFD Level 1 — Reward Creation and Redemption",
     "Data flows for adding rewards, browsing, point deduction, ticket generation, and transaction creation",
     _dfd11_reward),
    ("Figure 12", "DFD Level 1 — Report Generation and Export",
     "Data flows for multi-collection aggregation, Jinja2 rendering, and openpyxl Excel export",
     _dfd12_reports),
]


def build_dfd_section():
    items = []
    items.append(sp(0.3))
    items.append(para("DATA FLOW DIAGRAMS", "h1"))
    items.append(hr())
    items.append(para(
        "The Data Flow Diagrams (DFDs) below illustrate how data moves between the "
        "external actors, internal processes, and Firestore data stores in the T2T system. "
        "DFD notation: double-border rectangles = external entities; ellipses = processes; "
        "open-sided rectangles = data stores; labeled arrows = data flows.",
        "body"))
    items.append(sp(0.4))

    leg = [
        ["Symbol", "Shape", "Meaning"],
        ["External Entity", "Double-border Rectangle (Navy)", "Actor outside the system boundary"],
        ["Process",         "Ellipse (Teal)",                  "Data transformation or computation"],
        ["Data Store",      "Open-sided Rectangle (Gray)",     "Persistent Firestore collection"],
        ["Data Flow",       "Labeled Arrow",                   "Data moving between components"],
    ]
    items.append(make_table(leg, col_widths=[
        CHART_W*0.20, CHART_W*0.36, CHART_W*0.44]))
    items.append(sp(0.5))

    for fig, title, subtitle, fn in DFD_CHARTS:
        items.append(sp(0.3))
        items.append(para(f"{fig}. {title}", "h3"))
        items.append(para(subtitle, "figc"))
        try:
            items.append(DrawingFlowable(fn()))
        except Exception as e:
            items.append(para(f"[DFD error: {e}]", "body"))
        items.append(sp(0.4))
        items.append(PageBreak())

    return items


# ══════════════════════════════════════════════════════════════════════════════
# ── SEQUENCE DIAGRAM ENGINE ───────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

SEQ_PART  = HexColor("#0f3460")   # participant box
SEQ_LIFE  = HexColor("#aaaacc")   # lifeline
SEQ_MSG   = HexColor("#1a1a2e")   # message arrow
SEQ_DASH  = HexColor("#558877")   # return/response arrow
SEQ_NOTE  = HexColor("#f0f4f8")   # note/fragment bg
SEQ_ACT   = HexColor("#cce0ff")   # activation box


class SeqDiag:
    """Builds UML sequence diagrams."""
    FONT  = "Helvetica"
    FONTB = "Helvetica-Bold"
    FS    = 7.0
    PW    = 90    # participant box width
    PH    = 28    # participant box height
    STEP  = 28    # vertical gap per message

    def __init__(self, participants, w, h, spacing=None):
        self.parts = participants
        self.n     = len(participants)
        self.W     = w; self.H = h
        self.d     = Drawing(w, h)
        margin = 50
        span   = w - 2 * margin
        self.spacing = spacing or (span / max(self.n - 1, 1))
        self.xs = [margin + i * self.spacing for i in range(self.n)]
        self.top_y = h - self.PH/2 - 8
        self._draw_parts()
        self.cur_y = self.top_y - self.PH/2 - 6

    def _txt(self, lbl, cx, cy, bw, color=C_WHITE, bold=False, fsize=None):
        sz = fsize or self.FS
        fn = self.FONTB if bold else self.FONT
        cpl = max(int(bw / (sz * 0.58)), 5)
        words = lbl.split(); lines = []; cur = ""
        for w in words:
            t = (cur+" "+w).strip()
            if len(t) <= cpl: cur = t
            else:
                if cur: lines.append(cur)
                cur = w
        if cur: lines.append(cur)
        n = len(lines); lh = sz + 2.2
        base_y = cy + (n-1)*lh/2
        for i, txt in enumerate(lines):
            self.d.add(String(cx, base_y - i*lh, txt,
                              fontName=fn, fontSize=sz,
                              fillColor=color, textAnchor="middle"))

    def _draw_parts(self):
        for x, name in zip(self.xs, self.parts):
            self.d.add(Rect(x-self.PW/2, self.top_y-self.PH/2,
                            self.PW, self.PH,
                            fillColor=SEQ_PART, strokeColor=C_WHITE,
                            strokeWidth=0.8))
            self._txt(name, x, self.top_y, self.PW-6, bold=True)

    def _lifelines(self, bottom_y):
        for x in self.xs:
            top = self.top_y - self.PH/2
            y = top
            while y > bottom_y:
                end = max(y - 5, bottom_y)
                self.d.add(Line(x, y, x, end,
                                strokeColor=SEQ_LIFE, strokeWidth=0.7))
                y = end - 3

    def _arrowhead_r(self, x, y):
        a = 5
        self.d.add(Polygon([x-a, y+a/2, x-a, y-a/2, x, y],
                           fillColor=SEQ_MSG, strokeColor=SEQ_MSG, strokeWidth=0))

    def _arrowhead_l(self, x, y, color=None):
        a = 5; c = color or SEQ_DASH
        self.d.add(Polygon([x+a, y+a/2, x+a, y-a/2, x, y],
                           fillColor=c, strokeColor=c, strokeWidth=0))

    def msg(self, fi, ti, label, ret=False):
        """Solid arrow from participant fi to ti. ret=True = dashed return."""
        self.cur_y -= self.STEP
        y = self.cur_y
        x1 = self.xs[fi]; x2 = self.xs[ti]
        color = SEQ_DASH if ret else SEQ_MSG
        sw = 1.0

        if ret:
            # dashed line
            dx = x2 - x1; steps = max(int(abs(dx)/6), 3)
            for j in range(steps):
                t0 = j/steps; t1 = (j+0.4)/steps
                self.d.add(Line(x1+dx*t0, y, x1+dx*t1, y,
                                strokeColor=color, strokeWidth=sw))
        else:
            self.d.add(Line(x1, y, x2-(5 if x2>x1 else -5), y,
                            strokeColor=color, strokeWidth=sw))

        if x2 > x1:
            self._arrowhead_r(x2, y)
        else:
            self._arrowhead_l(x2, y, color)

        mid = (x1+x2)/2
        self.d.add(String(mid, y+3, label,
                          fontName=self.FONT, fontSize=6.5,
                          fillColor=color, textAnchor="middle"))

    def note(self, label, x_idx=0):
        """Comment / [bracket] note line."""
        self.cur_y -= 10
        y = self.cur_y
        # faint separator
        self.d.add(Line(20, y, self.W-20, y,
                        strokeColor=HexColor("#dddddd"), strokeWidth=0.4,
                        strokeDashArray=[3,2]))
        self.d.add(String(self.xs[x_idx]-self.PW/2+4, y+3,
                          f"[ {label} ]",
                          fontName=self.FONT, fontSize=6,
                          fillColor=HexColor("#666688")))
        self.cur_y -= 6

    def finalize(self):
        """Draw lifelines then return Drawing."""
        self._lifelines(self.cur_y - 20)
        return self.d


# ── Sequence Diagram Builders ─────────────────────────────────────────────────

def _seq13_login():
    """Figure 13 – System Login."""
    parts = ["Browser\n/ Client", "Flask\n(/home)", "super_users\nCollection",
             "admins\nCollection"]
    s = SeqDiag(parts, CHART_W, 500, spacing=140)
    s.msg(0, 1, "POST /home  {email, password}")
    s.msg(1, 2, "query by email")
    s.msg(2, 1, "SuperUser doc", ret=True)
    s.note("Verify SHA-256 hash + check account_locked_until", x_idx=1)
    s.msg(1, 3, "query by email (if SU auth fails)")
    s.msg(3, 1, "Admin doc", ret=True)
    s.note("Check status == 'active', compare plaintext password", x_idx=1)
    s.msg(1, 2, "update session_tokens array (max 5)")
    s.msg(2, 1, "write confirmed", ret=True)
    s.note("session.permanent=True, 30-day lifetime", x_idx=1)
    s.msg(1, 0, "302 Redirect /dashboard + Set-Cookie: session", ret=True)
    return s.finalize()


def _seq14_bottle():
    """Figure 14 – Bottle Deposit."""
    parts = ["Student", "QR\nArduino", "bridge.py", "Firestore\nDB",
             "Bottle\nSensor", "Admin\n(Web)"]
    s = SeqDiag(parts, CHART_W, 640, spacing=98)
    s.msg(0, 1, "Scan QR Code")
    s.msg(1, 2, "QR:<uid>  (9600 baud serial)")
    s.msg(2, 3, "db.collection('students').document(uid).get()")
    s.msg(3, 2, "{name, studentID, points}", ret=True)
    s.msg(2, 4, "STUDENT:<name>:<id>  (LCD display)")
    s.msg(0, 4, "Insert Bottle")
    s.msg(4, 2, "BOTTLE_DETECTED:<id>")
    s.msg(2, 1, "SCAN_MATERIAL")
    s.msg(1, 2, "MATERIAL:PET  (capacitive sensor)")
    s.msg(2, 4, "ACCEPTED  (buzzer + LCD)")
    s.msg(2, 3, "update points/bottles (firestore.Increment)")
    s.msg(2, 3, "transactions.add({type:deposit, status:pending})")
    s.msg(3, 2, "txn doc ID", ret=True)
    s.msg(3, 5, "admin notification")
    s.msg(5, 3, "POST /api/transactions/verify/<id>")
    s.msg(3, 5, "status=completed", ret=True)
    return s.finalize()


def _seq15_reward():
    """Figure 15 – Reward Redemption."""
    parts = ["Student\n(Flutter)", "Flask\nAPI", "Firestore\nDB", "Admin\n(Web)"]
    s = SeqDiag(parts, CHART_W, 560, spacing=160)
    s.msg(0, 1, "Browse Rewards")
    s.msg(1, 2, "GET rewards (status=active, stock>0)")
    s.msg(2, 1, "rewards list", ret=True)
    s.msg(1, 0, "reward cards", ret=True)
    s.msg(0, 1, "Confirm Redemption  (reward_id)")
    s.msg(1, 2, "GET student doc → check points >= cost")
    s.msg(2, 1, "{points:150}", ret=True)
    s.note("student.points -= cost   totalPointsSpent += cost", x_idx=1)
    s.note("ticketCode = secrets.token_urlsafe()", x_idx=1)
    s.msg(1, 2, "transactions.add({type:redeem, status:pending, ticketCode})")
    s.msg(2, 1, "txn_id", ret=True)
    s.msg(1, 0, "{ticket_code}", ret=True)
    s.msg(2, 3, "admin notification: 'New Redemption Pending'")
    s.msg(3, 2, "POST /api/transactions/verify/<id>")
    s.msg(2, 3, "status=completed, reward.stock -= 1", ret=True)
    s.msg(1, 0, "FCM push: 'Reward Approved!'", ret=True)
    return s.finalize()


def _seq16_admin_mgmt():
    """Figure 16 – Admin Account Management."""
    parts = ["Super User\n(Web)", "Flask\n(/users)", "admins\nCollection",
             "notifications\nCollection"]
    s = SeqDiag(parts, CHART_W, 580, spacing=145)
    s.msg(0, 1, "GET /users")
    s.msg(1, 2, "get_all_admins()")
    s.msg(2, 1, "admin list docs", ret=True)
    s.msg(1, 0, "render users.html", ret=True)
    s.note("[ Create Admin ]", x_idx=0)
    s.msg(0, 1, "POST /api/users/add  {name, email, dept, password}")
    s.msg(1, 2, "get_admin_by_email → check uniqueness")
    s.msg(2, 1, "None (email unique)", ret=True)
    s.msg(1, 2, "Admin.save()  →  new doc in admins")
    s.msg(2, 1, "doc_id", ret=True)
    s.msg(1, 3, "_notify_admins() → write notification")
    s.msg(3, 1, "notification saved", ret=True)
    s.msg(1, 0, "{success: true}", ret=True)
    s.note("[ Toggle Admin Status ]", x_idx=0)
    s.msg(0, 1, "POST /api/users/toggle/<id>")
    s.msg(1, 2, "update status='inactive' / 'suspended'")
    s.msg(2, 1, "write confirmed", ret=True)
    s.msg(1, 0, "{success: true}", ret=True)
    return s.finalize()


def _seq17_machine():
    """Figure 17 – Machine Status Update."""
    parts = ["Arduino\nMachine", "bridge.py", "Firestore\nDB", "Admin\n(/machine_monitor)"]
    s = SeqDiag(parts, CHART_W, 520, spacing=128)
    s.msg(0, 1, "SESSION_START:<student_id>  (serial)")
    s.msg(1, 2, "update: current_bottles+1, last_online=now")
    s.msg(2, 1, "write confirmed", ret=True)
    s.note("... bottles deposited during session ...", x_idx=1)
    s.msg(0, 1, "SESSION_END:<student_id>  (serial)")
    s.note("session closed; bridge.py idles", x_idx=1)
    s.msg(3, 2, "GET /machine_monitor")
    s.msg(2, 3, "machine docs (status, fill%, last_online)", ret=True)
    s.note("fill% = current_bottles / capacity × 100", x_idx=2)
    s.note("warn if fill% > 80% or last_online > 30 min", x_idx=2)
    s.note("Admin renders machine dashboard cards", x_idx=3)
    return s.finalize()


# ── Sequence Section Builder ──────────────────────────────────────────────────

SEQ_CHARTS = [
    ("Figure 13", "Sequential Diagram — System Login and Session Establishment",
     "Chronological message-passing for login, password validation, and session token creation",
     _seq13_login),
    ("Figure 14", "Sequential Diagram — Student Bottle Deposit via Vending Machine",
     "Full sequence from QR scan through material detection, Firestore update, and admin verification",
     _seq14_bottle),
    ("Figure 15", "Sequential Diagram — Student Reward Redemption and Admin Verification",
     "Reward browsing, point deduction, ticket generation, admin approval, and FCM notification",
     _seq15_reward),
    ("Figure 16", "Sequential Diagram — Super User Admin Account Management",
     "Admin creation, email uniqueness check, Firestore save, and status toggle sequence",
     _seq16_admin_mgmt),
    ("Figure 17", "Sequential Diagram — Machine Status Update by bridge.py",
     "Session-based machine fill tracking, Firestore timestamp update, and dashboard rendering",
     _seq17_machine),
]


def build_sequence_section():
    items = []
    items.append(sp(0.3))
    items.append(para("SEQUENTIAL DIAGRAMS", "h1"))
    items.append(hr())
    items.append(para(
        "Sequential diagrams visualize the chronological message-passing between actors "
        "and system components for each major T2T workflow. Solid arrows indicate requests "
        "or commands; dashed arrows indicate responses or return values.",
        "body"))
    items.append(sp(0.4))

    leg = [
        ["Element", "Appearance", "Meaning"],
        ["Participant",    "Navy rectangle at top",           "Actor or system component"],
        ["Lifeline",       "Vertical dashed gray line",       "Participant's existence over time"],
        ["Message",        "Solid horizontal arrow",          "Request, command, or data sent"],
        ["Return",         "Dashed horizontal arrow",         "Response or return value"],
        ["Note/Fragment",  "[ label ] separator line",        "Condition, loop, or comment"],
    ]
    items.append(make_table(leg, col_widths=[
        CHART_W*0.16, CHART_W*0.34, CHART_W*0.50]))
    items.append(sp(0.5))

    for fig, title, subtitle, fn in SEQ_CHARTS:
        items.append(sp(0.3))
        items.append(para(f"{fig}. {title}", "h3"))
        items.append(para(subtitle, "figc"))
        try:
            items.append(DrawingFlowable(fn()))
        except Exception as e:
            items.append(para(f"[Sequence diagram error: {e}]", "body"))
        items.append(sp(0.4))
        items.append(PageBreak())

    return items


# ══════════════════════════════════════════════════════════════════════════════
# ── SYSTEM CONTEXT DIAGRAM ────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

def _draw_ctx_diagram():
    """UML-style System Context Diagram showing T2T + all external entities."""
    W = CHART_W; H = 580
    d = Drawing(W, H)

    FONT  = "Helvetica"; FONTB = "Helvetica-Bold"

    def txt(lbl, cx, cy, bw, color=C_WHITE, bold=False, fsize=7.5):
        fn = FONTB if bold else FONT
        cpl = max(int(bw / (fsize * 0.58)), 5)
        words = lbl.split(); lines = []; cur = ""
        for w in words:
            t = (cur + " " + w).strip()
            if len(t) <= cpl: cur = t
            else:
                if cur: lines.append(cur)
                cur = w
        if cur: lines.append(cur)
        n = len(lines); lh = fsize + 2.5
        by = cy + (n - 1) * lh / 2
        for i, ln in enumerate(lines):
            d.add(String(cx, by - i * lh, ln, fontName=fn, fontSize=fsize,
                         fillColor=color, textAnchor="middle"))

    def entity_box(cx, cy, label, icon, w=118, h=52):
        d.add(Rect(cx - w/2, cy - h/2, w, h, rx=6, ry=6,
                   fillColor=HexColor("#1a3a5c"), strokeColor=HexColor("#aaccee"), strokeWidth=1.2))
        d.add(String(cx, cy + h/2 - 13, icon,
                     fontName=FONT, fontSize=8.5, fillColor=HexColor("#88ccff"),
                     textAnchor="middle"))
        txt(label, cx, cy - 5, w - 10, fsize=7.0)

    def sys_box(cx, cy, w=224, h=175):
        d.add(Rect(cx - w/2, cy - h/2, w, h, rx=10, ry=10,
                   fillColor=HexColor("#0f3460"),
                   strokeColor=HexColor("#4499cc"), strokeWidth=2))
        d.add(Rect(cx - w/2 + 4, cy + h/2 - 38, w - 8, 30, rx=5, ry=5,
                   fillColor=HexColor("#16213e"), strokeColor=None))
        d.add(String(cx, cy + h/2 - 20, "T2T: Trash 2 Treasure",
                     fontName=FONTB, fontSize=9.5, fillColor=C_WHITE,
                     textAnchor="middle"))
        stack = ["Python 3.10+ / Flask 3.0+ / Gunicorn",
                 "Firebase Firestore  (9 collections)",
                 "Firebase Authentication + Storage",
                 "Firebase Cloud Messaging  (FCM)",
                 "Google Cloud Run  (Container Host)"]
        for i, ln in enumerate(stack):
            d.add(String(cx, cy + h/2 - 58 - i * 20, ln,
                         fontName=FONT, fontSize=7, fillColor=HexColor("#99ccee"),
                         textAnchor="middle"))

    def arrow(x1, y1, x2, y2, lbl_fwd="", lbl_ret="",
              color=HexColor("#4488aa")):
        import math
        dx = x2 - x1; dy = y2 - y1
        length = math.sqrt(dx * dx + dy * dy)
        if length == 0: return
        ux = dx / length; uy = dy / length
        px = -uy * 4; py = ux * 4
        sw = 1.1; a = 5

        def head(ax, ay, ddx, ddy):
            ll = math.sqrt(ddx*ddx + ddy*ddy)
            if ll == 0: return
            uux = ddx/ll; uuy = ddy/ll
            ppx = -uuy; ppy = uux
            d.add(Polygon([ax - a*uux + a/2*ppx, ay - a*uuy + a/2*ppy,
                            ax - a*uux - a/2*ppx, ay - a*uuy - a/2*ppy,
                            ax, ay],
                           fillColor=color, strokeColor=color, strokeWidth=0))

        # forward
        d.add(Line(x1 + px, y1 + py, x2 + px - ux*6, y2 + py - uy*6,
                   strokeColor=color, strokeWidth=sw))
        head(x2 + px, y2 + py, dx, dy)
        # return
        d.add(Line(x2 - px, y2 - py, x1 - px + ux*6, y1 - py + uy*6,
                   strokeColor=color, strokeWidth=sw))
        head(x1 - px, y1 - py, -dx, -dy)

        mid_x = (x1 + x2) / 2; mid_y = (y1 + y2) / 2
        off_x = -uy * 13; off_y = ux * 13
        if lbl_fwd:
            d.add(String(mid_x + off_x + px * 1.5, mid_y + off_y + py * 1.5, lbl_fwd,
                         fontName=FONT, fontSize=6.5, fillColor=color,
                         textAnchor="middle"))
        if lbl_ret:
            d.add(String(mid_x - off_x - px * 1.5, mid_y - off_y - py * 1.5, lbl_ret,
                         fontName=FONT, fontSize=6.5, fillColor=color,
                         textAnchor="middle"))

    # ── layout ────────────────────────────────────────────────────────────────
    # System box: centered horizontally, vertically centered in canvas
    cx = W / 2; cy = H / 2 + 10   # slight upward bias

    # System boundary half-sizes
    sw2 = 112; sh2 = 87    # half-width / half-height of sys_box

    # Entity positions — clear of sys_box edges by ≥ 50 pt
    EW = 118; EH = 52
    LEFT_X  = EW / 2 + 10          # ≈ 69
    RIGHT_X = W - EW / 2 - 10      # ≈ 483
    TOP_Y   = H - EH / 2 - 12      # ≈ 542
    BOT_Y   = EH / 2 + 12          # ≈ 38

    ent_positions = {
        "super":    (cx,      TOP_Y),          # top-center
        "firebase": (cx,      BOT_Y),           # bottom-center
        "admin":    (LEFT_X,  cy + 60),         # left-upper
        "student":  (LEFT_X,  cy - 60),         # left-lower
        "arduino":  (RIGHT_X, cy + 60),         # right-upper
        "bridge":   (RIGHT_X, cy - 60),         # right-lower
    }

    sys_box(cx, cy)

    entity_box(*ent_positions["super"],    "Super User\n(Web Panel / System Admin)", "[ SU ]", w=140, h=52)
    entity_box(*ent_positions["firebase"], "Firebase Cloud Platform\n(Firestore / Auth / FCM / Storage)", "[ FB ]", w=180, h=52)
    entity_box(*ent_positions["admin"],    "Admin\nFlutter App",                     "[ A ]",  w=EW, h=EH)
    entity_box(*ent_positions["student"],  "Student\nFlutter App",                   "[ S ]",  w=EW, h=EH)
    entity_box(*ent_positions["arduino"],  "Arduino Vending\nMachine",               "[ HW ]", w=EW, h=EH)
    entity_box(*ent_positions["bridge"],   "bridge.py\n(Python Relay)",              "[ B ]",  w=EW, h=EH)

    # Arrows from entity edge to nearest sys_box edge
    # Super User → top edge of sys_box
    arrow(cx, TOP_Y - EH/2 - 2,  cx, cy + sh2 + 2,
          "HTTPS / Flask Web", "HTML / JSON Responses")
    # Firebase → bottom edge of sys_box
    arrow(cx, BOT_Y + EH/2 + 2,  cx, cy - sh2 - 2,
          "Firebase Admin SDK", "Real-time / Auth")
    # Admin → left edge of sys_box
    arrow(LEFT_X + EW/2 + 2, cy + 60,  cx - sw2 - 2, cy + 30,
          "REST / HTTPS", "JSON + FCM Push")
    # Student → left edge of sys_box
    arrow(LEFT_X + EW/2 + 2, cy - 60,  cx - sw2 - 2, cy - 30,
          "REST / HTTPS", "JSON + FCM Push")
    # Arduino → right edge of sys_box
    arrow(RIGHT_X - EW/2 - 2, cy + 60, cx + sw2 + 2, cy + 30,
          "Serial → Firestore", "Status / Ack")
    # bridge.py → right edge of sys_box
    arrow(RIGHT_X - EW/2 - 2, cy - 60, cx + sw2 + 2, cy - 30,
          "Firestore SDK", "Student / Txn data")

    return d


def build_context_section():
    items = []
    items.append(sp(0.3))
    items.append(para("SYSTEM CONTEXT DIAGRAM", "h1"))
    items.append(hr())
    items.append(para(
        "The System Context Diagram shows the T2T system as a central component and "
        "identifies all external entities that interact with it. Each bidirectional arrow "
        "represents a communication channel with protocol and data-type labels.",
        "body"))
    items.append(sp(0.4))

    leg = [
        ["Entity",                "Description"],
        ["Super User (Web)",      "System administrator — manages admins, departments, and reports via browser"],
        ["Admin Flutter App",     "Department admin — verifies transactions and manages rewards via Flutter"],
        ["Student Flutter App",   "End-user — deposits bottles, redeems rewards, views points via Flutter"],
        ["Arduino Vending Machine","Hardware sensor unit — detects bottles and reads QR codes at 9600-baud serial"],
        ["bridge.py (Relay)",     "Python serial relay — reads machine events and writes directly to Firestore SDK"],
        ["Firebase Cloud Platform","Backend infrastructure — Firestore, Auth, FCM, Storage, Cloud Run"],
    ]
    items.append(make_table(leg, col_widths=[CHART_W*0.30, CHART_W*0.70]))
    items.append(sp(0.5))

    items.append(DrawingFlowable(_draw_ctx_diagram()))
    items.append(sp(0.4))

    # Interface table from markdown
    ifaces = [
        ["Interface",         "Protocol",   "Direction",    "Description"],
        ["Super User ↔ T2T",  "HTTPS / Flask",    "Bidirectional", "Browser CRUD via Jinja2 HTML and JSON API endpoints"],
        ["Admin App ↔ T2T",   "REST / HTTPS",     "Bidirectional", "Flutter calls Flask API; receives FCM push notifications"],
        ["Student App ↔ T2T", "REST / HTTPS",     "Bidirectional", "Flutter calls Flask API; receives transaction status updates"],
        ["Arduino ↔ bridge.py","Serial (UART)",   "Bidirectional", "9600-baud serial over USB; bridge.py acts as the relay"],
        ["bridge.py ↔ Firestore","Firebase SDK",  "Bidirectional", "Python SDK reads student data, writes transactions & machine status"],
        ["T2T ↔ Firebase",    "Firebase Admin SDK","Bidirectional", "All Firestore CRUD, authentication, and storage operations"],
    ]
    items.append(para("System Interfaces", "h3"))
    items.append(make_table(ifaces, col_widths=[
        CHART_W*0.20, CHART_W*0.16, CHART_W*0.14, CHART_W*0.50]))
    items.append(sp(0.3))
    items.append(PageBreak())
    return items


# ══════════════════════════════════════════════════════════════════════════════
# ── SYSTEM USE CASE DIAGRAM ───────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

def _draw_usecase_diagram():
    """
    Clean UML Use Case Diagram.
    Each actor has its own dedicated relay lane outside the system boundary.
    All connections use L-shaped elbow routes (horizontal→vertical→horizontal).
    Arduino is drawn as a vending-machine box symbol.
    """
    W = CHART_W; H = 610
    d = Drawing(W, H)
    FONT = "Helvetica"; FONTB = "Helvetica-Bold"

    # ── grid constants ─────────────────────────────────────────────────────
    BPAD  = 82           # horizontal actor margin; boundary starts at BPAD
    BX    = BPAD
    BW    = W - 2 * BPAD           # ≈ 388 pt
    BY    = 18
    ITH   = 17           # item row height
    TITH  = 20           # title bar height
    PAD   = 6            # bottom padding
    RGAP  = 10           # gap between group rows
    GW    = (BW - 14) // 2         # ≈ 187 pt per column
    C1    = BX + 6                 # left-column left x
    C2    = C1 + GW + 8            # right-column left x
    GH    = TITH + 4 * ITH + PAD   # standard group height = 94 pt

    def row_y(i):          # bottom-y of row i (0 = bottom-most)
        return BY + i * (GH + RGAP)

    # ── actor relay lane x-positions (outside boundary) ────────────────────
    # Two separate lanes per side so Student/Admin lines never overlap.
    LANE_STU = BX - 8    # Student's vertical lane
    LANE_ADM = BX - 18   # Admin's vertical lane
    LANE_HW  = BX + BW + 8   # Arduino's vertical lane
    LANE_SU  = BX + BW + 18  # Super User's vertical lane

    # ── actor center x-positions ────────────────────────────────────────────
    AX_L = BX - 44       # left actors center x  ≈ 38
    AX_R = BX + BW + 44  # right actors center x ≈ W-38

    # ── colors ─────────────────────────────────────────────────────────────
    C_STU = HexColor("#1a4a7a")   # Student – blue
    C_ADM = HexColor("#0d5c42")   # Admin   – teal
    C_HW  = HexColor("#1a6a1a")   # Arduino – green
    C_SU  = HexColor("#6a1a1a")   # Super User – red

    KEY_COLORS = {
        "auth": C_STU, "bottle": C_STU,
        "txn":  C_ADM, "reward": C_ADM, "student": C_ADM, "machine": C_HW,
        "dept": C_SU,  "reports": C_SU, "admgmt":  C_SU,  "notif":   C_SU,
    }
    GRP_BG = HexColor("#eef2f7")

    # ── use-case group ──────────────────────────────────────────────────────
    def uc_group(gx, gy, title, items_list, key):
        tc = KEY_COLORS[key]
        # background box
        d.add(Rect(gx, gy, GW, GH, rx=5, ry=5,
                   fillColor=GRP_BG, strokeColor=tc, strokeWidth=1.1))
        # title bar (rounded rect + square patch at bottom to avoid double-curve)
        d.add(Rect(gx, gy + GH - TITH, GW, TITH, rx=5, ry=5,
                   fillColor=tc, strokeColor=None))
        d.add(Rect(gx, gy + GH - TITH, GW, TITH // 2,
                   fillColor=tc, strokeColor=None))
        d.add(String(gx + GW / 2, gy + GH - TITH + 6, title,
                     fontName=FONTB, fontSize=7.5,
                     fillColor=C_WHITE, textAnchor="middle"))
        # use-case items
        for i, uc in enumerate(items_list):
            uy = gy + GH - TITH - (i + 1) * ITH + (ITH - 9) // 2
            d.add(Ellipse(gx + 4, uy, 16, 9,
                          fillColor=C_WHITE, strokeColor=tc, strokeWidth=0.8))
            d.add(String(gx + 24, uy + 2, uc,
                         fontName=FONT, fontSize=6.8,
                         fillColor=HexColor("#1a1a2e")))
        return gy + GH / 2   # center_y

    # ── draw groups (bottom → top rows) ────────────────────────────────────
    g = {}
    g["auth"]    = uc_group(C1, row_y(0), "Authentication & Access",
        ["Login / Logout", "Register  (Super User)",
         "Remember Me  (30 days)", "Session Token Validation"], "auth")
    g["bottle"]  = uc_group(C2, row_y(0), "Bottle Deposit",
        ["Scan QR Code  (Flutter)", "Insert Bottle in Machine",
         "PET Material Validation", "View Points & History"], "bottle")

    g["txn"]     = uc_group(C1, row_y(1), "Transaction Processing",
        ["Verify Deposit Txn", "Verify Redeem Txn",
         "Reject Transaction", "View Transaction History"], "txn")
    g["reward"]  = uc_group(C2, row_y(1), "Reward Management",
        ["Add / Edit Reward", "Delete / Toggle Status",
         "Redeem Reward  (Flutter)", "Set Reward Stock & Cost"], "reward")

    g["student"] = uc_group(C1, row_y(2), "Student Management",
        ["Register Account  (Flutter)", "View Student List",
         "Activate / Suspend / Ban", "View Profile & History"], "student")
    g["machine"] = uc_group(C2, row_y(2), "Machine Monitoring",
        ["View Machine Status Board", "View Fill Percentage",
         "Update Machine Status", "Log Maintenance Activity"], "machine")

    g["dept"]    = uc_group(C1, row_y(3), "Department Management",
        ["Add / Edit Department", "Delete / Toggle Status",
         "View Department Details", "Assign Students to Dept"], "dept")
    g["reports"] = uc_group(C2, row_y(3), "Reports & Analytics",
        ["View Dashboard Statistics", "Generate Student Reports",
         "Generate Dept Reports", "Export as Excel  (.xlsx)"], "reports")

    g["admgmt"]  = uc_group(C1, row_y(4), "Admin User Mgmt  (SU)",
        ["Create Admin Account", "Edit Admin Profile",
         "Deactivate Admin Account", "View Admin Activity"], "admgmt")
    g["notif"]   = uc_group(C2, row_y(4), "Notifications",
        ["View In-Panel Notifications", "Mark Notifications as Read",
         "Receive Push  (FCM)", "System Broadcast"], "notif")

    # ── system boundary (on top of groups so it frames them visibly) ────────
    BH = row_y(4) + GH + 14 - BY
    d.add(Rect(BX, BY, BW, BH, rx=8, ry=8,
               fillColor=None,
               strokeColor=HexColor("#0f3460"), strokeWidth=2.2))
    d.add(String(BX + BW / 2, BY + BH - 10, "T2T System Boundary",
                 fontName=FONTB, fontSize=9.5,
                 fillColor=HexColor("#0f3460"), textAnchor="middle"))

    # ── stick-figure actor ──────────────────────────────────────────────────
    def stick_actor(cx, cy, label, color):
        r = 8; body = 14; arm = 12; leg = 13
        d.add(Ellipse(cx - r, cy + r, 2*r, 2*r,
                      fillColor=color, strokeColor=color, strokeWidth=0))
        d.add(Line(cx, cy + r, cx, cy - body,
                   strokeColor=color, strokeWidth=1.8))
        d.add(Line(cx - arm, cy + 2, cx + arm, cy + 2,
                   strokeColor=color, strokeWidth=1.8))
        d.add(Line(cx, cy - body, cx - leg*0.75, cy - body - leg,
                   strokeColor=color, strokeWidth=1.8))
        d.add(Line(cx, cy - body, cx + leg*0.75, cy - body - leg,
                   strokeColor=color, strokeWidth=1.8))
        foot_y = cy - body - leg
        for i, ln in enumerate(label.split("\n")):
            d.add(String(cx, foot_y - 11 - i * 9, ln,
                         fontName=FONTB, fontSize=7.2,
                         fillColor=color, textAnchor="middle"))
        return cy   # waist y

    # ── vending-machine actor (Arduino) ─────────────────────────────────────
    def machine_actor(cx, cy, label, color):
        """Draws a simple vending-machine silhouette centered at (cx, cy)."""
        bw = 36; bh = 52
        dark  = HexColor("#0a3d15")
        light = HexColor("#ccffcc")
        top   = cy + bh / 2; bot = cy - bh / 2

        # outer cabinet
        d.add(Rect(cx - bw/2, bot, bw, bh, rx=3, ry=3,
                   fillColor=color, strokeColor=dark, strokeWidth=1.8))
        # top panel (logo strip)
        panel_h = 9
        d.add(Rect(cx - bw/2 + 2, top - panel_h - 1, bw - 4, panel_h, rx=2, ry=2,
                   fillColor=dark, strokeColor=None))
        d.add(String(cx, top - panel_h + 2, "T2T",
                     fontName=FONTB, fontSize=5.5,
                     fillColor=light, textAnchor="middle"))
        # display screen
        sw = bw - 10; sh = 14
        d.add(Rect(cx - sw/2, cy + 4, sw, sh, rx=2, ry=2,
                   fillColor=C_WHITE, strokeColor=dark, strokeWidth=0.8))
        # horizontal slot (bottle insertion)
        d.add(Rect(cx - sw/2 + 2, cy - 4, sw - 4, 5,
                   fillColor=dark, strokeColor=None))
        # three colored control buttons
        btn_y = bot + 10
        for bi, bcol in enumerate([HexColor("#e74c3c"),
                                    HexColor("#2ecc71"),
                                    HexColor("#3498db")]):
            bx_b = cx - 10 + bi * 10
            d.add(Ellipse(bx_b - 4, btn_y, 8, 7,
                          fillColor=bcol, strokeColor=dark, strokeWidth=0.5))
        # label below cabinet
        for i, ln in enumerate(label.split("\n")):
            d.add(String(cx, bot - 11 - i * 9, ln,
                         fontName=FONTB, fontSize=7.2,
                         fillColor=color, textAnchor="middle"))
        return cy   # waist y for connections

    # ── actor vertical centers ──────────────────────────────────────────────
    def mid(a, b):
        return (row_y(a) + row_y(b) + GH) / 2

    CY_STU = mid(0, 1)       # between rows 0-1
    CY_ADM = mid(1, 3)       # between rows 1-3
    CY_HW  = mid(0, 2)       # between rows 0-2
    CY_SU  = mid(2, 4)       # between rows 2-4

    w_stu = stick_actor(AX_L, CY_STU, "Student\n(Flutter)",       C_STU)
    w_adm = stick_actor(AX_L, CY_ADM, "Admin\n(Flutter + Web)",   C_ADM)
    w_hw  = machine_actor(AX_R, CY_HW, "Arduino\nMachine",         C_HW)
    w_su  = stick_actor(AX_R, CY_SU,  "Super User\n(Web Panel)",  C_SU)

    # ── elbow connection helper ─────────────────────────────────────────────
    # Route: actor → (horizontal to lane) → (vertical to group_cy)
    #        → (horizontal to group edge). Dots mark branch points on lane.
    def dot(x, y, color):
        d.add(Ellipse(x - 3, y - 3, 6, 6,
                      fillColor=color, strokeColor=color, strokeWidth=0))

    def elbow_l(lane_x, actor_cy, group_edge_x, group_cy, color):
        sw = 0.9
        # 1. actor → lane  (horizontal)
        d.add(Line(AX_L + 18, actor_cy, lane_x, actor_cy,
                   strokeColor=color, strokeWidth=sw))
        # 2. lane vertical to group height
        d.add(Line(lane_x, actor_cy, lane_x, group_cy,
                   strokeColor=color, strokeWidth=sw))
        # 3. lane → group left edge  (horizontal)
        d.add(Line(lane_x, group_cy, group_edge_x, group_cy,
                   strokeColor=color, strokeWidth=sw))
        dot(lane_x, group_cy, color)

    def elbow_r(lane_x, actor_cy, group_edge_x, group_cy, color):
        sw = 0.9
        # 1. actor → lane  (horizontal)
        d.add(Line(AX_R - 18, actor_cy, lane_x, actor_cy,
                   strokeColor=color, strokeWidth=sw))
        # 2. lane vertical to group height
        d.add(Line(lane_x, actor_cy, lane_x, group_cy,
                   strokeColor=color, strokeWidth=sw))
        # 3. lane → group right edge  (horizontal)
        d.add(Line(lane_x, group_cy, group_edge_x, group_cy,
                   strokeColor=color, strokeWidth=sw))
        dot(lane_x, group_cy, color)

    # ── Student connections (left, blue) ────────────────────────────────────
    # Auth (left col) → arrive at C1 (left edge of left column)
    elbow_l(LANE_STU, w_stu, C1,     g["auth"],    C_STU)
    # Bottle Deposit (right col) → arrive at C2 (left edge of right column)
    elbow_l(LANE_STU, w_stu, C2,     g["bottle"],  C_STU)
    # Reward Mgmt (right col)
    elbow_l(LANE_STU, w_stu, C2,     g["reward"],  C_STU)
    # anchor dot at actor level on Student lane
    dot(LANE_STU, w_stu, C_STU)

    # ── Admin connections (left, teal) ──────────────────────────────────────
    elbow_l(LANE_ADM, w_adm, C1,     g["txn"],     C_ADM)
    elbow_l(LANE_ADM, w_adm, C1,     g["student"], C_ADM)
    elbow_l(LANE_ADM, w_adm, C2,     g["reward"],  C_ADM)
    elbow_l(LANE_ADM, w_adm, C2,     g["machine"], C_ADM)
    dot(LANE_ADM, w_adm, C_ADM)

    # ── Arduino connections (right, green) ──────────────────────────────────
    # Bottle Deposit & Machine Monitoring are both right-column groups
    elbow_r(LANE_HW,  w_hw,  C2 + GW, g["bottle"],  C_HW)
    elbow_r(LANE_HW,  w_hw,  C2 + GW, g["machine"], C_HW)
    dot(LANE_HW, w_hw, C_HW)

    # ── Super User connections (right, red) ─────────────────────────────────
    # Notifications & Reports are right-column → arrive at right edge C2+GW
    elbow_r(LANE_SU,  w_su,  C2 + GW, g["notif"],   C_SU)
    elbow_r(LANE_SU,  w_su,  C2 + GW, g["reports"], C_SU)
    # Admin User Mgmt & Dept Mgmt are left-column → arrive at right edge C1+GW
    elbow_r(LANE_SU,  w_su,  C1 + GW, g["admgmt"],  C_SU)
    elbow_r(LANE_SU,  w_su,  C1 + GW, g["dept"],    C_SU)
    dot(LANE_SU, w_su, C_SU)

    # ── color legend (inside boundary, bottom-left) ─────────────────────────
    lx = BX + 6; ly = BY + 5
    d.add(String(lx, ly + 1, "Actor key:",
                 fontName=FONTB, fontSize=6.5,
                 fillColor=HexColor("#333333")))
    lx += 54
    for clr, name in [(C_STU, "Student"), (C_ADM, "Admin"),
                      (C_HW, "Arduino Machine"), (C_SU, "Super User")]:
        d.add(Rect(lx, ly, 9, 9, fillColor=clr, strokeColor=None))
        d.add(String(lx + 12, ly + 1, name,
                     fontName=FONT, fontSize=6.5,
                     fillColor=HexColor("#333333")))
        lx += 74

    return d


def build_usecase_section():
    items = []
    items.append(sp(0.3))
    items.append(para("SYSTEM USE CASE DIAGRAM", "h1"))
    items.append(hr())
    items.append(para(
        "The Use Case Diagram identifies the four primary actors and their interactions "
        "with the T2T system. Each group of use cases represents a functional area; "
        "association lines connect actors to the use cases they can initiate.",
        "body"))
    items.append(sp(0.4))

    actors = [
        ["Actor",               "Role",         "Scope"],
        ["Student",             "End-user (Flutter App)",
         "Own account — deposit bottles, redeem rewards, view points & history"],
        ["Admin (Department)",  "Day-to-day operator (Flutter + Web)",
         "Assigned department — verify txns, manage rewards, monitor machines"],
        ["Super User",          "System administrator (Web Panel)",
         "Full access — all Admin capabilities + admin accounts, all departments, system-wide analytics"],
        ["Arduino Machine",     "Hardware sensor unit (bridge.py relay)",
         "Write-only — submit bottle deposits to Firestore transactions and machines collections"],
    ]
    items.append(make_table(actors, col_widths=[
        CHART_W*0.18, CHART_W*0.22, CHART_W*0.60]))
    items.append(sp(0.5))

    items.append(DrawingFlowable(_draw_usecase_diagram()))
    items.append(sp(0.3))
    items.append(PageBreak())
    return items
def _parse_md_table(lines):
    rows = []
    for line in lines:
        if re.match(r'^\s*\|?[-:| ]+\|?\s*$', line):
            continue
        cells = [c.strip() for c in re.split(r'(?<!\|)\|(?!\|)', line)]
        cells = [c for c in cells if c != ""]
        if cells: rows.append(cells)
    return rows


def _md_slice(md_text, start_marker, end_marker=None):
    """Extract the markdown section from start_marker up to end_marker (exclusive)."""
    m1 = re.search(re.escape(start_marker), md_text)
    if not m1:
        return ""
    start = m1.start()
    if end_marker:
        m2 = re.search(re.escape(end_marker), md_text[start:])
        if m2:
            return md_text[start: start + m2.start()]
    return md_text[start:]


def _md_flowables(md_text):
    """Convert a markdown string to ReportLab flowables (no section skipping)."""
    flowables = []; lines = md_text.split("\n"); i = 0
    while i < len(lines):
        line = lines[i]
        if re.match(r'^-{3,}$', line.strip()):
            flowables.append(hr()); i += 1; continue

        hm = re.match(r'^(#{1,4})\s+(.*)', line)
        if hm:
            lv = len(hm.group(1)); txt = hm.group(2).strip()
            if lv == 1:
                flowables += [sp(0.3), para(txt, "h1"), hr()]
            elif lv == 2:
                flowables += [sp(0.2), para(txt, "h2"),
                              HRFlowable(width="100%", thickness=0.5,
                                         color=C_ACCENT, spaceAfter=4)]
            elif lv == 3:
                flowables.append(para(txt, "h3"))
            else:
                flowables.append(para(txt, "h4"))
            i += 1; continue

        if line.strip().startswith("```"):
            code_lines = []; i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i]); i += 1
            i += 1
            flowables.append(Preformatted("\n".join(code_lines), STYLES["code"],
                                          maxLineLength=95))
            flowables.append(sp(0.1)); continue

        if "|" in line and i+1 < len(lines) and re.match(r'^\s*\|?[-:| ]+\|?\s*$', lines[i+1]):
            tl = []
            while i < len(lines) and "|" in lines[i]:
                tl.append(lines[i]); i += 1
            rows = _parse_md_table(tl)
            if rows:
                flowables.append(make_table(rows)); flowables.append(sp(0.15))
            continue

        if re.match(r'^(\s*[-*+])\s+', line):
            flowables.append(para("• " + re.sub(r'^\s*[-*+]\s+','',line), "bullet"))
            i += 1; continue

        if re.match(r'^\s*\d+\.\s+', line):
            flowables.append(para(re.sub(r'^\s*\d+\.\s+','',line), "bullet"))
            i += 1; continue

        if not line.strip():
            flowables.append(sp(0.1)); i += 1; continue

        # ASCII art block — skip (replaced by drawn diagrams)
        ascii_c = set("│─┐┘└┌├┤┬┴┼╔╗╚╝║═▲▼►◄○●")
        if any(c in ascii_c for c in line):
            while i < len(lines) and (any(c in ascii_c for c in lines[i]) or
                                       lines[i].startswith("  ")):
                i += 1
            continue

        tl2 = []
        while i < len(lines) and lines[i].strip() and not re.match(r'^#{1,4}\s', lines[i]):
            tl2.append(lines[i]); i += 1
        combined = " ".join(tl2).strip()
        if combined: flowables.append(para(combined, "body"))

    return flowables


def md_to_flowables(md_text):
    """
    Splits markdown into sections; drawn sections are skipped here.
    Drawn by dedicated builders:
      Figs 1-7  : build_flowchart_section()
      Figs 8-12 : build_dfd_section()
      Context   : build_context_section()
      Use Case  : build_usecase_section()
      Figs 13-17: build_sequence_section()
    Only TESTING AND EVALUATION onwards is rendered from markdown.
    """
    # Only render the Testing / Data Dict / Source Code sections from markdown
    tail = _md_slice(md_text, "## TESTING AND EVALUATION")
    return _md_flowables(tail)


# ══════════════════════════════════════════════════════════════════════════════
# ── COVER ─────────────────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

def build_cover():
    cover = []
    banner = Table([[Paragraph("Appendix A",
                               _ms("bt", base["Normal"], fontSize=36,
                                   fontName="Helvetica-Bold", textColor=C_WHITE,
                                   alignment=TA_CENTER))]],
                   colWidths=[PAGE_W - 2*MARGIN])
    banner.setStyle(TableStyle([
        ("BACKGROUND",(0,0),(-1,-1),C_DARK),
        ("TOPPADDING",(0,0),(-1,-1),30),
        ("BOTTOMPADDING",(0,0),(-1,-1),30)]))
    cover += [sp(2), banner, sp(0.8)]

    for line in ["PROCESS FLOWCHARTS, DATA FLOW DIAGRAMS,",
                 "SYSTEM CONTEXT, USE CASE, SEQUENTIAL DIAGRAMS,",
                 "TEST CASES, DATA DICTIONARY, AND SOURCE CODE"]:
        cover.append(para(line, "cap"))

    cover += [sp(1), hr(), sp(0.5)]

    tb = Table([[Paragraph("Trash 2 Treasure (T2T)",
                           _ms("st", base["Normal"], fontSize=16,
                               fontName="Helvetica-Bold", textColor=C_WHITE,
                               alignment=TA_CENTER))]],
               colWidths=[PAGE_W - 2*MARGIN])
    tb.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,-1),C_ACCENT),
                            ("TOPPADDING",(0,0),(-1,-1),14),
                            ("BOTTOMPADDING",(0,0),(-1,-1),14)]))
    cover.append(tb); cover.append(sp(0.4))
    for line in ["A Web-Based Bottle Recycling and Student Rewards Management System",
                 "Using Python/Flask · Firebase Firestore · Flutter · Arduino"]:
        cover.append(para(line, "cap"))

    cover.append(sp(2))
    stack = [
        ["Component","Technology","Purpose"],
        ["Backend","Python 3.10+ / Flask 3.0+","REST API & Web Panel"],
        ["Database","Firebase Firestore","NoSQL Real-time DB"],
        ["Auth","Firebase Authentication","UID & Token Management"],
        ["Mobile","Flutter (Dart)","Admin & Student Apps"],
        ["Hardware","Arduino + bridge.py","Vending Machine Interface"],
        ["Hosting","Google Cloud Run / Gunicorn","Production Deployment"],
    ]
    cw = (PAGE_W - 2*MARGIN) / 3
    cover.append(make_table(stack, col_widths=[cw,cw,cw]))
    cover += [sp(2), PageBreak()]
    return cover


# ══════════════════════════════════════════════════════════════════════════════
# ── PAGE TEMPLATE ─────────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

def on_page(canvas, doc):
    if doc.page == 1: return
    canvas.saveState()
    w, h = A4
    canvas.setFillColor(C_DARK)
    canvas.rect(0, h-1.2*cm, w, 1.2*cm, fill=1, stroke=0)
    canvas.setFillColor(C_WHITE)
    canvas.setFont("Helvetica-Bold", 8)
    canvas.drawString(MARGIN, h-0.75*cm, "Appendix A  —  T2T: Trash 2 Treasure")
    canvas.setFont("Helvetica", 8)
    canvas.drawRightString(w-MARGIN, h-0.75*cm, "System Documentation")
    canvas.setFillColor(C_GRAY)
    canvas.rect(0, 0, w, 1*cm, fill=1, stroke=0)
    canvas.setFillColor(C_DARK)
    canvas.setFont("Helvetica", 8)
    canvas.drawCentredString(w/2, 0.35*cm, f"Page {doc.page}")
    canvas.drawString(MARGIN, 0.35*cm,
                      "Web-Based Bottle Recycling & Rewards Management System")
    canvas.restoreState()


# ══════════════════════════════════════════════════════════════════════════════
# ── MAIN ──────────────────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

def main():
    bd = os.path.dirname(os.path.abspath(__file__))
    md_path  = os.path.join(bd, "APPENDIX_A_DETAILED.md")
    pdf_path = os.path.join(bd, "APPENDIX_A_DETAILED.pdf")

    print(f"[INFO] Reading  {md_path}")
    with open(md_path, encoding="utf-8") as f:
        md_text = f.read()

    print("[INFO] Building graphical flowcharts (Figs 1-7) …")
    fc_sect = build_flowchart_section()

    print("[INFO] Building DFD diagrams (Figs 8-12) …")
    dfd_sect = build_dfd_section()

    print("[INFO] Building System Context diagram …")
    ctx_sect = build_context_section()

    print("[INFO] Building System Use Case diagram …")
    uc_sect = build_usecase_section()

    print("[INFO] Building sequence diagrams (Figs 13-17) …")
    seq_sect = build_sequence_section()

    print("[INFO] Parsing markdown (test cases, data dict, source code) …")
    rest = md_to_flowables(md_text)

    flowables = build_cover() + fc_sect + dfd_sect + ctx_sect + uc_sect + seq_sect + rest

    print(f"[INFO] Writing  {pdf_path}")
    doc = SimpleDocTemplate(
        pdf_path, pagesize=A4,
        leftMargin=MARGIN, rightMargin=MARGIN,
        topMargin=1.5*cm, bottomMargin=1.4*cm,
        title="Appendix A — T2T System Documentation",
        author="T2T Capstone Team",
        subject="Trash 2 Treasure System Appendix")
    doc.build(flowables, onFirstPage=on_page, onLaterPages=on_page)
    print(f"[OK]  PDF saved → {pdf_path}")


if __name__ == "__main__":
    main()
