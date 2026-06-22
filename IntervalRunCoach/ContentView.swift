import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Trenink") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(statusTitle)
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text(primaryTimeText)
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .monospacedDigit()

                        ProgressView(value: viewModel.progress)

                        HStack {
                            Label("Kolo \(viewModel.currentRound)/\(viewModel.rounds)", systemImage: "repeat")
                            Spacer()
                            Text("Zbyva \(viewModel.format(seconds: viewModel.totalRemainingSeconds))")
                                .foregroundStyle(.secondary)
                        }

                        if let next = viewModel.nextSegment, viewModel.isRunning {
                            Text("Dalsi: \(next.title)")
                                .foregroundStyle(.secondary)
                        } else if viewModel.countdownToStart > 0 {
                            Text("Priprav se na start")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    HStack(spacing: 12) {
                        Button(viewModel.isRunning ? "Reset" : "Start") {
                            if viewModel.isRunning {
                                viewModel.resetWorkout()
                            } else {
                                viewModel.startWorkout()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(viewModel.isPaused ? "Pokracovat" : "Pauza") {
                            viewModel.pauseOrResumeWorkout()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.isRunning && !viewModel.isPaused)
                    }
                }

                Section("Rychle presety") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            presetButton(title: "1 / 3", subtitle: "8 kol") {
                                viewModel.applyPreset(runSeconds: 60, walkSeconds: 180, rounds: 8)
                            }
                            presetButton(title: "2 / 2", subtitle: "8 kol") {
                                viewModel.applyPreset(runSeconds: 120, walkSeconds: 120, rounds: 8)
                            }
                            presetButton(title: "3 / 1", subtitle: "10 kol") {
                                viewModel.applyPreset(runSeconds: 180, walkSeconds: 60, rounds: 10)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Nastaveni") {
                    Stepper("Pocet kol: \(viewModel.rounds)", value: $viewModel.rounds, in: 1...30)
                        .onChange(of: viewModel.rounds) { _, _ in
                            viewModel.save()
                        }
                        .disabled(viewModel.isRunning || viewModel.isPaused || viewModel.countdownToStart > 0)

                    Toggle("Hlasove oznameni", isOn: $viewModel.enableVoice)
                        .onChange(of: viewModel.enableVoice) { _, _ in
                            viewModel.save()
                        }

                    Toggle("Zvuk", isOn: $viewModel.enableSound)
                        .onChange(of: viewModel.enableSound) { _, _ in
                            viewModel.save()
                        }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifikace")
                            Text(viewModel.notificationPermissionState)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Povolit") {
                            viewModel.requestNotificationPermission()
                        }
                    }
                }

                Section("Intervaly") {
                    ForEach(viewModel.segments) { segment in
                        IntervalRow(
                            segment: segment,
                            isDisabled: viewModel.isRunning || viewModel.isPaused || viewModel.countdownToStart > 0,
                            onChange: { title, minutes, seconds in
                                viewModel.updateSegment(
                                    id: segment.id,
                                    title: title,
                                    minutes: minutes,
                                    seconds: seconds
                                )
                            }
                        )
                    }
                    .onDelete(perform: viewModel.removeSegments)
                    .onMove(perform: viewModel.moveSegments)

                    Button("Pridat interval") {
                        viewModel.addSegment()
                    }
                    .disabled(viewModel.isRunning || viewModel.isPaused || viewModel.countdownToStart > 0)
                }
            }
            .navigationTitle("Interval Run Coach")
            .toolbar {
                EditButton()
                    .disabled(viewModel.isRunning || viewModel.isPaused || viewModel.countdownToStart > 0)
            }
        }
    }

    private var statusTitle: String {
        if viewModel.countdownToStart > 0 {
            return "Priprava"
        }
        return viewModel.currentSegment?.title ?? "Pripraveno"
    }

    private var primaryTimeText: String {
        if viewModel.countdownToStart > 0 {
            return "\(viewModel.countdownToStart)"
        }
        return viewModel.format(seconds: viewModel.secondsRemaining)
    }

    private func presetButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 88, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning || viewModel.isPaused || viewModel.countdownToStart > 0)
    }
}

private struct IntervalRow: View {
    let segment: IntervalSegment
    let isDisabled: Bool
    let onChange: (String, Int, Int) -> Void

    @State private var title: String
    @State private var minutes: Int
    @State private var seconds: Int

    init(segment: IntervalSegment, isDisabled: Bool, onChange: @escaping (String, Int, Int) -> Void) {
        self.segment = segment
        self.isDisabled = isDisabled
        self.onChange = onChange
        _title = State(initialValue: segment.title)
        _minutes = State(initialValue: segment.durationSeconds / 60)
        _seconds = State(initialValue: segment.durationSeconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nazev intervalu", text: $title)
                .textInputAutocapitalization(.sentences)
                .onChange(of: title) { _, value in
                    onChange(value, minutes, seconds)
                }
                .disabled(isDisabled)

            HStack {
                Stepper("Minuty: \(minutes)", value: $minutes, in: 0...59)
                    .onChange(of: minutes) { _, value in
                        onChange(title, value, seconds)
                    }
                    .disabled(isDisabled)

                Stepper("Sekundy: \(seconds)", value: $seconds, in: 0...59)
                    .onChange(of: seconds) { _, value in
                        onChange(title, minutes, value)
                    }
                    .disabled(isDisabled)
            }
            .font(.subheadline)

            Text("Delka: \(String(format: "%02d:%02d", minutes, seconds))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .onChange(of: segment) { _, value in
            title = value.title
            minutes = value.durationSeconds / 60
            seconds = value.durationSeconds % 60
        }
    }
}
