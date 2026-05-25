# Sound Effects Guide

## Overview

The YGTeeV app uses sound effects to enhance the gaming experience when users earn XP and interact with quiz questions.

## Required Sound Files

You'll need to add the following sound effect files to the Xcode project:

### 1. `correct_answer.mp3`
- **Purpose**: Plays when user selects the correct answer
- **Style**: Bright, positive chime or "ding" sound
- **Duration**: 0.5-1 second
- **Suggestions**:
  - Success notification sound
  - Bright bell chime
  - Positive UI feedback sound

### 2. `xp_earned.mp3`
- **Purpose**: Plays right after correct answer (0.1s delay) when XP appears
- **Style**: Coin collection, level up, or achievement sound
- **Duration**: 0.5-1.5 seconds
- **Suggestions**:
  - Coins jingling
  - Power-up sound
  - Achievement unlock sound
  - Retro game "level up" sound

### 3. `wrong_answer.mp3`
- **Purpose**: Plays when user selects wrong answer
- **Style**: Gentle error sound (not harsh)
- **Duration**: 0.3-0.8 seconds
- **Suggestions**:
  - Soft buzzer
  - Descending tone
  - Gentle "miss" sound

### 4. `level_up.mp3` (Future use)
- **Purpose**: Plays when user reaches a new level
- **Style**: Epic achievement sound
- **Duration**: 1-2 seconds
- **Suggestions**:
  - Fanfare
  - Victory theme
  - Triumphant chime

## How to Add Sound Files to Xcode

1. **Find or create your sound files** (see recommendations below)
2. **Drag the .mp3 files into Xcode**:
   - Open your Xcode project
   - Select the YGTeeV folder in the project navigator
   - Drag the 4 sound files into the project
   - ✅ Check "Copy items if needed"
   - ✅ Check "YGTeeV" under "Add to targets"
   - Click "Finish"

3. **Verify files are added**:
   - The sound files should appear in your Xcode project navigator
   - Build the project to ensure they're included in the bundle

## Where to Find Free Sound Effects

### Recommended Sources (Royalty-Free)

1. **Freesound.org** (requires free account)
   - Search: "success", "coin", "level up", "wrong answer"
   - Filter by: Creative Commons 0 (public domain)

2. **Pixabay** (no account needed)
   - URL: https://pixabay.com/sound-effects/
   - Search: "game success", "achievement", "error"
   - All sounds are free for commercial use

3. **ZapSplat** (free account)
   - URL: https://www.zapsplat.com
   - Search: "game ui", "success", "coin"
   - Filter by license type

4. **Mixkit** (no account)
   - URL: https://mixkit.co/free-sound-effects/
   - Browse: "Game" category
   - All sounds are free for commercial use

### Specific Search Terms

For best results, search for:
- **Correct Answer**: "success ui", "positive notification", "achievement unlock"
- **XP Earned**: "coin collect", "point gain", "level up short"
- **Wrong Answer**: "error soft", "incorrect gentle", "miss"
- **Level Up**: "level up", "victory short", "achievement fanfare"

## Gaming Feel Tips

For the best gaming UX:

1. **Keep sounds short** (under 1.5 seconds each)
2. **Match energy levels**:
   - Correct answer: Medium energy, positive
   - XP earned: High energy, exciting
   - Wrong answer: Low energy, gentle
3. **Avoid harsh sounds** - this is a faith app, keep it encouraging
4. **Test volume** - sounds play at reduced volume (0.4-0.7) by default

## Testing Sounds

Once you've added the files:

1. Launch the app in the simulator or device
2. Navigate to a Daily Plan
3. Answer a question correctly
4. You should hear:
   - First: `correct_answer.mp3` (immediately)
   - Then: `xp_earned.mp3` (0.1s later)
   - See: XP animation with particle burst

## Troubleshooting

**"Sound file not found" warning in console**
- Make sure files are named exactly: `correct_answer.mp3`, `xp_earned.mp3`, etc.
- Verify files are in the Xcode project navigator
- Check "Target Membership" includes YGTeeV

**No sound plays**
- Check device/simulator volume
- Verify sound isn't muted
- Sound effects use `.ambient` category (won't interrupt music)

**Sound is too loud/quiet**
- Edit volume in `SoundManager.swift`
- Look for `volume:` parameter in `playSound()` calls
- Default values: 0.4 (wrong), 0.5 (xp), 0.6 (correct), 0.7 (level up)

## Future Enhancements

Future sound opportunities:
- Streak milestone reached
- Garden plant watered
- Tree growth stage completed
- Daily goal completed
- Week completed
- Badge unlocked
