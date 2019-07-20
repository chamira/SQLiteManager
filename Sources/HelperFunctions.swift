//
//  HelperFunctions.swift
//  Pods
//
//  Created by Chamira Fernando on 23/09/16.
//
//

import Foundation

/////String into NSString
//public func sqlStr(_ str:String) -> NSString {
//    return str as NSString
//}
//
/////Data into NSData
//public func sqlData(_ data:Data) -> NSData {
//    return NSData(data: data)
//}
//
/////Int into NSNumber
//public func sqlNumber(_ number:Int) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Int8 into NSNumber
//public func sqlNumber(_ number: Int8) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////UInt8 into NSNumber
//public func sqlNumber(_ number: UInt8) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Int16 into NSNumber
//public func sqlNumber(_ number: Int16) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////UInt16 into NSNumber
//public func sqlNumber(_ number: UInt16) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Int32 into NSNumber
//public func sqlNumber(_ number: Int32) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////UInt32 into NSNumber
//public func sqlNumber(_ number: UInt32) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Int64 into NSNumber
//public func sqlNumber(_ number: Int64) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////UInt64 into NSNumber
//public func sqlNumber(_ number: UInt64) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Float into NSNumber
//public func sqlNumber(_ number: Float) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Double into NSNumber
//public func sqlNumber(_ number: Double) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////Bool into NSNumber
//public func sqlNumber(_ number: Bool) -> NSNumber {
//    return NSNumber(value: number)
//}
//
/////UInt into NSNumber
//public func sqlNumber(_ number: UInt) -> NSNumber {
//    return NSNumber(value: number)
//}

public func errorKeyStr(forCFStr cfStr: CFString) -> String {
	return "\(cfStr)"
}

public protocol SQLValue {
    var value: NSObjectProtocol { get }
}

public protocol SQLReturnValue {}

public extension SQLValue {
    var value: NSObjectProtocol {
        if self is String {
            return self as! NSString
        } else if self is Int {
            return NSNumber(value: self as! Int)
        } else if self is Int8 {
            return NSNumber(value: self as! Int8)
        } else if self is Int16 {
            return NSNumber(value: self as! Int16)
        } else if self is Int32 {
            return NSNumber(value: self as! Int32)
        } else if self is Int64 {
            return NSNumber(value: self as! Int64)
        } else if self is UInt {
            return NSNumber(value: self as! UInt)
        } else if self is UInt8 {
            return NSNumber(value: self as! UInt8)
        } else if self is UInt16 {
            return NSNumber(value: self as! UInt16)
        } else if self is UInt32 {
            return NSNumber(value: self as! UInt32)
        } else if self is UInt64 {
            return NSNumber(value: self as! UInt64)
        } else if self is Float {
            return NSNumber(value: self as! Float)
        } else if self is Float32 {
            return NSNumber(value: self as! Float32)
        } else if self is Float64 {
            return NSNumber(value: self as! Float64)
        } else if self is Double {
            return NSNumber(value: self as! Double)
        } else if self is Bool {
            return NSNumber(value: self as! Bool)
        } else if self is Data {
            return NSData(data: self as! Data)
        }
        return NSNull()
    }
}

extension String: SQLValue {}
extension Data: SQLValue {}
extension Bool: SQLValue {}
extension Int: SQLValue {}
extension Int8: SQLValue {}
extension Int32: SQLValue {}
extension Int64: SQLValue {}
extension UInt: SQLValue {}
extension UInt8: SQLValue {}
extension UInt32: SQLValue {}
extension UInt64: SQLValue {}
extension Float: SQLValue {}
extension Double: SQLValue {}

extension SQLReturnValue {
    public var string: String? {
        return self as? String
    }

    public var int: Int? {
        return self as? Int
    }

    public var float: Float? {
        return self as? Float
    }

    public var double: Double? {
        return self as? Double
    }

    public var data: Data? {
        return self as? Data
    }

    public var date: Date? {
        guard let v = self as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: v)
    }
}
extension String: SQLReturnValue {}
extension Data: SQLReturnValue {}
extension Bool: SQLReturnValue {}
extension Int: SQLReturnValue {}
extension Float: SQLReturnValue {}
extension Double: SQLReturnValue {}
