import SwiftUI
import AppKit

struct NudgeDetailView: View {
    let nudge: Nudge
    let onRespond: (NudgeStatus, String?) -> Void

    @State private var replyText = ""
    @State private var showReplyField = false
    @State private var threadExpanded = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var replyFocused: Bool

    private let expandThreshold: CGFloat = 40
    private let maxCompactHeight: CGFloat = 120
    private let maxExpandedHeight: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: priorityColor.opacity(0.6), radius: 4)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text(nudge.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(threadExpanded ? 3 : 1)

                    HStack(spacing: 4) {
                        if let folder = nudge.sourceFolder {
                            Text(folder)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Text(nudge.timestamp, style: .relative)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Thread area
            if threadExpanded {
                threadHint

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let body = nudge.body {
                            MessageBubble(text: body, sender: nudge.from ?? "ai")
                        }
                        ForEach(nudge.replies) { reply in
                            MessageBubble(text: reply.message, sender: reply.sender)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: maxExpandedHeight)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Compact — latest message only, capped height
                ZStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        if hasThread {
                            threadHint
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            latestMessageView
                                .padding(.horizontal, 10)
                                .padding(.bottom, 6)
                        }
                        .frame(maxHeight: maxCompactHeight)
                    }
                    .offset(y: dragOffset)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            let drag = value.translation.height
                            if drag > 0 {
                                dragOffset = drag * 0.15
                            } else {
                                let resistance = min(abs(drag), expandThreshold * 1.5)
                                dragOffset = -resistance * 0.6
                            }
                        }
                        .onEnded { value in
                            let drag = value.translation.height
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                dragOffset = 0
                                if drag < -expandThreshold && hasThread {
                                    threadExpanded = true
                                }
                            }
                        }
                )
            }

            // Reply field
            if showReplyField {
                HStack(spacing: 6) {
                    TextField("Reply...", text: $replyText)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .focused($replyFocused)
                        .onSubmit {
                            if !replyText.isEmpty {
                                onRespond(.replied, replyText)
                            }
                        }

                    Button(action: {
                        if !replyText.isEmpty {
                            onRespond(.replied, replyText)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(replyText.isEmpty ? .white.opacity(0.15) : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(replyText.isEmpty)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Action bar
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                if nudge.status == .done {
                    // Done nudges: just acknowledge + reply
                    ActionButton(icon: "arrowshape.turn.up.left", label: "Reply", color: .blue) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReplyField.toggle()
                        }
                        if showReplyField {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NSApp.activate(ignoringOtherApps: true)
                                replyFocused = true
                            }
                        }
                    }

                    ActionDivider()

                    ActionButton(icon: "checkmark", label: "OK", color: .green) {
                        onRespond(.dismissed, nil)
                    }
                } else {
                    ActionButton(icon: "checkmark", label: nudge.buttons.primary, color: .green) {
                        onRespond(.approved, nudge.buttons.primary)
                    }

                    ActionDivider()

                    ActionButton(icon: "xmark", label: nudge.buttons.secondary, color: .red) {
                        onRespond(.rejected, nudge.buttons.secondary)
                    }

                    ActionDivider()

                    ActionButton(icon: "arrowshape.turn.up.left", label: "Reply", color: .blue) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReplyField.toggle()
                        }
                        if showReplyField {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                NSApp.activate(ignoringOtherApps: true)
                                replyFocused = true
                            }
                        }
                    }

                    if let url = nudge.url {
                        ActionDivider()

                        ActionButton(icon: "arrow.up.right", label: nudge.action ?? "Open", color: .white) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    ActionDivider()

                    // Dismiss — archive without action
                    ActionButton(icon: "archivebox", label: "Done", color: .gray) {
                        onRespond(.dismissed, nil)
                    }
                }
            }
            .frame(height: 28)
        }
        .frame(width: 240)
        .background(glassBackground)
        .overlay(glassBorder)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: threadExpanded)
        .animation(.easeOut(duration: 0.2), value: showReplyField)
        .onTapGesture(count: 2) {
            openExpandedWindow()
        }
    }

    // MARK: - Glass styling

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
    }

    // MARK: - Subviews

    private var threadHint: some View {
        HStack(spacing: 4) {
            Image(systemName: threadExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 7, weight: .bold))
            Text(threadExpanded ? "Collapse" : "\(totalMessageCount) messages")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.2))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                threadExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var latestMessageView: some View {
        if let lastReply = nudge.replies.last {
            MessageBubble(text: lastReply.message, sender: lastReply.sender)
        } else if let body = nudge.body {
            MessageBubble(text: body, sender: nudge.from ?? "ai")
        }
    }

    // MARK: - Expanded Window

    private func openExpandedWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = nudge.title
        window.isReleasedWhenClosed = true
        window.level = .floating
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        window.isMovableByWindowBackground = true
        window.center()

        let expandedView = ExpandedNudgeView(
            nudge: nudge,
            onRespond: { status, message in
                onRespond(status, message)
                window.close()
                DispatchQueue.main.async {
                    NSApp.setActivationPolicy(.accessory)
                }
            },
            onClose: {
                window.close()
                DispatchQueue.main.async {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        )

        window.contentView = NSHostingView(rootView: expandedView)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Computed

    private var hasThread: Bool { totalMessageCount > 1 }

    private var totalMessageCount: Int {
        (nudge.body != nil ? 1 : 0) + nudge.replies.count
    }

    private var priorityColor: Color {
        switch nudge.priority {
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Expanded Reading View

struct ExpandedNudgeView: View {
    let nudge: Nudge
    let onRespond: (NudgeStatus, String?) -> Void
    let onClose: () -> Void

    @State private var replyText = ""
    @FocusState private var replyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: priorityColor.opacity(0.5), radius: 4)

                        Text(nudge.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 6) {
                        if let folder = nudge.sourceFolder {
                            Text(folder)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Text(nudge.timestamp, style: .relative)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.2))
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().overlay(.white.opacity(0.08))

            // Full conversation
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    if let body = nudge.body {
                        ExpandedBubble(text: body, sender: nudge.from ?? "ai")
                    }

                    ForEach(nudge.replies) { reply in
                        ExpandedBubble(text: reply.message, sender: reply.sender)
                    }
                }
                .padding(20)
            }

            Divider().overlay(.white.opacity(0.08))

            // Reply + Actions
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField("Reply...", text: $replyText)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .focused($replyFocused)
                        .onSubmit {
                            if !replyText.isEmpty {
                                onRespond(.replied, replyText)
                            }
                        }

                    Button(action: {
                        if !replyText.isEmpty { onRespond(.replied, replyText) }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(replyText.isEmpty ? .white.opacity(0.15) : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(replyText.isEmpty)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                        )
                )

                HStack(spacing: 10) {
                    if nudge.status == .done {
                        ExpandedActionButton(label: "OK", color: .green) {
                            onRespond(.dismissed, nil)
                        }
                    } else {
                        ExpandedActionButton(label: nudge.buttons.primary, color: .green) {
                            onRespond(.approved, nudge.buttons.primary)
                        }

                        ExpandedActionButton(label: nudge.buttons.secondary, color: .red) {
                            onRespond(.rejected, nudge.buttons.secondary)
                        }

                        if let url = nudge.url {
                            ExpandedActionButton(label: nudge.action ?? "Open", color: .blue) {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        ExpandedActionButton(label: "Done", color: .gray) {
                            onRespond(.dismissed, nil)
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
    }

    private var priorityColor: Color {
        switch nudge.priority {
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

struct ExpandedBubble: View {
    let text: String
    let sender: String

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 60) }

            VStack(alignment: isHuman ? .trailing : .leading, spacing: 2) {
                Text(isHuman ? "You" : "AI")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))

                Text(markdownText)
                    .font(.system(size: 13))
                    .foregroundStyle(isHuman ? .white.opacity(0.9) : .white.opacity(0.75))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isHuman ? .blue.opacity(0.2) : .white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isHuman ? .blue.opacity(0.1) : .white.opacity(0.04),
                                lineWidth: 0.5
                            )
                    )
            }

            if !isHuman { Spacer(minLength: 60) }
        }
    }

    private var isHuman: Bool { sender == "human" }

    private var markdownText: AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

struct ExpandedActionButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? color : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? color.opacity(0.1) : .white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isHovered ? color.opacity(0.2) : .white.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = h }
        }
    }
}

// MARK: - Message Bubble (compact card)

struct MessageBubble: View {
    let text: String
    let sender: String

    var body: some View {
        HStack {
            if isHuman { Spacer(minLength: 24) }

            Text(markdownText)
                .font(.system(size: 11))
                .foregroundStyle(isHuman ? .white.opacity(0.9) : .white.opacity(0.7))
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHuman ? .blue.opacity(0.25) : .white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isHuman ? .blue.opacity(0.12) : .white.opacity(0.04),
                            lineWidth: 0.5
                        )
                )

            if !isHuman { Spacer(minLength: 24) }
        }
    }

    private var isHuman: Bool { sender == "human" }

    private var markdownText: AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

// MARK: - Action Button (compact card)

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(isHovered ? color : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(isHovered ? color.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct ActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(width: 0.5, height: 14)
    }
}
