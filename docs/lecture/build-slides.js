const pptxgen = require("pptxgenjs");
const path = require("path");

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";
pres.author = "Mason (전용원)";
pres.title = "OpenClaw — ClawNode";

// ── ClawNode Brand ──
const C = {
  bg:      "050505",
  accent:  "FF6B00",
  accent2: "FFB680",
  white:   "FFFFFF",
  offwhite:"E8E8E8",
  gray:    "999999",
  dimgray: "666666",
  card:    "111111",
  cardLine:"2A2A2A",
  accentCard: "1A0800",
  accentLine: "3D1A00",
};

const FONT = "Pretendard";
const BG = path.resolve(__dirname, "mockups/slide-bg-clawnode.png");
const LOGO = path.resolve(__dirname, "../../website-v2/public/images/clawnode-logo-transparent.png");

function makeSlide() {
  const s = pres.addSlide();
  s.addImage({ path: BG, x: 0, y: 0, w: 10, h: 5.625 });
  s.addImage({
    path: LOGO, x: 7.8, y: 5.0, h: 0.4,
    sizing: { type: "contain", h: 0.4, w: 2.0 },
  });
  return s;
}

// Helper: rounded card
function addCard(s, x, y, w, h, opts = {}) {
  const fill = opts.accent
    ? { color: C.accentCard }
    : { color: C.card };
  const line = opts.accent
    ? { color: C.accentLine, width: 0.5 }
    : { color: C.cardLine, width: 0.5 };
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, fill, line, rectRadius: 0.1,
  });
}

// Helper: number badge
function addBadge(s, x, y, text, color) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w: 0.5, h: 0.35,
    fill: { color }, rectRadius: 0.06,
  });
  s.addText(text, {
    x, y, w: 0.5, h: 0.35,
    fontSize: 11, fontFace: FONT, color: C.white, bold: true,
    align: "center", valign: "middle", margin: 0,
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 1: LLM vs OpenClaw
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();

  // Section label
  s.addText("LLM vs OpenClaw", {
    x: 0.5, y: 0.25, w: 9, h: 0.35,
    fontSize: 11, fontFace: FONT, color: C.accent, bold: true,
    charSpacing: 3,
  });

  // Left column — LLM
  addCard(s, 0.5, 0.8, 4.0, 4.0);
  s.addText("LLM", {
    x: 0.5, y: 1.0, w: 4.0, h: 0.5,
    fontSize: 28, fontFace: FONT, color: C.white, bold: true, align: "center", margin: 0,
  });
  s.addText("AI의 두뇌", {
    x: 0.5, y: 1.5, w: 4.0, h: 0.3,
    fontSize: 12, fontFace: FONT, color: C.gray, align: "center",
  });
  s.addText("ChatGPT  /  Claude  /  Gemini", {
    x: 0.5, y: 1.9, w: 4.0, h: 0.25,
    fontSize: 10, fontFace: FONT, color: C.dimgray, align: "center",
  });
  s.addText([
    { text: "질문하면 답한다", options: { breakLine: true } },
    { text: "글을 쓴다", options: { breakLine: true } },
    { text: "코드를 짠다", options: { breakLine: true } },
  ], {
    x: 1.2, y: 2.4, w: 2.6, h: 1.2,
    fontSize: 14, fontFace: FONT, color: C.offwhite, lineSpacing: 26,
  });
  s.addText("하지만 직접 뭔가를 하진 못한다", {
    x: 1.0, y: 3.7, w: 3.0, h: 0.3,
    fontSize: 12, fontFace: FONT, color: C.dimgray, italic: true,
  });

  // Right column — OpenClaw
  addCard(s, 5.5, 0.8, 4.0, 4.0, { accent: true });
  s.addText("OpenClaw", {
    x: 5.5, y: 1.0, w: 4.0, h: 0.5,
    fontSize: 28, fontFace: FONT, color: C.accent, bold: true, align: "center", margin: 0,
  });
  s.addText("두뇌에 몸을 붙이다", {
    x: 5.5, y: 1.5, w: 4.0, h: 0.3,
    fontSize: 12, fontFace: FONT, color: C.accent2, align: "center",
  });
  const abilities = [
    "파일을 읽고 쓰는 손",
    "인터넷을 검색하는 눈",
    "메시지를 보내는 입",
    "어제 대화를 기억하는 기억력",
  ];
  s.addText(
    abilities.map((t, i) => ({
      text: t,
      options: { breakLine: i < abilities.length - 1 },
    })),
    {
      x: 6.2, y: 2.1, w: 2.8, h: 2.2,
      fontSize: 14, fontFace: FONT, color: C.white, lineSpacing: 30,
    }
  );

  // VS badge
  s.addShape(pres.shapes.OVAL, {
    x: 4.4, y: 2.3, w: 1.2, h: 1.2,
    fill: { color: C.bg },
    line: { color: C.accent, width: 2 },
  });
  s.addText("vs", {
    x: 4.4, y: 2.3, w: 1.2, h: 1.2,
    fontSize: 18, fontFace: FONT, color: C.accent, bold: true,
    align: "center", valign: "middle", margin: 0,
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 2: 매우 유능한 신입 부사수
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();

  // Big quote
  s.addText([
    { text: "\u201C", options: { fontSize: 60, fontFace: "Georgia", color: C.accent } },
  ], { x: 0.4, y: 0.1, w: 0.6, h: 0.8, margin: 0 });

  s.addText([
    { text: "매우 유능하고 똑똑한", options: { breakLine: true } },
    { text: "신입 부사수", options: {} },
  ], {
    x: 1.0, y: 0.3, w: 8, h: 1.0,
    fontSize: 32, fontFace: FONT, color: C.white, bold: true, lineSpacing: 44,
  });

  // Three columns
  const cols = [
    { title: "능력", sub: "뛰어남", desc: "시키는 건\n거의 다 한다", color: "2ECC71" },
    { title: "경험", sub: "신입", desc: "우리 회사\n맥락을 모른다", color: "E67E22" },
    { title: "핵심", sub: "교육", desc: "가르쳐줘야\n한다", color: C.accent },
  ];
  cols.forEach((c, i) => {
    const x = 0.6 + i * 3.15;
    addCard(s, x, 1.8, 2.85, 3.0);

    s.addText(c.title, {
      x, y: 2.0, w: 2.85, h: 0.5,
      fontSize: 22, fontFace: FONT, color: c.color, bold: true, align: "center",
    });
    s.addText(c.sub, {
      x, y: 2.5, w: 2.85, h: 0.35,
      fontSize: 14, fontFace: FONT, color: C.gray, align: "center",
    });
    // Divider line
    s.addShape(pres.shapes.LINE, {
      x: x + 0.8, y: 3.0, w: 1.25, h: 0,
      line: { color: C.cardLine, width: 0.5 },
    });
    s.addText(c.desc, {
      x: x + 0.3, y: 3.2, w: 2.25, h: 1.2,
      fontSize: 14, fontFace: FONT, color: C.offwhite, align: "center", lineSpacing: 24,
    });
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 3: 핵심 특장점
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();

  s.addText("핵심 특장점", {
    x: 0.5, y: 0.25, w: 9, h: 0.5,
    fontSize: 28, fontFace: FONT, color: C.white, bold: true,
  });

  const feats = [
    { n: "01", t: "장기기억", d: "몇 개월 전 대화도 기억.\n기억은 학습이 되고, 행동을 만든다.", c: C.accent },
    { n: "02", t: "행동력", d: "메일 발송, 시트 작성, 웹 검색,\n디자인, 코딩, 리서치까지.", c: "00B894" },
    { n: "03", t: "접근성", d: "텔레그램, 디스코드, 슬랙.\n자연어로 대화하면 된다.", c: "0984E3" },
    { n: "04", t: "커스터마이징", d: "시간이 갈수록 나에게 맞춰\n성격, 말투, 행동이 변한다.", c: "D63031" },
  ];
  feats.forEach((f, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = 0.5 + col * 4.7;
    const y = 1.0 + row * 2.15;

    addCard(s, x, y, 4.4, 1.85);
    addBadge(s, x + 0.2, y + 0.2, f.n, f.c);

    s.addText(f.t, {
      x: x + 0.85, y: y + 0.15, w: 3.2, h: 0.4,
      fontSize: 18, fontFace: FONT, color: C.white, bold: true, valign: "middle",
    });
    s.addText(f.d, {
      x: x + 0.3, y: y + 0.65, w: 3.8, h: 1.0,
      fontSize: 13, fontFace: FONT, color: C.gray, lineSpacing: 22,
    });
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 4: 마케팅 매니저
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();
  s.addText("사례 1", {
    x: 0.5, y: 0.2, w: 2, h: 0.35,
    fontSize: 11, fontFace: FONT, color: C.accent, bold: true, charSpacing: 2,
  });
  s.addText("마케팅 매니저", {
    x: 0.5, y: 0.5, w: 9, h: 0.5,
    fontSize: 24, fontFace: FONT, color: C.white, bold: true,
  });
  s.addText("\u201C이번주 마케팅 내용 분석해줘\u201D", {
    x: 0.5, y: 1.0, w: 9, h: 0.3,
    fontSize: 13, fontFace: FONT, color: C.accent2, italic: true,
  });
  s.addImage({
    path: path.resolve(__dirname, "mockups/marketing-iphone.png"),
    x: 3.9, y: 1.3, w: 2.2, h: 3.5,
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 5: SRT 매크로
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();
  s.addText("사례 2", {
    x: 0.5, y: 0.2, w: 2, h: 0.35,
    fontSize: 11, fontFace: FONT, color: C.accent, bold: true, charSpacing: 2,
  });
  s.addText("SRT 매크로", {
    x: 0.5, y: 0.5, w: 9, h: 0.5,
    fontSize: 24, fontFace: FONT, color: C.white, bold: true,
  });
  s.addText("\u201C기차가 없어\u201D  \u2192  18분 만에 매크로 제작  \u2192  예약 완료", {
    x: 0.5, y: 1.0, w: 9, h: 0.3,
    fontSize: 12, fontFace: FONT, color: C.accent2, italic: true,
  });
  s.addImage({
    path: path.resolve(__dirname, "mockups/srt-iphone-1.png"),
    x: 1.5, y: 1.3, w: 2.2, h: 3.5,
  });
  s.addImage({
    path: path.resolve(__dirname, "mockups/srt-iphone-2.png"),
    x: 6.3, y: 1.3, w: 2.2, h: 3.5,
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 6: 꼼지락
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();
  s.addText("사례 3", {
    x: 0.5, y: 0.2, w: 2, h: 0.35,
    fontSize: 11, fontFace: FONT, color: C.accent, bold: true, charSpacing: 2,
  });
  s.addText("아기옷 중고거래 앱", {
    x: 0.5, y: 0.5, w: 9, h: 0.5,
    fontSize: 24, fontFace: FONT, color: C.white, bold: true,
  });
  ["ggomjirak 1.png", "ggomjirak 2.png", "ggomjirak 3.png"].forEach((img, i) => {
    s.addImage({
      path: path.resolve(__dirname, img),
      x: 0.5 + i * 3.15, y: 1.1, h: 4.2,
      sizing: { type: "contain", h: 4.2, w: 2.85 },
    });
  });
}

// ══════════════════════════════════════════════════════════════════════
// SLIDE 7: Q&A
// ══════════════════════════════════════════════════════════════════════
{
  const s = makeSlide();
  s.addText("Q & A", {
    x: 0.5, y: 1.6, w: 9, h: 1.2,
    fontSize: 52, fontFace: FONT, color: C.white, bold: true,
    align: "center", valign: "middle",
  });
  s.addText("궁금한 점 있으시면 질문 주세요", {
    x: 0.5, y: 3.0, w: 9, h: 0.5,
    fontSize: 15, fontFace: FONT, color: C.dimgray, align: "center",
  });
}

// ── Build + verify ──
const out = path.resolve(__dirname, "OpenClaw-Presentation-v4.pptx");
pres.writeFile({ fileName: out }).then(() => {
  console.log("Created:", out);
}).catch(e => console.error("Error:", e));
