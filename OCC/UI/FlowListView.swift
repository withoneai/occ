import SwiftUI
import AppKit

// MARK: - Tabbed Command Panel (Flows + Skills)

enum CommandTab: String, CaseIterable {
    case flows = "Flows"
    case skills = "Skills"
}

struct CommandPanelView: View {
    @ObservedObject var flowStore: FlowStore
    @ObservedObject var skillStore: SkillStore
    let onSelectFlow: (Flow) -> Void
    let onSelectSkill: (Skill) -> Void

    @State private var selectedTab: CommandTab = .flows

    private var itemCount: Int {
        switch selectedTab {
        case .flows: return flowStore.flows.count
        case .skills: return skillStore.skills.count
        }
    }

    private var isEmpty: Bool {
        switch selectedTab {
        case .flows: return flowStore.flows.isEmpty
        case .skills: return skillStore.skills.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Connections summary (always on top)
            if !flowStore.allPlatforms.isEmpty {
                HStack(spacing: -4) {
                    ForEach(flowStore.allPlatforms.prefix(8), id: \.self) { platform in
                        ConnectorIcon(platform: platform)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
                    }
                    if flowStore.allPlatforms.count > 8 {
                        Text("+\(flowStore.allPlatforms.count - 8)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 6)
                    }
                    Spacer()
                    Text("\(flowStore.allPlatforms.count) connected")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }

            // Tab picker
            HStack(spacing: 0) {
                ForEach(CommandTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            Text("\(tab == .flows ? flowStore.flows.count : skillStore.skills.count)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? .white.opacity(0.1) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, flowStore.allPlatforms.isEmpty ? 10 : 0)
            .padding(.bottom, 6)

            // Content
            if isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        switch selectedTab {
                        case .flows:
                            ForEach(flowStore.flows) { flow in
                                FlowRow(flow: flow, lastRun: flowStore.lastRun(for: flow.id))
                                    .onTapGesture { onSelectFlow(flow) }
                            }
                        case .skills:
                            ForEach(skillStore.skills) { skill in
                                SkillRow(skill: skill)
                                    .onTapGesture { onSelectSkill(skill) }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(width: 300, height: isEmpty ? 120 : min(CGFloat(itemCount * 44 + (flowStore.allPlatforms.isEmpty ? 70 : 100)), 400))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: selectedTab == .flows ? "arrow.triangle.branch" : "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(.quaternary)
            Text(selectedTab == .flows ? "No flows yet" : "No skills yet")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: Skill
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(skill.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                } else if let cmd = skill.slashCommand {
                    Text(cmd)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer()

            if isHovering {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? .white.opacity(0.05) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(skill.description)
    }
}

struct FlowRow: View {
    let flow: Flow
    let lastRun: Date?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Flow name + meta (left)
            VStack(alignment: .leading, spacing: 1) {
                Text(flow.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("\(flow.stepCount) step\(flow.stepCount == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)

                    if let lastRun {
                        Text("·")
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                        Text(lastRun, style: .relative)
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
            }

            Spacer()

            // Platform icons (right, overlapping)
            if !flow.platforms.isEmpty {
                HStack(spacing: -4) {
                    ForEach(flow.platforms.prefix(4), id: \.self) { platform in
                        ConnectorIcon(platform: platform)
                            .frame(width: 18, height: 18)
                            .background(
                                Circle()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                }
            }

            // Run hint on hover
            if isHovering {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? .white.opacity(0.05) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(flow.description)
    }
}

// MARK: - Flow Input View

struct FlowInputView: View {
    let flow: Flow
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Flow name label
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.3))
                Text(flow.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            // Input field
            HStack(spacing: 8) {
                TextField("Describe what to run...", text: $text)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .onSubmit {
                        send()
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                    .onExitCommand {
                        onCancel()
                    }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(text.isEmpty ? .white.opacity(0.15) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 300)
    }

    private func send() {
        guard !text.isEmpty else { return }
        onSend(text)
    }
}

// MARK: - Skill Input View

struct SkillInputView: View {
    let skill: Skill
    let onSend: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 7))
                    .foregroundStyle(.white.opacity(0.3))
                Text(skill.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                TextField("What should this skill do...", text: $text)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .onSubmit { send() }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                    .onExitCommand { onCancel() }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(text.isEmpty ? .white.opacity(0.15) : .blue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 300)
    }

    private func send() {
        guard !text.isEmpty else { return }
        onSend(text)
    }
}

// MARK: - Connector Icon (local PNG with remote SVG fallback)

struct ConnectorIcon: View {
    let platform: String

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Letter fallback
                ZStack {
                    Circle()
                        .fill(.quaternary.opacity(0.3))
                    Text(platform.prefix(1).uppercased())
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            image = await Self.loadIcon(for: platform)
        }
    }

    private static let cache = NSCache<NSString, NSImage>()

    private static func loadIcon(for platform: String) async -> NSImage? {
        let cacheKey = platform as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // 1. Try bundled PNG
        if let pngURL = Bundle.module.url(forResource: platform, withExtension: "png"),
           let img = NSImage(contentsOf: pngURL) {
            cache.setObject(img, forKey: cacheKey)
            return img
        }

        // 2. Fallback: download SVG from CDN and rasterize
        guard let url = URL(string: "https://assets.withone.ai/connectors/\(platform).svg") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let nsImage = NSImage(data: data) else { return nil }

            let size = NSSize(width: 64, height: 64)
            let rendered = NSImage(size: size)
            rendered.lockFocus()
            nsImage.draw(
                in: NSRect(origin: .zero, size: size),
                from: NSRect(origin: .zero, size: nsImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            rendered.unlockFocus()

            cache.setObject(rendered, forKey: cacheKey)
            return rendered
        } catch {
            return nil
        }
    }
}
