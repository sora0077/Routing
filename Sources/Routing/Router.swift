//
//  Router.swift
//  Routing
//
//  Created by 林達也 on 2016/09/20.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


protocol Middleware {
    
    func handle(request: Request, response: Response, next: @escaping () -> Void) throws
}


public struct Request {
    
    public let url: URL
    
    public internal(set) var parameters: [String: String] = [:]
}

extension Request {
    
    init(url: URL) {
        self.url = url
    }
}

public struct Response {
    
    public internal(set) var error: Error?
}

public final class Router {
    
    public typealias Handler =  (Request, Response, () -> Void) throws -> Void
    
    private var elements: [Element] = []
    
    public func register(pattern: String, handlers: @escaping Handler...) {
        elements.append(Element(pattern: pattern, middlewares: handlers.map(MiddlewareGenerator.init)))
    }
    
    public func canOpenURL(url: URL) -> Bool {
        for elem in elements {
            if elem.match(path: url.path) != nil {
                return true
            }
        }
        return false
    }
    
    public func open(url: URL, completion: @escaping () -> Void = {}) {
        ElementWalker(elements: ArraySlice(elements),
                      request: Request(url: url),
                      response: Response(),
                      callback: completion).next()
    }
}

private struct MiddlewareGenerator: Middleware {
    
    let callback: Router.Handler
    
    init(handler: @escaping Router.Handler) {
        callback = handler
    }
    
    func handle(request: Request, response: Response, next: @escaping () -> Void) throws {
        try callback(request, response, next)
    }
}

private struct ElementWalker {
    
    let elements: ArraySlice<Element>
    let request: Request
    let response: Response
    let callback: () -> Void
    
    func next() {
        if elements.isEmpty {
            callback()
        } else {
            let walker = ElementWalker(elements: elements.dropFirst(), request: request, response: response, callback: callback)
            elements[elements.startIndex].process(request: request, response: response, next: walker.next)
        }
    }
}
