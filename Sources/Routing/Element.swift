//
//  Element.swift
//  Routing
//
//  Created by 林達也 on 2016/09/20.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


final class Element {
    
    let pattern: String?
    let regex: RegularExpression?
    let keys: [String]?
    
    let middlewares: [Middleware]
    
    init(pattern: String?, middlewares: [Middleware] = [], builder: RegexBuilder = RegexBuilder.shared) {
        self.pattern = pattern
        self.middlewares = middlewares
        (regex, keys) = builder.build(pattern: pattern)
    }
    
    func process(request: Request, response: Response, next: @escaping () -> Void) {
        print(request.parameters)
        
        guard response.error == nil else {
            next()
            return
        }
        
        guard let regex = regex else {
            var request = request
            request.parameters = [:]
            walk(request: request, response: response, next: next)
            return
        }
        
        let path = request.url.path
        
        guard let match = regex.firstMatch(in: path, range: NSRange(location: 0, length: path.utf16.count)) else {
            next()
            return
        }
        
        var request = request
        request.parameters = makeParameters(path: path, match: match)
        walk(request: request, response: response, next: next)
        
        print(request.parameters)
    }
    
    private func walk(request: Request, response: Response, next: @escaping () -> Void) {
        Walker(middlewares: ArraySlice(middlewares),
               request: request,
               response: response,
               callback: next).next()
    }
    
    private func makeParameters(path: String, match: TextCheckingResult) -> [String: String] {
        var parameters: [String: String] = [:]
        for (index, key) in (keys ?? []).enumerated() {
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
    
    init(middlewares: ArraySlice<Middleware>, request: Request, response: Response, callback: @escaping () -> Void) {
        self.middlewares = middlewares
        self.request = request
        self.response = response
        self.callback = callback
    }
    
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
