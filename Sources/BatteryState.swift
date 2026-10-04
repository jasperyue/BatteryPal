import Foundation
import IOKit.ps

struct BatteryState {
    let percent: Int?
    let charging: Bool
    let pluggedIn: Bool
    let minutes: Int?
    static let unavailable = BatteryState(percent: nil, charging: false, pluggedIn: false, minutes: nil)
    var mood: String {
        guard let percent else { return "unknown" }
        if charging { return "charging" }
        // 状态优先级：charging > low (0–20) > normal (21–79) > high (80–100)。
        if percent <= 20 { return "low" }
        if percent >= 80 { return "high" }
        return "normal"
    }
    static func read() -> BatteryState {
        // [IOKit.ps] 获取电源快照和电源列表；下面的 CFTypeRef 来自 CoreFoundation。
        // takeRetainedValue() 是 Swift Unmanaged 的方法，接管 Copy 返回值的所有权。
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return .unavailable }
        for source in sources {
            // [IOKit.ps] 获取单个电源的字典；所有 kIOPS… 常量也是该子模块定义的键/值。
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let time = info[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
            return BatteryState(percent: min(100, Swift.max(0, Int(Double(current) / Double(max) * 100))),
                                charging: charging, pluggedIn: plugged, minutes: time.flatMap { $0 > 0 ? $0 : nil })
        }
        return .unavailable
    }
}

// 纯状态规则，便于验证：只有可见、正在充电且允许动态效果时才启动计时器。
enum ChargingAnimation {
    static func enabled(charging: Bool, hasBattery: Bool, sleeping: Bool, reduceMotion: Bool) -> Bool {
        charging && hasBattery && !sleeping && !reduceMotion
    }
    static func frame(at tick: Int) -> Int { tick % 2 } // 0 = 明亮，1 = 柔和。
    static func shouldBlink(at tick: Int) -> Bool { tick > 0 && tick % 6 == 0 }
}
