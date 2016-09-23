//
//  Router.swift
//  Routing
//
//  Created by 林達也 on 2016/09/20.
//  Copyright © 2016年 jp.sora0077. All rights reserved.
//

import Foundation


public protocol Middleware {
    
    func handle(request: Request, response: Response, next: @escaping (Response) -> Void) throws
}


public struct Request {
    
    public let url: URL
    
    public internal(set) var parameters: [String: String] = [:]
    
    public private(set) lazy var queryItems: [String: String?] = {
        let comps = URLComponents(url: self.url, resolvingAgainstBaseURL: true)
        let items = comps?.queryItems ?? []
        var mapping: [String: String?] = [:]
        for item in items {
            mapping[item.name] = item.value
        }
        return mapping
    }()
}

extension Request {
    
    init(url: URL) {
        self.url = url
    }
}

public struct Response {
    
    public internal(set) var error: Error?
    
    private var closingClosures: [() -> Void] = []
    
    public mutating func closing(_ closure: @escaping () -> Void) {
        closingClosures.append(closure)
    }
    
    fileprivate func fireClosing() {
        closingClosures.reversed().forEach { $0() }
    }
}

public final class Router {
    
    public typealias Handler =  (Request, Response, (Response) -> Void) throws -> Void
    
    private var elements: [Element] = []
    
    public init() {
        
    }
    
    public func install(middleware: Middleware..., for pattern: String = "*") {
        elements.append(Element(pattern: pattern, middlewares: middleware, isHandler: false))
    }
    
    public func register(pattern: String, handlers: @escaping Handler...) {
        elements.append(Element(pattern: pattern, middlewares: handlers.map(MiddlewareGenerator.init), isHandler: true))
    }
    
    public func canOpenURL(url: URL) -> Bool {
        for elem in elements {
            if elem.isHandler && elem.match(path: url.path) != nil {
                return true
            }
        }
        return false
    }
    
    public func open(url: URL, completion: ((Response) -> Void)? = nil) {
        let closure: (Response) -> Void = { res in
            completion?(res)
            res.fireClosing()
        }
        ElementWalker(elements: ArraySlice(elements),
                      request: Request(url: url),
                      callback: closure).next(response: Response())
    }
}

private struct MiddlewareGenerator: Middleware {
    
    let callback: Router.Handler
    
    init(handler: @escaping Router.Handler) {
        callback = handler
    }
    
    func handle(request: Request, response: Response, next: @escaping (Response) -> Void) throws {
        try callback(request, response, next)
    }
}

private struct ElementWalker {
    
    let elements: ArraySlice<Element>
    let request: Request
    let callback: (Response) -> Void
    
    func next(response: Response) {
        if elements.isEmpty {
            callback(response)
        } else {
            let walker = ElementWalker(elements: elements.dropFirst(), request: request, callback: callback)
            elements[elements.startIndex].process(request: request, response: response, next: walker.next)
        }
    }
}
