//
//  PixelGarden.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// Pixel art garden scene
struct PixelGarden: View {
    var body: some View {
        GeometryReader { outerGeometry in
            ZStack {
                // Sky gradient
                LinearGradient(
                    colors: [YGColors.pixSky, YGColors.pixSkyDusk],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Sun
                Circle()
                    .fill(YGColors.yellow)
                    .frame(width: 32, height: 32)
                    .shadow(color: YGColors.yellow.opacity(0.4), radius: 8)
                    .shadow(color: YGColors.yellow.opacity(0.2), radius: 16)
                    .position(x: outerGeometry.size.width - 50, y: 30)
                
                // Clouds
                PixelCloud()
                    .offset(x: -140, y: -80)
                
                PixelCloud(small: true)
                    .offset(x: 80, y: -60)
                
                // Hills (background) - adjusted to appear lower with more grass
                GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.35))
                    path.addQuadCurve(
                        to: CGPoint(x: geometry.size.width * 0.3, y: geometry.size.height * 0.38),
                        control: CGPoint(x: geometry.size.width * 0.15, y: geometry.size.height * 0.28)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: geometry.size.width * 0.6, y: geometry.size.height * 0.36),
                        control: CGPoint(x: geometry.size.width * 0.45, y: geometry.size.height * 0.42)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.38),
                        control: CGPoint(x: geometry.size.width * 0.8, y: geometry.size.height * 0.30)
                    )
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color(hex: "7BCB7E"))
            }
            
            // Dirt ground - brown speckled dirt
            VStack {
                Spacer()

                ZStack {
                    // Base dirt layer
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8B6F47"), Color(hex: "6B5536")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Dirt speckles
                    Canvas { context, size in
                        let speckleColors = [
                            Color(hex: "7A5C3A"),
                            Color(hex: "9B7F5A"),
                            Color(hex: "5C4A33"),
                            Color(hex: "A68968")
                        ]

                        // Create random but consistent speckle pattern
                        for i in 0..<150 {
                            let x = CGFloat((i * 73) % Int(size.width))
                            let y = CGFloat((i * 41) % Int(size.height))
                            let speckleSize = CGFloat([2.0, 3.0, 4.0, 2.5, 3.5][(i * 13) % 5])
                            let colorIndex = (i * 7) % speckleColors.count

                            let rect = CGRect(x: x, y: y, width: speckleSize, height: speckleSize)
                            context.fill(Path(rect), with: .color(speckleColors[colorIndex]))
                        }
                    }
                }
                .frame(height: 450)
            }
            

            
            // Fence
            VStack {
                Spacer()
                
                PixelFence()
                    .frame(height: 30)
                    .padding(.bottom, 4)
            }
        }
        }
    }
}

// Pixel cloud component
struct PixelCloud: View {
    var small: Bool = false
    
    var body: some View {
        Canvas { context, size in
            let scale = small ? 0.7 : 1.0
            let w = 64.0 * scale
            let h = 28.0 * scale
            let pixelSize = w / 32
            
            // Cloud shape in pixel grid
            let cloudPixels: [(Int, Int)] = [
                // Bottom row
                (4, 6), (4, 7), (4, 8), (4, 9), (4, 10), (4, 11), (4, 12), (4, 13), (4, 14), (4, 15), (4, 16), (4, 17), (4, 18), (4, 19), (4, 20), (4, 21), (4, 22), (4, 23), (4, 24), (4, 25), (4, 26),
                // Middle rows
                (6, 6), (6, 7), (6, 8), (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14), (6, 15), (6, 16), (6, 17), (6, 18), (6, 19), (6, 20), (6, 21), (6, 22), (6, 23), (6, 24), (6, 25), (6, 26),
                // Top section
                (8, 8), (8, 9), (8, 10), (8, 11), (8, 12), (8, 13), (8, 14), (8, 15), (8, 16), (8, 17), (8, 18), (8, 19), (8, 20), (8, 21), (8, 22),
                (10, 12), (10, 13), (10, 14), (10, 15), (10, 16), (10, 17), (10, 18), (10, 19)
            ]
            
            for (y, x) in cloudPixels {
                let rect = CGRect(
                    x: CGFloat(x) * pixelSize,
                    y: CGFloat(y) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(.white))
            }
        }
        .frame(width: small ? 45 : 64, height: small ? 20 : 28)
    }
}

// Pixel fence component
struct PixelFence: View {
    var body: some View {
        Canvas { context, size in
            let fenceColor = Color.white
            let postWidth: CGFloat = 6
            let postSpacing: CGFloat = 20
            let railHeight: CGFloat = 3
            
            // Posts
            var x: CGFloat = 8
            while x < size.width {
                // Post
                context.fill(
                    Path(CGRect(x: x, y: 8, width: postWidth, height: 32)),
                    with: .color(fenceColor)
                )
                // Post top
                context.fill(
                    Path(CGRect(x: x, y: 6, width: postWidth, height: 2)),
                    with: .color(fenceColor)
                )
                // Post cap
                context.fill(
                    Path(CGRect(x: x + 1, y: 4, width: postWidth - 2, height: 2)),
                    with: .color(fenceColor)
                )
                x += postSpacing
            }
            
            // Horizontal rails
            context.fill(
                Path(CGRect(x: 0, y: 14, width: size.width, height: railHeight)),
                with: .color(fenceColor)
            )
            context.fill(
                Path(CGRect(x: 0, y: 26, width: size.width, height: railHeight)),
                with: .color(fenceColor)
            )
        }
    }
}

#Preview {
    PixelGarden()
        .frame(height: 300)
}
