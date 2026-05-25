//
//  GardenStoreView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// MARK: - Store Item Model
struct StoreItem: Identifiable {
    let id: String
    let name: String
    let category: ItemCategory
    let xpCost: Int
    let rarity: ItemRarity
    let emoji: String
    let flavor: String
    let growsInto: String?

    enum ItemCategory: String, CaseIterable {
        case trees = "trees"
        case bushes = "bushes"
        case smallPlants = "small_plants"

        var label: String {
            switch self {
            case .trees: return "🌳 Trees"
            case .bushes: return "🌿 Bushes"
            case .smallPlants: return "🌻 Small Plants"
            }
        }
    }

    enum ItemRarity: String {
        case common, rare, epic, legendary

        var label: String { rawValue.capitalized }

        var color: Color {
            switch self {
            case .common: return Color(hex: "7FCBFF")
            case .rare: return Color(hex: "B4FF3C")
            case .epic: return Color(hex: "FF3DA5")
            case .legendary: return Color(hex: "FFD60A")
            }
        }

        var bgColor: Color {
            switch self {
            case .common: return Color(hex: "7FCBFF").opacity(0.12)
            case .rare: return Color(hex: "B4FF3C").opacity(0.14)
            case .epic: return Color(hex: "FF3DA5").opacity(0.14)
            case .legendary: return Color(hex: "FFD60A").opacity(0.16)
            }
        }
    }

    static let all: [StoreItem] = [
        // Trees (32×32 grid, 7-10 stages)
        StoreItem(id: "oak", name: "Oak Acorn", category: .trees, xpCost: 3000, rarity: .legendary, emoji: "🌰", flavor: "Mighty oaks of righteousness · Isa 61:3", growsInto: "Mighty Oak · 10 stages"),
        StoreItem(id: "pine", name: "Pine Cone", category: .trees, xpCost: 3000, rarity: .legendary, emoji: "🌲", flavor: "Evergreen strength · Ps 92:12", growsInto: "Pine Tree · 10 stages"),
        StoreItem(id: "cherry", name: "Cherry Pit", category: .trees, xpCost: 1500, rarity: .epic, emoji: "🍒", flavor: "Patience grows fruit · Luke 13:6", growsInto: "Cherry Tree · 7 stages"),
        StoreItem(id: "olive", name: "Olive Pit", category: .trees, xpCost: 1500, rarity: .epic, emoji: "🫒", flavor: "Symbol of peace · Gen 8:11", growsInto: "Olive Tree · 7 stages"),
        StoreItem(id: "fig", name: "Fig Seed", category: .trees, xpCost: 1500, rarity: .epic, emoji: "🌳", flavor: "The fig tree will blossom · Hab 3:17", growsInto: "Fig Tree · 7 stages"),
        
        // Bushes (16×16 grid, 7 stages)
        StoreItem(id: "mustard", name: "Mustard Seed", category: .bushes, xpCost: 800, rarity: .rare, emoji: "🌿", flavor: "The smallest of all · Mark 4:31", growsInto: "Mustard Bush · 7 stages"),
        StoreItem(id: "rose", name: "Rose Seed", category: .bushes, xpCost: 800, rarity: .rare, emoji: "🌹", flavor: "Sharon's flower · SoS 2:1", growsInto: "Rose Bush · 7 stages"),
        
        // Small Plants (16×16 grid, 4 stages)
        StoreItem(id: "lavender", name: "Lavender Seed", category: .smallPlants, xpCost: 200, rarity: .common, emoji: "🪻", flavor: "Purple blooms of peace", growsInto: "Lavender · 4 stages"),
        StoreItem(id: "wheat", name: "Wheat Seed", category: .smallPlants, xpCost: 200, rarity: .common, emoji: "🌾", flavor: "Harvest of righteousness · Jas 3:18", growsInto: "Wheat · 4 stages"),
        StoreItem(id: "sunflower", name: "Sunflower Seed", category: .smallPlants, xpCost: 200, rarity: .common, emoji: "🌻", flavor: "Grows tall toward the light · Matt 13:23", growsInto: "Sunflower · 4 stages"),
        StoreItem(id: "tulip", name: "Tulip Bulb", category: .smallPlants, xpCost: 200, rarity: .common, emoji: "🌷", flavor: "Consider the lilies · Matt 6:28", growsInto: "Tulip · 4 stages"),
    ]
}

// MARK: - Garden Store View
struct GardenStoreView: View {
    let onItemPurchased: (StoreItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) var appState
    @State private var selectedCategory: String = "all"
    @State private var selectedItem: StoreItem? = nil
    @State private var ownedItems: Set<String> = ["sunflower", "wheat"]

    var filteredItems: [StoreItem] {
        if selectedCategory == "all" {
            return StoreItem.all
        } else {
            return StoreItem.all.filter { $0.category.rawValue == selectedCategory }
        }
    }

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(hex: "1B1230"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Sky stripe at top
            LinearGradient(
                colors: [
                    Color(hex: "BFE6F5"),
                    Color(hex: "C8B5FF"),
                    Color(hex: "6B2BFF"),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.4)
            .frame(height: 220)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top nav
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "140E28").opacity(0.55))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                                }

                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garden")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)

                        Text("Store")
                            .font(.lilitaOne(size: 32))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // XP balance
                    HStack(spacing: 6) {
                        Text("⚡")
                            .font(.system(size: 14))
                        Text("\(appState.user.xp)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(YGColors.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFD60A"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(YGColors.ink, lineWidth: 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                // Tagline
                Text("Spend XP on seeds. Plant in your garden — spend 5 💧 per stage to grow. Harvest for XP!")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        CategoryButton(title: "All", id: "all", selected: $selectedCategory)
                        ForEach(StoreItem.ItemCategory.allCases, id: \.rawValue) { category in
                            CategoryButton(title: category.label, id: category.rawValue, selected: $selectedCategory)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                // Item grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(filteredItems) { item in
                            StoreItemCard(
                                item: item,
                                balance: appState.user.xp,
                                owned: ownedItems.contains(item.id)
                            )
                            .onTapGesture {
                                selectedItem = item
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(
                item: item,
                balance: appState.user.xp,
                owned: ownedItems.contains(item.id),
                onBuy: {
                    // Purchase logic
                    appState.user.xp -= item.xpCost
                    ownedItems.insert(item.id)
                    selectedItem = nil
                    
                    // Close store and trigger placement
                    dismiss()
                    onItemPurchased(item)
                },
                onPlace: {
                    // Close store and trigger placement for owned item
                    selectedItem = nil
                    dismiss()
                    onItemPurchased(item)
                }
            )
        }
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let title: String
    let id: String
    @Binding var selected: String

    var body: some View {
        Button {
            selected = id
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected == id ? YGColors.ink : .white.opacity(0.78))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected == id ? .white : .white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 999)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }
                .clipShape(Capsule())
        }
    }
}

// MARK: - Store Item Card
struct StoreItemCard: View {
    let item: StoreItem
    let balance: Int
    let owned: Bool

    var canAfford: Bool {
        balance >= item.xpCost
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rarity tag
            HStack {
                Spacer()
                Text(item.rarity.label.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(item.rarity.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(item.rarity.bgColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(10)

            // Bloom sprite display
            PixelTree(size: 80, stage: .stage1, species: item.id, isBloom: true)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color(hex: "140E28").opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(item.rarity.color.opacity(0.35), lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            // Item name
            Text(item.name)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // Price / status
            HStack {
                if owned {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                        Text("Owned")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "B4FF3C"))
                } else {
                    HStack(spacing: 4) {
                        Text("⚡")
                            .font(.system(size: 11))
                        Text("\(item.xpCost)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(canAfford ? Color(hex: "FFD60A") : .white.opacity(0.4))
                }

                Spacer()

                Text(owned ? "PLACE" : canAfford ? "BUY" : "LOCKED")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(owned ? .white.opacity(0.7) : canAfford ? YGColors.ink : .white.opacity(0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(owned ? .white.opacity(0.08) : canAfford ? Color(hex: "B4FF3C") : .white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(.white.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(item.rarity.color.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Item Detail Sheet
struct ItemDetailSheet: View {
    let item: StoreItem
    let balance: Int
    let owned: Bool
    let onBuy: () -> Void
    let onPlace: () -> Void
    @Environment(\.dismiss) private var dismiss

    var canAfford: Bool {
        balance >= item.xpCost
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1B1230"), Color(hex: "0A0712")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.18))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Item display
                        HStack(spacing: 14) {
                            // Bloom sprite well
                            PixelTree(size: 90, stage: .stage1, species: item.id, isBloom: true)
                                .frame(width: 110, height: 110)
                                .background(Color(hex: "140E28").opacity(0.6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(item.rarity.color.opacity(0.35), lineWidth: 1.5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.rarity.label.uppercased()) · \(item.category == .trees ? "TREE" : item.category == .bushes ? "BUSH" : "SMALL PLANT")")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(item.rarity.color)

                                Text(item.name)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text("\"\(item.flavor)\"")
                                    .font(.system(size: 13))
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineSpacing(4)
                            }
                        }

                        // Grows into card
                        if let growsInto = item.growsInto {
                            HStack(spacing: 10) {
                                Text("💧")
                                    .font(.system(size: 22))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GROWS INTO")
                                        .font(.system(size: 10.5, weight: .heavy))
                                        .tracking(0.6)
                                        .foregroundStyle(Color(hex: "7FCBFF"))

                                    Text(growsInto)
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("Spend 5 💧 per stage to grow. Harvest fruit for +XP!")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(hex: "7FCBFF").opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color(hex: "7FCBFF").opacity(0.25), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Buy button
                        if owned {
                            Button {
                                onPlace()
                            } label: {
                                Text("Place in Garden →")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(YGColors.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        } else {
                            Button {
                                if canAfford {
                                    onBuy()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if canAfford {
                                        Text("Buy for")
                                        Text("⚡")
                                        Text("\(item.xpCost)")
                                    } else {
                                        Text("Need")
                                        Text("⚡")
                                        Text("\(item.xpCost - balance) more")
                                    }
                                }
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(canAfford ? YGColors.ink : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(canAfford ? Color(hex: "B4FF3C") : .white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: canAfford ? Color(hex: "B4FF3C").opacity(0.3) : .clear, radius: 10, y: 8)
                            }
                            .disabled(!canAfford)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    GardenStoreView(onItemPurchased: { _ in })
        .environment(AppState())
}
