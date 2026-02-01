//
//  ClockState.swift
//  timedial
//
//  Created by Shubham Shrivastav on 31/01/26.
//

import Foundation

struct ClockState {
    var currentTime: Date
    var selectedTimezone: TimeZone
    var isDragging: Bool
    
    init(currentTime: Date = Date(), selectedTimezone: TimeZone = .current, isDragging: Bool = false) {
        self.currentTime = currentTime
        self.selectedTimezone = selectedTimezone
        self.isDragging = isDragging
    }
}
