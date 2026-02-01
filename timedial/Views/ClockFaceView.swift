//
//  ClockFaceView.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import SwiftUI

struct ClockFaceView: View {
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle with subtle shadow
            Circle()
                .fill(Color.primary.opacity(0.05))
                .frame(width: radius * 2, height: radius * 2)
            
            // Outer circle
            Circle()
                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            
            // Hour ticks (drawn first, behind numbers)
            ForEach(0..<60, id: \.self) { tick in
                Rectangle()
                    .fill(tick % 5 == 0 ? Color.primary.opacity(0.5) : Color.primary.opacity(0.2))
                    .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 10 : 6)
                    .offset(y: -radius + (tick % 5 == 0 ? 5 : 3))
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
            
            // Hour numbers positioned correctly
            ForEach(1...12, id: \.self) { hour in
                let angle = Double(hour) * 30 - 90 // -90 to start from 12 o'clock
                let radians = angle * .pi / 180
                let numberRadius = radius - 25
                
                Text("\(hour)")
                    .font(.system(size: radius > 80 ? 14 : 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.8))
                    .position(
                        x: radius + numberRadius * cos(radians),
                        y: radius + numberRadius * sin(radians)
                    )
            }
            
            // Center dot with glow
            Circle()
                .fill(Color.accentColor)
                .frame(width: 12, height: 12)
                .shadow(color: .accentColor.opacity(0.5), radius: 3)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}
