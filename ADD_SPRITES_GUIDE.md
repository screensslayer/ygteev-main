# How to Add Plant Sprites to Xcode

## The Problem

The plant sprites need to be added to the Xcode project, but they have a specific folder structure:

```
Sprites/
  cherry/
    stage-01.png, stage-02.png, ..., stage-07.png
    bloom.png, withered.png
  oak/
    stage-01.png, ..., stage-10.png
    bloom.png, withered.png
  (+ 9 more species)
  fx/
    water.png, sparkle.png, heart.png
```

If we add these files individually, Xcode will flatten the structure and create duplicate file errors (since every species has `stage-01.png`, etc.).

## The Solution: Add as Folder Reference

You need to add the `Sprites` folder as a **folder reference** (blue folder icon) instead of a group (yellow folder icon).

### Step-by-Step Instructions

1. **Locate the Sprites folder:**
   - The sprites are at: `/Users/jimjacob/Downloads/YGTeeV-Xcode-Sprites/Sprites`

2. **Open Xcode:**
   - Open your YGTeeV project in Xcode

3. **Add the folder:**
   - In the Xcode project navigator (left sidebar), right-click on the `YGTeeV` folder (the one with your source files)
   - Select **"Add Files to YGTeeV..."**

4. **Configure the import:**
   - Navigate to `/Users/jimjacob/Downloads/YGTeeV-Xcode-Sprites/`
   - Select the `Sprites` folder
   - **IMPORTANT**: At the bottom of the dialog:
     - ✅ Check "Copy items if needed"
     - ✅ Select "Create folder references" (NOT "Create groups")
       - This is the key! The folder should be **blue** in Xcode, not yellow
     - ✅ Check the "YGTeeV" target under "Add to targets"
   - Click "Add"

5. **Verify:**
   - The `Sprites` folder should appear in your project navigator with a **blue folder icon**
   - You should see the subdirectories: cherry, oak, fig, olive, mustard, rose, lavender, wheat, sunflower, tulip, fx
   - The folder should be at the same level as your Views, Models, Services folders

## What I've Already Updated

I've already updated the code to load sprites from this folder structure:

### PixelTree.swift
- Now loads actual PNG sprites instead of drawing pixel art
- Looks for sprites at path: `Sprites/{species}/stage-{XX}.png`
- Example: `Sprites/cherry/stage-03.png`
- Supports withered and bloom states

### Updated Components
- ✅ GardenFullView - passes species to PixelTree
- ✅ PlansHomeView - passes species to PixelTree
- ✅ PlanCompletionView - uses cherry tree
- ✅ GardenItem model - updated to use new PlantStage enum

### Store System
- ✅ Updated to 11 plant species
- ✅ Categories changed to Trees, Bushes, Small Plants
- ✅ All items use species IDs that match the sprite folder names

## After Adding the Sprites

Once you've added the Sprites folder as a folder reference:

1. **Build the project** in Xcode (Cmd+B)
2. **Run the app** to see the actual plant sprites
3. The sprites should load automatically - no additional code changes needed

## Troubleshooting

**If sprites don't load:**
- Check the console for error messages like `❌ Sprite not found: ...`
- Verify the Sprites folder is **blue** (folder reference), not yellow (group)
- Check that the folder is added to the YGTeeV target:
  - Select the Sprites folder
  - Open File Inspector (right sidebar)
  - Under "Target Membership", ensure "YGTeeV" is checked

**If you see duplicate file errors:**
- The folder was added as a group instead of a folder reference
- Remove it and re-add it, making sure to select "Create folder references"

## Sprite File Structure

Each species has these files:
- `stage-01.png` through `stage-{N}.png` (N = 4, 7, or 10 depending on species)
- `bloom.png` (final mature stage)
- `withered.png` (dry/dead state)

Trees (32×32 grid):
- Oak: 10 stages
- Pine: 10 stages
- Cherry: 7 stages
- Olive: 7 stages
- Fig: 7 stages

Bushes (16×16 grid):
- Mustard: 7 stages
- Rose: 7 stages

Small Plants (16×16 grid):
- Lavender: 4 stages
- Wheat: 4 stages
- Sunflower: 4 stages
- Tulip: 4 stages

FX folder:
- water.png
- sparkle.png
- heart.png

## Render Sizes (from spec)

The sprites are rendered at different sizes depending on context:

| Tier | Grid | Garden | Detail | Hero |
|------|------|--------|--------|------|
| Tree | 32×32 | 96 pt | 128 pt | 192 pt |
| Bush | 16×16 | 64 pt | 96 pt | 128 pt |
| Small | 16×16 | 48 pt | 64 pt | 96 pt |

The code uses `.interpolation(.none)` to preserve crisp pixel art at all sizes.
