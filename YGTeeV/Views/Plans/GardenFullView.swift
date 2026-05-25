//
//  GardenFullView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

struct GardenFullView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @State private var showStore = false
    @State private var selectedItem: GardenItem? = nil
    @State private var itemToPlace: StoreItem? = nil
    @State private var placementPosition: CGPoint = CGPoint(x: 200, y: 400)
    @State private var itemToMove: GardenItem? = nil
    @State private var movePosition: CGPoint = .zero
    @State private var isShaking = false
    @State private var showHarvestSheet = false
    @State private var harvestingItem: GardenItem? = nil
    @State private var showXPAnimation = false
    @State private var earnedXP = 0
    
    var body: some View {
        ZStack {
            // Garden background
            PixelGarden()
                .ignoresSafeArea()
            
            // Interactive garden items
            ZStack {
                ForEach(appState.gardenItems) { item in
                    ZStack {
                        // Glow effect for bloom state
                        if item.isInBloom {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.yellow.opacity(0.4), Color.yellow.opacity(0.0)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: sizeForStage(item.stage, species: item.type) * 0.7
                                    )
                                )
                                .frame(width: sizeForStage(item.stage, species: item.type) * 1.4, height: sizeForStage(item.stage, species: item.type) * 1.4)
                                .scaleEffect(isShaking ? 1.1 : 1.0)
                                .opacity(isShaking ? 0.8 : 0.6)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isShaking)
                        }

                        PixelTree(size: sizeForStage(item.stage, species: item.type), stage: item.currentStage, species: item.type, isBloom: item.isInBloom)
                    }
                    .rotationEffect(.degrees(itemToMove?.id == item.id && isShaking ? 2 : 0))
                    .animation(
                        itemToMove?.id == item.id && isShaking ?
                            .easeInOut(duration: 0.1).repeatForever(autoreverses: true) : .default,
                        value: isShaking
                    )
                    .position(itemToMove?.id == item.id ? movePosition : item.position)
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    // Start moving mode
                                    if itemToPlace == nil {
                                        withAnimation(.spring(response: 0.3)) {
                                            itemToMove = item
                                            movePosition = item.position
                                            selectedItem = nil
                                            isShaking = true
                                        }
                                        
                                        // Haptic feedback
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                    }
                                }
                                .simultaneously(with: TapGesture()
                                    .onEnded { _ in
                                        if itemToPlace == nil && itemToMove == nil {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedItem = item
                                            }
                                        }
                                    }
                                )
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if itemToMove?.id == item.id {
                                        movePosition = value.location
                                    }
                                }
                                .onEnded { _ in
                                    if itemToMove?.id == item.id {
                                        // Save new position
                                        saveItemPosition(item: item, newPosition: movePosition)
                                        
                                        withAnimation(.spring(response: 0.3)) {
                                            itemToMove = nil
                                            isShaking = false
                                        }
                                    }
                                }
                        )
                }
                
                // Placement preview (when placing new item)
                if let placingItem = itemToPlace {
                    ZStack {
                        // Shovel background
                        ShovelIcon()
                            .frame(width: 80, height: 80)

                        // Stage 1 sprite preview on top of shovel
                        PixelTree(size: 44, stage: .stage1, species: placingItem.id)
                            .offset(x: -2, y: -8)
                    }
                    .position(placementPosition)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                placementPosition = value.location
                            }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap outside closes water card
                if selectedItem != nil {
                    withAnimation(.spring(response: 0.3)) {
                        selectedItem = nil
                    }
                }
            }
            
            VStack {
                // Top bar
                VStack(spacing: 6) {
                    Text("MY GARDEN")
                        .font(.lilitaOne(size: 34))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    
                    Text("LVL \(appState.user.level)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Stats row
                HStack(spacing: 8) {
                    GardenStatCard(icon: "💧", value: "\(appState.user.water)", label: "Water")
                    GardenStatCard(icon: "⚡", value: "\(appState.user.xp)", label: "XP")
                    
                    // Store button instead of streak
                    Button {
                        showStore = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("🏪")
                                .font(.system(size: 22))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Store")
                                    .font(.lilitaOne(size: 20))
                                    .foregroundStyle(.white)
                                
                                Text("SHOP")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .tracking(0.5)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(.white.opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Active tree card (only when item selected) - moved below stats
                if let item = selectedItem {
                    HStack(spacing: 12) {
                        PixelTree(size: 48, stage: item.currentStage, species: item.type)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.displayName) · \(item.isInBloom ? "🌟 Bloom!" : "Stage \(item.stage)/\(item.maxStages)")")
                                .font(.lilitaOne(size: 14))
                                .foregroundStyle(YGColors.ink)

                            if !item.isInBloom {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(YGColors.paper2)
                                            .overlay {
                                                Rectangle()
                                                    .strokeBorder(YGColors.ink, lineWidth: 1.5)
                                            }

                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [YGColors.lime, YGColors.yellow],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * item.progress)
                                    }
                                }
                                .frame(height: 8)
                                .clipShape(Rectangle())
                                .padding(.top, 2)

                                Text("Water \(item.watersUntilNext) more times to \(item.stage == item.maxStages ? "bloom" : "grow")")
                                    .font(.system(size: 11))
                                    .foregroundStyle(YGColors.ink.opacity(0.6))
                                    .padding(.top, 2)
                            } else {
                                Text("🍎 Ready to harvest! Tap harvest to collect XP and reset.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.orange)
                                    .padding(.top, 2)
                            }
                        }
                        
                        Spacer()

                        if item.isInBloom {
                            Button {
                                harvestItem()
                            } label: {
                                Text("🍎 Harvest")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.primary(
                                gradient: LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            ))
                            .frame(height: 44)
                            .shadow(color: Color.orange.opacity(0.4), radius: 12)
                        } else {
                            Button {
                                waterItem()
                            } label: {
                                Text("💧 Water")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.primary(
                                gradient: LinearGradient(
                                    colors: [YGColors.water, YGColors.water],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            ))
                            .frame(height: 44)
                            .shadow(color: YGColors.water.opacity(0.4), radius: 12)
                        }
                    }
                    .padding(14)
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(YGColors.ink, lineWidth: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        // Prevent tap from propagating to background
                    }
                }
                
                Spacer()
                
                // Placement mode controls
                if itemToPlace != nil {
                    VStack(spacing: 12) {
                        Text("Drag to position your item")
                            .font(.lilitaOne(size: 14))
                            .foregroundStyle(YGColors.ink)
                        
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    itemToPlace = nil
                                    placementPosition = CGPoint(x: 200, y: 400)
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(.white)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(YGColors.ink, lineWidth: 2)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button {
                                placeItem()
                            } label: {
                                Text("Place Here ✓")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [YGColors.lime, YGColors.lime],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: YGColors.lime.opacity(0.4), radius: 8)
                            }
                        }
                    }
                    .padding(16)
                    .background(.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(YGColors.ink, lineWidth: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showStore) {
            GardenStoreView(onItemPurchased: { purchasedItem in
                withAnimation(.spring(response: 0.3)) {
                    itemToPlace = purchasedItem
                    selectedItem = nil
                }
            })
        }
        .sheet(isPresented: $showHarvestSheet) {
            if let item = harvestingItem {
                HarvestSheet(item: item, onSell: {
                    confirmHarvest()
                })
            }
        }
        .overlay {
            // XP flying animation overlay
            if showXPAnimation {
                XPFlyingAnimation(xpAmount: earnedXP)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
    
    func sizeForStage(_ stage: Int, species: String) -> CGFloat {
        // Small plants (4 stages): lavender, wheat, sunflower, tulip
        let isSmallPlant = ["lavender", "wheat", "sunflower", "tulip"].contains(species)
        
        // Bushes (7 stages): mustard, rose
        let isBush = ["mustard", "rose"].contains(species)
        
        // Trees (7-10 stages): cherry, olive, fig, oak, pine
        let isTree = ["cherry", "olive", "fig", "oak", "pine"].contains(species)
        
        if isSmallPlant {
            // Small plants: 32pt -> 64pt max
            switch stage {
            case 1: return 32
            case 2: return 44
            case 3: return 54
            case 4: return 64
            default: return 64
            }
        } else if isBush {
            // Bushes: 48pt -> 112pt max
            switch stage {
            case 1: return 48
            case 2: return 60
            case 3: return 72
            case 4: return 84
            case 5: return 96
            case 6: return 104
            case 7: return 112
            default: return 112
            }
        } else {
            // Trees: 64pt -> 320pt max
            switch stage {
            case 1: return 64
            case 2: return 88
            case 3: return 112
            case 4: return 144
            case 5: return 176
            case 6: return 208
            case 7: return 240
            case 8: return 264
            case 9: return 292
            case 10: return 320
            default: return 96
            }
        }
    }
    
    func placeItem() {
        guard let item = itemToPlace else { return }

        // All plant categories can be planted (trees, bushes, small plants)
        if item.category == .trees || item.category == .bushes || item.category == .smallPlants {
            let newItem = GardenItem(
                type: item.id,
                stage: 1,
                watersUntilNext: 2, // Stage 1 → 2 requires 2 waters
                position: placementPosition
            )

            withAnimation(.spring(response: 0.4)) {
                appState.gardenItems.append(newItem)
                itemToPlace = nil
                placementPosition = CGPoint(x: 200, y: 400)
            }
        }
    }
    
    func waterItem() {
        guard let selectedId = selectedItem?.id,
              let index = appState.gardenItems.firstIndex(where: { $0.id == selectedId }) else { return }

        // Check if user has water
        guard appState.user.water > 0 else { return }

        // Don't water if already in bloom
        guard !appState.gardenItems[index].isInBloom else { return }

        // Deduct water
        appState.user.water -= 1

        // Water the item
        appState.gardenItems[index].watersUntilNext -= 1

        // Check if stage up
        if appState.gardenItems[index].watersUntilNext <= 0 {
            let currentItem = appState.gardenItems[index]

            if currentItem.stage < currentItem.maxStages {
                // Advance to next stage
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    appState.gardenItems[index].stage += 1
                    appState.gardenItems[index].watersUntilNext = appState.gardenItems[index].totalWatersInStage
                }
            } else {
                // Reached max stage - enter bloom state
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    appState.gardenItems[index].isInBloom = true
                }
            }
        }

        // Update selected item
        selectedItem = appState.gardenItems[index]
    }

    func harvestItem() {
        guard let item = selectedItem else { return }

        // Show harvest sheet
        harvestingItem = item
        showHarvestSheet = true
    }

    func confirmHarvest() {
        guard let selectedId = harvestingItem?.id,
              let index = appState.gardenItems.firstIndex(where: { $0.id == selectedId }) else { return }

        let item = appState.gardenItems[index]

        // Calculate harvest XP based on plant type
        let harvestXP: Int
        switch item.type {
        case "lavender", "wheat", "sunflower", "tulip": harvestXP = 100
        case "mustard", "rose": harvestXP = 250
        case "cherry", "olive", "fig": harvestXP = 500
        case "oak", "pine": harvestXP = 1000
        default: harvestXP = 100
        }

        // Close harvest sheet
        showHarvestSheet = false

        // Award XP
        earnedXP = harvestXP
        showXPAnimation = true

        // Play sounds
        SoundManager.shared.playCorrectAnswer()
        SoundManager.shared.playXPEarned()

        // Animate XP update
        withAnimation(.easeOut(duration: 0.8)) {
            appState.user.xp += harvestXP
        }

        // Hide XP animation after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showXPAnimation = false
        }

        // Reset plant
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            // Reset plant back 2 stages (or to stage 1 if less than 3)
            let newStage = max(1, item.stage - 2)
            appState.gardenItems[index].stage = newStage
            appState.gardenItems[index].watersUntilNext = appState.gardenItems[index].totalWatersInStage
            appState.gardenItems[index].isInBloom = false

            // Clear selection after harvest
            selectedItem = nil
            harvestingItem = nil
        }
    }
    
    func saveItemPosition(item: GardenItem, newPosition: CGPoint) {
        guard let index = appState.gardenItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Update position in app state
        appState.gardenItems[index].position = newPosition
        
        // TODO: Persist to database when backend is ready
        print("💾 Saved item position: \(item.displayName) at \(newPosition)")
    }
}

struct GardenStatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 22))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.lilitaOne(size: 20))
                    .foregroundStyle(.white)
                
                Text(label.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.2))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Shovel Icon
struct ShovelIcon: View {
    var body: some View {
        Canvas { context, size in
            let handleColor = Color(hex: "8B6F47") // Brown handle
            let bladeColor = Color(hex: "A8A8A8") // Silver blade

            // Shovel handle (wooden stick)
            let handlePath = Path { path in
                // Handle - diagonal stick
                path.move(to: CGPoint(x: size.width * 0.65, y: size.height * 0.15))
                path.addLine(to: CGPoint(x: size.width * 0.35, y: size.height * 0.55))
            }
            context.stroke(handlePath, with: .color(handleColor), lineWidth: 8)
            context.stroke(handlePath, with: .color(Color.black.opacity(0.2)), lineWidth: 10)

            // Handle grip (darker brown)
            let gripPath = Path { path in
                path.move(to: CGPoint(x: size.width * 0.65, y: size.height * 0.15))
                path.addLine(to: CGPoint(x: size.width * 0.55, y: size.height * 0.28))
            }
            context.stroke(gripPath, with: .color(Color(hex: "6B5536")), lineWidth: 9)

            // Shovel blade (spade shape)
            let bladePath = Path { path in
                let bladeTop = CGPoint(x: size.width * 0.35, y: size.height * 0.55)
                let bladeLeft = CGPoint(x: size.width * 0.20, y: size.height * 0.70)
                let bladeBottom = CGPoint(x: size.width * 0.30, y: size.height * 0.85)
                let bladeRight = CGPoint(x: size.width * 0.45, y: size.height * 0.70)

                path.move(to: bladeTop)
                path.addQuadCurve(to: bladeLeft, control: CGPoint(x: size.width * 0.22, y: size.height * 0.60))
                path.addQuadCurve(to: bladeBottom, control: CGPoint(x: size.width * 0.18, y: size.height * 0.78))
                path.addQuadCurve(to: bladeRight, control: CGPoint(x: size.width * 0.42, y: size.height * 0.78))
                path.addQuadCurve(to: bladeTop, control: CGPoint(x: size.width * 0.43, y: size.height * 0.60))
                path.closeSubpath()
            }

            // Draw blade shadow
            context.fill(bladePath, with: .color(Color.black.opacity(0.3)))
            context.translateBy(x: 0, y: -2)
            context.fill(bladePath, with: .color(bladeColor))

            // Blade highlight
            let highlightPath = Path { path in
                path.move(to: CGPoint(x: size.width * 0.32, y: size.height * 0.58))
                path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.68))
            }
            context.stroke(highlightPath, with: .color(.white.opacity(0.4)), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
    }
}

// MARK: - Harvest Sheet
struct HarvestSheet: View {
    let item: GardenItem
    let onSell: () -> Void
    @Environment(\.dismiss) private var dismiss

    var harvestXP: Int {
        switch item.type {
        case "lavender", "wheat", "sunflower", "tulip": return 100
        case "mustard", "rose": return 250
        case "cherry", "olive", "fig": return 500
        case "oak", "pine": return 1000
        default: return 100
        }
    }

    var rarity: String {
        switch item.type {
        case "lavender", "wheat", "sunflower", "tulip": return "COMMON"
        case "mustard", "rose": return "RARE"
        case "cherry", "olive", "fig": return "EPIC"
        case "oak", "pine": return "LEGENDARY"
        default: return "COMMON"
        }
    }

    var rarityColor: Color {
        switch item.type {
        case "lavender", "wheat", "sunflower", "tulip": return Color(hex: "FFFFFF")
        case "mustard", "rose": return Color(hex: "B4FF3C")
        case "cherry", "olive", "fig": return Color(hex: "FF3DA5")
        case "oak", "pine": return Color(hex: "FFD60A")
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Title
                Text("🍎 HARVEST READY!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 40)

                Spacer().frame(height: 30)

                // Bloom sprite showcase
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [rarityColor.opacity(0.6), rarityColor.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)

                    // Plant sprite
                    PixelTree(size: 140, stage: item.currentStage, species: item.type, isBloom: true)
                }
                .padding(.vertical, 20)

                // Rarity badge
                Text(rarity)
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(rarityColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(rarityColor.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)

                // Plant name
                Text(item.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Sell for XP card
                VStack(spacing: 8) {
                    Text("SELL YOUR FRUIT")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 8) {
                        Text("⚡")
                            .font(.system(size: 32))

                        Text("+\(harvestXP) XP")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FFD60A"), Color(hex: "FFA500")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "1A1A1A"))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(hex: "FFD60A").opacity(0.3), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 40)
                .padding(.bottom, 30)

                // Sell button
                Button {
                    dismiss()
                    // Delay to allow sheet to close before showing XP animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSell()
                    }
                } label: {
                    Text("💰 SELL FRUIT")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "FFD60A"), Color(hex: "FFA500")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color(hex: "FFD60A").opacity(0.5), radius: 20, y: 8)
                }
                .padding(.horizontal, 40)

                // Cancel button
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 16)
                }

                Spacer()
            }
        }
        .presentationBackground(.clear)
    }
}

#Preview {
    GardenFullView()
        .environment(AppState())
}
