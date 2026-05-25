# Garden Store System Update

## Overview

The Garden Store has been completely redesigned based on the Plant System Specification to implement a proper growth and harvest economy powered by XP and water drops (💧).

## What Changed

### 1. New Categories

**Old categories:**
- 🌱 Seeds
- 🪨 Decor
- 🕊 Animals

**New categories:**
- 🌳 Trees (5 species)
- 🌿 Bushes (2 species)
- 🌻 Small Plants (4 species)

### 2. New Plant Catalog (11 Species)

All items are now **seeds that grow into plants** with a proper stage-based growth system:

#### Trees (32×32 grid)
- **Oak** - 3000 XP, 10 stages, Legendary
- **Pine** - 3000 XP, 10 stages, Legendary
- **Cherry** - 1500 XP, 7 stages, Epic
- **Olive** - 1500 XP, 7 stages, Epic (Biblical ✅)
- **Fig** - 1500 XP, 7 stages, Epic (Biblical ✅)

#### Bushes (16×16 grid, 7 stages)
- **Mustard** - 800 XP, Rare (Biblical ✅)
- **Rose** - 800 XP, Rare

#### Small Plants (16×16 grid, 4 stages)
- **Lavender** - 200 XP, Common
- **Wheat** - 200 XP, Common (Biblical ✅)
- **Sunflower** - 200 XP, Common
- **Tulip** - 200 XP, Common

### 3. Economy Changes

The new system follows the spec from `PLANT_SYSTEM_SPEC.md`:

**Pricing structure:**
- Small plants (4 stages): 200 XP
- Bushes (7 stages): 800 XP
- Trees (7 stages): 1500 XP
- Trees (10 stages): 3000 XP

**Growth costs:**
- Each stage requires **5 💧 (water drops)**
- Total water to mature:
  - Small plants: 20 💧
  - Bushes: 35 💧
  - Trees (7-stage): 35 💧
  - Trees (10-stage): 50 💧

**Harvest rewards:**
- Small plants: +100 XP
- Bushes: +250 XP
- Trees (7-stage): +500 XP
- Trees (10-stage): +1000 XP

**Important:** Harvest XP is intentionally **less than** seed cost. This ensures most XP comes from reading the Bible, not farming the garden.

### 4. UI/UX Updates

**Store tagline updated:**
> "Spend XP on seeds. Plant in your garden — spend 5 💧 per stage to grow. Harvest for XP!"

**Detail sheet:**
- Changed emoji from 🌱 to 💧 to emphasize water-based growth
- Updated description: "Spend 5 💧 per stage to grow. Harvest fruit for +XP!"
- Color scheme changed to water blue (#7FCBFF)

**Category labels:**
- Updated to show "TREE", "BUSH", or "SMALL PLANT" instead of old categories

### 5. Code Changes

**Files modified:**
- `YGTeeV/Views/Plans/GardenStoreView.swift` - Complete redesign of store items and categories
- `YGTeeV/Views/Plans/GardenFullView.swift` - Updated plant placement logic to support all three categories

**Key changes:**
```swift
// Old
enum ItemCategory {
    case seeds, decor, animals
}

// New
enum ItemCategory {
    case trees, bushes, smallPlants
}
```

**Placement logic:**
```swift
// Now accepts trees, bushes, and smallPlants
if item.category == .trees || item.category == .bushes || item.category == .smallPlants {
    // Plant it in the garden
}
```

## Integration with Existing System

### Compatible Features

✅ **XP balance** - Already displayed in store header
✅ **Purchase flow** - Works with existing purchase logic
✅ **Garden placement** - Uses existing `GardenItem` model
✅ **Water tracking** - Connects to existing water currency

### Not Yet Implemented (Future Work)

The following features from `PLANT_SYSTEM_SPEC.md` are **not yet implemented** in the iOS app but are designed into the spec:

🔲 **Withering** - Plants wither after 48 hours without water
🔲 **Ripening clock** - 30-minute countdown after reaching final stage
🔲 **Harvest flow** - Tap mature plant → harvest sheet → gain XP
🔲 **Stage drop-back** - After harvest, plant drops back 2 stages
🔲 **Per-stage sprites** - Currently using placeholder pixel trees
🔲 **Water UI** - 5-pip progress meter (●●●○○) for stage progress
🔲 **Bloom effects** - Sparkle FX on harvest-ready plants

### Data Model Requirements (For Future Implementation)

The spec defines this data model:

```swift
struct PlantSpecies {
    let id: String              // "cherry"
    let label: String           // "Cherry Tree"
    let tier: Tier              // .tree | .bush | .small
    let grid: Int               // 16 or 32
    let stages: Int             // 4, 7, or 10
    let isBiblical: Bool
    let seedCostXP: Int         // 200 / 800 / 1500 / 3000
    let harvestXP: Int          // 100 / 250 / 500 / 1000
}

enum PlantState {
    case growing(stage: Int, waterIntoNextStage: Int)
    case withered(stage: Int, waterIntoNextStage: Int)
    case ripening(readyAt: Date)
    case harvestReady
    case harvested
}
```

This should be implemented when adding the full harvest system.

## Testing Checklist

- [x] Store builds without errors
- [x] All 11 species display correctly
- [x] Category filters work (Trees, Bushes, Small Plants)
- [x] XP costs match the spec
- [x] Purchase flow works
- [x] Plant placement works for all categories
- [ ] **TODO:** Test actual watering mechanics
- [ ] **TODO:** Verify water drop spending
- [ ] **TODO:** Implement harvest flow
- [ ] **TODO:** Add plant sprites from `ygteev-plant-sprites.zip`

## Sprite Assets Needed

The spec references a sprite pack at:
> `/Users/jimjacob/Downloads/YGTeeV (11)/Plant Growth Sprites.html`

This contains downloadable sprites for all 11 species with:
- Individual stage PNGs (e.g., `cherry-stage-01.png` through `cherry-stage-07.png`)
- Withered state sprites
- Bloom sprites for harvest-ready state
- FX overlays (sparkle, water, heart)

These need to be imported into `Assets.xcassets` when implementing the full visual system.

## Biblical Plants

4 of the 11 species have Biblical significance:
- 🫒 **Olive** - Symbol of peace (Genesis 8:11)
- 🌳 **Fig** - The fig tree will blossom (Habakkuk 3:17)
- 🌿 **Mustard** - The smallest of all (Mark 4:31)
- 🌾 **Wheat** - Harvest of righteousness (James 3:18)

## Next Steps

1. ✅ Update store categories and items
2. ✅ Update pricing to match spec
3. ✅ Fix category references in GardenFullView
4. 🔲 Import sprite assets from Plant Growth Sprites pack
5. 🔲 Implement PlantSpecies data model
6. 🔲 Implement PlantState enum with all states
7. 🔲 Add water spending UI (5-pip meter)
8. 🔲 Implement withering logic (48-hour timer)
9. 🔲 Implement ripening clock (30 minutes)
10. 🔲 Implement harvest flow with stage drop-back
11. 🔲 Add sparkle FX for harvest-ready plants
12. 🔲 Wire up XP earning from harvests

## Reference Documents

- **Full spec:** `/Users/jimjacob/Downloads/YGTeeV (11)/PLANT_SYSTEM_SPEC.md`
- **Visual reference:** `/Users/jimjacob/Downloads/YGTeeV (11)/Plant Growth Sprites.html`
- **Sprite pack:** Download from HTML file above
