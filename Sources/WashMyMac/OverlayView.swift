import SwiftUI

/// Contents of the black screen: everything is drawn straight onto black, no panels.
/// The hint lives for a few seconds, then dissolves and leaves the beacon behind.
struct OverlayView: View {
    @ObservedObject var session: CleaningSession
    let isPrimary: Bool

    @State private var pulse = false

    private var isUnlocking: Bool { session.unlockProgress > 0.001 }

    /// Share of the time left before auto-exit — the ring is filled with it.
    private var timeFraction: Double {
        let total = Double(Settings.shared.autoUnlockMinutes * 60)
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(session.secondsLeft) / total))
    }

    private var showsCenter: Bool { isPrimary && (isUnlocking || session.hintVisible) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isPrimary {
                center.opacity(showsCenter ? 1 : 0)
            }

            if isPrimary && !showsCenter {
                VStack {
                    Spacer()
                    beacon.padding(.bottom, 44)
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showsCenter)
        .animation(.easeOut(duration: 0.2), value: isUnlocking)
        .colorScheme(.dark)
    }

    // MARK: - Centre of the screen

    private var center: some View {
        VStack(spacing: 0) {
            ring
                .frame(width: 108, height: 108)

            // The hint always stays in the layout and merely turns transparent,
            // so the block keeps its height and the ring never jumps around.
            ZStack(alignment: .top) {
                hintText
                    .opacity(isUnlocking ? 0 : 1)

                Text(L.t("overlay.unlocking"))
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(isUnlocking ? 1 : 0)
            }
            .padding(.top, 26)
        }
    }

    private var hintText: some View {
        VStack(spacing: 0) {
            Text(L.t("overlay.ready"))
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Text(L.f("overlay.hold", CleaningSession.unlockKeyLabel, L.decimal(Settings.shared.holdSeconds)))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 9)

            if session.guardMode == .windowOnly {
                Label(
                    L.t("overlay.degraded"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(Color.orange.opacity(0.75))
                .padding(.top, 18)
            }
        }
    }

    /// One ring in two roles: the countdown to auto-exit and the progress of
    /// holding the unlock combination.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.09), lineWidth: 3)

            Circle()
                .trim(from: 0, to: isUnlocking ? session.unlockProgress : timeFraction)
                .stroke(
                    .white.opacity(isUnlocking ? 1 : 0.32),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if isUnlocking {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Text(L.clock(session.secondsLeft))
                    .font(.system(size: 21, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Beacon

    /// Shows up once the hint is gone: proof that the Mac is alive and the
    /// screen did not simply switch itself off.
    private var beacon: some View {
        HStack(spacing: 8) {
            Circle()
                .frame(width: 5, height: 5)
                .opacity(pulse ? 1 : 0.28)
            Text("⌃⌥⌘\(CleaningSession.unlockKeyLabel)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.22))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
