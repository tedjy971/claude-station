import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    @State private var hookInstalled = false
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i <= step ? Color.blue : Color.primary.opacity(0.1))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24).padding(.top, 16)

            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: hookStep
                default: readyStep
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            Spacer()

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
                Button(step < 2 ? "Next" : "Get Started") {
                    if step < 2 {
                        withAnimation { step += 1 }
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .frame(width: 440, height: 340)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 48)).foregroundStyle(.blue)
            Text("Welcome to Claude Station")
                .font(.title2.bold())
            Text("Monitor and control your Claude Code agents from one place.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    private var hookStep: some View {
        VStack(spacing: 12) {
            Image(systemName: hookInstalled ? "checkmark.shield.fill" : "bolt.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(hookInstalled ? .green : .orange)
            Text("Install Hook")
                .font(.title2.bold())
            Text("The hook lets Claude Station receive events instantly from Claude Code.")
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)

            if hookInstalled {
                Label("Hook installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.callout)
            } else {
                Button("Install Hook") {
                    hookInstalled = HookServer.installHook()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48)).foregroundStyle(.purple)
            Text("You're all set!")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                shortcutRow("⌃⇧A", "Approve all waiting agents")
                shortcutRow("⌃⇧D", "Deny all waiting agents")
                shortcutRow("⌃⇧V", "Toggle popover")
            }
            .padding(.horizontal, 40)
        }
    }

    private func shortcutRow(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced).bold())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(desc).font(.caption).foregroundStyle(.secondary)
        }
    }
}
