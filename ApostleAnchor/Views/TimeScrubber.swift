import SwiftUI

/// Day chips + hour slider + play button controlling the forecast time the
/// whole Plan tab renders.
struct TimeScrubber: View {
    @Environment(AppModel.self) private var model
    @State private var playTask: Task<Void, Never>?
    @State private var playing = false

    var body: some View {
        VStack(spacing: 6) {
            if model.hours.isEmpty {
                HStack(spacing: 8) {
                    if model.isLoading {
                        ProgressView().controlSize(.small)
                        Text("Loading forecast…").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No forecast yet — tap refresh.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.days, id: \.self) { day in
                            dayChip(day)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        togglePlay()
                    } label: {
                        Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.teal)
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { Double(model.selectedHourIndex) },
                            set: { model.selectedHourIndex = Int($0.rounded()) }
                        ),
                        in: 0...Double(max(model.hours.count - 1, 1)),
                        step: 1
                    )
                    .tint(Theme.teal)

                    Text(timeLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
        .onDisappear { stopPlay() }
    }

    private func dayChip(_ day: Date) -> some View {
        let isSelected = model.selectedTime.map { model.calendar.startOfDay(for: $0) == day } ?? false
        return Button {
            model.selectDay(day)
        } label: {
            Text(Fmt.dayChip.string(from: day))
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.teal : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var timeLabel: String {
        model.selectedTime.map { Fmt.hourLabel.string(from: $0) } ?? "—"
    }

    private func togglePlay() {
        if playing {
            stopPlay()
        } else {
            playing = true
            playTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(350))
                    if Task.isCancelled { break }
                    if model.hours.isEmpty { break }
                    model.selectedHourIndex = (model.selectedHourIndex + 1) % model.hours.count
                }
            }
        }
    }

    private func stopPlay() {
        playTask?.cancel()
        playTask = nil
        playing = false
    }
}
