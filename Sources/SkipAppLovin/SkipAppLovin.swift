// Licensed under the GNU General Public License v3.0 with Linking Exception
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception

#if !SKIP_BRIDGE
import SwiftUI
import OSLog

#if SKIP
import com.applovin.sdk.AppLovinSdk
import com.applovin.sdk.AppLovinSdkInitializationConfiguration
import androidx.compose.ui.platform.LocalContext
#else
import AppLovinSDK
#endif

public struct SkipAppLovin: @unchecked Sendable {
    public static let current = SkipAppLovin()
    #if SKIP
    let sdk: AppLovinSdk
    init() {
        sdk = AppLovinSdk.getInstance(ProcessInfo.processInfo.androidContext)
    }
    #else
    let sdk: ALSdk
    init() {
        sdk = ALSdk.shared()
    }
    #endif
    
    
    
    public func initialize(
        sdkKey: String,
        axonEventKey: String? = nil,
        mediationProvider: String? = nil,
        pluginVersion: String? = nil,
        segmentCollection: MASegmentCollection? = nil,
        testDeviceAdvertisingIdentifiers: [String]? = nil,
        adUnitIdentifiers: [String]? = nil,
        exceptionHandlerEnabled: Bool? = nil
    ) async -> ALSdkConfiguration {
        #if SKIP
        let builder = AppLovinSdkInitializationConfiguration.builder(sdkKey)
        guard axonEventKey == nil else {
            fatalError("axonEventKey not supported in SkipAppLovin")
        }
        if let mediationProvider {
            builder.setMediationProvider(mediationProvider)
        }
        if let pluginVersion {
            builder.setPluginVersion(pluginVersion)
        }
        if let segmentCollection {
            builder.setSegmentCollection(segmentCollection.maxSegmentCollection)
        }
        if let testDeviceAdvertisingIdentifiers {
            builder.setTestDeviceAdvertisingIds(testDeviceAdvertisingIdentifiers.toList())
        }
        if let adUnitIdentifiers {
            builder.setAdUnitIds(adUnitIdentifiers.toList())
        }
        if let exceptionHandlerEnabled {
            builder.setExceptionHandlerEnabled(exceptionHandlerEnabled)
        }
        let sdkConfig = await withCheckedContinuation { continuation in
            sdk.initialize(builder.build()) { sdkConfig in
                continuation.resume(returning: sdkConfig)
            }
        }
        return ALSdkConfiguration(sdkConfig)
        #else
        let initConfig: ALSdkInitializationConfiguration
        if let axonEventKey {
            initConfig = ALSdkInitializationConfiguration(sdkKey: sdkKey, axonEventKey: axonEventKey) { builder in
                if let mediationProvider {
                    builder.mediationProvider = mediationProvider
                }
                if let pluginVersion {
                    builder.pluginVersion = pluginVersion
                }
                if let segmentCollection {
                    builder.segmentCollection = segmentCollection
                }
                if let testDeviceAdvertisingIdentifiers {
                    builder.testDeviceAdvertisingIdentifiers = testDeviceAdvertisingIdentifiers
                }
                if let adUnitIdentifiers {
                    builder.adUnitIdentifiers = adUnitIdentifiers
                }
                if let exceptionHandlerEnabled {
                    builder.exceptionHandlerEnabled = exceptionHandlerEnabled
                }
            }
        } else {
            initConfig = ALSdkInitializationConfiguration(sdkKey: sdkKey) { builder in
                if let mediationProvider {
                    builder.mediationProvider = mediationProvider
                }
                if let pluginVersion {
                    builder.pluginVersion = pluginVersion
                }
                if let segmentCollection {
                    builder.segmentCollection = segmentCollection
                }
                if let testDeviceAdvertisingIdentifiers {
                    builder.testDeviceAdvertisingIdentifiers = testDeviceAdvertisingIdentifiers
                }
                if let adUnitIdentifiers {
                    builder.adUnitIdentifiers = adUnitIdentifiers
                }
                if let exceptionHandlerEnabled {
                    builder.exceptionHandlerEnabled = exceptionHandlerEnabled
                }
            }
        }
        let sdkConfig = await sdk.initialize(with: initConfig)
        return sdkConfig
        #endif
    }
    
    public func showMediationDebugger() {
        sdk.showMediationDebugger()
    }
    
    public func showCreativeDebugger() {
        sdk.showCreativeDebugger()
    }
    
    public var settings: ALSdkSettings {
        #if SKIP
        ALSdkSettings(AppLovinSdk.getInstance( UIApplication.shared.androidActivity ).getSettings())
        #else
        ALSdk.shared().settings
        #endif
    }
}

#endif
