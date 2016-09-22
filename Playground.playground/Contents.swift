//: Playground - noun: a place where people can play

import UIKit
@testable import Routing


//let elem = Element(pattern: "/test/:id", middlewares: [])
//let request = Request(url: URL(string: "http://com/test/100")!, parameters: [:])
//let response = Response()
//elem.process(request: request, response: response, next: {})


let router = Router()
router.register(pattern: "/test/:id") { (request, response, next) in
    print(request)
    next()
}
router.register(pattern: "/test/:id(\\d{4})") { (request, response, next) in
    print("2", request)
    next()
}

router.canOpenURL(url: URL(string: "http://hoge/testd/100d")!)

router.open(url: URL(string: "http://hoge/a/test/1000")!) {
    print("done")
}
