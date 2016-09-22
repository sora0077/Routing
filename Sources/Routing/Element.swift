//
//  Element.swift
//  Routing
//
//  Created by 林達也 on 2016/09/20.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


struct Element {
    
    let pattern: String
    private let regex: RegularExpression
    private let keys: [String]
    
    private let middlewares: [Middleware]
    
    init(pattern: String, middlewares: [Middleware] = [], builder: RegexBuilder = RegexBuilder.shared) {
        self.pattern = pattern
        self.middlewares = middlewares
        (regex, keys) = builder.build(pattern: pattern)
    }
    
    func match(path: String) -> TextCheckingResult? {
        return regex.firstMatch(in: path, range: NSRange(location: 0, length: path.utf16.count))
    }
    
    func process(request: Request, response: Response, next: @escaping () -> Void) {
        guard response.error == nil else {
            next()
            return
        }
        
        let path = request.url.path
        
        guard let match = match(path: path) else {
            next()
            return
        }
        
        var request = request
        request.parameters = makeParameters(path: path, match: match)
        Walker(middlewares: ArraySlice(middlewares),
               request: request,
               response: response,
               callback: next).next()
    }
    
    private func makeParameters(path: String, match: TextCheckingResult) -> [String: String] {
        var parameters: [String: String] = [:]
        for (index, key) in keys.enumerated() {
            if let range = match.rangeAt(index + 1).range(for: path) {
                parameters[key] = path.substring(with: range)
            }
        }
        return parameters
    }
}


private struct Walker {
    
    let middlewares: ArraySlice<Middleware>
    let request: Request
    var response: Response
    let callback: () -> Void
    
    func next() {
        if middlewares.isEmpty {
            callback()
        } else {
            var walker = Walker(middlewares: middlewares.dropFirst(), request: request, response: response, callback: callback)
            do {
                try middlewares[middlewares.startIndex].handle(request: request, response: response, next: walker.next)
            } catch {
                walker.response.error = error
                walker.next()
            }
        }
    }
}
