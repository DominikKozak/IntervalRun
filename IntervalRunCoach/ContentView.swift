import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.linen
                    .ignoresSafeArea()

                backgroundTexture

                List {
                    headerRow
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 6, trailing: 20))

                    workoutCard
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))

                    presetsCard
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))

                    settingsCard
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 10, trailing: 20))

                    intervalHeader
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))

                    ForEach(Array(viewModel.segments.enumerated()), id: \.element.id) { index, segment in
                        IntervalRow(
                            segment: segment,
                            isDisabled: viewModel.isWorkoutActive,
                            onChange: { title, minutes, seconds in
                                viewModel.updateSegment(
                                    id: segment.id,
                                    title: title,
                                    minutes: minutes,
                                    seconds: seconds
                                )
                            },
                            onDelete: {
                                viewModel.removeSegments(at: IndexSet(integer: index))
                            }
                        )
                        .moveDisabled(viewModel.isWorkoutActive)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                    .onMove(perform: viewModel.moveSegments)

                    addIntervalButton
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 28, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.deepOlive)
                        .disabled(viewModel.isWorkoutActive)
                }
            }
        }
        .tint(AppPalette.clockwork)
    }

    private var backgroundTexture: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppPalette.linen,
                    AppPalette.latte.opacity(0.72),
                    AppPalette.cedar.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppPalette.weathered.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: -140, y: -260)

            Circle()
                .fill(AppPalette.mauve.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 160, y: 250)
        }
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interval")
                .font(.system(size: 48, weight: .regular, design: .serif))
                .foregroundStyle(AppPalette.deepOlive)

            Text("Run Coach")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.clockwork)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(statusTitle)
                    .font(.system(size: 36, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.linen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()

                Text(viewModel.roundSummaryText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppPalette.linen)
                    .background(AppPalette.clockwork.opacity(0.72), in: Capsule())
            }

            Text(primaryTimeText)
                .font(.system(size: 68, weight: .bold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(AppPalette.linen)
                .accessibilityLabel("Zbyvajici cas")
                .accessibilityValue(primaryTimeText)

            VStack(alignment: .leading, spacing: 9) {
                ProgressView(value: viewModel.progress)
                    .tint(AppPalette.latte)
                    .accessibilityLabel("Prubeh treninku")
                    .accessibilityValue("\(Int(viewModel.progress * 100)) procent")

                HStack {
                    Label("Zbyva \(viewModel.remainingSummaryText)", systemImage: "hourglass")
                    Spacer()
                    if let next = viewModel.nextSegment, viewModel.isRunning {
                        Text("Dalsi: \(next.displayTitle)")
                    } else if viewModel.countdownToStart > 0 {
                        Text("Priprav se")
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppPalette.latte)
            }

            HStack(spacing: 12) {
                if viewModel.isWorkoutActive {
                    Button("Finish") {
                        viewModel.finishWorkout()
                    }
                    .buttonStyle(FilledCapsuleButtonStyle(background: AppPalette.latte, foreground: AppPalette.cafeNoir))
                } else {
                    Button("Start") {
                        viewModel.startWorkout()
                    }
                    .buttonStyle(FilledCapsuleButtonStyle(background: AppPalette.latte, foreground: AppPalette.cafeNoir))
                }

                Button(viewModel.isPaused ? "Pokracovat" : "Pauza") {
                    viewModel.pauseOrResumeWorkout()
                }
                .buttonStyle(OutlineCapsuleButtonStyle())
                .disabled(!viewModel.isRunning && !viewModel.isPaused)
            }

            if viewModel.isWorkoutActive {
                Button("Reset bez dokonceni") {
                    if viewModel.isWorkoutActive {
                        viewModel.resetWorkout()
                    }
                }
                .buttonStyle(OutlineCapsuleButtonStyle())
                .accessibilityHint("Zrusi trenink bez finish zvuku")
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppPalette.deepOlive, AppPalette.cafeNoir],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppPalette.latte.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: AppPalette.cafeNoir.opacity(0.22), radius: 18, x: 0, y: 12)
    }

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Rychle presety")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    presetButton(title: "1 / 3", subtitle: "8 kol", color: AppPalette.clockwork) {
                        viewModel.applyPreset(runSeconds: 60, walkSeconds: 180, rounds: 8)
                    }
                    presetButton(title: "2 / 2", subtitle: "8 kol", color: AppPalette.cedar) {
                        viewModel.applyPreset(runSeconds: 120, walkSeconds: 120, rounds: 8)
                    }
                    presetButton(title: "3 / 1", subtitle: "10 kol", color: AppPalette.mauve) {
                        viewModel.applyPreset(runSeconds: 180, walkSeconds: 60, rounds: 10)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .cardStyle()
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel("Nastaveni")

            VStack(alignment: .leading, spacing: 10) {
                Text("Opakovani")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(AppPalette.deepOlive)

                Picker("Opakovani", selection: $viewModel.repeatMode) {
                    ForEach(RepeatMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isWorkoutActive)
                .onChange(of: viewModel.repeatMode) { _, _ in
                    viewModel.save()
                }
            }

            if viewModel.repeatMode == .fixedRounds {
                Stepper("Pocet kol: \(viewModel.rounds)", value: $viewModel.rounds, in: 1...30)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(AppPalette.deepOlive)
                    .onChange(of: viewModel.rounds) { _, _ in
                        viewModel.save()
                    }
                    .disabled(viewModel.isWorkoutActive)
            }

            Divider().overlay(AppPalette.cedar.opacity(0.24))

            PickerRow(title: "Hudba", selectionTitle: viewModel.audioMode.title) {
                Picker("Hudba", selection: $viewModel.audioMode) {
                    ForEach(AudioMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: viewModel.audioMode) { _, _ in
                    viewModel.save()
                }
            }
            .disabled(viewModel.isWorkoutActive)

            PickerRow(title: "Hlaseni", selectionTitle: viewModel.announcementType.title) {
                Picker("Hlaseni", selection: $viewModel.announcementType) {
                    ForEach(AnnouncementType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .onChange(of: viewModel.announcementType) { _, _ in
                    viewModel.save()
                }
            }
            .disabled(viewModel.isWorkoutActive)

            PickerRow(title: "Jazyk", selectionTitle: viewModel.announcementLanguage.title) {
                Picker("Jazyk", selection: $viewModel.announcementLanguage) {
                    ForEach(AnnouncementLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .onChange(of: viewModel.announcementLanguage) { _, _ in
                    viewModel.save()
                }
            }
            .disabled(viewModel.isWorkoutActive)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notifikace")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(AppPalette.deepOlive)
                    Text(viewModel.notificationPermissionState)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppPalette.clockwork.opacity(0.78))
                }

                Spacer()

                if viewModel.notificationPermissionState == "Povoleno" {
                    Text("Aktivni")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .foregroundStyle(AppPalette.linen)
                        .background(AppPalette.deepOlive, in: Capsule())
                } else {
                    Button("Povolit") {
                        viewModel.requestNotificationPermission()
                    }
                    .buttonStyle(FilledCapsuleButtonStyle(background: AppPalette.deepOlive, foreground: AppPalette.linen))
                }
            }
        }
        .cardStyle()
    }

    private var intervalHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            SectionLabel("Intervaly")
            Spacer()
            Text("Edit pro poradi")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.clockwork.opacity(0.78))
        }
    }

    private var addIntervalButton: some View {
        Button {
            viewModel.addSegment()
        } label: {
            Label("Pridat interval", systemImage: "plus")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledCapsuleButtonStyle(background: AppPalette.clockwork, foreground: AppPalette.linen))
        .disabled(viewModel.isWorkoutActive)
    }

    private var statusTitle: String {
        if viewModel.countdownToStart > 0 {
            return "Priprava"
        }
        return viewModel.currentSegment?.displayTitle ?? "Pripraveno"
    }

    private var primaryTimeText: String {
        if viewModel.countdownToStart > 0 {
            return "\(viewModel.countdownToStart)"
        }
        return viewModel.format(seconds: viewModel.secondsRemaining)
    }

    private func presetButton(title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .tracking(0.4)
            }
            .frame(width: 92, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .foregroundStyle(AppPalette.linen)
            .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isWorkoutActive)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

#Preview {
    ContentView()
}

private struct IntervalRow: View {
    let segment: IntervalSegment
    let isDisabled: Bool
    let onChange: (String, Int, Int) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var minutesText: String
    @State private var secondsText: String
    @FocusState private var isTitleFieldFocused: Bool

    init(
        segment: IntervalSegment,
        isDisabled: Bool,
        onChange: @escaping (String, Int, Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.segment = segment
        self.isDisabled = isDisabled
        self.onChange = onChange
        self.onDelete = onDelete
        _title = State(initialValue: segment.title)
        _minutesText = State(initialValue: String(segment.durationSeconds / 60))
        _secondsText = State(initialValue: String(segment.durationSeconds % 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                TextField("Nazev intervalu", text: $title)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(AppPalette.deepOlive)
                    .textInputAutocapitalization(.sentences)
                    .focused($isTitleFieldFocused)
                    .onSubmit(commitTitleChange)
                    .onChange(of: isTitleFieldFocused) { _, isFocused in
                        if !isFocused {
                            commitTitleChange()
                        }
                    }
                    .disabled(isDisabled)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.mauve)
                        .frame(width: 34, height: 34)
                        .background(AppPalette.mauve.opacity(0.12), in: Circle())
                }
                .disabled(isDisabled)
                .accessibilityLabel("Smazat interval")
            }

            HStack(spacing: 12) {
                durationField(title: "Minuty", text: $minutesText)
                durationField(title: "Sekundy", text: $secondsText)
            }

            HStack {
                Text("Delka")
                Spacer()
                Text(formattedDuration)
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppPalette.clockwork.opacity(0.82))
        }
        .padding(18)
        .background(AppPalette.latte.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.weathered.opacity(0.34), lineWidth: 1)
        )
        .onChange(of: segment) { _, value in
            title = value.title
            minutesText = String(value.durationSeconds / 60)
            secondsText = String(value.durationSeconds % 60)
        }
    }

    private var formattedDuration: String {
        String(format: "%02d:%02d", parsedMinutes, parsedSeconds)
    }

    private var parsedMinutes: Int {
        min(max(Int(minutesText) ?? 0, 0), 59)
    }

    private var parsedSeconds: Int {
        min(max(Int(secondsText) ?? 0, 0), 59)
    }

    private func durationField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.clockwork.opacity(0.76))

            TextField("0", text: sanitizedBinding(for: text))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .foregroundStyle(AppPalette.deepOlive)
                .background(AppPalette.linen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.cedar.opacity(0.26), lineWidth: 1)
                )
                .disabled(isDisabled)
        }
    }

    private func sanitizedBinding(for text: Binding<String>) -> Binding<String> {
        Binding(
            get: {
                text.wrappedValue
            },
            set: { newValue in
                let digitsOnly = newValue.filter(\.isNumber)
                let trimmed = String(digitsOnly.prefix(2))
                let clampedValue = min(Int(trimmed) ?? 0, 59)
                text.wrappedValue = trimmed.isEmpty ? "" : String(clampedValue)
                applyChange()
            }
        )
    }

    private func applyChange(title: String? = nil) {
        onChange(title ?? self.title, parsedMinutes, parsedSeconds)
    }

    private func commitTitleChange() {
        applyChange(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private enum AppPalette {
    static let clockwork = Color(hex: 0x72583E)
    static let cedar = Color(hex: 0x7C7960)
    static let latte = Color(hex: 0xDBC4A5)
    static let deepOlive = Color(hex: 0x44422D)
    static let cafeNoir = Color(hex: 0x443223)
    static let mauve = Color(hex: 0x755151)
    static let weathered = Color(hex: 0xA08670)
    static let linen = Color(hex: 0xFFF9F3)
}

private struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(AppPalette.clockwork)
    }
}

private struct PickerRow<PickerContent: View>: View {
    let title: String
    let selectionTitle: String
    @ViewBuilder let picker: PickerContent

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(AppPalette.deepOlive)

            Spacer()

            Menu {
                picker
            } label: {
                HStack(spacing: 7) {
                    Text(selectionTitle)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(AppPalette.linen)
                .background(AppPalette.deepOlive, in: Capsule())
            }
        }
    }
}

private struct EarthyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(AppPalette.deepOlive)

                Spacer()

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(configuration.isOn ? AppPalette.deepOlive : AppPalette.weathered.opacity(0.34))
                    .frame(width: 52, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(AppPalette.linen)
                            .frame(width: 24, height: 24)
                            .padding(3)
                    }
                    .animation(.snappy(duration: 0.18), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Zapnuto" : "Vypnuto")
    }
}

private struct FilledCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(foreground.opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.48))
            .background(background.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.32), in: Capsule())
    }
}

private struct OutlineCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(AppPalette.linen.opacity(isEnabled ? (configuration.isPressed ? 0.64 : 1) : 0.42))
            .overlay(
                Capsule()
                    .stroke(AppPalette.latte.opacity(isEnabled ? (configuration.isPressed ? 0.44 : 0.72) : 0.24), lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.7)
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .background(AppPalette.linen.opacity(0.82), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppPalette.weathered.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: AppPalette.cafeNoir.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}

private extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
