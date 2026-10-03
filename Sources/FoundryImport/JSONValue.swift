import Foundation

/// A parsed JSON value with forgiving accessors. Foundry documents vary in shape between packs, so
/// fields are read leniently: a missing or mistyped field reads as empty or zero.
public enum JSONValue: Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(data: Data) throws {
        self = JSONValue(any: try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    init(any: Any) {
        switch any {
        case let dictionary as [String: Any]: self = .object(dictionary.mapValues(JSONValue.init(any:)))
        case let array as [Any]: self = .array(array.map(JSONValue.init(any:)))
        case let string as String: self = .string(string)
        case let number as NSNumber: self = Self.value(of: number)
        default: self = .null
        }
    }

    private static func value(of number: NSNumber) -> JSONValue {
        CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.doubleValue)
    }

    public subscript(key: String) -> JSONValue {
        if case let .object(dictionary) = self { return dictionary[key] ?? .null }
        return .null
    }

    /// Follows a dotted path such as `"system.attributes.ac.value"`.
    public subscript(path path: String) -> JSONValue {
        path.split(separator: ".").reduce(self) { $0[String($1)] }
    }

    public var string: String {
        switch self {
        case let .string(value): return value
        case let .number(value): return value == value.rounded() ? String(Int(value)) : String(value)
        default: return ""
        }
    }

    public var int: Int {
        switch self {
        case let .number(value): return Int(value)
        case let .string(value): return Int(value.trimmingCharacters(in: .whitespaces)) ?? 0
        default: return 0
        }
    }

    /// The integer value, or nil when the field is absent or not a number.
    public var optionalInt: Int? {
        switch self {
        case let .number(value): return Int(value)
        case let .string(value): return Int(value)
        default: return nil
        }
    }

    public var bool: Bool {
        if case let .bool(value) = self { return value }
        return false
    }

    public var array: [JSONValue] {
        if case let .array(values) = self { return values }
        return []
    }

    public var object: [String: JSONValue] {
        if case let .object(dictionary) = self { return dictionary }
        return [:]
    }

    public var strings: [String] { array.map(\.string).filter { !$0.isEmpty } }

    public var isNull: Bool { self == .null }
}
