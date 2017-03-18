//
//  ExperimentalResponse.swift
//  InfiniteGateway
//
//  Created by Eric Betts on 3/17/17.
//  Copyright © 2017 Eric Betts. All rights reserved.
//

import Foundation


class B1Response : Response {
    var nfcIndex : UInt8  {
        get {
            if let command = command as? B1Command {
                return command.nfcIndex
            }
            return 0
        }
    }
    
    var value2 : UInt8  {
        get {
            if let command = command as? B1Command {
                return command.value2
            }
            return 0
        }
    }
    
    override var description: String {
        let me = String(describing: type(of: self)).components(separatedBy: ".").last!
        return "\(me)[\(command.params.toHexString()): \(params.toHexString())]"
    }
}

class B8Response : Response {
    var value : UInt8  {
        get {
            if let command = command as? B8Command {
                return command.value
            }
            return 0
        }
    }
    
    override var description: String {
        let me = String(describing: type(of: self)).components(separatedBy: ".").last!
        return "\(me)[\(command.params.toHexString()): \(params.toHexString())]"
    }
}


class B9Response : Response {
    var value : UInt8  {
        get {
            if let command = command as? B9Command {
                return command.value
            }
            return 0
        }
    }
    
    override var description: String {
        let me = String(describing: type(of: self)).components(separatedBy: ".").last!
        return "\(me)[\(command.params.toHexString()): \(params.toHexString())]"
    }
}


class C0Response : Response {
    override var description: String {
        let me = String(describing: type(of: self)).components(separatedBy: ".").last!
        return "\(me)[\(params.toHexString())]"
    }
}

class C1Response : Response {
    var value : UInt8  {
        get {
            if let command = command as? C1Command {
                return command.value
            }
            return 0
        }
    }
    
    override var description: String {
        let me = String(describing: type(of: self)).components(separatedBy: ".").last!
        return "\(me)[\(params.toHexString())]"
    }
}
