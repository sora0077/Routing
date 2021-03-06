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
    private let queue: DispatchQueue?
    private let regex: RegularExpression
    private let keys: [String]
    
    let isHandler: Bool
    
    private let middlewares: [Middleware]
    
    init(pattern: String, queue: DispatchQueue?, middlewares: [Middleware], isHandler: Bool, builder: RegexBuilder = RegexBuilder.shared) {
        self.pattern = pattern
        self.queue = queue
        self.middlewares = middlewares
        self.isHandler = isHandler
        (regex, keys) = builder.build(pattern: pattern)
    }
    
    func match(path: String) -> TextCheckingResult? {
        return regex.firstMatch(in: path, range: NSRange(location: 0, length: path.utf16.count))
    }
    
    func process(request: Request, response: Response, next: @escaping (Response) -> Void) {
        
        func execute() {
            guard response.error == nil else {
                next(response)
                return
            }
            
            let path = request.url.path
            
            guard let match = match(path: path) else {
                next(response)
                return
            }
            
            var request = request
            request.parameters = makeParameters(path: path, match: match)
            Walker(middlewares: ArraySlice(middlewares),
                   request: request,
                   callback: next).next(response: response)
        }
        
        if let queue = queue {
            queue.async(execute: execute)
        } else {
            execute()
        }
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
    let callback: (Response) -> Void
    
    func next(response: Response) {
        if middlewares.isEmpty {
            callback(response)
        } else {
            let walker = Walker(middlewares: middlewares.dropFirst(), request: request, callback: callback)
            do {
                try middlewares[middlewares.startIndex].handle(request: request, response: response, next: walker.next)
            } catch {
                var response = response
                response.error = error
                walker.next(response: response)
            }
        }
    }
}
