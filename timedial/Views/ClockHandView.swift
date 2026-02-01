//
//  ClockHandView.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import SwiftUI

struct ClockHandView: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [color, color.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: length)
            .shadow(color: color.opacity(0.3), radius: 2, x: 1, y: 1)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}
