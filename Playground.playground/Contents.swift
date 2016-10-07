//: Playground - noun: a place where people can play

import UIKit
import Routing
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true


struct Logger: Middleware {
    
    func handle(request: Request, response: Response, next: @escaping (Response) -> Void) throws {
        print("log ", request)
        let date = Date()
        var response = response
        response.closing {
            print("log end:", Date().timeIntervalSince(date))
        }
        next(response)
    }
}

struct AnotherMiddleware: Middleware {
    
    func handle(request: Request, response: Response, next: @escaping (Response) -> Void) throws {
        
        print("another middleware start")
        var response = response
        response.closing {
            print("another middleware end")
        }
        next(response)
    }
}

let router = Router()
router.install(middleware: Logger(), AnotherMiddleware())
router.register(pattern: "/test/:id") { (request, response, next) in
    print(request)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        next(response)
    }
    
}
router.register(pattern: "/test/:id([0-9]+)") { (request, response, next) in
    print("2", request)
    next(response)
}

router.canOpenURL(url: URL(string: "http://hoge/test/100")!)

router.open(url: URL(string: "http://hoge/test/1000")!) { res in
    print("done", res)
}
