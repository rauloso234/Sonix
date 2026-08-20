enum JoinCodeGenerator {
    private static let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate(length: Int = 6) -> String {
        String((0..<length).compactMap { _ in characters.randomElement() })
    }

    static func normalize(_ value: String) -> String {
        String(
            value
                .uppercased()
                .filter { characters.contains($0) }
                .prefix(6)
        )
    }

    static func isValid(_ value: String) -> Bool {
        normalize(value).count == 6
    }
}
