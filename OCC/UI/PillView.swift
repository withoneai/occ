import SwiftUI

struct PillContainerView: View {
    @ObservedObject var router: NotificationRouter
    var position: PillPosition

    private var isExpanded: Bool {
        router.state == .expanded && !router.activeNudges.isEmpty
    }

    private var isInput: Bool {
        router.state == .input
    }

    @State private var showInlineInput = false

    var body: some View {
        VStack(alignment: dotAlignment, spacing: 6) {
            // Inline input (above the cards when expanded)
            if showInlineInput {
                PillInputView(
                    onSend: { message in
                        RequestWriter.sendRequest(message)
                        router.markRequestSent()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                            showInlineInput = false
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                            showInlineInput = false
                        }
                    }
                )
                .transition(.scale(scale: 0.5, anchor: pillAnchor).combined(with: .opacity))
            }

            // Card stack
            if isExpanded {
                // Plus button to send a new request
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            showInlineInput.toggle()
                        }
                        if showInlineInput {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                    }) {
                        Image(systemName: showInlineInput ? "minus" : "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 240)
                .transition(.scale(scale: 0.5).combined(with: .opacity))

                CardStackView(router: router)
                    .transition(.scale(scale: 0.5, anchor: pillAnchor).combined(with: .opacity))

                if router.activeNudges.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(0..<router.activeNudges.count, id: \.self) { i in
                            Circle()
                                .fill(i == router.currentIndex ? .white.opacity(0.6) : .white.opacity(0.15))
                                .frame(width: 4, height: 4)
                                .scaleEffect(i == router.currentIndex ? 1.2 : 1.0)
                        }
                    }
                    .padding(.top, 2)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }

            // Input field (when idle, no notifications)
            if isInput {
                PillInputView(
                    onSend: { message in
                        RequestWriter.sendRequest(message)
                        router.markRequestSent()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                            router.collapse()
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                            router.collapse()
                        }
                    }
                )
                .transition(.scale(scale: 0.5, anchor: pillAnchor).combined(with: .opacity))
            }

            // The pill icon
            PillDot(
                state: router.state,
                priority: router.currentPriority,
                count: router.activeNudges.count,
                requestedCount: router.requestedCount,
                workingCount: router.workingCount,
                showingFlows: router.showingFlows
            )
            .onTapGesture {
                switch router.state {
                case .idle:
                    if !router.activeNudges.isEmpty {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            router.expand()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            router.showInput()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                case .active:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        router.expand()
                    }
                case .expanded:
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        showInlineInput = false
                        router.collapse()
                    }
                case .input:
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                        router.collapse()
                    }
                }
            }
        }
        .frame(maxWidth: 280, maxHeight: .infinity, alignment: frameAlignment)
        .padding(8)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: router.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: router.currentIndex)
    }

    private var dotAlignment: HorizontalAlignment {
        switch position {
        case .bottomRight: return .trailing
        case .bottomLeft: return .leading
        case .bottomCenter: return .center
        }
    }

    private var frameAlignment: Alignment {
        switch position {
        case .bottomRight: return .bottomTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomCenter: return .bottom
        }
    }

    private var pillAnchor: UnitPoint {
        switch position {
        case .bottomRight: return .bottomTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomCenter: return .bottom
        }
    }
}

// MARK: - Input View

struct PillInputView: View {
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask AI something...", text: $text)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($isFocused)
                .onSubmit {
                    if !text.isEmpty {
                        onSend(text)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isFocused = true
                    }
                }
                .onExitCommand {
                    onCancel()
                }

            Button(action: {
                if !text.isEmpty { onSend(text) }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(text.isEmpty ? .white.opacity(0.15) : .blue)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 240)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
    }
}

// MARK: - Card Stack with Drag Swipe

struct CardStackView: View {
    @ObservedObject var router: NotificationRouter
    @State private var dragOffset: CGFloat = 0

    private let cardWidth: CGFloat = 240
    private let swipeThreshold: CGFloat = 40

    var body: some View {
        ZStack {
            ForEach(Array(router.activeNudges.enumerated()), id: \.element.id) { index, nudge in
                let depth = index - router.currentIndex

                if depth >= -1 && depth <= 2 {
                    NudgeDetailView(
                        nudge: nudge,
                        onRespond: { status, message in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                router.respond(to: nudge, status: status, message: message)
                            }
                        }
                    )
                    .scaleEffect(scaleFor(depth: depth, drag: dragOffset))
                    .offset(y: yOffsetFor(depth: depth))
                    .blur(radius: blurFor(depth: depth, drag: dragOffset))
                    .opacity(opacityFor(depth: depth, drag: dragOffset))
                    .zIndex(Double(100 - abs(depth)))
                    .allowsHitTesting(depth == 0)
                    .offset(x: xOffsetFor(depth: depth, drag: dragOffset))
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    let drag = value.translation.width
                    let canNext = router.currentIndex < router.activeNudges.count - 1
                    let canPrev = router.currentIndex > 0

                    if (drag < 0 && !canNext) || (drag > 0 && !canPrev) {
                        dragOffset = rubberBand(drag, limit: 60)
                    } else {
                        dragOffset = drag
                    }
                }
                .onEnded { value in
                    let drag = value.translation.width
                    let velocity = value.velocity.width

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        if drag < -swipeThreshold || velocity < -500 {
                            router.navigateNext()
                        } else if drag > swipeThreshold || velocity > 500 {
                            router.navigatePrevious()
                        }
                        dragOffset = 0
                    }
                }
        )
    }

    private func rubberBand(_ offset: CGFloat, limit: CGFloat) -> CGFloat {
        let sign: CGFloat = offset < 0 ? -1 : 1
        let abs = abs(offset)
        return sign * limit * (1 - exp(-abs / limit))
    }

    private func xOffsetFor(depth: Int, drag: CGFloat) -> CGFloat {
        if depth == 0 { return drag }
        if depth == 1 && drag < 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return 20 * (1 - progress)
        }
        if depth == -1 && drag > 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return -20 * (1 - progress)
        }
        return 0
    }

    private func scaleFor(depth: Int, drag: CGFloat) -> CGFloat {
        let base: CGFloat
        switch depth {
        case -1: base = 0.94
        case 0: base = 1.0
        case 1: base = 0.94
        case 2: base = 0.88
        default: return 0.85
        }
        if depth == 1 && drag < 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return base + (1.0 - base) * progress
        }
        if depth == -1 && drag > 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return base + (1.0 - base) * progress
        }
        return base
    }

    private func yOffsetFor(depth: Int) -> CGFloat {
        switch depth {
        case 0, -1: return 0
        case 1: return -8
        case 2: return -14
        default: return -18
        }
    }

    private func blurFor(depth: Int, drag: CGFloat) -> CGFloat {
        let base: CGFloat
        switch depth {
        case 0: base = 0
        case 1, -1: base = 2
        case 2: base = 4
        default: return 6
        }
        if depth == 1 && drag < 0 {
            return base * (1 - min(abs(drag) / cardWidth, 1.0))
        }
        if depth == -1 && drag > 0 {
            return base * (1 - min(abs(drag) / cardWidth, 1.0))
        }
        return base
    }

    private func opacityFor(depth: Int, drag: CGFloat) -> Double {
        let base: Double
        switch depth {
        case -1: base = 0.3
        case 0: base = 1.0
        case 1: base = 0.6
        case 2: base = 0.3
        default: return 0
        }
        if depth == 1 && drag < 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return base + (1.0 - base) * progress
        }
        if depth == -1 && drag > 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return base + (1.0 - base) * progress
        }
        if depth == 0 {
            let progress = min(abs(drag) / cardWidth, 1.0)
            return 1.0 - progress * 0.3
        }
        return base
    }
}

// MARK: - Pill Dot (Logo Icon)

struct PillDot: View {
    let state: PillState
    let priority: NudgePriority
    let count: Int
    let requestedCount: Int
    let workingCount: Int
    var showingFlows: Bool = false

    @AppStorage("occ.pill.iconStyle") private var iconStyle: String = "logo"
    @State private var isPulsing = false
    @State private var glowOpacity: Double = 0
    @State private var statusBlink = false
    @State private var isHovering = false

    private var hasAiActivity: Bool { requestedCount > 0 || workingCount > 0 }
    private var useChibi: Bool { iconStyle != "logo" }

    var body: some View {
        ZStack {
            if useChibi {
                // Chibi character
                ChibiView(
                    character: ChibiCharacter(rawValue: iconStyle) ?? .cat,
                    state: state,
                    hasNotification: count > 0,
                    isWorking: isWorking,
                    isRequested: requestedCount > 0 && workingCount == 0,
                    notificationCount: count
                )
            } else {
                // Logo
                if isActive {
                    OCCIcon(color: .white, size: iconSize + 6)
                        .opacity(glowOpacity * 0.3)
                        .blur(radius: 6)
                }

                OCCIcon(color: iconColor, size: iconSize)
                    .opacity(iconOpacity)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .scaleEffect(isHovering ? 1.15 : (isPulsing ? 1.05 : 1.0))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovering)
            }

            if !useChibi {
                // AI activity dot (logo mode only)
                if hasAiActivity {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 5, height: 5)
                        .opacity(isWorking ? (statusBlink ? 1.0 : 0.25) : 0.8)
                        .shadow(color: .yellow.opacity(0.5), radius: isWorking && statusBlink ? 4 : 0)
                        .offset(x: 12, y: -10)
                }

                // Count badge (logo mode only)
                if count > 1 {
                    Text("\(count)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.red.opacity(0.85)))
                        .offset(x: 14, y: -14)
                }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                    glowOpacity = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    isPulsing = false
                    glowOpacity = 0
                }
            }
        }
        .onChange(of: isWorking) { working in
            if working {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    statusBlink = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    statusBlink = false
                }
            }
        }
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }

    private var isWorking: Bool { workingCount > 0 }

    private var isActive: Bool {
        (state == .active || state == .idle) && count > 0
    }

    private var iconSize: CGFloat {
        (count > 0 || hasAiActivity) ? 20 : 18
    }

    private static let brandYellow = Color(red: 243/255, green: 199/255, blue: 71/255) // #F3C747

    private var iconColor: Color {
        if showingFlows { return Self.brandYellow }
        guard count > 0 || hasAiActivity else { return .white.opacity(0.25) }
        if hasAiActivity && count == 0 { return .white.opacity(0.5) }
        return .white
    }

    private var iconOpacity: Double {
        if showingFlows { return 1.0 }
        if hasAiActivity && count == 0 { return 0.6 }
        guard count > 0 else { return 0.4 }
        switch state {
        case .active: return isPulsing ? 1.0 : 0.7
        case .expanded, .input: return 1.0
        case .idle: return 0.65
        }
    }
}
