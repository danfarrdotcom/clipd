import Foundation

enum OutputFormat: String, CaseIterable, Identifiable {
    case gif = "GIF"
    case mp4 = "MP4"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .gif: return "gif"
        case .mp4: return "mp4"
        }
    }

    var utType: String {
        switch self {
        case .gif: return "com.compuserve.gif"
        case .mp4: return "public.mpeg-4"
        }
    }
}
