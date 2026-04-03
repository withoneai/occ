import SwiftUI

// MARK: - Chibi Character System

enum ChibiCharacter: String, CaseIterable {
    case cat, dog, bunny, owl, fox, panda, penguin
    case slime, ghost, robot, sprout, star, octopus, mushroom, alien, tanuki, dragon

    var label: String {
        switch self {
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .bunny: return "Bunny"
        case .owl: return "Owl"
        case .fox: return "Fox"
        case .panda: return "Panda"
        case .penguin: return "Penguin"
        case .slime: return "Slime"
        case .ghost: return "Ghost"
        case .robot: return "Robot"
        case .sprout: return "Sprout"
        case .star: return "Star"
        case .octopus: return "Octo"
        case .mushroom: return "Shroom"
        case .alien: return "Alien"
        case .tanuki: return "Tanuki"
        case .dragon: return "Dragon"
        }
    }
}

// MARK: - Chibi View

struct ChibiView: View {
    let character: ChibiCharacter
    let state: PillState
    let hasNotification: Bool
    let isWorking: Bool
    let isRequested: Bool       // AI picked up request, getting ready
    let notificationCount: Int

    @State private var blinkPhase = false
    @State private var bounce = false
    @State private var isHovering = false
    @State private var walkFrame = false
    @State private var walkBob: CGFloat = 0
    @State private var walkLean: Double = 0
    @State private var walkTimer: DispatchSourceTimer?
    @State private var readyFrame = false
    @State private var speechPulse = false
    @State private var isSleeping = true
    @State private var sleepBob: CGFloat = 0
    @State private var sleepScale: CGFloat = 1.0

    private let pixelSize: CGFloat = 2.5

    var body: some View {
        ZStack {
            // Character
            let grid = currentGrid
            let colors = palette(for: character)

            VStack(spacing: 0) {
                ForEach(0..<grid.count, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<grid[row].count, id: \.self) { col in
                            Rectangle()
                                .fill(colors(grid[row][col]))
                                .frame(width: pixelSize, height: pixelSize)
                        }
                    }
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .scaleEffect(isHovering ? 1.2 : (bounce ? 1.1 : (effectivelySleeping ? sleepScale : 1.0)))
            .rotationEffect(.degrees(isRunning ? walkLean : 0))
            .offset(y: isRunning ? walkBob : (effectivelySleeping ? sleepBob : (bounce ? -2 : 0)))
            .opacity(effectivelySleeping ? 0.45 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isHovering)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bounce)
            .animation(.easeInOut(duration: 0.25), value: walkBob)
            .animation(.easeInOut(duration: 0.25), value: walkLean)
            .animation(.easeInOut(duration: 0.8), value: isSleeping)
            .animation(.easeInOut(duration: 1.5), value: sleepBob)

            // Pixel speech bubble with count
            if hasNotification {
                pixelSpeechBubble
                    .offset(x: 14, y: -14)
                    .scaleEffect(speechPulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: speechPulse)
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering && effectivelySleeping { wakeUp() }
        }
        .onAppear {
            startBlinking()
            startSleepBreathing()
            if hasNotification { wakeUp(); speechPulse = true }
            if isRunning { wakeUp(); startWalking() }
        }
        .onChange(of: hasNotification) { active in
            if active { wakeUp(); startBounce(); speechPulse = true } else { speechPulse = false; scheduleSleep() }
        }
        .onChange(of: isWorking) { working in
            if working { wakeUp(); startWalking() } else if !isRequested { stopWalking(); scheduleSleep() }
        }
        .onChange(of: isRequested) { requested in
            if requested { wakeUp(); startWalking() } else if !isWorking { stopWalking(); scheduleSleep() }
        }
        .onChange(of: state) { newState in
            if newState != .idle {
                wakeUp()
            } else {
                scheduleSleep()
            }
        }
    }

    private var isRunning: Bool { isWorking || isRequested }
    private var isIdle: Bool { !isRunning && !hasNotification }

    /// When sleeping, eyes are always closed (blinkPhase forced true)
    /// Never sleep when running or has notifications
    private var effectivelySleeping: Bool { isSleeping && isIdle }
    private var effectiveBlink: Bool { effectivelySleeping || blinkPhase }

    // MARK: - Current Grid Selection

    private var currentGrid: [[Int]] {
        if isRunning {
            return walkPixels(for: character)
        } else {
            return pixels(for: character)
        }
    }

    // MARK: - Pixel Speech Bubble

    private var pixelSpeechBubble: some View {
        ZStack {
            // Tiny pixel bubble (5x4 grid)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                }
                HStack(spacing: 0) {
                    Rectangle().fill(.white).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                    Rectangle().fill(.clear).frame(width: 2, height: 2)
                }
            }

            // Count number inside bubble
            if notificationCount > 0 {
                Text("\(notificationCount)")
                    .font(.system(size: 6, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .offset(y: -1)
            }
        }
    }

    // MARK: - Animations

    private func startBlinking() {
        func scheduleBlink() {
            let delay = Double.random(in: 2.0...4.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.06)) { blinkPhase = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.06)) { blinkPhase = false }
                    if Int.random(in: 0...4) == 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeInOut(duration: 0.06)) { blinkPhase = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.06)) { blinkPhase = false }
                            }
                        }
                    }
                    scheduleBlink()
                }
            }
        }
        scheduleBlink()
    }

    private func startBounce() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { bounce = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bounce = false }
        }
    }

    // MARK: - Sleep / Wake

    private func wakeUp() {
        guard isSleeping else { return }
        isSleeping = false
        startBounce()
        scheduleSleep()
    }

    private func scheduleSleep() {
        // Don't sleep if busy
        guard isIdle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [self] in
            guard isIdle else { return }
            isSleeping = true
        }
    }

    private func startSleepBreathing() {
        func breathe() {
            withAnimation(.easeInOut(duration: 2.0)) {
                sleepBob = -1.5
                sleepScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    sleepBob = 0
                    sleepScale = 0.97
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    breathe()
                }
            }
        }
        breathe()
    }

    // MARK: - Walk (AI working)

    private func startWalking() {
        stopWalking()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.3)
        timer.setEventHandler {
            walkFrame.toggle()
            walkBob = walkFrame ? -1.5 : 0
            walkLean = walkFrame ? 2 : -2
        }
        timer.resume()
        walkTimer = timer
    }

    private func stopWalking() {
        walkTimer?.cancel()
        walkTimer = nil
        walkFrame = false
        walkBob = 0
        walkLean = 0
    }

    // MARK: - Ready Pixel Grids (reserved for future use)

    private func readyPixels(for char: ChibiCharacter) -> [[Int]] {
        let e = effectiveBlink ? 1 : 3
        let f = readyFrame
        // Eyes look left or right
        let eL = f ? 3 : e  // left eye
        let eR = f ? e : 3  // right eye

        switch char {
        case .cat:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,1,2,0,0,2,1,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,eL,1,1,1,1,1,eR,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .dog:
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [2,2,1,1,1,1,1,1,2,2],
                [0,1,1,1,1,1,1,1,1,0],
                [0,eL,1,1,1,1,1,eR,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .bunny:
            return [
                [0,0, f ? 0 : 1, 0,0,0,0, f ? 1 : 0,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,eL,1,1,1,1,1,eR,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .owl:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [1,1,6,eL,1,1,6,eR,1,1],
                [1,1,6,6,1,1,6,6,1,1],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,2,1,1,1,1,2,1,0],
                [0,0,1,2,1,1,2,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
            ]
        case .fox:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [2,7,2,0,0,0,0,2,7,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,eL,1,1,1,1,1,eR,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,8,8,1,1,8,8,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .panda:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,eL,2,1,1,2,eR,2,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [0,2,2,0,0,0,0,2,2,0],
            ]
        case .penguin:
            return [
                [0,0,0,2,2,2,2,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,1,1,1,1,2,2,0],
                [0,2,eL,1,1,1,1,eR,2,0],
                [0,2,1,1,4,4,1,1,2,0],
                [2,2,1,5,1,1,5,1,2,2],
                [2,0,1,1,1,1,1,1,0,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,9,9,0,0,9,9,0,0],
            ]
        case .slime:
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,eL,1,1,1,eR,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
            ]
        case .ghost:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,eL,1,1,1,eR,1,1,0],
                [0,1,1,1,4,1,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,0,1,0,0,1,0,1,0],
            ]
        case .robot:
            return [
                [0,0,0,0,2,0,0,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,2,2,2,2,2,2,0],
                [0,2,6,eL,2,2,6,eR,2,0],
                [0,2,2,2,4,4,2,2,2,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,2,2,0,0,2,2,0,0],
            ]
        case .sprout:
            return [
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,0,6,0,0,6,0,0,0],
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,eL,1,1,eR,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,0,1,0,0,1,0,0,0],
            ]
        case .star:
            return [
                [0,0,0,0,1,1,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [1,1,1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,eL,1,1,eR,1,1,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,0,0,1,1,0,0,1,0],
                [1,0,0,0,0,0,0,0,0,1],
            ]
        case .octopus:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,eL,1,1,1,eR,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,0,1,0,1,1,0,1,0,1],
                [1,0,1,0,1,1,0,1,0,1],
                [0,0,0,0,0,0,0,0,0,0],
            ]
        case .mushroom:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,6,2,2,6,2,2,0],
                [2,2,6,6,2,2,6,6,2,2],
                [2,2,2,2,2,2,2,2,2,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,eL,1,1,eR,1,0,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,1,0,0,1,1,0,0],
            ]
        case .alien:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,eL,eL,1,1,1,eR,eR,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,0,0,0,0,1,0,0],
            ]
        case .tanuki:
            return [
                [0,2,2,0,0,0,0,2,2,0],
                [2,1,1,2,0,0,2,1,1,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,eL,2,1,1,2,eR,2,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .dragon:
            return [
                [0,6,0,0,0,0,0,0,6,0],
                [6,0,2,2,2,2,2,2,0,6],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [2,1,eL,1,1,1,eR,1,1,2],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        }
    }

    // MARK: - Walk Pixel Grids (running)

    private func walkPixels(for char: ChibiCharacter) -> [[Int]] {
        let e = effectiveBlink ? 1 : 3
        let f = walkFrame

        switch char {
        case .cat:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,1,2,0,0,2,1,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,e,1,1,1,e,1,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .dog:
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [2,2,1,1,1,1,1,1,2,2],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .bunny:
            return [
                [0,0,1,0,0,0,0,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,e,1,1,1,e,1,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .owl:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [1,1,6,e,1,1,6,e,1,1],
                [1,1,6,6,1,1,6,6,1,1],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,2,1,1,1,1,2,1,0],
                [0,0,1,2,1,1,2,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                f ? [0,1,0,0,0,0,0,0,1,0] : [0,0,0,1,0,0,1,0,0,0],
            ]
        case .fox:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [2,7,2,0,0,0,0,2,7,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,e,1,1,1,e,1,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,8,8,1,1,8,8,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .panda:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,2,e,1,1,2,2,e,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                f ? [2,2,0,0,0,0,0,0,2,2] : [0,0,2,2,0,0,2,2,0,0],
            ]
        case .penguin:
            return [
                [0,0,0,2,2,2,2,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,1,1,1,1,2,2,0],
                [0,2,1,e,1,1,e,1,2,0],
                [0,2,1,1,4,4,1,1,2,0],
                [2,2,1,5,1,1,5,1,2,2],
                [2,0,1,1,1,1,1,1,0,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                f ? [0,9,9,0,0,0,0,9,9,0] : [0,0,0,9,9,9,9,0,0,0],
            ]
        case .slime:
            // Slime jiggles side to side
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                f ? [1,1,1,1,1,1,1,1,1,0] : [0,1,1,1,1,1,1,1,1,1],
                f ? [1,1,1,1,1,1,1,1,0,0] : [0,0,1,1,1,1,1,1,1,1],
                f ? [0,1,1,1,1,1,1,0,0,0] : [0,0,0,1,1,1,1,1,1,0],
            ]
        case .ghost:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,1,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [0,1,0,1,0,1,0,1,0,0] : [0,0,1,0,1,0,1,0,1,0],
            ]
        case .robot:
            return [
                [0,0,0,0,2,0,0,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,2,2,2,2,2,2,0],
                [0,2,6,e,2,2,6,e,2,0],
                [0,2,2,2,4,4,2,2,2,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                f ? [0,2,2,0,0,0,0,2,2,0] : [0,0,2,2,0,0,2,2,0,0],
            ]
        case .sprout:
            return [
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,0,6,0,0,6,0,0,0],
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,e,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                f ? [0,0,1,0,0,0,0,1,0,0] : [0,0,0,1,0,0,1,0,0,0],
            ]
        case .star:
            return [
                [0,0,0,0,1,1,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [1,1,1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,e,1,1,e,1,1,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,0,0,0,1,1,0,0,0,1] : [0,1,0,0,1,1,0,0,1,0],
                f ? [0,0,0,0,0,0,0,0,0,0] : [1,0,0,0,0,0,0,0,0,1],
            ]
        case .octopus:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,0,1,0,1,0,1,0,1,0] : [0,1,0,1,0,1,0,1,0,1],
                f ? [0,0,0,0,0,1,0,0,0,1] : [1,0,0,0,1,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0],
            ]
        case .mushroom:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,6,2,2,6,2,2,0],
                [2,2,6,6,2,2,6,6,2,2],
                [2,2,2,2,2,2,2,2,2,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,e,1,1,e,1,0,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                f ? [0,1,1,0,0,0,0,1,1,0] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .alien:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,e,e,1,1,1,e,e,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                f ? [0,0,1,0,0,0,0,1,0,0] : [0,0,0,1,0,0,1,0,0,0],
            ]
        case .tanuki:
            return [
                [0,2,2,0,0,0,0,2,2,0],
                [2,1,1,2,0,0,2,1,1,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,e,2,1,1,2,e,2,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        case .dragon:
            return [
                [0,6,0,0,0,0,0,0,6,0],
                [6,0,2,2,2,2,2,2,0,6],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [2,1,e,1,1,1,e,1,1,2],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                f ? [1,1,0,0,0,0,0,0,1,1] : [0,0,1,1,0,0,1,1,0,0],
            ]
        }
    }

    // MARK: - Idle Pixel Grids

    private func pixels(for char: ChibiCharacter) -> [[Int]] {
        let e = effectiveBlink ? 1 : 3
        switch char {
        case .cat:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,1,2,0,0,2,1,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,e,1,1,1,e,1,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .dog:
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [2,2,1,1,1,1,1,1,2,2],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .bunny:
            return [
                [0,0,1,0,0,0,0,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,e,1,1,1,e,1,1,1],
                [1,5,1,1,4,4,1,1,5,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .owl:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [1,1,6,e,1,1,6,e,1,1],
                [1,1,6,6,1,1,6,6,1,1],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,2,1,1,1,1,2,1,0],
                [0,0,1,2,1,1,2,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,0,0,0,0,1,0,0],
            ]
        case .fox:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [2,7,2,0,0,0,0,2,7,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,e,1,1,1,e,1,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,8,8,1,1,8,8,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .panda:
            return [
                [0,0,2,0,0,0,0,2,0,0],
                [0,2,2,0,0,0,0,2,2,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,2,e,1,1,2,2,e,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [0,2,2,0,0,0,0,2,2,0],
            ]
        case .penguin:
            return [
                [0,0,0,2,2,2,2,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,1,1,1,1,2,2,0],
                [0,2,1,e,1,1,e,1,2,0],
                [0,2,1,1,4,4,1,1,2,0],
                [2,2,1,5,1,1,5,1,2,2],
                [2,0,1,1,1,1,1,1,0,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,9,9,0,0,9,9,0,0],
            ]
        case .slime:
            return [
                [0,0,0,0,0,0,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,1,1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
            ]
        case .ghost:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,1,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,0,1,0,0,1,0,1,0],
            ]
        case .robot:
            return [
                [0,0,0,0,2,0,0,0,0,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,2,2,2,2,2,2,0],
                [0,2,6,e,2,2,6,e,2,0],
                [0,2,2,2,4,4,2,2,2,0],
                [0,0,2,2,2,2,2,2,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,2,1,1,1,1,1,1,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,2,2,0,0,2,2,0,0],
            ]
        case .sprout:
            return [
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,0,6,0,0,6,0,0,0],
                [0,0,0,0,6,6,0,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,e,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,0,1,0,0,1,0,0,0],
            ]
        case .star:
            return [
                [0,0,0,0,1,1,0,0,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [1,1,1,1,1,1,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,e,1,1,e,1,1,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,0,0,1,1,0,0,1,0],
                [1,0,0,0,0,0,0,0,0,1],
            ]
        case .octopus:
            return [
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,e,1,1,1,e,1,1,0],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,5,1,1,1,1,5,1,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,0,1,0,1,1,0,1,0,1],
                [1,0,1,0,1,1,0,1,0,1],
                [0,0,0,0,0,0,0,0,0,0],
            ]
        case .mushroom:
            return [
                [0,0,2,2,2,2,2,2,0,0],
                [0,2,2,6,2,2,6,2,2,0],
                [2,2,6,6,2,2,6,6,2,2],
                [2,2,2,2,2,2,2,2,2,2],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,e,1,1,e,1,0,0],
                [0,0,1,1,4,4,1,1,0,0],
                [0,0,1,5,1,1,5,1,0,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,1,1,0,0,1,1,0,0],
            ]
        case .alien:
            return [
                [0,2,0,0,0,0,0,0,2,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,e,e,1,1,1,e,e,1,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,1,1,1,1,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,0,0,1,1,1,1,0,0,0],
                [0,0,1,0,0,0,0,1,0,0],
            ]
        case .tanuki:
            return [
                [0,2,2,0,0,0,0,2,2,0],
                [2,1,1,2,0,0,2,1,1,2],
                [0,1,1,1,1,1,1,1,1,0],
                [1,1,1,1,1,1,1,1,1,1],
                [1,2,e,2,1,1,2,e,2,1],
                [1,1,1,1,4,4,1,1,1,1],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        case .dragon:
            return [
                [0,6,0,0,0,0,0,0,6,0],
                [6,0,2,2,2,2,2,2,0,6],
                [0,2,1,1,1,1,1,1,2,0],
                [2,1,1,1,1,1,1,1,1,2],
                [2,1,e,1,1,1,e,1,1,2],
                [0,1,1,1,4,4,1,1,1,0],
                [0,1,1,5,1,1,5,1,1,0],
                [0,0,1,1,1,1,1,1,0,0],
                [0,1,1,1,1,1,1,1,1,0],
                [0,1,1,0,0,0,0,1,1,0],
            ]
        }
    }

    // MARK: - Color Palettes

    private func palette(for char: ChibiCharacter) -> (Int) -> Color {
        switch char {
        case .cat:
            return { v in
                switch v {
                case 1: return Color(red: 0.85, green: 0.75, blue: 0.65)
                case 2: return Color(red: 0.55, green: 0.45, blue: 0.38)
                case 3: return Color(red: 0.15, green: 0.15, blue: 0.15)
                case 4: return Color(red: 0.85, green: 0.55, blue: 0.55)
                case 5: return Color(red: 0.95, green: 0.75, blue: 0.75)
                default: return .clear
                }
            }
        case .dog:
            return { v in
                switch v {
                case 1: return Color(red: 0.82, green: 0.68, blue: 0.50)
                case 2: return Color(red: 0.60, green: 0.42, blue: 0.25)
                case 3: return Color(red: 0.15, green: 0.15, blue: 0.15)
                case 4: return Color(red: 0.20, green: 0.20, blue: 0.20)
                case 5: return Color(red: 0.95, green: 0.78, blue: 0.70)
                default: return .clear
                }
            }
        case .bunny:
            return { v in
                switch v {
                case 1: return Color(red: 0.95, green: 0.92, blue: 0.90)
                case 2: return Color(red: 0.80, green: 0.75, blue: 0.72)
                case 3: return Color(red: 0.20, green: 0.15, blue: 0.15)
                case 4: return Color(red: 0.90, green: 0.60, blue: 0.65)
                case 5: return Color(red: 0.95, green: 0.78, blue: 0.80)
                default: return .clear
                }
            }
        case .owl:
            return { v in
                switch v {
                case 1: return Color(red: 0.78, green: 0.65, blue: 0.50)
                case 2: return Color(red: 0.55, green: 0.40, blue: 0.28)
                case 3: return Color(red: 0.10, green: 0.10, blue: 0.10)
                case 4: return Color(red: 0.85, green: 0.65, blue: 0.30)
                case 6: return Color(red: 0.95, green: 0.88, blue: 0.70)
                default: return .clear
                }
            }
        case .fox:
            return { v in
                switch v {
                case 1: return Color(red: 0.92, green: 0.55, blue: 0.25)
                case 2: return Color(red: 0.75, green: 0.38, blue: 0.15)
                case 3: return Color(red: 0.12, green: 0.12, blue: 0.12)
                case 4: return Color(red: 0.18, green: 0.18, blue: 0.18)
                case 7: return Color(red: 0.95, green: 0.70, blue: 0.40)
                case 8: return Color(red: 0.95, green: 0.92, blue: 0.88)
                default: return .clear
                }
            }
        case .panda:
            return { v in
                switch v {
                case 1: return Color(red: 0.95, green: 0.95, blue: 0.95)
                case 2: return Color(red: 0.15, green: 0.15, blue: 0.15)
                case 3: return Color(red: 0.95, green: 0.95, blue: 0.95)
                case 4: return Color(red: 0.20, green: 0.20, blue: 0.20)
                case 5: return Color(red: 0.95, green: 0.75, blue: 0.75)
                default: return .clear
                }
            }
        case .penguin:
            return { v in
                switch v {
                case 1: return Color(red: 0.95, green: 0.95, blue: 0.95)
                case 2: return Color(red: 0.15, green: 0.18, blue: 0.25)
                case 3: return Color(red: 0.10, green: 0.10, blue: 0.10)
                case 4: return Color(red: 0.90, green: 0.65, blue: 0.20)
                case 5: return Color(red: 0.95, green: 0.80, blue: 0.80)
                case 9: return Color(red: 0.90, green: 0.60, blue: 0.15)
                default: return .clear
                }
            }
        case .slime:
            return { v in
                switch v {
                case 1: return Color(red: 0.45, green: 0.85, blue: 0.55)  // green jelly
                case 3: return Color(red: 0.15, green: 0.35, blue: 0.18)  // dark eye
                case 4: return Color(red: 0.35, green: 0.70, blue: 0.42)  // mouth
                case 5: return Color(red: 0.65, green: 0.95, blue: 0.72)  // cheek highlight
                default: return .clear
                }
            }
        case .ghost:
            return { v in
                switch v {
                case 1: return Color(red: 0.92, green: 0.90, blue: 0.95)  // pale lavender
                case 3: return Color(red: 0.20, green: 0.15, blue: 0.30)  // purple eye
                case 4: return Color(red: 0.75, green: 0.60, blue: 0.80)  // mouth
                case 5: return Color(red: 0.95, green: 0.80, blue: 0.90)  // blush
                default: return .clear
                }
            }
        case .robot:
            return { v in
                switch v {
                case 1: return Color(red: 0.70, green: 0.75, blue: 0.80)  // silver body
                case 2: return Color(red: 0.40, green: 0.45, blue: 0.55)  // dark metal
                case 3: return Color(red: 0.30, green: 0.85, blue: 0.95)  // cyan eye
                case 4: return Color(red: 0.55, green: 0.60, blue: 0.65)  // mouth grille
                case 6: return Color(red: 0.20, green: 0.65, blue: 0.75)  // eye socket
                default: return .clear
                }
            }
        case .sprout:
            return { v in
                switch v {
                case 1: return Color(red: 0.90, green: 0.82, blue: 0.65)  // earthy tan
                case 3: return Color(red: 0.20, green: 0.18, blue: 0.12)  // dark eye
                case 4: return Color(red: 0.75, green: 0.50, blue: 0.45)  // mouth
                case 5: return Color(red: 0.95, green: 0.78, blue: 0.68)  // cheek
                case 6: return Color(red: 0.40, green: 0.78, blue: 0.35)  // green leaf
                default: return .clear
                }
            }
        case .star:
            return { v in
                switch v {
                case 1: return Color(red: 1.0, green: 0.85, blue: 0.30)   // golden yellow
                case 3: return Color(red: 0.20, green: 0.15, blue: 0.05)  // dark eye
                case 4: return Color(red: 0.90, green: 0.60, blue: 0.25)  // mouth
                case 5: return Color(red: 1.0, green: 0.70, blue: 0.60)   // blush
                default: return .clear
                }
            }
        case .octopus:
            return { v in
                switch v {
                case 1: return Color(red: 0.85, green: 0.50, blue: 0.70)  // pink-purple
                case 3: return Color(red: 0.20, green: 0.10, blue: 0.18)  // dark eye
                case 4: return Color(red: 0.70, green: 0.35, blue: 0.55)  // mouth
                case 5: return Color(red: 0.95, green: 0.70, blue: 0.82)  // cheek
                default: return .clear
                }
            }
        case .mushroom:
            return { v in
                switch v {
                case 1: return Color(red: 0.95, green: 0.92, blue: 0.85)  // cream stem
                case 2: return Color(red: 0.85, green: 0.30, blue: 0.30)  // red cap
                case 3: return Color(red: 0.18, green: 0.15, blue: 0.12)  // eye
                case 4: return Color(red: 0.80, green: 0.55, blue: 0.50)  // mouth
                case 5: return Color(red: 0.95, green: 0.78, blue: 0.75)  // cheek
                case 6: return Color(red: 0.95, green: 0.90, blue: 0.80)  // cap spots
                default: return .clear
                }
            }
        case .alien:
            return { v in
                switch v {
                case 1: return Color(red: 0.55, green: 0.90, blue: 0.80)  // teal
                case 2: return Color(red: 0.35, green: 0.60, blue: 0.55)  // antennae
                case 3: return Color(red: 0.10, green: 0.10, blue: 0.10)  // big dark eye
                case 4: return Color(red: 0.40, green: 0.75, blue: 0.65)  // mouth
                default: return .clear
                }
            }
        case .tanuki:
            return { v in
                switch v {
                case 1: return Color(red: 0.75, green: 0.60, blue: 0.42)  // brown
                case 2: return Color(red: 0.35, green: 0.28, blue: 0.18)  // dark brown mask
                case 3: return Color(red: 0.12, green: 0.12, blue: 0.10)  // eye
                case 4: return Color(red: 0.22, green: 0.20, blue: 0.18)  // nose
                case 5: return Color(red: 0.90, green: 0.75, blue: 0.65)  // cheek
                default: return .clear
                }
            }
        case .dragon:
            return { v in
                switch v {
                case 1: return Color(red: 0.55, green: 0.75, blue: 0.85)  // ice blue body
                case 2: return Color(red: 0.35, green: 0.50, blue: 0.62)  // darker scales
                case 3: return Color(red: 0.12, green: 0.12, blue: 0.15)  // eye
                case 4: return Color(red: 0.70, green: 0.50, blue: 0.55)  // mouth
                case 5: return Color(red: 0.80, green: 0.70, blue: 0.85)  // cheek
                case 6: return Color(red: 0.85, green: 0.55, blue: 0.30)  // horn orange
                default: return .clear
                }
            }
        }
    }
}
