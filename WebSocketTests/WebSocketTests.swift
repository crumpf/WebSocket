//
//  WebSocketTests.swift
//  WebSocketTests
//
//  Created by Christopher Rumpf on 2/18/21.
//

import XCTest
@testable import WebSocket

class WebSocketTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testWhenSocketOpensThenSendReceiveMessageThenClose() throws {
        guard let url = URL(string: "wss://echo.websocket.org") else {
            XCTFail("Invalid URL")
            return
        }
        
        let expect = SocketExpectation()
        let socket = WebSocket(delegate: expect)
        socket.open(with: url)
        
        wait(for: [expect.openExpectation], timeout: 10.0)
        
        socket.send("hello") {_ in }
        
        wait(for: [expect.receiveExpectation], timeout: 5.0)
                
        try! socket.close()
        
        wait(for: [expect.closeExpectation], timeout: 15.0)
    }
    
    func testWhenSocketOpensThenSendPingThenClose() throws {
        guard let url = URL(string: "wss://echo.websocket.org") else {
            XCTFail("Invalid URL")
            return
        }
        
        let expect = SocketExpectation()
        let socket = WebSocket(delegate: expect)
        socket.open(with: url)
        
        wait(for: [expect.openExpectation], timeout: 10.0)
        
        let pingExpectation = XCTestExpectation(description: "ping")
        socket.sendPing { (error) in
            if let error = error {
                XCTFail("pong failed: \(error)")
            }
            print("websocket pong")
            pingExpectation.fulfill()
        }
        
        wait(for: [pingExpectation], timeout: 5.0)
                
        try! socket.close()
        
        wait(for: [expect.closeExpectation], timeout: 15.0)

    }

}

class SocketExpectation: WebSocketDelegate {
    
    let openExpectation = XCTestExpectation(description: "socket opened")
    let closeExpectation = XCTestExpectation(description: "socket closed")
    let receiveExpectation = XCTestExpectation(description: "socket received message")
    
    func socket(_ socket: WebSocket, didOpenWithProtocol protocol: String?) {
        print("websocket opened")
        openExpectation.fulfill()
    }
    
    func socket(_ socket: WebSocket, didCloseWithCode closeCode: Int, reason: String?) {
        print("websocket closed")
        closeExpectation.fulfill()
    }
    
    func socket(_ socket: WebSocket, didError error: Error) {
        print("websocket error: \(error)")
    }
    
    func socket(_ socket: WebSocket, receivedString string: String) {
        print("websocket received: \(string)")
        receiveExpectation.fulfill()
    }
    
    func socket(_ socket: WebSocket, receivedData data: Data) {
        print("websocket received data")
    }
    
}
