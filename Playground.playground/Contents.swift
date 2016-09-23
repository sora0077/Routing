//: Playground - noun: a place where people can play

import UIKit
import Routing


struct Logger: Middleware {
    
    func handle(request: Request, response: Response, next: @escaping (Response) -> Void) throws {
        print("log ", request)
        next(response)
    }
}


let router = Router()
router.install(middleware: Logger())
router.register(pattern: "/test/:id") { (request, response, next) in
    print(request)
    next(response)
}
router.register(pattern: "/test/:id(\\d{4})") { (request, response, next) in
    print("2", request)
    next(response)
}

router.canOpenURL(url: URL(string: "http://hoge/tdest/100d")!)

router.open(url: URL(string: "http://hoge/test/1000")!) { _ in
    print("done")
}
