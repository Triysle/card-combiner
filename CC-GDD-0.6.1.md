# Card Combiner - Game Design Document
 
**Version:** 0.6.1  
**Last Updated:** December 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Monster System](#monster-system)
3. [Card Mechanics](#card-mechanics)
4. [Card Visual System](#card-visual-system)
5. [Foil System](#foil-system)
6. [Deck & Discard System](#deck--discard-system)
7. [Hand System](#hand-system)
8. [Merging](#merging)
9. [Collection & Submission](#collection--submission)
10. [Economy](#economy)
11. [Booster Packs](#booster-packs)
12. [Upgrades](#upgrades)
13. [User Interface](#user-interface)
14. [Technical Specifications](#technical-specifications)
15. [Open Questions & Future Considerations](#open-questions--future-considerations)

---

## Overview

**Genre:** Incremental / Idle / Merge Game  
**Theme:** Monster collection  
**Platform:** Browser (HTML5 via Godot), desktop  
**Input:** Mouse-only (drag-and-drop focused)

**Core Fantasy:** Collect monsters, merge cards to increase their power, and complete your collection by submitting MAX-rank cards for every form.

**Design Pillars:**

- **Tactile card feel**: Drag-and-drop interactions for all card manipulation
- **Single currency simplicity**: Points drive all economic decisions
- **Progressive discovery**: New species and forms unlocked through gameplay
- **Clear win condition**: Submit MAX cards for all forms to complete the game

**Win Condition:** Submit a MAX card for every form of every species (all 123 forms collected).

---

## Monster System

### Species Unlock System

Players don't start with all 59 species available. Species unlock progressively:

- **Starting Species**: MID 001-010 (10 species active at game start)
- **Unlock Trigger**: Completing a species (submitting MAX for all its forms)
- **Unlock Reward**: Next sequential MID unlocks + free ★ base form card added to deck
- **Pack Generation**: Only draws from unlocked species
- **Collection Viewer**: Only shows unlocked species (header counter hints at more: "0/123 MAXED")

This prevents overwhelming new players with 59 species and creates meaningful progression milestones.

### Monster Identity

Each monster belongs to a **species** with multiple forms:

- **Base Form** (Form I): Starting form, available when species unlocks
- **Higher Forms** (Form II, III, etc.): Unlocked by submitting previous form's MAX card
- **Final Form**: Last form in the chain

Example chain: `Bees I (Honeet) → Bees II (Larvegg) → Bees III (Queenbee)`

### Monster Properties

Each monster species has:

- **MID (Monster ID)**: Three-digit identifier (e.g., 001)
- **Name**: Species name (e.g., "Bees", "Time Cat", "Buff Vegetable")
- **Base Color**: Primary species color for card gradient background
- **Secondary Color**: Complementary/analogous color for gradient
- **Gradient Type**: Direction/style of background gradient
- **Forms**: Array of forms with individual sprites and display names

Each monster form has:

- **Form Index**: 1 = base, 2 = second form, etc.
- **Display Name**: Punny/creative name for the form (e.g., "Meowment", "Purrpetual")
- **Sprite**: Monster artwork texture
- **Can Evolve**: Whether submitting this form unlocks the next

### Monster Roster

59 species with 123 total forms. See Appendix for full roster.

### Monster Registry

Monsters are defined via `MonsterSpecies` resources:

- Located in `resources/monsters/`
- Filename format: `{MID}_{species_name}.tres` (e.g., `006_bees.tres`)
- Each species has `base_color` and `secondary_color` properties for gradient backgrounds
- Each species has a `gradient_type` property (string enum)
- Each species has an array of `MonsterForm` resources
- **Web Export**: Uses explicit `preload()` statements (not runtime `DirAccess`) for browser compatibility

---

## Card Mechanics

### Card Identity

Cards represent monster instances with these properties:

- **Monster ID (MID)**: Which species this card represents
- **Form**: Current form (I, II, III, etc.)
- **Rank**: Power level within form (1-4 normal, 5 = MAX)
- **Foil**: Whether this is a foil variant (bonus points, animated holographic effect)

### Rank System (5 Ranks)

- **★** (Rank 1): Base rank from packs
- **★★** (Rank 2): Merge ★ + ★
- **★★★** (Rank 3): Merge ★★ + ★★
- **★★★★** (Rank 4): Merge ★★★ + ★★★
- **MAX** (Rank 5): Merge ★★★★ + ★★★★

**Display**: Ranks 1-4 show filled star icons (actual image assets via `star_filled.png`). Stars are always gold colored. MAX shows bold "MAX" text.

### Card Display

Cards show (from top to bottom):

- **Name Plate**: Ribbon texture with display name, tinted by rank
- **Monster Sprite**: Centered artwork
- **Info Plate**: Bottom bar with MID-Form (left) and rank stars/MAX (right), tinted by rank
- **Background**: Species-specific two-color gradient
- **Frame**: Dark border (consistent across all ranks)
- **Foil Overlay**: Holographic rainbow shimmer effect (if foil, covers background + sprite only)

### Card Back

- **Texture**: Loaded from `CardVisuals.card_back_texture` resource (`card_back_CCS.png`)
- **Used in**: Deck pile, collection grid (uncollected forms), pack opening animation
- **Border alignment**: Card back texture fills entire card area (no inset)

### Card Size

- **Hand slots / Discard**: 120×160 pixels
- **Drag previews**: 100×130 pixels (centered on cursor)
- **Pack opening**: 120×160 pixels (matches hand slots)
- **Collection viewer**: Dynamic (sized to fit 5 cards horizontally)

---

## Card Visual System

### Design Philosophy

**Species determines GRADIENT COLORS, Rank determines PLATE STYLE**

This ensures cards of the same species are immediately recognizable via their unique gradient, while rank progression is shown through plate coloring and effects.

### Species Gradient Backgrounds

Each species has a unique two-color gradient background:

**Properties (per species):**
- `base_color`: Primary species color
- `secondary_color`: Complementary or analogous color (generated programmatically, manually editable)
- `gradient_type`: Direction/pattern of the gradient

**Gradient Types (7 options):**
- `linear_horizontal`: Left to right
- `linear_vertical`: Top to bottom
- `linear_diagonal_down`: Top-left to bottom-right
- `linear_diagonal_up`: Bottom-left to top-right
- `radial_center`: Center outward
- `radial_corner`: Corner outward
- `diamond`: Diamond pattern from center

**Implementation**: Uses Godot's `GradientTexture2D` applied to a TextureRect, inset 3px from card edges.

### Rank Plate Styling

Name plate and info plate are styled based on rank:

| Rank | Color | Effect |
|------|-------|--------|
| ★ | Bronze `(0.80, 0.50, 0.20)` | Color modulation only |
| ★★ | Silver `(0.65, 0.65, 0.70)` | Color modulation only |
| ★★★ | Gold `(1.00, 0.84, 0.00)` | Color modulation only |
| ★★★★ | Platinum `(0.90, 0.90, 0.95)` | Sweeping highlight shimmer shader |
| MAX | Diamond `(0.40, 0.80, 1.00)` | Light blue glow with pulse animation shader |

### Star Display

- Stars rendered as image icons in an HBoxContainer
- Star size: 11×11 pixels (fits 4 stars in info plate)
- **Stars are always gold** `(1.0, 0.85, 0.0)` regardless of rank
- MAX cards show "MAX" label instead of stars

### Card Layering (bottom to top)

1. **Base Panel**: Dark fill with rounded corners
2. **Foil Content Container**: Groups gradient + sprite + foil overlay
   - **Gradient Background**: Species gradient, inset 3px
   - **Monster Sprite**: Centered artwork
   - **Foil Overlay**: Holographic shimmer (if foil) - contained here so plates are unaffected
3. **Name Plate**: Ribbon texture at top, rank-tinted
4. **Name Label**: Monster name text
5. **Info Plate**: Bar texture at bottom, rank-tinted
6. **MID Label**: "001-I" format text
7. **Rank Container**: Gold stars or MAX label
8. **Frame**: Dark border (topmost)

---

## Foil System

### Overview

Foil cards are visually distinct variants with animated holographic rainbow effects and bonus point generation. Foils are rare drops from packs and are preserved through the merge chain.

### Visual Appearance

- **Holographic shimmer**: Diagonal rainbow bands sweep across the card
- **Metallic specular highlights**: Sharp white bands for metallic shine
- **Effect scope**: Only covers background gradient and monster sprite
- **Unaffected elements**: Name plate, info plate, text labels, stars, frame
- **Per-instance variation**: Each card has randomized animation timing and speed (±10%) to prevent synchronized shimmer across multiple foils

**Shader details:**
- Rainbow hue shifts based on position and time
- Two-layer specular highlights at different angles
- Additive blend mode for bright, dazzling effect
- Shader state preserved during drag/drop operations (no jarring restarts)

### Foil Mechanics

- **Pack-Only Source**: Foils only drop from booster packs. Base chance is 0%, increased via Foil Chance upgrade.
- **One Per Pack Maximum**: Each pack rolls once for foil chance. If successful, exactly one random card in the pack becomes foil.
- **Merge Inheritance**: If either parent card is foil, the result is foil. Merging two non-foils always produces a non-foil.
- **MAX Always Foil**: All MAX cards are automatically foil, regardless of parent foil status.
- **Submission**: Foil MAX cards submit normally, no special treatment.

**Foil Flow Example:**
```
Non-foil ★ + Non-foil ★ = Non-foil ★★
Foil ★ + Non-foil ★ = Foil ★★
Foil ★★ + Foil ★★ = Foil ★★★
Any ★★★★ + Any ★★★★ = Foil MAX (always)
```

### Point Bonus

Foil cards generate bonus points in hand slots:

- **Base Bonus**: Foil cards generate 2× points
- **Upgraded Bonus**: Foil Bonus upgrade increases multiplier (2×→4×→8×→16×→32×→64×→100×)

**Formula:**
```
Card Points = Form × Rank × (Foil Multiplier if foil)
Display in slot: Shows foil-boosted value
```

---

## Deck & Discard System

### Layout Structure

Both Deck and Discard use consistent VBoxContainer layout:

1. **Label above**: "DECK" or "DISCARD" (matches "HAND" styling)
2. **Slot panel**: Contains card display area and count
3. **Card area**: Top ~85% of slot (cards aligned to top)
4. **Count area**: Bottom ~15% of slot

### Deck

- **Label**: "DECK" centered above slot
- **Visual**: Face-down card back (from CardVisuals resource) when cards present
- **Count**: "(X)" displayed at bottom of slot
- **Starting state**: Empty (0 cards - first pack is free)
- **No upper limit**: Deck grows indefinitely via booster packs
- **Interaction**: Click deck to draw (when timer ready)
- **Ready indicator**: Green overlay when draw available
- **Shuffle state**: Dimmed card back when deck empty but discard has cards

### Discard Pile

- **Label**: "DISCARD" centered above slot
- **Visual**: Face-up top card when cards present
- **Count**: "(X)" displayed at bottom of slot
- **True stack**: Multiple cards accumulate
- **Top card only**: Player interacts with top card only
- **Interactions**:
  - Drag to hand slot (place card)
  - Drag to matching card (merge)
  - Receive cards discarded from hand

### Drawing

- **Timer-based**: Cooldown between draws (starts at 10 seconds)
- **Draw action**: Top card moves face-up to discard pile
- **Full hand**: Drawing still works; card goes to discard pile

### Shuffle Trigger

When deck is empty and player attempts to draw:

1. Entire discard pile shuffles into deck
2. Automatic draw occurs

**Also triggers on**: Opening a booster pack

---

## Hand System

### Hand Slots

- **Fixed size**: 10 slots (no upgrades)
- **Layout**: 2 rows of 5 slots, horizontally centered
- **Label**: "HAND" centered above grid
- **Empty slots**: No text displayed (clean empty state)

### Slot Layout

Each slot uses consistent structure:
- **Card area**: Top portion (cards sized 120×154 within slot)
- **Output area**: Bottom portion showing point generation

### Slot Functionality

- Cards in slots generate Points per tick
- Cards can be dragged to other slots (swap)
- Cards can be dragged to discard pile
- Cards can be dragged onto matching cards to merge
- Empty slots receive cards from discard pile
- Shows point generation rate below each card ("+X/s") including foil bonus

### Drag Preview

- **Size**: 100×130 pixels
- **Position**: Centered on cursor (wrapped in container for offset)
- **Foil preservation**: Foil shader continues animating during drag

---

## Merging

### Basic Merge

**Mechanic**: Drag one card onto another matching card.

**Match Requirements**:

- Same Monster ID (MID)
- Same Form
- Same Rank
- Neither card is MAX

**Result**: One card consumed, remaining card gains +1 Rank, inherits foil status

### Rank Progression

- ★ + ★ → ★★
- ★★ + ★★ → ★★★
- ★★★ + ★★★ → ★★★★
- ★★★★ + ★★★★ → MAX (always foil)

### MAX Cards

- Created by merging two ★★★★ cards of the same MID/form
- MAX cards cannot be merged (must be submitted)
- MAX cards are always foil
- MAX cards generate 5 points/s base (Form × 5)

### Foil on Merge

- Result is foil if either parent is foil
- Merging two non-foils produces a non-foil
- MAX cards are always foil regardless of parents
- **No random roll on merge** - foils only come from packs

### Merge Targets

- Cards in hand slots (result stays in hand)
- Top card of discard pile (result goes to discard)

---

## Collection & Submission

### Collection Panel (Right Panel)

Combined panel containing both collection viewer access and submission:

- **Header**: "COLLECTION" (font size 16)
- **Open Button**: "Open Collection" button
- **Rate Label**: Shows collection points per second ("+X/s")
- **Submit Slot**: Drop zone for MAX cards with "Drop MAX card here" text
- **Add Button**: "Add to Collection" button (disabled until MAX card placed)

### Collection Point Generation

Submitted MAX cards passively generate points:

- **Base Rate**: 100 points per submitted MAX card per tick
- **With Upgrade**: 100 × submitted_count × (1.0 + Collection Boost level × 0.1)

### Submit Slot

- Accepts MAX cards only
- Cannot accept already-submitted forms
- Dragging card away returns it to discard

### Submission Flow

1. **Drop MAX card** in submit slot
2. **Click "Add to Collection"** button
3. **Collection popup opens** automatically
4. **Auto-scroll** to the submitted MID's row
5. **Card flip animation**: Card starts face-down, then flips to face-up (submitted state)
6. **Collection closes** after animation
7. **Popup sequence**:
   - If final form of species AND new species unlocked → Final Form Popup, then Unlock Popup (new species card)
   - If final form of species, no unlock available → Final Form Popup only
   - If not final form → Unlock Popup (next form card)
   - If game complete → Win Screen

### Collection Viewer

**Layout:**
- **Nearly fullscreen**: 10px padding from screen edges
- **Header**: "COLLECTION - X/123 MAXED" with Close button
- **Column headers**: Form numerals (I, II, III...) - fixed position, does not scroll
- **Grid structure**: Species (MID) as rows, Forms as columns
- **Row headers**: MID labels on left (font size 20)
- **Card sizing**: Calculated to fit 5 cards horizontally (no horizontal scroll)
- **Vertical scroll**: Enabled for species rows only (column headers stay fixed)
- **Initial state**: Hidden on load (instantiated but not visible)
- **Species Filter**: Only shows unlocked species (not all 59)

**Card States** (two visual states):
- **Submitted**: Full color foil MAX card with green border - face up
- **Not Collected**: Card back (face down) - same appearance whether form unlocked or locked

**MID Label Colors**:
- Dark green (0.15, 0.5, 0.1): All forms of this species submitted
- Dark gold (0.6, 0.5, 0.1): Some forms submitted
- Dark grey (0.2, 0.2, 0.2): No forms submitted

### Unlock Popup

Appears when unlocking new content:

- **Style**: Same as pack opening (dark overlay, panel_bg, centered)
- **Title**: "Unlocked [Card Name]!" (works for both forms and species)
- **Content**: Face-down ★ card of the new form/species
- **Animation**: Card auto-flips to reveal face
- **Button**: "Add to Deck" (appears after flip completes)
- **Action**: Closes popup (card already added to deck by GameState)

### Final Form Popup

Appears when submitting a final form MAX card:

- **Style**: Same as pack opening (dark overlay, panel_bg, centered)
- **Title**: "Final Form MAX!"
- **Content**: "Collection Progress: X/123"
- **Subtitle**: "New species unlocked!" (if applicable)
- **Button**: "OK"
- **Action**: Closes popup, then shows Unlock Popup if species was unlocked

### Win Screen

Appears when all forms of all species are collected:

- **Style**: Full overlay screen (dark background, panel_bg)
- **Title**: "You Win!" (font size 36, dark green)
- **Message**: "Thank you for playing!" (font size 18)
- **Buttons**:
  - "Credits" - Closes win screen, opens credits overlay
  - "Reset Save (New Game)" - Resets game and reloads scene

---

## Economy

### Single Currency: Points

Points are the sole currency, used for:

- Purchasing booster packs
- Purchasing upgrades

### Point Generation

Points come from two sources: hand cards and collection.

**Hand Cards:**
```
Card Points = Form × Rank × (Foil Multiplier if foil)
Hand Rate = Sum of all card points in hand
```

**Collection:**
```
Collection Rate = 10 × submitted_count × (1.0 + Collection Boost level × 0.1)
```

**Total per Tick:**
```
Points per Tick = (Hand Rate + Collection Rate) × (1.0 + Points Boost level × 0.1)
```

**Example**: 
- Hand: Form II × Rank 3 × Foil (8×) = 48 pts
- Collection: 5 submitted × 100 × 1.2 (20% boost) = 600 pts
- Total: (48 + 600) × 1.1 (10% points boost) = 712 pts/tick

**Note**: Cards in deck or discard do NOT generate points.

### Pack Cost

**Formula**:
```
Base Cost = Total Card Value × 10
Final Cost = Base Cost × (100 - Pack Discount%) / 100
```

Where Total Card Value = sum of (Form × Rank) for all owned cards.

**First Pack**: Free (0 cards = 0 cost)
**Maximum Discount**: 90% (packs never become free)

### Softlock Prevention

If player has 0 cards and cannot afford a pack, a free pack is automatically granted.

---

## Booster Packs

### Contents

- **5 cards per pack**
- **Variable monsters**: Random from unlocked species' unlocked forms
- **Variable ranks**: Heavily weighted toward ★
- **Foil chance**: One roll per pack; if successful, one random card becomes foil

### Rank Distribution

| Rank | Chance |
|------|--------|
| ★ | 90% |
| ★★ | 9% |
| ★★★ | 1% |
| ★★★★ | 0% (merge only) |
| MAX | 0% (merge only) |

### Pity System

- Slot 5: 90% chance ★★, 10% chance ★★★

### Foil Distribution

- Pack rolls once for foil chance (based on Foil Chance upgrade level, max 90%)
- If successful, exactly ONE random card in the pack becomes foil
- Maximum one foil per pack regardless of chance percentage

### Pack Opening Animation

1. Player clicks "Buy Booster Pack"
2. Cost deducted
3. Overlay appears with "Opening Pack..." title
4. 5 cards slide in face-down, then flip to reveal
5. Foil cards display holographic shimmer effect
6. "Add to Deck" button fades in
7. Cards added to deck on confirm
8. Deck shuffles

---

## Upgrades

### Upgrade Philosophy

Upgrades are divided into three tiers based on impact and cost scaling:

- **Minor Upgrades**: Incremental percentage bonuses, cheap and frequently purchased
- **Average Upgrades**: Steady progression toward meaningful caps, moderate cost growth
- **Major Upgrades**: Significant gameplay-changing effects, expensive milestones

### Available Upgrades

| Upgrade | Type | Effect | Cap | Starting Cost | Scaling |
|---------|------|--------|-----|---------------|---------|
| Points Boost | Minor | +10% additive to total points | None | 10 | 10 + 50 × level |
| Collection Boost | Minor | +10% additive to collection points | None | 100 | 100 + 50 × level |
| Pack Discount | Average | +1% off pack cost | 90% | 1,000 | 1000 × (level+1)² |
| Foil Chance | Average | +1% foil chance per pack | 90% | 1,000 | 1000 × (level+1)² |
| Draw Speed | Major | Halves draw cooldown | 0.5s (5 levels) | 100 | 100 × 10^level |
| Foil Bonus | Major | Doubles foil point multiplier | 100× (6 levels) | 10,000 | 1000 × 10^(level+1) |

### Upgrade Details

**Points Boost (Minor)**
- Effect: Multiplies total point income by (1.0 + level × 0.1)
- Level 0: 100% → Level 10: 200% → Level 20: 300%
- Cost examples: 10, 60, 110, 160, 210...

**Collection Boost (Minor)**
- Effect: Multiplies collection point income by (1.0 + level × 0.1)
- Level 0: 100% → Level 10: 200% → Level 20: 300%
- Cost examples: 100, 150, 200, 250, 300...

**Pack Discount (Average)**
- Effect: Reduces pack cost by level %
- Level 10: 10% off → Level 50: 50% off → Level 90: 90% off (MAX)
- Cost examples: 1K, 4K, 9K, 16K, 25K...

**Foil Chance (Average)**
- Effect: level % chance for one foil card per pack
- Level 10: 10% → Level 50: 50% → Level 90: 90% (MAX)
- Cost examples: 1K, 4K, 9K, 16K, 25K...

**Draw Speed (Major)**
- Effect: Draw cooldown = 10s / 2^level (minimum 0.5s)
- Level 0: 10s → Level 1: 5s → Level 2: 2.5s → Level 3: 1.25s → Level 4: 0.625s → Level 5: 0.5s (MAX)
- Cost: 100, 1K, 10K, 100K, 1M

**Foil Bonus (Major)**
- Effect: Foil cards generate 2^(level+1) × points (capped at 100×)
- Level 0: 2× → Level 1: 4× → Level 2: 8× → Level 3: 16× → Level 4: 32× → Level 5: 64× → Level 6: 100× (MAX)
- Cost: 10K, 100K, 1M, 10M, 100M, 1B

### Upgrade Display Format

Each upgrade button shows:
```
Name - Cost
Description: current value → next value
```

Example:
```
Collection Boost - 150
+0% -> +10% collection points
```

When maxed:
```
Foil Chance - MAX
90% foil chance per pack
```

### Button States

- **Affordable**: Normal button style, clickable
- **Can't Afford**: Disabled style, shows progress bar at bottom
- **Maxed**: Pressed/pushed-in style, no progress bar

### Progress Bar

Each upgrade button displays a progress bar showing how close the player is to affording it:

- **Position**: Bottom of button, inside button bounds
- **Style**: Semi-transparent white fill on transparent background
- **Height**: 4 pixels
- **Corners**: Rounded on bottom-left and bottom-right to match button contour
- **Visibility**: Hidden when upgrade is affordable or maxed

---

## User Interface

### Layout (Two-Panel)

**Top-Left Corner** (floating):
- Settings button
- "How to Play" button

**Center Panel**:
- Title panel: "CARD COMBINER" in styled panel background (PanelContainer with StyleBoxTexture)
- Booster Pack button
- Deck and Discard piles (labels above, consistent slot styling)
- "HAND" label
- 10 hand slots (2 rows × 5)

**Right Panel** (top to bottom):
- Points panel (header font size 16)
- Upgrades panel (header font size 16)
- Collection panel (header font size 16, includes rate label and submit slot)

### Panel Styling

All panels use consistent `panel_bg.svg` texture:
- Settings popup
- How to Play popup
- Collection viewer
- Credits overlay
- Pack opening overlay
- Unlock popup
- Final form popup
- Win screen
- Points panel
- Upgrades panel
- Collection panel

### Slot Styling

All slots use consistent `slot_bg.svg` texture with no color tinting:
- Hand slots
- Deck slot
- Discard slot
- Submit slot

### Button Styling

Buttons use a grey color scheme with 3D depth effect:

- **Idle**: Grey (#a8a8a8) with darker bottom shadow (#787878)
- **Hover**: Brighter grey (#b8b8b8) with shadow (#888888)
- **Pressed**: Flat grey (#909090), no shadow (pushed-in appearance)
- **Disabled**: Muted grey (#808080) with shadow (#686868)
- **Focus**: Empty StyleBox (prevents focus from overriding pressed state)

### Text Styling

**Panel Headers**: Font size 16, color (0.25, 0.2, 0.15) - dark brown

**All counts and rates**: Dark text matching game style (no outlines)
- Deck count
- Discard count
- Hand slot output (+X/s)
- Points rate (+X/s)
- Collection rate (+X/s)

### Points Display

```
POINTS
1,234
+56/s
```

### Upgrades Panel

Always visible with "UPGRADES" header (not collapsible).

Each upgrade is a single button containing:
- Line 1: `Name - Cost` (or `Name - MAX` when maxed)
- Line 2: Description with current → next value
- Progress bar at bottom (when not affordable and not maxed)

### Debug Panel

- Hidden by default
- Toggle with Ctrl+`
- Appears in center area (between deck/discard and hand)
- Functions: Grant 1M Points, Create MAX Card, Create Foil Card

### Pack Opening Overlay

- Dark semi-transparent background
- "Pack Opened!" title
- 5 cards displayed at 120×160 size
- Button always present but invisible until animation completes (prevents layout jump)
- "Add to Deck" button fades in below

### Collection Popup

- Nearly fullscreen (10px padding from edges)
- Header: "COLLECTION - X/123 MAXED" with Close button
- Column headers: Form numerals (I, II, III...) - fixed, does not scroll
- Grid: MID labels (rows) × Form cards (columns)
- Cards sized to fit 5 horizontally
- Vertical scroll for species rows only
- Auto-scrolls to relevant MID on submission
- Supports flip animation for newly-submitted cards
- Only shows unlocked species

### How to Play

Popup with instructions:
1. Buy Booster Packs to get cards
2. Click the deck to draw cards
3. Move cards to your Hand to generate points
4. Combine matching cards to rank up (★ → ★★ → ★★★ → ★★★★ → MAX)
5. Submit MAX cards to your collection
6. Complete a species to unlock the next one!
7. Foil cards give bonus points - upgrade your luck!
8. Your collection generates passive points!

Complete your collection to win!

### Credits

- Created by Tee
- Made with Godot 4.5 and Claude Opus 4.5
- Art by Chequered Ink (https://ci.itch.io/all-game-assets)
- Font: Roboto Slab
- Playtesters: Alanox, Harbinger, Kittara, Malikav

---

## Technical Specifications

### Platform

- Godot 4.5.1
- Browser-based (HTML5 export via GitHub Pages)
- Mouse-only controls

### Tick Rate

- **Base tick**: 1 second
- **Point generation**: Calculated per tick
- **Draw cooldown**: Decrements continuously

### Key Scripts

| Script | Purpose |
|--------|---------|
| `game_state.gd` | Core game logic, save/load, point calculation, upgrade costs/effects |
| `main.gd` | Scene orchestration, UI setup, submission flow |
| `card_factory.gd` | Card creation, point value calculation (Form × Rank) |
| `card_display.gd` | Unified card rendering with gradients, plate shaders, foil overlay |
| `card_visuals.gd` | Visual configuration resource (card back, plate textures, drop colors) |
| `monster_registry.gd` | Monster definitions via explicit preloads (web-compatible) |
| `monster_species.gd` | Species resource with base_color, secondary_color, gradient_type, forms |
| `monster_form.gd` | Form resource with display_name and sprite |
| `slot.gd` | Hand slot behavior, foil-aware point display, smart card recreation |
| `discard_pile.gd` | Discard pile behavior (VBoxContainer) |
| `deck_pile.gd` | Deck behavior and drawing (VBoxContainer) |
| `grid.gd` | Hand slot grid management |
| `pack_opening.gd` | Pack opening animation |
| `deck_viewer.gd` | Collection viewer popup with fixed headers and flip animation |
| `collection_panel.gd` | Collection panel with rate display and submit functionality |
| `upgrades_panel.gd` | Upgrade display, purchase, and progress bar management |
| `unlock_popup.gd` | New form/species unlock popup |
| `final_form_popup.gd` | Final form submission popup |
| `win_screen.gd` | Win screen with credits/reset |
| `credits_overlay.gd` | Credits popup |

### Shader Files

| Shader | Purpose |
|--------|---------|
| `foil_shimmer.gdshader` | Holographic rainbow effect with metallic specular highlights |
| `plate_platinum.gdshader` | Sweeping highlight shimmer for ★★★★ plates |
| `plate_diamond.gdshader` | Light blue glow with pulse for MAX plates |

### Resource Files

| Resource | Location | Purpose |
|----------|----------|---------|
| Monster Species | `resources/monsters/*.tres` | 59 species definitions with colors, gradient type, forms |
| Card Visuals | `resources/default_card_visuals.tres` | Card back, plate textures, drop colors |
| Game Theme | `resources/game_theme.tres` | Button styles, fonts, focus handling |
| Star Icon | `assets/UI/star_filled.png` | Star image for rank display (always gold) |
| UI Assets | `assets/UI/*.svg` | Panel backgrounds, button states, slot backgrounds |
| Card Back | `assets/cardbacks/card_back_CCS.png` | Card back texture |
| Monster Sprites | `assets/monsters/*.png` | Monster artwork (1-5 forms per species) |

### Card Data Structure

```gdscript
Card = {
  mid: int,       # Monster ID (e.g., 1 for "001")
  form: int,      # 1 = base, 2 = second form, etc.
  rank: int,      # 1-4 normal, 5 = MAX
  is_max: bool,   # true for MAX cards (rank 5)
  is_foil: bool   # true for foil variants
}
```

### Key Constants

```gdscript
MAX_NORMAL_RANK = 4      # Highest rank before MAX (★★★★)
MAX_CARD_RANK = 5        # MAX cards are rank 5
COLLECTION_POINTS_PER_MAX = 10  # Points per submitted card per tick
STARTING_SPECIES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  # MIDs 001-010
```

### Save Data

- `deck`: Array of cards
- `discard`: Array of cards  
- `hand`: Array of cards (or empty dict for empty slots)
- `points`: int
- `upgrade_levels`: Dictionary
- `unlocked_species`: Array of MIDs
- `unlocked_forms`: Dictionary {mid: highest_unlocked_form}
- `submitted_forms`: Dictionary {mid: [form_indices]}
- `packs_purchased`: int

### Save Version

**Version "0.6.1"** - Balance pass: revised upgrade system, one foil per pack, progress bar UI

---

## Open Questions & Future Considerations

### Balance Questions

- Is 8-12 hour completion time appropriate?
- Late-game pacing once Pack Discount reaches 90%
- Foil Bonus level 6 (1B cost) as post-game trophy - too extreme?

### UX Questions

- Sound effects for merges, MAX creation, submission, foil reveal?
- Special animation for foil cards in packs?

### Future Features

- Monster abilities / special effects
- Achievements
- Statistics tracking (for win screen)
- Offline progress
- Prestige system

### Resolved in v0.6.1

- Complete upgrade system rebalance:
  - Points/Collection changed from 2× doubling to +10% additive
  - Pack Discount/Foil Chance capped at 90% instead of 100%
  - Draw Speed starts at 100, scales ×10 per level
  - Foil Bonus starts at 10K, caps at 100× (6 levels)
- One foil maximum per pack (random slot selection)
- Progress bar UI on upgrade buttons showing cost progress
- Adjusted starting costs: Points=10, Collection=100, Draw Speed=100

### Resolved in v0.6.0

- Foil system: foils only from packs, inheritance on merge
- MAX cards are always foil
- Foil overlay only affects background + sprite (not plates)
- Per-instance foil animation randomization
- SAVE_VERSION changed to string format

### Files to Delete (Housekeeping)

The following files are no longer used and can be removed:
- `scripts/resources/game_config.gd` (never instantiated)
- `assets/rank_backgrounds/rank_01_solid.svg` through `rank_10_ornate.svg` (all 10)
- `resources/shaders/rank_01_vignette.gdshader` through `rank_10_max.gdshader` (all 10)
- `assets/cardbacks/card_back_CCLOGOS.png` (unused alternate)

Keep these shaders:
- `foil_shimmer.gdshader`
- `plate_platinum.gdshader`
- `plate_diamond.gdshader`

---

*Version: 0.6.1*  
*Reflects implemented state as of December 2025*
