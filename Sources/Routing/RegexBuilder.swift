//
//  RegexBuilder.swift
//  Routing
//
//  Created by 林達也 on 2016/09/20.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


typealias RegularExpression = NSRegularExpression
typealias TextCheckingResult = NSTextCheckingResult


/// https://github.com/IBM-Swift/Kitura/blob/master/Sources/Kitura/RouteRegex.swift
final class RegexBuilder {
    static let shared = RegexBuilder()
    
    private let namedCaptureRegex: RegularExpression
    private let unnamedCaptureRegex: RegularExpression
    
    private init() {
        do {
            namedCaptureRegex = try RegularExpression(pattern: "(.*)?(?:\\:(\\w+)(?:\\(((?:\\\\.|[^()])+)\\))?(?:([+*?])?))", options: [])
            unnamedCaptureRegex = try RegularExpression(pattern: "(.*)?(?:(?:\\(((?:\\\\.|[^()])+)\\))(?:([+*?])?))", options: [])
        } catch {
            fatalError()
        }
    }
    
    func build(pattern: String?) -> (RegularExpression?, [String]?) {
        guard let pattern = pattern else {
            return (nil, nil)
        }
        
        var regexStr = "^"
        var keys: [String] = []
        var nonKeyIndex = 0
        
        
        let paths = pattern.components(separatedBy: "/")
        if paths.filter({$0 != ""}).isEmpty {
            regexStr.append("/")
        }
        
        func handle(path: String, regexStr: String, keys: [String], nonKeyIndex: Int) -> (String, [String], Int) {
            var regexStr = regexStr
            var keys = keys
            var nonKeyIndex = nonKeyIndex
            
            guard !path.isEmpty else {
                return (regexStr, keys, nonKeyIndex)
            }
            
            let toAppend: String
            if let (prefix, matchExp, plusQuestStar) = matchRanges(in: path, nonKeyIndex: &nonKeyIndex, keys: &keys) {
                toAppend = getStringToAppendToRegex(plusQuestStar: plusQuestStar, prefix: prefix, matchExp: matchExp)
            } else {
                toAppend = "/\(path)"
            }
            
            regexStr.append(toAppend)
            
            return (regexStr, keys, nonKeyIndex)
        }

        for path in paths {
            (regexStr, keys, nonKeyIndex) = handle(path: path, regexStr: regexStr, keys: keys, nonKeyIndex: nonKeyIndex)
        }
        regexStr.append("(?:/(?=$))?$")
        do {
            let regex = try RegularExpression(pattern: regexStr, options: [])
            return (regex, keys)
        } catch {
            fatalError("Failed to compile the regular expression for the route \(pattern)")
        }
    }
    
    private func matchRanges(in path: String, nonKeyIndex: inout Int, keys: inout [String]) -> (prefix: String, matchExp: String, plusQuestStar: String)?
    {
        var prefix = ""
        var matchExp = "[^/]+?"
        var plusQuestStar = ""
        
        if  path == "*" {
            // Handle a path element of * specially
            return (prefix, ".*", plusQuestStar)
        }
        
        let range = NSMakeRange(0, path.utf16.count)
        
        if let keyMatch = namedCaptureRegex.firstMatch(in: path, options: [], range: range) {
            // We found a path element with a named/key capture
            extract(from: path, with: keyMatch, at: 1, to: &prefix)
            extract(from: path, with: keyMatch, at: 3, to: &matchExp)
            extract(from: path, with: keyMatch, at: 4, to: &plusQuestStar)
            
            if let range = keyMatch.rangeAt(2).range(for: path) {
                keys.append(path.substring(with: range))
            }
            
            return (prefix, matchExp, plusQuestStar)
        } else if let nonKeyMatch = unnamedCaptureRegex.firstMatch(in: path, options: [], range: range) {
            // We found a path element with an unnamed capture
            extract(from: path, with: nonKeyMatch, at: 1, to: &prefix)
            extract(from: path, with: nonKeyMatch, at: 2, to: &matchExp)
            extract(from: path, with: nonKeyMatch, at: 3, to: &plusQuestStar)
            
            keys.append(String(nonKeyIndex))
            nonKeyIndex += 1
            return (prefix, matchExp, plusQuestStar)
        }
        
        return nil
    }
    
    
    private func extract(from path: String, with match: TextCheckingResult, at index: Int,
                 to string: inout String) {
        if let range = match.rangeAt(index).range(for: path) {
            string = path.substring(with: range)
        }
    }
    
    
    
    private func getStringToAppendToRegex(plusQuestStar: String, prefix: String,
                                  matchExp: String) -> String {
        // We have some kind of capture for this path element
        // Build the runtime regex depending on whether or not there is "repetition"
        switch plusQuestStar {
        case "+":
            return "/\(prefix)(\(matchExp)(?:/\(matchExp))*)"
        case "?":
            if prefix.isEmpty {
                return "(?:/(\(matchExp)))?"
            }
            return "/\(prefix)(?:(\(matchExp)))?"
        case "*":
            if prefix.isEmpty {
                return "(?:/(\(matchExp)(?:/\(matchExp))*))?"
            }
            return "/\(prefix)(?:(\(matchExp)(?:/\(matchExp))*))?"
        default:
            return "/\(prefix)(?:(\(matchExp)))"
        }
    }
}


extension NSRange {
    
    func range(for str: String) -> Range<String.Index>? {
        guard location != NSNotFound else { return nil }
        
        guard let fromUTFIndex = str.utf16.index(str.utf16.startIndex, offsetBy: location, limitedBy: str.utf16.endIndex) else { return nil }
        guard let toUTFIndex = str.utf16.index(fromUTFIndex, offsetBy: length, limitedBy: str.utf16.endIndex) else { return nil }
        guard let fromIndex = String.Index(fromUTFIndex, within: str) else { return nil }
        guard let toIndex = String.Index(toUTFIndex, within: str) else { return nil }
        
        return fromIndex..<toIndex
    }
}
