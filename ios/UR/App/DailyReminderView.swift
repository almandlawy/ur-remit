import SwiftUI

/// شاشة إعداد التذكير اليومي بالأسعار
struct DailyReminderView: View {
    @State private var manager = DailyReminderManager.shared

    private let weekdaySymbols: [(Int, String)] = [
        (1, "الأحد"),
        (2, "الاثنين"),
        (3, "الثلاثاء"),
        (4, "الأربعاء"),
        (5, "الخميس"),
        (6, "الجمعة"),
        (7, "السبت")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                URPageTitle(
                    title: "تذكير يومي بالأسعار",
                    subtitle: "استلم إشعاراً بسعر الدولار في وقت تحدده",
                    symbol: "bell.badge.fill"
                )

                // مفتاح التشغيل
                URCard {
                    Toggle(isOn: $manager.isEnabled) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("تفعيل التذكير").font(.subheadline.weight(.bold))
                            Text("إشعار محلي متكرر").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .tint(URColor.premiumGold)
                }

                if manager.isEnabled {
                    // اختيار الوقت
                    URCard {
                        VStack(alignment: .trailing, spacing: 12) {
                            HStack {
                                Spacer()
                                Text("الوقت").font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                                Image(systemName: "clock.fill").foregroundStyle(URColor.premiumGold)
                            }

                            DatePicker(
                                "اختر الوقت",
                                selection: timeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ar"))
                            .datePickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // اختيار الأيام
                    URCard {
                        VStack(alignment: .trailing, spacing: 12) {
                            HStack {
                                Spacer()
                                Text("الأيام").font(.subheadline.weight(.bold)).foregroundStyle(URColor.deepNavy)
                                Image(systemName: "calendar").foregroundStyle(URColor.premiumGold)
                            }

                            // أزرار سريعة
                            HStack(spacing: 8) {
                                quickDayButton("كل يوم", days: Set(1...7))
                                quickDayButton("أيام الأسبوع", days: Set(2...6))
                                quickDayButton("نهاية الأسبوع", days: Set([1, 7]))
                            }

                            // أيام فردية
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                spacing: 8
                            ) {
                                ForEach(weekdaySymbols, id: \.0) { day, name in
                                    weekdayToggle(day: day, name: name)
                                }
                            }
                        }
                    }

                    // ملخص
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(URColor.royalBlue)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("سيصلك إشعار:").font(.caption.weight(.semibold)).foregroundStyle(URColor.deepNavy)
                            Text("\(manager.weekdaysText) — الساعة \(manager.timeText)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(URColor.royalBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                } else {
                    // حالة إيقاف
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill").foregroundStyle(.secondary)
                        Text("التذكير غير مفعّل حالياً").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(14)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                }

                Text("الإشعارات محلية فقط ولا تُرسل بياناتك خارج جهازك.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(14)
        }
        .background(URColor.ivory.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await manager.reschedule()
        }
    }

    // MARK: - Bindings
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: manager.hour,
                    minute: manager.minute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                manager.hour = comps.hour ?? 9
                manager.minute = comps.minute ?? 0
            }
        )
    }

    // MARK: - Subviews
    private func quickDayButton(_ title: String, days: Set<Int>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                manager.weekdays = days
            }
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    manager.weekdays == days ? URColor.premiumGold : .white,
                    in: Capsule()
                )
                .foregroundStyle(manager.weekdays == days ? .white : URColor.deepNavy)
                .overlay(Capsule().stroke(URColor.hairline))
        }
        .buttonStyle(.plain)
    }

    private func weekdayToggle(day: Int, name: String) -> some View {
        let isOn = manager.weekdays.contains(day)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isOn {
                    manager.weekdays.remove(day)
                } else {
                    manager.weekdays.insert(day)
                }
            }
        } label: {
            Text(name)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    isOn ? URColor.royalBlue : .white,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .foregroundStyle(isOn ? .white : URColor.deepNavy)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(URColor.hairline))
        }
        .buttonStyle(.plain)
    }
}
