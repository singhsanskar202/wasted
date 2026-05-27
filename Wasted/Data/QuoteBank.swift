import Foundation

enum QuoteBank {
    static let quotes: [String] = [
        "The average person spends 7 years of their life on their phone. What will you do with yours?",
        "You have the same 24 hours as everyone else.",
        "Distraction is the enemy of greatness.",
        "Every hour you scroll, someone else is building something.",
        "Your attention is the most valuable thing you own. Act like it.",
        "What are you avoiding right now?",
        "The app doesn't miss you when you leave. Close it.",
        "Boredom is where creativity lives. You keep killing it.",
        "Five minutes became an hour again.",
        "Is this how you want to spend your one life?",
        "Your future self is watching. Disappointed.",
        "You're not relaxing. You're numbing.",
        "That hour is gone. Permanently.",
        "Presence is a choice. You keep choosing elsewhere.",
        "The scroll has no end. You do.",
        "Put the phone down. The world is happening without you.",
        "Notifications aren't emergencies. Stop treating them like ones.",
        "This is your life, in real time. Use it well.",
        "You will not remember this scroll in ten years.",
        "Meanwhile, your goals are waiting.",
        "What could you learn in the time you just spent here?",
        "The most successful people guard their attention like money.",
        "You unlocked your phone looking for something. Did you find it?",
        "Every minute here is a minute not there.",
        "Dopamine spikes are not happiness.",
        "There's a version of you that doesn't need this. Be them.",
        "The feed refreshes. Your life doesn't.",
        "Awareness is the first step. You're reading this. Good.",
        "Close this. Go do the hard thing.",
        "You already know you've been on too long."
    ]

    static var random: String {
        quotes.randomElement() ?? quotes[0]
    }

    // Same quote all day — changes at midnight
    static var todaysQuote: String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return quotes[day % quotes.count]
    }
}
