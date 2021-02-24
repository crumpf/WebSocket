//
//  WebSocket.swift
//  WebSocket
//
//  Created by Christopher Rumpf on 2/18/21.
//

import Foundation

protocol WebSocketDelegate: class {
    func socket(_ socket: WebSocket, didOpenWithProtocol protocol: String?)
    func socket(_ socket: WebSocket, didCloseWithCode closeCode: Int, reason: String?)
    func socket(_ socket: WebSocket, didError error: Error)
    func socket(_ socket: WebSocket, receivedString string: String)
    func socket(_ socket: WebSocket, receivedData data: Data)
}

public class WebSocket: NSObject {
    
    init(delegate: WebSocketDelegate? = nil) {
        super.init()
        self.delegate = delegate
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    weak var delegate: WebSocketDelegate?
    
    enum WebSocketError: Error {
        case invalidCloseCode
    }
    
    enum State {
        case closed
        case closing
        case open
        case opening
    }
    
    private(set) var state = State.closed
    
    func open(with url: URL, protocols: [String] = []) {
        guard state == .closed else {
            return
        }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: url, protocols: protocols)
        listen()
        state = .opening
        webSocketTask?.resume()
    }
    
    func close(withCloseCode closeCode: Int = URLSessionWebSocketTask.CloseCode.goingAway.rawValue) throws {
        guard state == .open else {
            return
        }
        guard let code = URLSessionWebSocketTask.CloseCode(rawValue: closeCode) else {
            throw WebSocketError.invalidCloseCode
        }
        state = .closing
        webSocketTask?.cancel(with: code, reason: nil)
    }
    
    func send(_ string: String, completion: ((Error?) -> Void)? = nil) {
        send(.string(string), completion: completion ?? { _ in })
    }
    
    func send(_ data: Data, completion: ((Error?) -> Void)? = nil) {
        send(.data(data), completion: completion ?? { _ in })
    }
    
    func sendPing(pongReceiveHandler: @escaping (Error?) -> Void) {
        webSocketTask?.sendPing(pongReceiveHandler: pongReceiveHandler)
    }
    
    private func send(_ message: URLSessionWebSocketTask.Message, completion: @escaping (Error?) -> Void) {
        webSocketTask?.send(message, completionHandler: completion)
    }

    private func listen() {
        webSocketTask?.receive { [weak self] (result) in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let string):
                    self.delegate?.socket(self, receivedString: string)
                case .data(let data):
                    self.delegate?.socket(self, receivedData: data)
                @unknown default:
                    break
                }
            case .failure(let error as NSError) where error.code == POSIXError.ENOTCONN.rawValue:
                self.state = .closed
                self.delegate?.socket(self, didError: error)
                return
            case .failure(let error):
                self.delegate?.socket(self, didError: error)
                // should all failures return so we don't repeatedly call listen() and get spammed with failures
                // as with ENOTCONN above?
            }
            
            self.listen()
        }
    }
    
}

extension WebSocket: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        state = .open
        delegate?.socket(self, didOpenWithProtocol: `protocol`)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        state = .closed
        var decodedReason: String?
        if let reason = reason {
            decodedReason = String(data: reason, encoding: .utf8)
        }
        delegate?.socket(self, didCloseWithCode: closeCode.rawValue, reason: decodedReason)
    }
}
