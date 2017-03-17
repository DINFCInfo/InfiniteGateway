//
//  PortalDriver.swift
//  InfiniteGateway
//
//  Created by Eric Betts on 9/18/15.
//  Copyright © 2015 Eric Betts. All rights reserved.
//

import Foundation
import Cocoa

//Handles initial activation, requestion more token data, notification about new tokens

typealias tokenLoad = (Message.LedPlatform, Int, Token) -> Void
typealias tokenLeft = (Message.LedPlatform, Int) -> Void
class PortalDriver : NSObject {
    static let magic : Data = "(c) Disney 2013".data(using: String.Encoding.ascii)!
    static let secret : Data = Data(bytes: [0xAF, 0x62, 0xD2, 0xEC, 0x04, 0x91, 0x96, 0x8C, 0xC5, 0x2A, 0x1A, 0x71, 0x65, 0xF8, 0x65, 0xFE])
    static let singleton = PortalDriver()
    var portalThread : Thread?
    var portal : Portal = Portal.singleton
    
    var presence = Dictionary<UInt8, Detail>()
    var encryptedTokens : [UInt8:EncryptedToken] = [:]
    
    var loadTokenCallbacks : [tokenLoad] = []
    var leftTokenCallbacks : [tokenLeft] = []
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(PortalDriver.deviceConnected(_:)), name: NSNotification.Name(rawValue: "deviceConnected"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PortalDriver.incomingMessage(_:)), name: NSNotification.Name(rawValue: "incomingMessage"), object: nil)
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceDisconnected:", name: "deviceDisconnected", object: nil)
        
        portalThread = Thread(target: self.portal, selector:#selector(Portal.initUsb), object: nil)
        if let thread = portalThread {
            thread.start()
        }
    }
    
    func registerTokenLoaded(_ callback: @escaping tokenLoad) {
        loadTokenCallbacks.append(callback)
    }
    func registerTokenLeft(_ callback: @escaping tokenLeft) {
        leftTokenCallbacks.append(callback)
    }

    func deviceConnected(_ notification: Notification) {
        portal.outputCommand(ActivateCommand())
    }
    
    func incomingUpdate(_ update: Update) {
        print(update)
        var updateColor : NSColor = NSColor()
        if (update.direction == Update.Direction.arriving) {
            // NB: We don't call loadTokenCallbacks until token data is read
            updateColor = NSColor.white
            presence[update.nfcIndex] = Detail(nfcIndex: update.nfcIndex, platform: update.ledPlatform, sak: update.sak)
            portal.outputCommand(TagIdCommand(nfcIndex: update.nfcIndex))
        } else if (update.direction == Update.Direction.departing) {
            updateColor = NSColor.black
            presence.removeValue(forKey: update.nfcIndex)
            DispatchQueue.main.async(execute: {
                for callback in self.leftTokenCallbacks {
                    callback(update.ledPlatform, Int(update.nfcIndex))
                }
            })
        }        
        portal.outputCommand(LightOnCommand(ledPlatform: update.ledPlatform, color: updateColor))
    }
    
    func incomingResponse(_ response: Response) {
        if let _ = response as? ActivateResponse {
            portal.outputCommand(PresenceCommand())
        } else if let response = response as? PresenceResponse {
            portal.outputCommand(LightOnCommand(ledPlatform: .all, color: NSColor.black))
            for detail in response.details {
                presence[detail.nfcIndex] = detail
                portal.outputCommand(TagIdCommand(nfcIndex: detail.nfcIndex))
            }
        } else if let response = response as? TagIdResponse {
            print(response)
            encryptedTokens[response.nfcIndex] = EncryptedToken(tagId: response.tagId)
            let detail = presence[response.nfcIndex]            
            if (detail?.sak == .mifareMini) {
                portal.outputCommand(ReadCommand(nfcIndex: response.nfcIndex, block: 0))
            }
        } else if let response = response as? ReadResponse {
            print(response)
            if (response.status == .success) {
                tokenRead(response)
            }
        } else if let response = response as? WriteResponse {
            print(response)
        } else if let _ = response as? LightOnResponse {
        } else if let _ = response as? LightFadeResponse {
        } else if let _ = response as? LightFlashResponse {
        } else if let response = response as? B1Response {
            print(response)
            let value2 = response.value2
            if value2 < 0xff {
                self.portal.outputCommand(B1Command(nfcIndex: response.nfcIndex, value2: value2 + 1))
            }
        } else if let response = response as? B8Response {
            print(response)
            self.portal.outputCommand(B9Command(value: 0x2b))
        } else if let response = response as? B9Response {
            print(response)            
        } else if let _ = response as? C1Response {
            print(response)
            self.portal.outputCommand(C0Command())
        } else {
            print("Received \(response) for command \(response.command)")
        }
    }

    func tokenRead(_ response: ReadResponse) {
        if let token = encryptedTokens[response.nfcIndex] {
            token.load(response.blockNumber, blockData: response.blockData)
            if (token.complete()) {
                let ledPlatform = presence[response.nfcIndex]?.platform ?? .none
                if (token.decryptedToken != nil) {
                    portal.outputCommand(LightOnCommand(ledPlatform: ledPlatform, color: NSColor.green))
                    DispatchQueue.main.async(execute: {
                        for callback in self.loadTokenCallbacks {
                            callback(ledPlatform, Int(response.nfcIndex), token.decryptedToken!)
                        }
                    })
                } else {
                    portal.outputCommand(LightOnCommand(ledPlatform: ledPlatform, color: NSColor.red))
                }

                encryptedTokens.removeValue(forKey: response.nfcIndex)
            } else {
                let nextBlock = token.nextBlock()
                portal.outputCommand(ReadCommand(nfcIndex: response.nfcIndex, block: nextBlock))
            }
        } //end if token
    }
    
    func incomingMessage(_ notification: Notification) {
        let userInfo = notification.userInfo
        if let message = userInfo?["message"] as? Message {
            if let update = message as? Update {
                incomingUpdate(update)
            } else if let response = message as? Response {
                incomingResponse(response)
            }
        }
    }

    func experiment() {
        //self.portal.outputCommand(BeCommand(value: test))
        //self.portal.outputCommand(C1Command(value: test))
        //self.portal.outputCommand(C0Command())
        //var test : UInt8 = 0
        
        /*
        if #available(OSX 10.12, *) {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                self.portal.outputCommand(B1Command(value1: 0x00, value2: test))
                if test > 0x10 {
                    timer.invalidate()
                }
                test = test + 1
            })
        }
        */
    }
}
