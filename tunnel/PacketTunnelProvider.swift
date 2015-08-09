//
//  PacketTunnelProvider.swift
//  tunnel
//
//  Created by clowwindy on 7/18/15.
//  Copyright © 2015 clowwindy. All rights reserved.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    var session: NWUDPSession? = nil
    var conf = [String: AnyObject]()
    var pendingStartCompletion: (NSError? -> Void)?
    var userToken: NSData?
    
    override func startTunnelWithOptions(options: [String : NSObject]?, completionHandler: (NSError?) -> Void) {
        NSLog("test")
        if let serverAddress = self.protocolConfiguration.serverAddress {
            
            conf = (self.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration!
            if let port = conf["port"] as? String {
                NSLog("test2")
                session = self.createUDPSessionToEndpoint(NWHostEndpoint(hostname: serverAddress, port: port), fromEndpoint: nil)
                self.pendingStartCompletion = completionHandler
                NSLog("test3")
                if let userTokenString = conf["usertoken"] as? String {
                    if userTokenString.characters.count == 16 {
                        userToken = NSData.fromHexString(userTokenString)
                        NSLog("test4")
                    }
                }
                self.updateNetwork()
            }
        } else {
            completionHandler(NSError(domain:"PacketTunnelProviderDomain", code:-1, userInfo:[NSLocalizedDescriptionKey:"Configuration is missing serverAddress"]))
        }
    }
    
    func log(data: String) {
        self.session?.writeDatagram(data.dataUsingEncoding(NSUTF8StringEncoding)!, completionHandler: { (error: NSError?) -> Void in
        })
    }
    
    func updateNetwork() {
        NSLog("test5")
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: self.protocolConfiguration.serverAddress!)
        newSettings.IPv4Settings = NEIPv4Settings(addresses: [conf["ip"] as! String], subnetMasks: [conf["subnet"] as! String])
        newSettings.IPv4Settings!.includedRoutes = [NEIPv4Route.defaultRoute()]
        if conf["mtu"] != nil {
            newSettings.MTU = Int(conf["mtu"] as! String)
        } else {
            newSettings.MTU = 1432
        }
        newSettings.DNSSettings = NEDNSSettings(servers: [conf["dns"] as! String])
        NSLog("test6")
        SVCrypto.setPassword(conf["password"] as! String)
        NSLog("test7")
        self.setTunnelNetworkSettings(newSettings) { (error: NSError?) -> Void in
            NSLog("test8")
            self.readPacketsFromTUN()
            self.readPacketsFromUDP()
            NSLog("test9")
            if let completionHandler = self.pendingStartCompletion {
                // send an packet
                //        self.log("completion")
                NSLog("test10")
                NSLog("%@", String(error))
                completionHandler(error)
            }
        }
    }
    
    func readPacketsFromTUN() {
        self.packetFlow.readPacketsWithCompletionHandler {
            packets, protocols in
            //      self.log("readPacketsWithCompletionHandler")
            //      for p in protocols {
            //        self.log("protocol: " + p.stringValue)
            //      }
            for packet in packets {
                self.session?.writeDatagram(SVCrypto.encryptWithData(packet, userToken: self.userToken), completionHandler: { (error: NSError?) -> Void in
                })
            }
            self.readPacketsFromTUN()
        }
        
    }
    
    func readPacketsFromUDP() {
        session?.setReadHandler({ (newPackets: [NSData]?, error: NSError?) -> Void in
            //      self.log("readPacketsFromUDP")
            guard let packets = newPackets else { return }
            var protocols = [NSNumber]()
            var decryptedPackets = [NSData]()
            for packet in packets {
                // currently IPv4 only
                decryptedPackets.append(SVCrypto.decryptWithData(packet, userToken: self.userToken))
                protocols.append(2)
            }
            self.packetFlow.writePackets(decryptedPackets, withProtocols: protocols)
            }, maxDatagrams: 1024)
    }
    
    override func stopTunnelWithReason(reason: NEProviderStopReason, completionHandler: () -> Void) {
        // Add code here to start the process of stopping the tunnel
        //    self.log("stop tunnel")
        session?.cancel()
        completionHandler()
        super.stopTunnelWithReason(reason, completionHandler: completionHandler)
    }
    
    override func handleAppMessage(messageData: NSData, completionHandler: ((NSData?) -> Void)?) {
        // Add code here to handle the message
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleepWithCompletionHandler(completionHandler: () -> Void) {
        // Add code here to get ready to sleep
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up
    }
}
