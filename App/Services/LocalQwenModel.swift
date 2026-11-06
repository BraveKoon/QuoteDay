import Foundation

/// 기기에서 **직접 돌리는** Qwen3 (오픈소스 가중치).
///
/// 클라우드 Qwen 과 무엇이 다른가:
/// - 가중치가 기기에 있고, 추론도 기기에서 끝난다. 질문이 어디로도 나가지 않는다.
/// - 키도 요금도 없다. 대신 **처음 한 번 내려받아야** 하고, 답이 느리고 짧다.
///
/// 가중치는 앱에 넣지 않고 첫 사용 때 받는다. 번들에 넣으면 앱이 300MB~1GB
/// 커져서 셀룰러 설치가 막히고, 쓰지 않는 사람에게도 그 용량을 떠넘기게 된다.
///
/// 라이선스: Qwen3 는 **Apache 2.0** 이다. 상업 배포가 가능하고, 고지는
/// 앱 정보 화면과 아래 `licenseNotice` 에 남긴다.
public enum LocalQwenModel: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Qwen3-0.6B 4bit. 가볍고 빠르다. 오래된 기기에서도 돌아간다.
    case small
    /// Qwen3-1.7B 4bit. 답이 낫지만 메모리를 더 쓰고 느리다.
    case large
    /// Qwen3-4B 4bit. 가장 낫지만 가중치만 2.3GB 다. **물리 메모리 8GB 기기에서만** 쓴다.
    ///
    /// 이 앱에는 `increased-memory-limit` 권한이 없다. iOS 가 앱 하나에 허용하는
    /// 메모리는 물리 메모리보다 훨씬 작아서, 8GB 기기에서도 가중치 + KV 캐시 +
    /// MLX 작업 공간이 한도에 가깝다. 그래서 자동 선택에는 절대 넣지 않고,
    /// 사용자가 직접 고르게 한다.
    case xlarge

    public var id: String { rawValue }

    /// Hugging Face 저장소 이름. MLX 용 4bit 변환본을 쓴다(원본 bf16 은 너무 크다).
    public var repository: String {
        switch self {
        case .small: "mlx-community/Qwen3-0.6B-4bit"
        case .large: "mlx-community/Qwen3-1.7B-4bit"
        case .xlarge: "mlx-community/Qwen3-4B-4bit"
        }
    }

    /// 화면에 쓰는 이름.
    public var title: String {
        switch self {
        case .small: "Qwen3 0.6B"
        case .large: "Qwen3 1.7B"
        case .xlarge: "Qwen3 4B"
        }
    }

    public var detail: String {
        switch self {
        case .small:
            L("가볍고 빨라요. 오래된 기기에서도 돌아가고, 답은 짧은 편이에요.")
        case .large:
            L("답이 더 좋아요. 대신 메모리를 더 쓰고 느려요.")
        case .xlarge:
            L("가장 똑똑해요. 용량이 크고 느리며, 램 8GB 이상 기기에서만 쓸 수 있어요.")
        }
    }

    /// 내려받을 크기(바이트). 실제 값은 저장소에 따라 조금 다르므로 **어림값**이다.
    /// 진행률·용량 표시에만 쓰고, 판단 근거로는 쓰지 않는다.
    public var approximateBytes: Int64 {
        switch self {
        case .small: 350 * 1024 * 1024
        case .large: 1_100 * 1024 * 1024
        case .xlarge: 2_300 * 1024 * 1024
        }
    }

    /// 올리기 직전에 이 앱이 **더 쓸 수 있어야 하는** 메모리. 가중치 + KV 캐시·작업 공간.
    /// 이보다 적으면 올리다가 iOS 에 내려진다.
    public var minimumFreeMemory: UInt64 {
        switch self {
        case .small: 700 * 1024 * 1024
        case .large: 1_600 * 1024 * 1024
        case .xlarge: 3_000 * 1024 * 1024
        }
    }

    /// 이 모델을 무리 없이 돌리려면 필요한 물리 메모리.
    ///
    /// 모델 크기만큼 필요하지는 않다. 4bit 가중치에 KV 캐시·토크나이저·MLX
    /// 작업 공간이 더 붙고, iOS 는 앱 하나에 쓸 수 있는 메모리를 제한한다.
    public var requiredMemory: UInt64 {
        switch self {
        case .small: 4 * 1024 * 1024 * 1024
        case .large: 6 * 1024 * 1024 * 1024
        // 8GB 기기는 물리 메모리를 7.4GiB 쯤으로 보고한다. 7GiB 를 문턱으로 두면
        // 8GB 기기는 들어오고 6GB 기기(5.3GiB 쯤)는 들어오지 못한다.
        case .xlarge: 7 * 1024 * 1024 * 1024
        }
    }

    /// 이 기기에서 쓸 수 있는 모델인지. 4B 는 메모리가 모자라면 아예 고르지 못하게 한다.
    public func isSupported(physicalMemory: UInt64) -> Bool {
        switch self {
        case .small, .large: true
        case .xlarge: physicalMemory >= requiredMemory
        }
    }

    /// 이 기기에서 쓸 수 있는 모델들. 설정 화면이 이것만 보여 준다.
    public static func available(physicalMemory: UInt64) -> [LocalQwenModel] {
        allCases.filter { $0.isSupported(physicalMemory: physicalMemory) }
    }

    public static var availableOnThisDevice: [LocalQwenModel] {
        available(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    /// 이 기기에 맞는 모델. 8GB 기기는 4B, 6GB 이상은 1.7B, 그 아래는 0.6B.
    ///
    /// 1.15.8 까지는 4B 를 권하지 않았다(실행하면 iOS 가 앱을 내렸다). 메모리 한도를 늘리는
    /// 권한과 GPU 캐시 한도를 둔 뒤 실기기에서 4B 가 돌았고, 1.7B 와 같은 점검에서 답의 질이
    /// 크게 달랐다(1.7B: "이 명언의 술어는…", 4B: 질문에 맞는 설명). 쓸 수 있는 기기에는 4B 를 권한다.
    ///
    /// 물리 메모리를 인자로 받는 이유: 테스트에서 여러 기기를 흉내 낼 수 있어야 한다.
    public static func recommended(physicalMemory: UInt64) -> LocalQwenModel {
        if LocalQwenModel.xlarge.isSupported(physicalMemory: physicalMemory) { return .xlarge }
        return physicalMemory >= LocalQwenModel.large.requiredMemory ? .large : .small
    }

    /// 지금 기기의 권장 모델.
    public static var recommendedForThisDevice: LocalQwenModel {
        recommended(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    /// 사람이 읽는 크기. `ByteCountFormatter` 는 로케일을 타므로 형식을 고정한다.
    public var formattedSize: String { Self.format(approximateBytes) }

    static func format(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    /// 앱 정보·설정 화면에 남기는 고지. Apache 2.0 은 저작자 표시를 요구한다.
    public static var licenseNotice: String {
        L("Qwen3 © Alibaba Cloud. Apache License 2.0. 기기 안에서 직접 실행합니다.")
    }
}

/// 기기 내 Qwen 을 쓸지, 어느 크기를 쓸지.
public enum LocalQwenChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 기기 메모리를 보고 고른다(기본).
    case automatic
    case small
    case large
    case xlarge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: L("자동")
        case .small: "0.6B"
        case .large: "1.7B"
        case .xlarge: "4B"
        }
    }

    public var detail: String {
        switch self {
        case .automatic: L("기기 메모리에 맞춰 고르고, 없으면 작은 쪽을 받아요.")
        case .small: L("가볍고 빨라요.")
        case .large: L("답이 더 좋아요.")
        case .xlarge: L("가장 똑똑해요. 램 8GB 이상 기기에서만 쓸 수 있어요.")
        }
    }

    /// 이 기기에서 고를 수 있는 크기들.
    public static func available(physicalMemory: UInt64) -> [LocalQwenChoice] {
        allCases.filter { choice in
            switch choice {
            case .xlarge: LocalQwenModel.xlarge.isSupported(physicalMemory: physicalMemory)
            default: true
            }
        }
    }

    public static var availableOnThisDevice: [LocalQwenChoice] {
        available(physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }

    /// 실제로 쓸 모델. 자동이면 기기 메모리로 정한다.
    public func resolve(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> LocalQwenModel {
        switch self {
        case .automatic: LocalQwenModel.recommended(physicalMemory: physicalMemory)
        case .small: .small
        case .large: .large
        case .xlarge:
            // 예전에 4B 를 고른 기기라도, 지금 메모리가 모자라면(예: 설정이 다른 기기에서
            // 옮겨 온 경우) 앱이 죽는 쪽보다 한 단계 작은 모델이 낫다.
            LocalQwenModel.xlarge.isSupported(physicalMemory: physicalMemory)
                ? .xlarge
                : LocalQwenModel.recommended(physicalMemory: physicalMemory)
        }
    }
}
