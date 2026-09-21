---
name: Carelogue
colors:
  surface: '#fdf8f6'
  surface-dim: '#ddd9d7'
  surface-bright: '#fdf8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3f0'
  surface-container: '#f2edeb'
  surface-container-high: '#ece7e5'
  surface-container-highest: '#e6e2df'
  on-surface: '#1c1b1a'
  on-surface-variant: '#55433c'
  inverse-surface: '#31302f'
  inverse-on-surface: '#f4f0ee'
  outline: '#88726a'
  outline-variant: '#dbc1b8'
  surface-tint: '#984622'
  primary: '#984622'
  on-primary: '#ffffff'
  primary-container: '#d9784f'
  on-primary-container: '#501900'
  inverse-primary: '#ffb598'
  secondary: '#635d59'
  on-secondary: '#ffffff'
  secondary-container: '#e7ded8'
  on-secondary-container: '#68615d'
  tertiary: '#605e59'
  on-tertiary: '#ffffff'
  tertiary-container: '#94928c'
  on-tertiary-container: '#2c2b27'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbce'
  primary-fixed-dim: '#ffb598'
  on-primary-fixed: '#370e00'
  on-primary-fixed-variant: '#7a300c'
  secondary-fixed: '#eae1db'
  secondary-fixed-dim: '#cec5bf'
  on-secondary-fixed: '#1f1b17'
  on-secondary-fixed-variant: '#4b4642'
  tertiary-fixed: '#e6e2db'
  tertiary-fixed-dim: '#cac6bf'
  on-tertiary-fixed: '#1c1c18'
  on-tertiary-fixed-variant: '#484742'
  background: '#fdf8f6'
  on-background: '#1c1b1a'
  surface-variant: '#e6e2df'
typography:
  headline-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 34px
    fontWeight: '700'
    lineHeight: 41px
    letterSpacing: -0.02em
  headline-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system serves patients and their families navigating complex health journeys across bilingual (English and Traditional/Simplified Chinese) contexts in Canada. The core emotional tone is reassuring, unhurried, and deeply dignified—evoking the quiet tactile warmth of a high-grade linen-bound journal blended with the crisp, intuitive ergonomics of native iOS human interface guidelines.

The design movement is **Warm Minimalist Editorial**. Unlike sterile clinical dashboards or overwhelming medical charts, the interface prioritizes psychological comfort, legibility, and generous breathing room. Visual noise is minimized to reduce cognitive load during vulnerable, stressful caretaking moments. Information architecture is organized sequentially and chronologically like an archival notebook, using disciplined editorial hierarchy, soft paper-like elevation, and precise stroke weights.

## Colors

The palette draws inspiration from archival stationery, soothing natural clay, and deep ink.

- **Primary Accent (`#D9784F`)**: Warm Apricot. Reserved for key action items, active states, vital highlight markers, and primary callouts. It delivers warm contrast without the alarmist tone of clinical red.
- **Secondary Accent (`#FAF0EA`)**: Warm Apricot Tint. Used for low-intensity interactive highlights, active list selection badges, chip fills, and subtle focus states.
- **Surface Canvas (`#F7F5F2`)**: Warm Rice Paper. The default system-wide canvas color, eliminating the eye fatigue caused by clinical pure white.
- **Card Surface (`#FFFFFF`)**: Crisp Card Stock. Pure white floating cards that distinguish content modules from the warm ambient canvas.
- **Structural Neutral / Border (`#EAE6DF`)**: Soft Muted Linen. Used for single-pixel card outlines, dividers, and grouped table cell separators.
- **Ink Primary (`#1C1B1A`)**: Deep Sumi Ink. The highest contrast text color for primary headings, body text, and critical metrics.
- **Ink Secondary (`#8A8680`)**: Muted Slate Grey. Used for metadata, timestamps, timestamps, supporting translations, and inactive states.

Color is strictly applied with functional restraint: interactive elements stand out via warm apricot tones, while the canvas retains its calm, non-stimulating baseline.

## Typography

Typography balances clean Latin geometry with seamless pairing for Chinese glyphs (PingFang SC / Noto Sans SC/TC in implementation). Plus Jakarta Sans provides friendly, humanist proportions with crisp terminals, mirroring Apple's SF Pro clarity while lending a softer, paper-journal quality.

### Bilingual Handling Rules
- **Stacking & Pairing:** In bilingual mode, English and Chinese appear paired. For primary labels with secondary language translations (e.g., Medication Name / 藥物名稱), the primary language uses `body-md` in `#1C1B1A` while the translated counterpart uses `body-sm` in `#8A8680` directly underneath or adjacent with an optical em-dash.
- **Line Heights:** Generous line heights are enforced across all levels to prevent tall CJK (Chinese, Japanese, Korean) ideograms from clashing across wrapped lines.
- **Numbers and Metrics:** Numeric data (dosages, blood pressure, lab values) are displayed in semi-bold tabular numerals to ensure alignment down chronological care feeds.

## Layout & Spacing

The layout model is mobile-first, centered on fixed max-width cards and safe-area insets mimicking native iOS grouped views. 

### Grid & Form Factors
- **Mobile (Up to 600px):** Single-column layout. Margin is `1.25rem` (20px) on left and right edges. Vertical stack gap between cards is `1rem`. Generous top scroll padding allows large titles to collapse cleanly into the navigation bar upon scrolling.
- **Tablet & Compact Desktop (601px - 1024px):** Single centered reading column (max width 640px) or an asymmetric 2-column layout (master chronological timeline on the left, active care dossier on the right) with a `1.5rem` gutter and `2rem` screen margin.
- **Desktop (1025px+):** Centered workspace container capped at `880px` to maintain focused readability, avoiding horizontal eye strain during data entry or review.

### Spacing Rhythm
Vertical white space between conceptual groupings uses `space-xl` (`2.25rem`) to delineate days or distinct medical events. Within a card module, internal padding adheres to `space-lg` (`1.5rem`), while compact list rows use `space-sm` (`0.5rem`) vertical padding to keep touch targets generous (minimum 44×44px hit areas) without visual clutter.

## Elevation & Depth

This system intentionally bypasses heavy skeuomorphism and stark dropshadows in favor of **Soft Ambient Paper Stacking**.

### Surface Hierarchy
1. **Level 0 (Canvas):** `#F7F5F2` (Warm Rice Paper). The foundational surface holding all screens.
2. **Level 1 (Card & Grouped Containers):** `#FFFFFF` (Crisp Paper). Cards rest upon Level 0 with a gentle structural boundary: a `1px` continuous border of `#EAE6DF` paired with an ultra-diffused, warm-tinted ambient shadow: `box-shadow: 0 4px 20px -2px rgba(28, 27, 26, 0.03), 0 2px 6px -1px rgba(28, 27, 26, 0.02)`.
3. **Level 2 (Modals, Action Sheets & Overlays):** `#FFFFFF` elevated with a floating ambient shadow: `box-shadow: 0 12px 32px -4px rgba(28, 27, 26, 0.08), 0 4px 12px -2px rgba(28, 27, 26, 0.04)`, bordered by `#EAE6DF`.
4. **Level 3 (Navigation Bars & Floating Toolbars):** `#F7F5F2` with 85% opacity backed by an iOS-style translucent blur (`backdrop-filter: blur(20px)`), with a hairline bottom border of `#EAE6DF`.

## Shapes

The design system uses a curated **Rounded (Level 2)** shape language, balancing approachable softness with structure.

- **Primary Cards & Containers:** Radii strictly adhere to `1.125rem` (18px) to `1.25rem` (20px), evoking the smooth, organic rounded corners of Apple native widgets and bound physical journals.
- **Interactive Controls (Inputs, Buttons):** Radii use `0.75rem` (12px) to provide defined, stable targets.
- **Pills & Status Tags:** Fully rounded capsule pill shape (`9999px`) for short badges, category chips, and filter toggles.
- **Dividers & Outlines:** 1px stroke weight using `#EAE6DF`, never sharp or harsh.

## Components

### Buttons
- **Primary Action Button:** Background `#D9784F`, text `#FFFFFF`, height 50px, border-radius 14px, typography `label-lg`. Pressed state: `#C4673F` scale (0.98).
- **Secondary / Ghost Button:** Background `#FAF0EA`, text `#D9784F`, border 1px solid transparent, height 50px, border-radius 14px.
- **Quiet Button:** Background transparent, text `#8A8680`, hover/tap text `#1C1B1A`.

### Cards & Journal Modules
- **Timeline Entry Card:** Crisp white `#FFFFFF` surface, 18px border radius, 1px `#EAE6DF` outline, 20px internal padding. Left edge features an optional subtle 3px vertical pill indicator in `#D9784F` for flagged/urgent entries.
- **Metric Highlight Card:** Small compact card displaying health indicators (e.g., vitals, hydration, mood). White background, 16px radius, contains a small top SF-style line icon in `#D9784F` within a `#FAF0EA` circular badge (32×32px).

### Chips & Filter Tags
- **Filter Chip:** Height 34px, pill-shaped (`9999px`), padding 0 14px. Default state: `#FFFFFF` background, 1px `#EAE6DF` border, `#8A8680` text. Selected state: `#FAF0EA` background, 1px `#D9784F` border, `#D9784F` text, `label-md`.

### Input Fields & Search
- **Text & Numeric Inputs:** Height 48px, background `#FFFFFF`, border 1px solid `#EAE6DF`, border-radius 12px, padding 0 16px, text `#1C1B1A`, placeholder `#8A8680`. Focus state: border 1.5px solid `#D9784F` with a soft outer halo (`0 0 0 3px rgba(217, 120, 79, 0.12)`).
- **Bilingual Field Labels:** Placed above inputs with the English label in `label-md` `#1C1B1A` and the Chinese secondary descriptor in `label-sm` `#8A8680` directly alongside.

### List Rows & Cell Groups
- **Grouped Inset Table:** Emulates iOS inset grouped tables. Background `#FFFFFF`, 18px border-radius, hairline internal divider `#EAE6DF` indented 16px from left. Left content holds an icon and primary bilingual title; right content holds value/status and a gentle `#8A8680` chevron disclosure indicator.

### Checkboxes & Radios
- **Selection Controls:** 22px diameter. Default: border 1.5px `#EAE6DF`, background `#FFFFFF`. Selected: background `#D9784F`, border-color `#D9784F`, displaying a white `#FFFFFF` SF-style micro checkmark or centered dot.

### Specialized Component: Bilingual Audio & Note Log
- A voice-memo and transcription card designed for doctor appointments. Features a wave amplitude visualizer in `#D9784F`, bilingual synchronized transcription side-by-side or stacked, and a warm timestamp header.