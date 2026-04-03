# Chibi Creator

Create new pixel art chibi characters for OCC (One's Command Center). Each character is a 10x10 grid of color-indexed pixels with idle, ready, and walking animation frames.

## File

All characters live in `OCC/UI/ChibiView.swift`.

## Architecture

### 1. Register the character

Add a new case to `ChibiCharacter` enum and its label:

```swift
enum ChibiCharacter: String, CaseIterable {
    case cat, dog, bunny, owl, fox, panda, penguin
    case slime, ghost, robot, sprout, star, octopus, mushroom, alien, tanuki, dragon
    case yourNewChar  // <-- add here

    var label: String {
        // ...
        case .yourNewChar: return "Name"  // <-- short display name (max 6 chars)
    }
}
```

### 2. Create 3 pixel grids

Each grid is a `[[Int]]` — 10 rows x 10 columns. Each `Int` is a color index:

| Index | Meaning | Notes |
|-------|---------|-------|
| 0 | Transparent | Background |
| 1 | Body / primary color | Main fill |
| 2 | Secondary / accent | Ears, markings, darker areas |
| 3 | Eyes | Use `e` variable (swaps to `1` when blinking) |
| 4 | Nose / mouth | Small detail |
| 5 | Cheeks / blush | Rosy highlights |
| 6-9 | Extra colors | Character-specific (horns, spots, feet, etc.) |

#### Grid A: Idle (`pixels(for:)`)

The resting pose. Character standing still, facing forward.

```swift
case .yourNewChar:
    return [
        [0,0,0,0,0,0,0,0,0,0],  // row 0 - top (ears/horns/hair)
        [0,0,0,0,0,0,0,0,0,0],  // row 1
        [0,0,1,1,1,1,1,1,0,0],  // row 2 - head top
        [0,1,1,1,1,1,1,1,1,0],  // row 3 - head
        [0,1,e,1,1,1,e,1,1,0],  // row 4 - eyes (use `e` for blinking)
        [0,1,1,1,4,4,1,1,1,0],  // row 5 - nose
        [0,1,5,1,1,1,1,5,1,0],  // row 6 - cheeks
        [0,0,1,1,1,1,1,1,0,0],  // row 7 - body
        [0,0,1,1,1,1,1,1,0,0],  // row 8 - body
        [0,0,1,1,0,0,1,1,0,0],  // row 9 - feet
    ]
```

**Rules:**
- Eyes MUST use the `e` variable (not hardcoded `3`), so blinking works
- Keep it symmetrical or near-symmetrical
- Transparent (0) around edges to form the silhouette
- Feet on row 9 for walk animation

#### Grid B: Ready (`readyPixels(for:)`)

Eyes look left/right alternately. Used when AI has picked up a request and is getting ready.

```swift
case .yourNewChar:
    // `eL` = left eye, `eR` = right eye (alternate which is open)
    return [
        // Same as idle but with eL/eR instead of e
        // Row 4: [0,1,eL,1,1,1,eR,1,1,0]
    ]
```

**Rules:**
- Use `eL` and `eR` variables (they alternate which eye is "looking")
- Body/ears can also shift slightly between frames using `f` (readyFrame bool)
- Everything else stays the same as idle

#### Grid C: Walking (`walkPixels(for:)`)

Legs alternate between two positions. Used when AI is actively working.

```swift
case .yourNewChar:
    // `f` = walkFrame (alternates true/false every 0.3s)
    return [
        // Rows 0-8: same as idle
        // Row 9: alternate foot positions
        f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
    ]
```

**Rules:**
- Only the bottom 1-2 rows should change between frames
- Frame A: feet spread apart (wider)
- Frame B: feet together (narrower)
- Use `f` (walkFrame bool) to switch
- Creatures without legs (slime, ghost, octopus) can jiggle/shift instead

### 3. Create a color palette

Add a case to `palette(for:)`. Return a closure mapping index → Color:

```swift
case .yourNewChar:
    return { v in
        switch v {
        case 1: return Color(red: R, green: G, blue: B)  // body
        case 2: return Color(red: R, green: G, blue: B)  // accent
        case 3: return Color(red: R, green: G, blue: B)  // eye color
        case 4: return Color(red: R, green: G, blue: B)  // nose/mouth
        case 5: return Color(red: R, green: G, blue: B)  // cheek blush
        default: return .clear
        }
    }
```

**Color guidelines:**
- Use RGB values 0.0-1.0
- Body colors should be soft/pastel — nothing too saturated
- Eyes should be dark (0.10-0.20 range) for contrast
- Cheeks should be warm pink/peach tones
- Keep the overall feel cute and friendly

### 4. Verify

After adding all 4 pieces (enum case, idle grid, ready grid, walk grid, palette):

```bash
swift build
```

The character automatically appears in the settings picker in the menu bar popover.

## Design Tips

- **Silhouette first**: sketch the outline with 1s and 0s, then add details
- **Eyes make it cute**: big eyes (1 pixel each at minimum) centered on the face
- **Cheeks are key**: rosy cheeks (index 5) make everything adorable
- **Less is more**: at 10x10, every pixel counts — don't overcrowd
- **Test blinking**: make sure the eye positions look natural when closed (replaced with body color)
- **Symmetry**: most characters look best nearly symmetrical
- **Unique silhouette**: each character should be recognizable by outline alone

## Existing Characters for Reference

| Character | Key Features | Special Colors |
|-----------|-------------|----------------|
| Cat | Pointed ears (2), beige body | — |
| Dog | Floppy ears (2), golden | — |
| Bunny | Tall straight ears | — |
| Owl | Wide head, big eye rings (6) | 6=eye ring |
| Fox | Orange with white cheeks (8) | 7=ear inner, 8=white |
| Panda | Black patches around eyes | — |
| Penguin | White belly, dark body | 9=orange feet |
| Slime | Blob shape, no feet | Jiggles instead of walking |
| Ghost | Wavy bottom, no feet | Bottom edge alternates |
| Robot | Antenna, metal body | 6=eye socket cyan |
| Sprout | Leaf on head (6) | 6=green leaf |
| Star | Five-pointed shape | Points wiggle when walking |
| Octo | Tentacles at bottom | Tentacles alternate |
| Shroom | Red cap with spots (6) | 6=cap spots |
| Alien | Big double-wide eyes, antennae | — |
| Tanuki | Dark face mask (2) | — |
| Dragon | Horns (6), scale accents | 6=orange horns |

## Animation System

The animations are handled automatically by `ChibiView`. You only need to provide the pixel grids. The view handles:

- **Blinking**: every 2-4.5s, eyes close for 0.1s (occasional double-blink)
- **Bounce**: springs up when notification arrives
- **Ready**: alternates `readyFrame` every 0.6s (eyes look around)
- **Walking**: alternates `walkFrame` every 0.3s with bob + lean
- **Speech bubble**: pixel bubble with count appears when notifications exist
- **Hover**: scales up 1.2x with spring animation
