//
//  PixelTree.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// Plant sprite component for the garden system
// Loads actual PNG sprites from the Sprites folder
struct PixelTree: View {
    let size: CGFloat
    let stage: PlantStage
    let species: String
    let isWithered: Bool
    let isBloom: Bool
    
    // Initializer with defaults
    init(size: CGFloat, stage: PlantStage, species: String = "cherry", isWithered: Bool = false, isBloom: Bool = false) {
        self.size = size
        self.stage = stage
        self.species = species
        self.isWithered = isWithered
        self.isBloom = isBloom
    }
    
    enum PlantStage: Int {
        case stage1 = 1
        case stage2 = 2
        case stage3 = 3
        case stage4 = 4
        case stage5 = 5
        case stage6 = 6
        case stage7 = 7
        case stage8 = 8
        case stage9 = 9
        case stage10 = 10
    }
    
    var body: some View {
        let imageName = getImageName()
        
        Image(imageName)
            .interpolation(.none) // CRITICAL: Preserve crisp pixels
            .resizable()
            .frame(width: size, height: size)
    }
    
    /// Get the image asset name from Assets.xcassets
    /// Format: {species}-stage-{XX}, {species}-bloom, or {species}-withered
    private func getImageName() -> String {
        if isBloom {
            return "\(species)-bloom"
        } else if isWithered {
            return "\(species)-withered"
        } else {
            return "\(species)-stage-\(String(format: "%02d", stage.rawValue))"
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("Cherry Tree Growth")
                .font(.headline)
            
            // Show all 7 stages of cherry tree
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(1...7, id: \.self) { stageNum in
                    VStack {
                        PixelTree(size: 96, stage: PixelTree.PlantStage(rawValue: stageNum)!)
                        Text("Stage \(stageNum)")
                            .font(.caption)
                    }
                }
                
                VStack {
                    PixelTree(size: 96, stage: .stage7, isWithered: true)
                    Text("Withered")
                        .font(.caption)
                }
                
                VStack {
                    PixelTree(size: 96, stage: .stage7, isBloom: true)
                    Text("Bloom")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
