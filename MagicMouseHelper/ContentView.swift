import SwiftUI

struct ContentView: View {
    @ObservedObject var engine: MouseEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "computermouse.fill").font(.title)
                VStack(alignment: .leading) {
                    Text("MagicMouseHelper").font(.headline)
                    Text(engine.status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(engine.running ? .green : .orange).frame(width: 8, height: 8)
            }
            Text("作用于所有鼠标及触摸板，暂不区分物理设备。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("启用鼠标增强", isOn: $engine.preferences.enabled)
            GroupBox("滚动") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("反转垂直滚动", isOn: $engine.preferences.reverseVertical)
                    Toggle("反转水平滚动", isOn: $engine.preferences.reverseHorizontal)
                    Toggle("禁用水平滚动", isOn: $engine.preferences.blockHorizontal)
                    speedSlider("垂直速度", value: $engine.preferences.verticalSpeed)
                    speedSlider("水平速度", value: $engine.preferences.horizontalSpeed)
                }.padding(4)
            }
            Toggle("Option + 左键模拟中键（支持拖动）", isOn: $engine.preferences.optionMiddleClick)
            Toggle("按住 Shift 临时使用原始鼠标行为", isOn: $engine.preferences.bypassWithShift)
            VStack(alignment: .leading, spacing: 4) {
                Text("排除应用（Bundle ID，每行一个）").font(.caption)
                TextEditor(text: $engine.preferences.excludedApps)
                    .font(.system(.caption, design: .monospaced)).frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
                Text("例如 com.apple.Safari；排除应用保留原始行为。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            Text("已观察事件：\(engine.eventCount) · \(engine.lastEvent)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("辅助功能设置") { engine.openPermissionSettings() }
                Button("启动 / 重试") {
                    engine.stop()
                    engine.start()
                }
            }
            HStack {
                Button("暂停监听") { engine.stop() }.disabled(!engine.running)
                Button("恢复默认") { engine.preferences = Preferences() }
                Spacer()
                Button("退出") { engine.quit() }
            }
            Text("设置自动保存在本机。未授权时不会修改鼠标事件。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 390)
    }

    private func speedSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).frame(width: 60, alignment: .leading)
            Slider(value: value, in: 0.25...4, step: 0.05)
            Text(String(format: "%.2f×", value.wrappedValue)).monospacedDigit().frame(width: 48)
        }
    }
}
