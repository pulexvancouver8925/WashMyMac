import Foundation
import IOKit.pwr_mgt

/// Keeps the display awake and at full brightness while cleaning.
///
/// One power assertion is not enough: we swallow every event, so as far as
/// macOS is concerned nobody is at the keyboard and the idle timer runs.
/// Hence the periodic "user is active" declaration as well.
final class DisplayKeeper {
    private var sleepAssertion: IOPMAssertionID = 0
    private var activityAssertion: IOPMAssertionID = 0
    private var heartbeat: Timer?

    func start() {
        var assertion: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "WashMyMac cleaning mode" as CFString,
            &assertion
        )
        if result == kIOReturnSuccess { sleepAssertion = assertion }

        declareUserActivity()
        let heartbeat = Timer(timeInterval: 20, repeats: true) { [weak self] _ in
            self?.declareUserActivity()
        }
        RunLoop.main.add(heartbeat, forMode: .common)
        self.heartbeat = heartbeat
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
        if sleepAssertion != 0 {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
        }
        activityAssertion = 0
    }

    private func declareUserActivity() {
        IOPMAssertionDeclareUserActivity(
            "WashMyMac cleaning mode" as CFString,
            kIOPMUserActiveLocal,
            &activityAssertion
        )
    }
}
