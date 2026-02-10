import Foundation
import os

/// Shared logger categories to keep simulation, rendering, and AI logs consistent.
public enum AppLogger {
    private static let subsystem = "TIT.The-Infinite-Terrarium"
    public nonisolated static let simulation = Logger(subsystem: subsystem, category: "simulation")
    public nonisolated static let rendering = Logger(subsystem: subsystem, category: "rendering")
    public nonisolated static let ai = Logger(subsystem: subsystem, category: "ai")
}
