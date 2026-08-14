import Foundation

/// 실행할 때마다 값이 바뀌지 않는 결정적 해시.
///
/// `Hasher` / `String.hashValue` 는 프로세스마다 seed 가 달라지므로
/// "날짜 → 명언 인덱스" 같은 재현 가능한 계산에 사용할 수 없다.
/// 앱과 위젯은 서로 다른 프로세스이기 때문에 이 구분이 특히 중요하다.
public enum StableHash {
    /// FNV-1a 64bit.
    public static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// splitmix64 – 낮은 비트까지 고르게 섞어 준다.
    public static func mix(_ seed: UInt64) -> UInt64 {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 문자열 seed 로부터 `0..<count` 범위의 결정적 인덱스를 만든다.
    public static func index(for string: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(mix(fnv1a(string)) % UInt64(count))
    }
}

public extension UUID {
    /// 같은 seed 에 대해 항상 같은 UUID 를 만든다.
    ///
    /// 번들에 포함된 명언은 매 실행마다 새 UUID 를 받으면 안 된다.
    /// (알림 payload / 위젯 딥링크에 UUID 가 들어가므로 재실행 후에도 유효해야 한다.)
    init(stableSeed seed: String) {
        var bytes = [UInt8](repeating: 0, count: 16)
        var state = StableHash.fnv1a(seed)
        for chunk in 0..<2 {
            state = StableHash.mix(state &+ UInt64(chunk))
            for byte in 0..<8 {
                bytes[chunk * 8 + byte] = UInt8((state >> (UInt64(byte) * 8)) & 0xFF)
            }
        }
        // RFC 4122 version 4 / variant 10xx 비트를 맞춰 준다.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

public extension Date {
    /// 로컬 자정 기준의 "yyyy-MM-dd" 키. 오늘의 명언 seed 로 사용한다.
    func dayKey(calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: self)
        let year = parts.year ?? 2000
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    /// 다음 자정. 위젯 타임라인 갱신 시점으로 사용한다.
    func nextMidnight(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay(calendar: calendar))
            ?? addingTimeInterval(24 * 60 * 60)
    }
}
