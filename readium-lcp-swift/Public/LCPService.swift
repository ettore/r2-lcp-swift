//
//  LCPService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared


/// Service used to fulfill and access protected publications.
/// If an LCPAuthenticating instance is not given when expected, the request is cancelled if no passphrase is found in the local database. This can be the desired behavior when trying to import a license in the background, without prompting the user for its passphrase.
public protocol LCPService {

    /// Imports a protected publication from a standalone LCPL file.
    /// - Returns: The download progress value as an `Observable`, from 0.0 to 1.0.
    @discardableResult
    func importPublication(from lcpl: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPImportedPublication?, LCPError?) -> Void) -> Observable<DownloadProgress>
    
    /// Opens the LCP license of a protected publication, to access its DRM metadata and decipher its content.
    func retrieveLicense(from publication: URL, authentication: LCPAuthenticating?, completion: @escaping (LCPLicense?, LCPError?) -> Void) -> Void
    
}


/// Consumable LCP rights, limited by a certain quantity.
public enum LCPRight: String {
    case print
    case copy
}


/// Informations about a downloaded publication.
public struct LCPImportedPublication {
    /// Path to the downloaded publication.
    /// You must move this file to the user library's folder.
    public let localURL: URL
    
    /// Download task used to fetch the publication.
    /// Note: this is for legacy purpose, when using R2Shared.DownloadSession.
    public let downloadTask: URLSessionDownloadTask?
    
    /// Filename that should be used for the publication when importing it in the user library.
    public let suggestedFilename: String
}


/// Opened license, used to decipher a protected publication or read its DRM metadata.
public protocol LCPLicense: DRMLicense {
    
    var license: LicenseDocument { get }
    var status: StatusDocument? { get }
    
    /// Returns the amount of quantity left for the given right.
    /// If nil, it means that the right is unlimited.
    func remainingQuantity(for right: LCPRight) -> Int?
    
    /// Consumes the given quantity for this right.
    /// - Returns: false if the right quantity was exceeded, in which case you should interrupt the action.
    func consume(_ right: LCPRight, quantity: Int) -> Bool
    
}


/// Protocol to implement in the client app, to handle the presentation of LCP view controllers during an user interaction.
public protocol LCPInteractionDelegate: AnyObject {
    
    /// Presents the given URL in a web browser (eg. SFSafariViewController).
    /// You must call the dismissed closure once the browser is dismissed, to continue the interaction.
    func presentLCPInteraction(at url: URL, dismissed: @escaping () -> Void)
    
}


/// LCP service factory.
public func R2MakeLCPService(interactionDelegate: LCPInteractionDelegate) -> LCPService {
    // Composition root
    let db = Database.shared
    let network = NetworkService()
    let device = DeviceService(repository: db.licenses, network: network)
    let crl = CRLService(network: network)
    let passphrases = PassphrasesService(repository: db.transactions)
    let licenses = LicensesService(licenses: db.licenses, crl: crl, device: device, network: network, passphrases: passphrases, interactionDelegate: interactionDelegate)
    
    return licenses
}