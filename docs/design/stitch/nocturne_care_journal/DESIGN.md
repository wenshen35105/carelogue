---
name: Nocturne Care Journal
colors:
  surface: '#16130e'
  surface-dim: '#16130e'
  surface-bright: '#3d3933'
  surface-container-lowest: '#110e09'
  surface-container-low: '#1e1b16'
  surface-container: '#221f1a'
  surface-container-high: '#2d2924'
  surface-container-highest: '#38342e'
  on-surface: '#e9e1d8'
  on-surface-variant: '#d9c2b8'
  inverse-surface: '#e9e1d8'
  inverse-on-surface: '#34302a'
  outline: '#a18c84'
  outline-variant: '#54433c'
  surface-tint: '#ffb596'
  primary: '#ffb596'
  on-primary: '#571f01'
  primary-container: '#e08a63'
  on-primary-container: '#5f2505'
  inverse-primary: '#914b29'
  secondary: '#d0c4bd'
  on-secondary: '#362f2a'
  secondary-container: '#4d4540'
  on-secondary-container: '#beb3ac'
  tertiary: '#73d6d4'
  on-tertiary: '#003736'
  tertiary-container: '#48afad'
  on-tertiary-container: '#003e3d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbcd'
  primary-fixed-dim: '#ffb596'
  on-primary-fixed: '#360f00'
  on-primary-fixed-variant: '#743414'
  secondary-fixed: '#ece0d8'
  secondary-fixed-dim: '#d0c4bd'
  on-secondary-fixed: '#201b16'
  on-secondary-fixed-variant: '#4d4540'
  tertiary-fixed: '#90f3f0'
  tertiary-fixed-dim: '#73d6d4'
  on-tertiary-fixed: '#00201f'
  on-tertiary-fixed-variant: '#00504f'
  background: '#16130e'
  on-background: '#e9e1d8'
  surface-variant: '#38342e'
typography:
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 2.5rem
    fontWeight: '600'
    lineHeight: 3rem
  display-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 2rem
    fontWeight: '600'
    lineHeight: 2.5rem
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.75rem
    fontWeight: '600'
    lineHeight: 2.25rem
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: 2rem
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: 1.75rem
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: '500'
    lineHeight: 1.5rem
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 1.125rem
    fontWeight: '400'
    lineHeight: 1.75rem
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.5rem
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.25rem
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.875rem
    fontWeight: '600'
    lineHeight: 1.25rem
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.75rem
    fontWeight: '500'
    lineHeight: 1rem
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 0.6875rem
    fontWeight: '500'
    lineHeight: 0.875rem
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-desktop: 1.5rem
  margin: 1.25rem
  margin-desktop: 2.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system embodies a nighttime self-reflection sanctuary tailored for personal health logging, medication tracking, and evening emotional debriefs. The brand identity is grounded, introspective, non-judgmental, and quiet. It balances the precision required of health metrics with the warmth of a textured bedside paper journal.

The target audience consists of mindful individuals managing routine health habits, sleep hygiene, chronic symptoms, or emotional check-ins right before sleep. The emotional environment must lower cortisol levels, banish the sterile coldness of clinical utilities, and prevent the retinal glare of harsh screen lighting. 

The visual style blends **Tactile Minimalism** with **Warm Low-Luminance Tonal Layering**. It rejects stark pure blacks and high-frequency stark borders, relying instead on nuanced umber undertones, velvety depth, and gentle apricot points of light that guide interaction without jarring tired eyes.

## Colors

The palette operates under a strict warm-spectrum discipline to safeguard circadian rhythms:

- **Primary Accent (`#E08A63`)**: Warm Apricot. Evokes soft candlelight, hearth glow, or a faded highlighter mark. Reserved for active interactive states, primary action anchors, confirmed statuses, and essential metric emphasis.
- **Subtle Accent Tint (`rgba(224, 138, 99, 0.15)`)**: Used exclusively for selected pill chips, hovered surfaces, and subtle highlight backdrops behind active icon metrics.
- **Canvas Ground (`#17140F`)**: Warm Charcoal base. Deep, soot-infused umber providing total darkness without cold optical void.
- **Surface Foundations**:
  - `surface-container-low` (`#1C1814`): Recessed groups, embedded list troughs, and inset canvas regions.
  - `surface-container` / Default Card (`#221E1A`): Elevated baseline for modular tracking cards, forms, and sheets.
  - `surface-container-high` (`#2C2621`): Raised sheets, interactive button baselines, floating toasts, and active card segments.
- **Hairline Dividers & Contours (`#332E28`)**: Soft earthy boundary lines that frame shapes cleanly without sharp contrast cuts.
- **Typography Colors**:
  - Primary Content (`#F5F1EC`): Warm Milk White. Highly legible yet creamy, avoiding the sharpness of `#FFFFFF`.
  - Secondary Content (`#A39C93`): Muted Hazel Grey. Calibrated for supporting metadata, timestamps, units, and placeholder states.

## Typography

The typography uses Plus Jakarta Sans as the primary Latin driver, backed by native system fallbacks (`-apple-system`, `PingFang SC`, `SF Pro`) to maintain flawless native cadence across devices.

- **Kerning and Rhythm**: Tracking is naturally open and breathable. Body text retains generous vertical leading (`1.5` to `1.6`) to prevent visual strain during prolonged evening reviews.
- **Weights**: Heavy weights (700+) are avoided. Headings top out at semi-bold (600), delivering structural authority without visual aggression.
- **Numbers and Metrics**: When rendering vital biometric metrics (sleep hours, dosages, timestamps), numeric strings use tabular lining properties (`font-variant-numeric: tabular-nums`) within `headline-md` and `display-mobile` to maintain linear alignment across journal entry grids.

## Layout & Spacing

The layout is built around a single-column, distraction-free stream on handheld viewports that transitions into an asymmetric journal grid on larger screens.

- **Mobile (< 768px)**: Fluid 4-column layout with `1.25rem` outer canvas padding (`margin`). Inter-card rhythm relies strictly on `space-md` (`1rem`) to keep the eye scrolling rhythmically down an unbroken column.
- **Desktop (>= 1024px)**: Centers within a constrained, book-inspired container (max-width `1080px`), leveraging an 8-column layout with `1.5rem` gutters (`gutter-desktop`). The primary diary flow spans 5 columns, while supporting trend graphs and daily biometrics occupy a 3-column reference sidebar.
- **Component Breathing Space**: Card interiors adhere to a generous internal padding rhythm using `space-lg` (`1.5rem`) on tablet/desktop and `space-md` (`1rem`) on compact displays.

## Elevation & Depth

This system avoids synthetic drop shadows, light sources from artificial angles, and neon glows. Depth is created via **Warm Tonal Stratification and Tinted Ambient Halos**:

- **Tonal Stepping**: Objects rise toward the user through luminosity shifts. Canvas (`#17140F`) sits deepest; grouping trays rest on `surface-container-low` (`#1C1814`); cards occupy `surface-container` (`#221E1A`); modal drawers and interactive pills rise to `surface-container-high` (`#2C2621`).
- **Low-Contrast Hairlines**: Every surface container features a 1px border utilizing `#332E28`. This acts as a delicate structural edge that defines cards against the dark background without harsh contrast.
- **Warm Ambient Occlusion**: Where interactive popovers or bottom sheets require spatial detachment, depth is handled via an extra-diffused, umber-tinted shadow: `box-shadow: 0 16px 32px -8px rgba(10, 8, 6, 0.65), 0 0 0 1px #332E28`.
- **Active Candlelight Sheen**: Clicked or focused states project a soft, warm radial aura: `0 0 20px rgba(224, 138, 99, 0.12)`.

## Shapes

The design system employs a softened tactile curvature scale that communicates comfort and organic ease:

- **Cards & Surfaces**: Set to `rounded-xl` (`1.25rem` / `20px` to `1rem` / `16px`), mimicking the rounded corners of high-end bound journals. 
- **Interactive Controls & Inputs**: Form fields, modal sheets, and inner progress indicators utilize `rounded-lg` (`1rem` / `16px`).
- **Chips, Badges, and Micro-actions**: Default to fully rounded capsules/pills (`9999px`) to invite gentle touch interaction.

## Components

### Buttons
- **Primary**: Solid Apricot background (`#E08A63`), text colored in Charcoal Ground (`#17140F`, font-weight 600). Minimal, gentle hover warmth.
- **Secondary**: Elevated base (`#2C2621`), 1px border (`#332E28`), warm milk text (`#F5F1EC`).
- **Tertiary / Ghost**: Transparent fill, warm hazel text (`#A39C93`), turning into `#F5F1EC` with `rgba(224, 138, 99, 0.08)` fill on press.

### Chips & Filter Tags
- Height: 36px, pill-shaped.
- **Inactive**: Fill `#1C1814`, border 1px `#332E28`, text `#A39C93`.
- **Active / Selected**: Fill `rgba(224, 138, 99, 0.15)`, border 1px `#E08A63`, text `#F5F1EC`.

### Journal Lists
- Set within `surface-container-low` (`#1C1814`) or separated by hairline `#332E28` rules.
- List items feature generous vertical padding (`space-md`), leading icon/biometric indicator in muted tones, trailing action or timestamp in `#A39C93`.

### Form Fields & Inputs
- Background: Inset `surface-container-low` (`#1C1814`).
- Border: 1px solid `#332E28`, transitioning to `#E08A63` on focus with a subtle `rgba(224, 138, 99, 0.15)` ring glow.
- Text: Primary Warm White (`#F5F1EC`); placeholder rendered in `#A39C93`.

### Selection Controls (Checkboxes & Radios)
- Box/Circle size: 20px. Base outline `#332E28` on `#1C1814`.
- Selected State: Smoothly fills with `#E08A63`; tick/bullet mark rendered in `#17140F`.

### Cards & Metric Clusters
- Surface `#221E1A`, bounded by 1px `#332E28`.
- Metric numbers rendered at `headline-lg` with unit suffixes in `body-sm` (`#A39C93`).
- Sub-elements (notes, symptoms) wrapped in inner pills with `surface-container-high` (`#2C2621`).

### Specialized: Evening Mood & Symptom Slider
- Track: Recessed 6px bar in `#1C1814` with a 1px border `#332E28`.
- Active segment: `#E08A63`.
- Thumb: 24px circular disc in `#F5F1EC`, casting an umber ambient drop shadow (`0 4px 12px rgba(10, 8, 6, 0.5)`).