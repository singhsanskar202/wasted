import Combine
import FamilyControls
import StoreKit
import SwiftUI

// ONE NUMBER. Everything else on this screen is subordinate to it, and the
// hierarchy IS the design.
//
// An itemised receipt sat where the number is for exactly one commit, and it
// broke the screen: with a single tracked app the line item and the total are the
// same number printed twice, and the eye had six competing text blocks — wordmark,
// date, app row, "total", percentage, equivalent — with nothing telling it where
// to land. Itemisation is what you open the receipt FOR. It is not what you
// glance at.
struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var proStore = ProStore.shared

    @State private var selection = HomeView.loadSavedSelection()
    @State private var showingPicker = false
    @State private var showingReceipt = false
    @State private var showingPaywall = false
    @State private var showingHistory = false
    @State private var hourlyData = UsageStore().loadTodayHourly()
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()
    @State private var appeared = false
    @State private var historicalPeak: HistoricalPeak? = nil
    @State private var realityCheck: RealityCheck? = nil
    @State private var trackingFailed = false
    @State private var trackingDegraded = false
    // The last total actually pushed to ActivityKit, so a five-second poll that
    // finds nothing new doesn't hammer the update budget.
    @State private var lastPushedTotal = -1
    // The widget is the only surface iOS never kills — the island dies 8h after
    // creation, notifications get swiped away — and nobody adds it unprompted
    // (device logs: `timeline built: 0` after weeks). One quiet mention, then
    // never again: repetition would make it a plea, and the mirror doesn't plead.
    @AppStorage("widget_hint_dismissed") private var widgetHintDismissed = false
    // The bill, and the week's grid. Both are disk reads, so they're built once
    // per refresh rather than on every one of this view's five-second renders.
    @State private var receipt = DailyReceipt(dateString: "", items: [], totalSeconds: 0, percentOfAwakeDay: 0)
    @State private var weekDays: [DailyUsage] = []
    @State private var exportedLog: ExportedLog?

    private let store = UsageStore()

    // The extension writes usage to the App Group only at thresholds; without
    // a poll the screen would only catch up on foreground. 5s keeps it close
    // to live while Wasted is open (the underlying data still steps at
    // thresholds, so this is as fresh as the OS makes usage available).
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private let gutter: CGFloat = 28

    // ONE NUMBER, THEN TWO ANSWERS TO IT.
    //
    //   1. THE VOICE   the mirror speaks, and it gets meaner as you scroll
    //   2. THE NUMBER  the only thing on this screen that shouts
    //   3. THE ZONES   WHERE the day leaked. the only actionable thing here
    //   4. THE WEEK    locked and blurred. a bad evening, or a bad life?
    //
    // The hierarchy is the design. An itemised receipt sat in slot 2 for exactly
    // one commit, and it destroyed the hierarchy: with a single tracked app the
    // line item and the total are the same number printed twice, and the eye had
    // six competing text blocks with nothing telling it where to land. Itemisation
    // is what you open the receipt FOR — it is not what you glance at.
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                trackingHealth
                voice

                VStack(spacing: 0) {
                    hero
                    Rule().padding(.top, 44)
                    zones
                    Rule()
                    week
                    Rule()
                    footer
                    closing
                }
            }
            .padding(.horizontal, gutter)
        }
        .background(Color.canvas.ignoresSafeArea())
        .task { await proStore.load() }
        .onAppear {
            appeared = true
            refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refresh()
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            refresh()
        }
        // The conversion moment gets the whole screen, once, with nothing to
        // compete against — see RealityCheckView.
        .fullScreenCover(item: $realityCheck) { check in
            RealityCheckView(check: check) {
                store.setRealityCheckShown(true)
                realityCheck = nil
            }
        }
        .sheet(isPresented: $showingReceipt, onDismiss: refresh) {
            // trueTotal, not the sum of the items: per-app thresholds are coarser
            // than the combined series, so the sheet reconciles the gap rather
            // than printing a bill that doesn't add up.
            ReceiptView(receipt: receipt, trueTotalSeconds: totalSeconds)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(store: proStore)
        }
        .sheet(isPresented: $showingHistory) {
            // Built at presentation, not on the refresh tick: the archive is
            // the one read that can be a year long.
            HistoryView(receipt: LongReceipt.build(days: store.loadFullHistory()))
        }
        .sheet(item: $exportedLog) { log in
            ShareLogSheet(url: log.url)
        }
    }

    // MARK: - Sections

    // The only place in this app where red is allowed to mean "something is
    // broken" rather than "this number is bad".
    //
    // If DeviceActivity rejects the event registration, the day records nothing —
    // and the failure mode is vicious: the number simply never moves. The user
    // doesn't see an error, they see a low number, and they might BELIEVE it.
    // An app whose entire promise is "you can't unsee the number" cannot quietly
    // show a false one.
    @ViewBuilder
    private var trackingHealth: some View {
        if trackingFailed {
            healthBanner(
                title: "tracking is off.",
                detail: "your phone isn't reporting usage. this number is not real.",
                action: "try again"
            ) {
                retryMonitoring()
            }
        } else if trackingDegraded {
            healthBanner(
                title: "nudges are off.",
                detail: "too many apps to track individually. the total still counts.",
                action: "track fewer apps"
            ) {
                showingPicker = true
            }
        }
    }

    private func healthBanner(
        title: String,
        detail: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.alarm)

            Text(detail)
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.inkQuiet)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                Haptics.light()
                perform()
            }) {
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private func retryMonitoring() {
        guard !selection.applications.isEmpty else {
            showingPicker = true
            return
        }
        ActivityScheduler.shared.startMonitoring(selection: selection)
        refresh()
    }

    // THE THESIS. The question the entire app exists to ask, and the first thing
    // you read every time you open it. It never changes — that's the point of a
    // thesis. The line that ESCALATES with your number is now the closing one, at
    // the bottom: you open to the question, and you leave with whatever today has
    // earned.
    private var voice: some View {
        Text("is this how you want to spend your one life?")
            .font(.system(size: 16, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(Color.ink.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.top, 52)
    }

    // THE NUMBER. One thing dominates this screen, and this is it.
    //
    // An itemised receipt lived here for exactly one commit and it was wrong: with
    // a single tracked app the line item and the total are THE SAME NUMBER printed
    // twice, and the eye had six things competing for it — wordmark, date, app row,
    // "total", the percentage, the equivalent — with no idea which one mattered.
    // Itemisation is what you open the receipt FOR. It is not what you glance at.
    //
    // So: the mirror's line above, the number, the mirror's line below. Nothing
    // else. That sandwich is the whole design.
    private var hero: some View {
        VStack(spacing: 0) {
            HeroCaption(text: "you wasted")
                .padding(.top, 40)

            HeroNumber(seconds: totalSeconds)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.9)
                .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.25).delay(0.1), value: appeared)
                .padding(.top, 16)

            HeroCaption(text: "on your phone today")
                .padding(.top, 16)

            if let equivalent = EquivalentTaskMapper.equivalent(for: totalSeconds) {
                MirrorLine(text: equivalent.line)
                    .padding(.top, 30)
                    .transition(.opacity)
            }

            QuietButton(title: "today's receipt") {
                showingReceipt = true
            }
            .padding(.top, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // WHERE IT LEAKS. The only actionable thing on the screen: the total tells you
    // that you lost time; this tells you WHEN, so "9pm is where my evening goes"
    // becomes a fact you can do something about.
    private var zones: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "danger zones")
                .padding(.top, 34)

            // An empty day is stated, not drawn. A 24-slot chart with nothing in it
            // reads as a broken component, not as "you haven't picked up your phone".
            if hourlyOrdered.contains(where: { $0 > 0 }) {
                DangerZones(hourly: hourlyOrdered)
                    .padding(.top, 22)
            } else {
                MirrorLine(text: "nothing yet today.", size: 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 34)
    }

    // IS THIS A BAD EVENING, OR A BAD LIFE? Locked and blurred until there are
    // seven days — but the data under the blur is REAL, and it fills in a little
    // more each day. The old screen faked this with random bars; curiosity built
    // on a lie is worth nothing.
    private var week: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: "your week")
                .padding(.top, 34)

            // The bars show the shape; the findings under them carry the
            // insight (worst day, the repeating window). The old corner text
            // ("worst: 9pm–11pm") moved down there, where it can say how MANY
            // days the window repeated — the fact that makes it a habit.
            WeekBars(days: weekDays, daysRequired: 7, peak: historicalPeak)
                .padding(.top, 22)

            // The week asks "bad evening, or bad life?" — this is where the
            // answer lives. Free gets the question; Pro gets the answer:
            // months, the all-time bill, the projection. The one gate in the
            // app, sitting exactly where the appetite for it is created.
            QuietButton(title: "the long receipt") {
                if proStore.isPro { showingHistory = true } else { showingPaywall = true }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 26)
        }
        .padding(.bottom, 26)
    }

    // WHAT IT'S TRACKING, AND WHAT IT COSTS.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerRow(label: "tracking", value: trackedLabel) {
                showingPicker = true
            }
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
            .onChange(of: selection) { _, newValue in
                saveSelection(newValue)
                ActivityScheduler.shared.startMonitoring(selection: newValue)
            }

            widgetHint

            // BETA ONLY — remove before the App Store.
            //
            // A tester's log can't be pulled with devicectl (that only reaches a
            // phone paired to the developer's own Mac), and it must never be
            // uploaded: the app promises "your data, your device, nobody else sees
            // it", and a silent diagnostics upload would make that a lie. So the
            // tester exports it themselves, and chooses who gets it.
            Button {
                Haptics.light()
                exportedLog = EventLog.export().map(ExportedLog.init(url:))
            } label: {
                Text("send diagnostics")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.ink.opacity(0.28))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(.top, 6)
        .padding(.bottom, 26)
    }

    // THE SURFACE THAT SURVIVES THE NIGHT. iOS kills the island 8 hours after
    // it's created and nothing extends that; the lock screen widget has no such
    // clock. Setup instruction, not usage advice — same category as "track
    // fewer apps" above, and it earns its pixels by being dismissible forever.
    @ViewBuilder
    private var widgetHint: some View {
        if !widgetHintDismissed {
            VStack(alignment: .leading, spacing: 6) {
                Text("the island goes dark after 8 hours. ios's rule.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.6))

                Text("opening wasted relights it. the lock screen widget never goes dark — long-press your lock screen, customise, add wasted.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.inkQuiet)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Haptics.light()
                    widgetHintDismissed = true
                } label: {
                    Text("got it")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
        }
    }

    // THE MIRROR, ESCALATING. It gets meaner as the number climbs — patient at
    // twenty minutes, brutal at four hours — and it's the last thing you read
    // before you put the phone down.
    //
    // It used to sit at the top. The THESIS sits there now, because the thesis is
    // the constant and the provocation is the variable: you open to the question
    // the whole app exists to ask, and you leave with whatever today has earned.
    private var closing: some View {
        Text(QuoteBank.quote(forSeconds: totalSeconds))
            .font(.system(size: 15, weight: .light, design: .serif))
            .italic()
            .foregroundStyle(Color.ink.opacity(0.42))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.top, 22)
            .padding(.bottom, 64)
            .animation(.easeInOut(duration: 0.5), value: QuoteBank.Temper(seconds: totalSeconds))
    }

    // MARK: - Data

    // HourlyUsage is a sparse dictionary; the strip wants a dense 24-slot day.
    private var hourlyOrdered: [Int] {
        (0..<24).map { hourlyData.hours[$0] ?? 0 }
    }


    private var trackedLabel: String {
        let count = selection.applications.count
        return "\(count) app\(count == 1 ? "" : "s")"
    }

    // THIS RUNS EVERY FIVE SECONDS, INCLUDING WHILE THE USER IS SCROLLING.
    //
    // It used to do about EIGHT JSON decodes off disk on the main thread —
    // loadTodayUsage three times, loadHistory four — and then reassign every
    // @State unconditionally, which forces SwiftUI to rebuild the entire scroll
    // content whether or not anything changed. That is the jitter.
    //
    // Now: ONE read of today, ONE of history, everything derived from those two
    // snapshots, and state assigned ONLY when the value actually moved. The total
    // steps at most once a minute, so eleven of every twelve ticks are now
    // completely silent — no state change, no re-render, no hitch.
    private func refresh() {
        let usage = store.loadTodayUsage()
        let history = store.loadHistory()

        assign(store.totalSeconds(in: usage), to: &totalSeconds)
        assign(store.hourly(in: usage), to: &hourlyData)
        assign(DailyReceipt.build(usage: usage, displayNames: loadDisplayNames()), to: &receipt)
        // Oldest first, TODAY LAST. History excludes today, so today is appended —
        // otherwise the newest row of the heatmap would always be yesterday, the
        // one day the user least needs to be told about.
        assign(Array(history.suffix(6)) + [usage], to: &weekDays)
        assign(InsightEngine.historicalPeak(history: history), to: &historicalPeak)
        assign(store.defaults.bool(forKey: AppGroupKeys.trackingFailedKey), to: &trackingFailed)
        assign(store.defaults.bool(forKey: AppGroupKeys.trackingDegradedKey), to: &trackingDegraded)

        updateRealityCheck(history: history)
        maybeAutoShowReceipt()
        syncIsland()
    }

    /// Writes only on a real change. Assigning an identical value to @State still
    /// invalidates the view in SwiftUI, so this is the difference between a silent
    /// tick and a full rebuild of the scroll content.
    private func assign<T: Equatable>(_ value: T, to state: inout T) {
        guard state != value else { return }
        state = value
    }

    // THE ISLAND WAS FROZEN AT WHATEVER THE TOTAL HAPPENED TO BE IN THE SINGLE
    // MILLISECOND YOU FOREGROUNDED THE APP.
    //
    // Only the main app can write to the island, and it used to write exactly
    // once per foreground (scenePhase == .active). But DeviceActivity delivers
    // thresholds LATE, in bursts — the device logs proved that — so the sequence
    // was:
    //
    //   1. you scroll; the extension records the usage but cannot touch the island
    //   2. you open Wasted; the store says 6m, so the island is anchored at 6m
    //   3. over the next seconds the extension delivers the BACKLOG: 7m … 13m
    //   4. this view's five-second poll picks that up and shows 13m
    //   5. nothing ever pushes it to the island, because scenePhase never changed
    //
    // App: 13m. Island: 6m. Both reading the same store.
    //
    // So the island is kept in sync while the app is OPEN, not just when it
    // OPENS. Pushed only when the value actually moves — the total changes at
    // most once a minute, so this is nowhere near ActivityKit's update budget,
    // whereas firing on every five-second tick would be.
    private func syncIsland() {
        guard totalSeconds != lastPushedTotal else { return }
        lastPushedTotal = totalSeconds
        Task { await LiveActivityCoordinator.shared.sync(totalSeconds: totalSeconds, canCreate: true) }
    }

    private func updateRealityCheck(history: [DailyUsage]) {
        guard
            !store.isRealityCheckShown(),
            let guessSeconds = store.guessSeconds(),
            let firstDay = history.first
        else { return }

        let firstDayTotal = firstDay.seconds.values.reduce(0, +)
        guard let check = RealityCheck.make(guessSeconds: guessSeconds, firstFullDaySeconds: firstDayTotal) else {
            return
        }
        // Setting this presents the full-screen moment; the haptic lives in the
        // view so it fires with the reveal, not with the state change.
        realityCheck = check
        EventLog.log(.trial, "REALITY CHECK shown — \(check.guessLine) \(check.realityLine) \(check.deltaLine)")
    }

    private func maybeAutoShowReceipt() {
        guard realityCheck == nil else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= AppGroupKeys.receiptHour, totalSeconds > 0 else { return }
        let today = DailyUsage.todayString()
        guard store.lastReceiptAutoShowDate() != today else { return }
        store.markReceiptAutoShown(date: today)
        showingReceipt = true
    }


    // MARK: - Persistence

    private func loadDisplayNames() -> [String: String] {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func loadSavedSelection() -> FamilyActivitySelection {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
    }

    private func saveSelection(_ selection: FamilyActivitySelection) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(selection)
        else { return }
        defaults.set(data, forKey: AppGroupKeys.trackedSelectionKey)
    }
}
