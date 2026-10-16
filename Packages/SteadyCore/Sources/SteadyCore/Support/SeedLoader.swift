import Foundation

public enum SeedLoader {
    public static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: data)
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        let data = try Data(contentsOf: url)
        return try decode(type, from: data, using: decoder)
    }
}
