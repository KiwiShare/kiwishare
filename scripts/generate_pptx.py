import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def build_presentation():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Executive Color Palette (High-contrast, professional Slate Navy & Emerald)
    BG_COLOR = RGBColor(13, 23, 38)        # #0D1726 - Executive Slate Navy
    CARD_BG = RGBColor(20, 36, 58)         # #14243A - Card Background
    CARD_BORDER = RGBColor(38, 68, 102)    # #264466 - Subtle card border
    CARD_BORDER_HI = RGBColor(16, 185, 129)# #10B981 - Highlight emerald border
    FRAME_BG = RGBColor(16, 30, 48)        # Frame background behind images
    
    TEXT_WHITE = RGBColor(255, 255, 255)
    TEXT_MINT = RGBColor(52, 211, 153)     # #34D399
    TEXT_EMERALD = RGBColor(16, 185, 129)  # #10B981
    TEXT_CYAN = RGBColor(6, 182, 212)      # #06B6D4
    TEXT_MUTED = RGBColor(176, 195, 222)   # #B0C3DE - High contrast body text
    TEXT_DIM = RGBColor(120, 140, 168)     # #788CA8

    FONT_TITLE = "Arial"
    FONT_BODY = "Arial"

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    assets_dir = os.path.join(base_dir, "docs", "presentation-assets")

    def set_slide_bg(slide):
        background = slide.background
        fill = background.fill
        fill.solid()
        fill.fore_color.rgb = BG_COLOR

    def add_header(slide, rubric_text, title_text, subtitle_text):
        # Top Rubric Pill Badge
        badge_box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(0.42), Inches(3.6), Inches(0.36))
        badge_box.fill.solid()
        badge_box.fill.fore_color.rgb = RGBColor(16, 45, 40)
        badge_box.line.color.rgb = TEXT_EMERALD
        badge_box.line.width = Pt(1)
        tf_b = badge_box.text_frame
        tf_b.word_wrap = True
        tf_b.vertical_anchor = MSO_ANCHOR.MIDDLE
        p_b = tf_b.paragraphs[0]
        p_b.text = rubric_text.upper()
        p_b.font.name = FONT_TITLE
        p_b.font.size = Pt(9.5)
        p_b.font.bold = True
        p_b.font.color.rgb = TEXT_MINT
        p_b.alignment = PP_ALIGN.CENTER

        # Slide Title
        tx_title = slide.shapes.add_textbox(Inches(0.8), Inches(0.84), Inches(11.73), Inches(0.55))
        tf_t = tx_title.text_frame
        tf_t.word_wrap = True
        p_t = tf_t.paragraphs[0]
        p_t.text = title_text
        p_t.font.name = FONT_TITLE
        p_t.font.size = Pt(21)
        p_t.font.bold = True
        p_t.font.color.rgb = TEXT_WHITE

        # Slide Subtitle
        tx_sub = slide.shapes.add_textbox(Inches(0.8), Inches(1.40), Inches(11.73), Inches(0.40))
        tf_s = tx_sub.text_frame
        tf_s.word_wrap = True
        p_s = tf_s.paragraphs[0]
        p_s.text = subtitle_text
        p_s.font.name = FONT_BODY
        p_s.font.size = Pt(12)
        p_s.font.color.rgb = TEXT_MUTED

    def add_footer(slide, current_idx, total_idx=10):
        # Subtle horizontal divider
        line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(6.85), Inches(11.73), Inches(0.015))
        line.fill.solid()
        line.fill.fore_color.rgb = RGBColor(30, 50, 75)
        line.line.fill.background()

        # Footer Left
        tx_left = slide.shapes.add_textbox(Inches(0.8), Inches(6.92), Inches(6.5), Inches(0.35))
        tf_l = tx_left.text_frame
        p_l = tf_l.paragraphs[0]
        p_l.text = "KiwiShare · Team Five Guys · COMPSCI 734 · University of Auckland"
        p_l.font.name = FONT_BODY
        p_l.font.size = Pt(9.5)
        p_l.font.color.rgb = TEXT_DIM

        # Footer Right
        tx_right = slide.shapes.add_textbox(Inches(8.5), Inches(6.92), Inches(4.03), Inches(0.35))
        tf_r = tx_right.text_frame
        p_r = tf_r.paragraphs[0]
        p_r.text = f"Slide {current_idx:02d} of {total_idx:02d}"
        p_r.font.name = FONT_BODY
        p_r.font.size = Pt(9.5)
        p_r.font.bold = True
        p_r.font.color.rgb = TEXT_MINT
        p_r.alignment = PP_ALIGN.RIGHT

    def add_card(slide, left, top, width, height, title, bullets, tags=None, is_highlight=False):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(height))
        card.fill.solid()
        card.fill.fore_color.rgb = CARD_BG
        card.line.color.rgb = CARD_BORDER_HI if is_highlight else CARD_BORDER
        card.line.width = Pt(1.5 if is_highlight else 1)

        tx = slide.shapes.add_textbox(Inches(left + 0.22), Inches(top + 0.16), Inches(width - 0.44), Inches(height - 0.32))
        tf = tx.text_frame
        tf.word_wrap = True

        p_title = tf.paragraphs[0]
        p_title.text = title
        p_title.font.name = FONT_TITLE
        p_title.font.size = Pt(13)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_MINT if is_highlight else TEXT_WHITE
        p_title.space_after = Pt(6)

        for lead, body in bullets:
            p = tf.add_paragraph()
            p.space_after = Pt(4)
            run_lead = p.add_run()
            run_lead.text = f"•  {lead}: "
            run_lead.font.name = FONT_BODY
            run_lead.font.size = Pt(9.5)
            run_lead.font.bold = True
            run_lead.font.color.rgb = TEXT_WHITE

            run_body = p.add_run()
            run_body.text = body
            run_body.font.name = FONT_BODY
            run_body.font.size = Pt(9.5)
            run_body.font.color.rgb = TEXT_MUTED

        if tags:
            p_tag = tf.add_paragraph()
            p_tag.space_before = Pt(4)
            for t in tags:
                r_tag = p_tag.add_run()
                r_tag.text = f" [{t}] "
                r_tag.font.name = FONT_BODY
                r_tag.font.size = Pt(8.5)
                r_tag.font.bold = True
                r_tag.font.color.rgb = TEXT_CYAN

    def add_image_panel(slide, left, top, width, height, image_filename, caption_text=None, border_color=CARD_BORDER_HI):
        img_path = os.path.join(assets_dir, image_filename)
        if not os.path.exists(img_path):
            print(f"[WARN] Image not found: {img_path}")
            return

        # Outer Frame
        frame_h = height + (0.42 if caption_text else 0)
        frame = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(left), Inches(top), Inches(width), Inches(frame_h))
        frame.fill.solid()
        frame.fill.fore_color.rgb = FRAME_BG
        frame.line.color.rgb = border_color
        frame.line.width = Pt(1.5)

        # Image Picture
        slide.shapes.add_picture(img_path, Inches(left + 0.08), Inches(top + 0.08), Inches(width - 0.16), Inches(height - 0.16))

        # Optional Caption Bar
        if caption_text:
            cap_box = slide.shapes.add_textbox(Inches(left + 0.1), Inches(top + height - 0.04), Inches(width - 0.2), Inches(0.4))
            tf_cap = cap_box.text_frame
            tf_cap.word_wrap = True
            tf_cap.vertical_anchor = MSO_ANCHOR.MIDDLE
            p_cap = tf_cap.paragraphs[0]
            p_cap.text = caption_text
            p_cap.font.name = FONT_BODY
            p_cap.font.size = Pt(8.5)
            p_cap.font.bold = True
            p_cap.font.color.rgb = TEXT_MINT
            p_cap.alignment = PP_ALIGN.CENTER

    # =========================================================================
    # SLIDE 1: Cover Slide
    # =========================================================================
    s1 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s1)

    # Left content column: width = 6.0"
    c_pill = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.1), Inches(4.5), Inches(0.42))
    c_pill.fill.solid()
    c_pill.fill.fore_color.rgb = RGBColor(12, 40, 32)
    c_pill.line.color.rgb = TEXT_EMERALD
    c_pill.line.width = Pt(1.5)
    tf_cp = c_pill.text_frame
    tf_cp.vertical_anchor = MSO_ANCHOR.MIDDLE
    p_cp = tf_cp.paragraphs[0]
    p_cp.text = "🌿  COMPSCI 734  •  UNIVERSITY OF AUCKLAND"
    p_cp.font.name = FONT_TITLE
    p_cp.font.size = Pt(10)
    p_cp.font.bold = True
    p_cp.font.color.rgb = TEXT_MINT
    p_cp.alignment = PP_ALIGN.CENTER

    tx_kicker = s1.shapes.add_textbox(Inches(0.8), Inches(1.75), Inches(5.8), Inches(0.35))
    tf_k = tx_kicker.text_frame
    p_k = tf_k.paragraphs[0]
    p_k.text = "SUSTAINABLE COMMUNITY MARKETPLACE"
    p_k.font.name = FONT_TITLE
    p_k.font.size = Pt(12)
    p_k.font.bold = True
    p_k.font.color.rgb = TEXT_EMERALD

    tx_logo = s1.shapes.add_textbox(Inches(0.8), Inches(2.1), Inches(5.8), Inches(1.1))
    tf_logo = tx_logo.text_frame
    p_logo = tf_logo.paragraphs[0]
    r_logo1 = p_logo.add_run()
    r_logo1.text = "Kiwi"
    r_logo1.font.name = FONT_TITLE
    r_logo1.font.size = Pt(56)
    r_logo1.font.bold = True
    r_logo1.font.color.rgb = TEXT_WHITE

    r_logo2 = p_logo.add_run()
    r_logo2.text = "Share"
    r_logo2.font.name = FONT_TITLE
    r_logo2.font.size = Pt(56)
    r_logo2.font.bold = True
    r_logo2.font.color.rgb = TEXT_MINT

    tx_sub1 = s1.shapes.add_textbox(Inches(0.8), Inches(3.3), Inches(5.8), Inches(0.8))
    tf_sub1 = tx_sub1.text_frame
    tf_sub1.word_wrap = True
    p_sub1 = tf_sub1.paragraphs[0]
    p_sub1.text = "A Decoupled, Cloud-Native & Cross-Platform Solution for Aotearoa"
    p_sub1.font.name = FONT_BODY
    p_sub1.font.size = Pt(15)
    p_sub1.font.color.rgb = TEXT_MUTED

    tx_auth = s1.shapes.add_textbox(Inches(0.8), Inches(4.2), Inches(5.8), Inches(0.4))
    tf_auth = tx_auth.text_frame
    p_auth = tf_auth.paragraphs[0]
    p_auth.text = "Team Five Guys  ·  COMPSCI 734  ·  University of Auckland"
    p_auth.font.name = FONT_BODY
    p_auth.font.size = Pt(12)
    p_auth.font.color.rgb = TEXT_WHITE

    badges = [
        ("● Live in Production", TEXT_MINT),
        ("🌐 kiwishare.online", TEXT_WHITE),
        ("☁️ kiwishare.onrender.com", TEXT_CYAN),
        ("📱 Android APK Ready", TEXT_MINT)
    ]
    for i, (b_text, b_col) in enumerate(badges):
        b_box = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8 + (i % 2) * 2.8), Inches(4.9 + (i // 2) * 0.65), Inches(2.6), Inches(0.48))
        b_box.fill.solid()
        b_box.fill.fore_color.rgb = CARD_BG
        b_box.line.color.rgb = CARD_BORDER
        b_box.line.width = Pt(1)
        tf_b = b_box.text_frame
        tf_b.vertical_anchor = MSO_ANCHOR.MIDDLE
        p = tf_b.paragraphs[0]
        p.text = b_text
        p.font.name = FONT_BODY
        p.font.size = Pt(9.5)
        p.font.bold = True
        p.font.color.rgb = b_col
        p.alignment = PP_ALIGN.CENTER

    # Right Hero Image
    add_image_panel(s1, 6.9, 1.2, 5.63, 4.8, "slide1_cover.jpg", "Auckland Sky Tower · Campus Ecosystem · Sustainable Circular Economy")
    add_footer(s1, 1)

    # =========================================================================
    # SLIDE 2: Genuine User Need (Criterion 4)
    # =========================================================================
    s2 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s2)
    add_header(s2, "Rubric Criterion 04 · User Need", "Genuine User Need: Building Verified Trust in Aotearoa", "Eliminating second-hand friction, seller ghosting, and commission tax for campus communities")

    # Left: 2 Cards (clean & punchy)
    add_card(s2, 0.8, 1.95, 5.8, 2.2, "1. Institutional Trust vs Anonymous Friction", [
        ("Student Identity Verification", "Mandatory .ac.nz institutional email verification eliminates anonymous scammers and counterfeit items."),
        ("Public Reputation Badges", "Every profile displays verified student status, completed transactions, and transparent community feedback."),
        ("Campus Safety Baseline", "Builds inherent peer-to-peer accountability across student dorms, faculties, and campuses.")
    ], tags=["Verified .ac.nz", "Zero Scammers", "Campus Safety"])

    add_card(s2, 0.8, 4.4, 5.8, 2.2, "2. Dynamic Trust Scores & Zero Platform Tax", [
        ("Dynamic Trust Scoring (0–100)", "Proprietary algorithm awards +5 reputation points for successful handovers and penalizes meetup cancellations."),
        ("100% Free Campus Exchange", "Zero commission fees compared to Trade Me's 7.9%–12.9% cut, encouraging sustainable item reuse."),
        ("Spatial Proximity Indexing", "Geospatial indexing matches buyers with items within walking distance (CBD, Ponsonby, Grafton).")
    ], tags=["Trust Score 0-100", "Zero Platform Tax", "Geospatial Matching"], is_highlight=True)

    # Right: Image
    add_image_panel(s2, 6.9, 1.95, 5.63, 4.25, "slide2_trust.jpg", "University Crest Verification · 100% Trust Gauge · Localized NZ Proximity")
    add_footer(s2, 2)

    # =========================================================================
    # SLIDE 3: Integrated Tri-Tier Solution (Criteria 1 & 6)
    # =========================================================================
    s3 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s3)
    add_header(s3, "Rubric Criteria 01 & 06 · Architecture", "Integrated Solution: Decoupled Tri-Tier Architecture", "Clear functional separation: Mobile for physical exchange, Web for governance, Cloud for atomic data")

    # Left: 3 Cards (one per tier)
    add_card(s3, 0.8, 1.95, 5.8, 1.4, "📱 Flutter Mobile App (Physical Interaction)", [
        ("60 FPS Discovery", "Mobile-optimized browsing, category filtering, and nearby distance queries."),
        ("Hardware Integration", "Optical QR scanning for instant handovers; native voice recording in chat.")
    ], tags=["Flutter 3.12+", "Provider", "GoRouter"])

    add_card(s3, 0.8, 3.45, 5.8, 1.4, "🌐 React Web Portal (Platform Governance)", [
        ("Live Administration", "Responsive desktop portal at kiwishare.online for platform monitoring."),
        ("Financial & Trust Moderation", "Real-time GMV metrics, user trust score adjustments, and item moderation.")
    ], tags=["React 18", "Vite", "Cloudflare SSL", "RBAC"], is_highlight=True)

    add_card(s3, 0.8, 4.95, 5.8, 1.65, "☁️ Koa RESTful API & MongoDB Atlas", [
        ("Stateless REST Gateway", "Node.js/TypeScript backend deployed on Render with standardized error handling."),
        ("ACID Multi-Document Sessions", "MongoDB replica set guarantees atomic all-or-nothing state transitions.")
    ], tags=["Koa.js", "TypeScript", "MongoDB Atlas", "ACID Sessions"])

    # Right: Image
    add_image_panel(s3, 6.9, 1.95, 5.63, 4.25, "slide3_arch.jpg", "Isometric Architecture: Flutter Mobile · React Web Admin · Koa/Atlas Cloud")
    add_footer(s3, 3)

    # =========================================================================
    # SLIDE 4: Modern Mobile Hardware Capabilities (Criterion 5)
    # =========================================================================
    s4 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s4)
    add_header(s4, "Rubric Criterion 05 · Mobile Capabilities", "Modern Mobile Capabilities: Native Hardware Integration", "Unlocking device sensors to deliver capabilities fundamentally impossible on conventional web browsers")

    # Left: 3 Sensor Cards
    add_card(s4, 0.8, 1.95, 5.8, 1.4, "📷 Optical Vision & Camera Scanning", [
        ("mobile_scanner", "Hardware camera reads seller's dynamic QR code at 60 FPS in < 200ms."),
        ("image_picker", "Fast listing photo capture with client-side compression to preserve cellular data.")
    ], tags=["mobile_scanner", "60 FPS Vision", "Client Compression"])

    add_card(s4, 0.8, 3.45, 5.8, 1.4, "🎙️ Native Microphone & Audio Streamer", [
        ("record Package", "Direct microphone capture with ambient noise filtering inside real-time chat."),
        ("just_audio Streamer", "Hardware-accelerated voice note playback with interactive scrubbing timeline.")
    ], tags=["record", "just_audio", "Voice Memos"], is_highlight=True)

    add_card(s4, 0.8, 4.95, 5.8, 1.65, "📍 GPS Sensors & Vector Mapping", [
        ("geolocator & geocoding", "High-precision device GPS automatically mapped to NZ suburbs (Ponsonby, CBD)."),
        ("flutter_map Integration", "Offline-cached OpenStreetMap vector tiles with zero proprietary API fees.")
    ], tags=["geolocator", "NZ Geocoding", "OpenStreetMap"])

    # Right: Image
    add_image_panel(s4, 6.9, 1.95, 5.63, 4.25, "slide4_mobile.jpg", "Native Hardware: Camera QR Beam · Audio Waveform · GPS Proximity")
    add_footer(s4, 4)

    # =========================================================================
    # SLIDE 5: Independent Learning Beyond Course (Criterion 3)
    # =========================================================================
    s5 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s5)
    add_header(s5, "Rubric Criterion 03 · Independent Learning", "Independent Learning: Technologies Applied Beyond Course Scope", "Four research-backed architectural innovations explored, benchmarked, and implemented by the team")

    # Left: 2 Cards (Deep Innovations)
    add_card(s5, 0.8, 1.95, 5.8, 2.2, "1. Audio Transcoding & Direct Edge Uploads", [
        ("FFmpeg-Static Pipeline", "Integrated static FFmpeg Linux binary to sanitize, inspect, and transcode conflicting mobile audio codecs (M4A/AAC) for 100% universal playback."),
        ("Cloudflare R2 Direct PUT", "Koa API generates 15-min S3-presigned URLs; mobile clients upload images directly to Cloudflare R2, bypassing API servers with zero egress cost.")
    ], tags=["ffmpeg-static", "Cloudflare R2", "S3 Presigned", "Zero Egress"], is_highlight=True)

    add_card(s5, 0.8, 4.4, 5.8, 2.2, "2. Generative AI Assistant & Automated Monorepo CI/CD", [
        ("Google Gemini 2.5 Flash", "Integrated server-side Gemini AI model to infer item category, condition, and sustainability tags from minimal user prompts in < 1 second."),
        ("Automated Monorepo CD", "Configured PNPM workspaces with standard-version and 4 automated GitHub Actions pipelines auto-tagging SemVer releases on merge to main.")
    ], tags=["Gemini 2.5 Flash", "PNPM Workspace", "GitHub Actions CD", "SemVer"])

    # Right: Image
    add_image_panel(s5, 6.9, 1.95, 5.63, 4.25, "slide5_innovation.jpg", "Neural AI Brain · FFmpeg Audio Pipeline · Cloudflare R2 Edge Storage")
    add_footer(s5, 5)

    # =========================================================================
    # SLIDE 6: Atomic QR Code Handover Protocol (Criteria 2 & 6)
    # =========================================================================
    s6 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s6)
    add_header(s6, "Rubric Criteria 02 & 06 · Protocol & ACID", "Technical Mastery: Cryptographic Handover Protocol", "Eliminating in-person delivery fraud and ghosting disputes through atomic cryptographic verification")

    # Left: 2 Cards (Protocol Flow + ACID Guarantee)
    add_card(s6, 0.8, 1.95, 5.8, 2.2, "1. Four-Step Cryptographic Handover Flow", [
        ("Step 1: Dynamic QR Generation", "Seller displays dynamic token QR_HANDOVER_TOKEN_<id>_<nonce> bound to 7-day MongoDB TTL index."),
        ("Step 2: Optical Camera Scan", "Buyer scans QR via mobile_scanner in < 200ms; sends authenticated claim request."),
        ("Step 3 & 4: State Transition", "Server commits transaction; seller receives +5 trust points and order is marked complete.")
    ], tags=["Dynamic Nonce", "TTL Expiration", "+5 Trust Reward"])

    add_card(s6, 0.8, 4.4, 5.8, 2.2, "2. MongoDB ACID Multi-Document Atomicity", [
        ("All-or-Nothing Commit", "Koa executes runMongoTransaction: [Transfer Ownership] ➔ [Seller TrustScore +5] ➔ [Burn Token] ➔ [Complete Order]."),
        ("Automatic Network Rollback", "If cellular connection drops mid-exchange, all operations abort cleanly with zero partial state corruption.")
    ], tags=["runMongoTransaction", "Zero State Drift", "Atomic Rollback"], is_highlight=True)

    # Right: Image
    add_image_panel(s6, 6.9, 1.95, 5.63, 4.25, "slide6_qr.jpg", "Dynamic Optical QR Handover · Atomic Commitment Shield")
    add_footer(s6, 6)

    # =========================================================================
    # SLIDE 7: Cybersecurity & OWASP Top 10 Blueprint (Criterion 9)
    # =========================================================================
    s7 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s7)
    add_header(s7, "Rubric Criterion 09 · Cybersecurity", "Cybersecurity & Privacy: Defense-in-Depth OWASP Controls", "Proactive mitigation embedded across client apps, API gateway, and database layers")

    # Left: 2 Cards (Auth/Crypto + Injection/Config)
    add_card(s7, 0.8, 1.95, 5.8, 2.2, "1. Access Control & Cryptographic Defense (A01, A02)", [
        ("JWT Authorization & RBAC", "Cryptographically signed JWT bearer tokens required for mutations; requireAdmin middleware guards governance routes."),
        ("Bcrypt Password Hashing", "User passwords salted and hashed with bcrypt (12 work factor rounds)."),
        ("TLS 1.3 HTTPS & Secrets Vault", "End-to-end encryption across Cloudflare edge; zero secrets stored in git repositories.")
    ], tags=["JWT Bearer", "requireAdmin RBAC", "Bcrypt (12 Rounds)"], is_highlight=True)

    add_card(s7, 0.8, 4.4, 5.8, 2.2, "2. Injection Prevention & Server Hardening (A03, A05)", [
        ("NoSQL & ReDoS Sanitization", "Strict Mongoose schemas block query injection; search queries sanitize regex expressions to prevent catastrophic backtracking."),
        ("Security Header Hardening", "Removed X-Powered-By fingerprint headers; strict CORS whitelist enforces approved production origins."),
        ("Masked Error Interceptor", "Runtime exceptions masked from client responses while detailed stack traces logged internally.")
    ], tags=["NoSQL Defense", "ReDoS Mitigation", "CORS Whitelist", "Error Masking"])

    # Right: Image
    add_image_panel(s7, 6.9, 1.95, 5.63, 4.25, "slide7_security.jpg", "Cyber Defense: Padlock Encryption · Firewall Shield · OWASP Top 10")
    add_footer(s7, 7)

    # =========================================================================
    # SLIDE 8: Software Engineering & Testing Strategy (Criteria 7 & 8)
    # =========================================================================
    s8 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s8)
    add_header(s8, "Rubric Criteria 07 & 08 · Engineering & Testing", "Software Engineering Standards & Multi-Tier Testing Strategy", "Enforcing production-grade code quality, automated test suites, and transparent team workflows")

    # Left: 2 Cards (Testing + CI/CD & Git-Flow)
    add_card(s8, 0.8, 1.95, 5.8, 2.2, "1. Multi-Tier Automated Testing Suites", [
        ("12 Backend Jest Suites", "Unit and integration tests with Supertest HTTP mocking covering Auth, OTP, Meetups, Transactions, and Admin."),
        ("Flutter Test Suites", "Granular repository, provider, navigation, and widget tests in mobile/test/ verifying offline states."),
        ("Audit Verification Reports", "Formal subsystem test reports archived in docs/testing-strategy/ for complete traceability.")
    ], tags=["12 Jest Suites", "Flutter Widget Tests", "Supertest Mocking"], is_highlight=True)

    add_card(s8, 0.8, 4.4, 5.8, 2.2, "2. Git-Flow Branching & 4 Automated CI Pipelines", [
        ("Structured Git-Flow", "Feature branches (feature/*) merge into pre for integration, with production releases tagged on main."),
        ("4 Parallel GitHub Actions", "Automated workflows validate linting (ESLint, Dart Analyze), execute tests, and compile Android APKs."),
        ("Pre-Commit Hygiene", "Husky hooks enforce Prettier and Dart Format to ensure zero lint drift across the monorepo.")
    ], tags=["Git-Flow Model", "GitHub Actions CI", "Husky Pre-Commit"])

    # Right: Image
    add_image_panel(s8, 6.9, 1.95, 5.63, 4.25, "slide8_testing.jpg", "Continuous Testing: Automated Test Nodes · CI/CD Quality Gate")
    add_footer(s8, 8)

    # =========================================================================
    # SLIDE 9: Realistic Deployment & Live Ecosystem (Criteria 10 & 11)
    # =========================================================================
    s9 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s9)
    add_header(s9, "Rubric Criteria 10 & 11 · Live Deployment", "Realistic Deployment: 100% Live Production Ecosystem", "Publicly accessible production services deployed across edge CDN, cloud containers, and physical mobile devices")

    # Left: 2 Cards (Live Services + Seeded Data)
    add_card(s9, 0.8, 1.95, 5.8, 2.2, "1. Public Production Endpoints (Ready to Access)", [
        ("Web Portal (kiwishare.online)", "Live single-page application hosted with Cloudflare CDN, global edge caching, and automated SSL."),
        ("REST API (kiwishare.onrender.com)", "Node.js 22 LTS container on Render with zero-downtime rolling updates and /health endpoint."),
        ("Mobile APK (GitHub Releases)", "Compiled Android APK with release notes ready for immediate assessor download.")
    ], tags=["kiwishare.online", "Render Cloud", "GitHub Releases APK"], is_highlight=True)

    add_card(s9, 0.8, 4.4, 5.8, 2.2, "2. Pre-Seeded MongoDB Atlas Database (Zero Setup)", [
        ("Campus Data Pre-Seeded", "Live database populated with 10 categories, verified student accounts, and active listings in Auckland (CBD, Ponsonby, Grafton)."),
        ("Ready-to-Scan Demo Order", "Includes confirmed meetup order #ORD_DEMO_MEETUP_2026 for instant QR handover evaluation without local configuration.")
    ], tags=["MongoDB Atlas ReplicaSet", "Auckland Suburbs", "Zero Config"])

    # Right: Image
    add_image_panel(s9, 6.9, 1.95, 5.63, 4.25, "slide9_deployment.jpg", "NZ Production Mesh: Cloudflare CDN · Render API · MongoDB Atlas")
    add_footer(s9, 9)

    # =========================================================================
    # SLIDE 10: Assessor Live Walkthrough & Team Five Guys (Criterion 12)
    # =========================================================================
    s10 = prs.slides.add_slide(blank_layout)
    set_slide_bg(s10)
    add_header(s10, "Rubric Criterion 12 · Demonstration", "Assessor Live Walkthrough & Demonstration", "Ready-to-evaluate live credentials and step-by-step 3-minute evaluation scenarios")

    # Left: 2 Cards (Credentials + 3-Min Scenarios)
    add_card(s10, 0.8, 1.95, 5.8, 2.2, "🔑 Pre-Seeded Test Credentials", [
        ("Universal Password", "password123 (applies to all seeded accounts)."),
        ("Platform Admin", "admin@kiwishare.online  ➔  Inspect kiwishare.online/admin for GMV analytics and user moderation."),
        ("Verified Student Seller", "demo@example.com  ➔  Displays QR token for order #ORD_DEMO_MEETUP_2026."),
        ("Verified Student Buyer", "testbuyer@kiwishare.online  ➔  Scans QR to claim ownership and test +5 trust reward.")
    ], tags=["P/W: password123", "Instant Live Login"], is_highlight=True)

    add_card(s10, 0.8, 4.4, 5.8, 2.2, "🚀 Fast 3-Minute Assessment Flows", [
        ("Scenario A: Web Administration", "Log into kiwishare.online as Admin; review live GMV metrics, fee turnover, and adjust trust scores."),
        ("Scenario B: Optical QR Handover", "Seller displays QR token on mobile; Buyer scans to witness atomic ownership transfer and +5 trust reward."),
        ("Step-by-Step Guide", "Refer to docs/demo-guide.md for comprehensive walkthrough instructions and API curl commands.")
    ], tags=["Web Admin Board", "Live QR Scan", "docs/demo-guide.md"])

    # Right: Team Image Panel
    add_image_panel(s10, 6.9, 1.95, 5.63, 4.25, "slide10_team.jpg", "Team Five Guys · COMPSCI 734 · University of Auckland")
    add_footer(s10, 10)

    # Save Presentation
    output_path = os.path.abspath(os.path.join(base_dir, "docs", "KiwiShare-COMPSCI734-Presentation.pptx"))
    prs.save(output_path)
    print(f"[SUCCESS] Successfully generated presentation at: {output_path}")
    print(f"[FILE SIZE] {os.path.getsize(output_path)} bytes")

if __name__ == "__main__":
    build_presentation()
