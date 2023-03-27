//
//  EVPlayer.swift
//  EVPlayer
//
//  Created by Emirhan Saygiver on 14.05.2022.
//

import UIKit
import AVKit

public protocol EVPlayerDelegate: AnyObject {
    func evPlayer(stateDidChangedTo state: EVVideoState)
    func evPlayer(timeChangedTo currentTime: Double, totalTime: Double, loadedRange: Double)
    func evPlayer(fullScreenTransactionUpdateTo state: EVFullScreenState)
}

public class EVPlayer: UIView {
    
    // MARK: - UI
    
    let videoLayer = UIView()
    var thumbnailInterface: EVThumbnailViewInterface!
    var coverInterface: EVCoverViewInterface!
    var progressInterface: EVProgressViewInterface!
    var bufferingInterface: EVBufferingViewInterface!
    
    // Tap Gestures
    lazy var singleTapGR = UITapGestureRecognizer(target: self, action: #selector(makePlayerPropertiesVisible))
    lazy var doubleTapGR = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
    
    // MARK: - Logic
    
    public weak var delegate: EVPlayerDelegate?

    var configuration: EVConfiguration?

    // Player
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerLayer: AVPlayerLayer?
    
    // Observers
    var timeObserver: Any?
    var progressBarHighlightedObserver: NSKeyValueObservation?
    
    lazy var videoState: EVVideoState = .thumbnail {
        didSet {
            delegate?.evPlayer(stateDidChangedTo: videoState)
        }
    }
    
    // MARK: - Initializer
    
    public init(frame: CGRect,
                interfaceImpl: EVPlayerInterfaceImplementation = EVPlayerInterfaceApplier()) {
        super.init(frame: frame)
        apply(interfaceImpl)
        setupUI()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        prepareForReuse()
        EVDefaultLogger.logger.log("EVView", type: .deinited)
    }
    
    public override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        playerLayer?.frame = bounds
    }
    
    func prepareForReuse() {
        player?.pause()
        player = nil
        playerItem = nil
        playerLayer = nil
        progressBarHighlightedObserver?.invalidate()
        progressBarHighlightedObserver = nil
        NotificationCenter.default.removeObserver(self)
        videoLayer.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if let timeObserverToken = timeObserver {
            player?.removeTimeObserver(timeObserverToken)
            timeObserver = nil
        }
    }
    
    private func apply(_ interfaceImpl: EVPlayerInterfaceImplementation) {
        thumbnailInterface = interfaceImpl._thumbnail
        coverInterface = interfaceImpl._cover
        progressInterface = interfaceImpl._progress
        bufferingInterface = interfaceImpl._buffering
    }
}

// MARK: - Interfaces

// Implementation of EVUIProtocol
/// setup, update UI and, apply configuration
/// show & hide progress
/// forward & rewind button UI update

extension EVPlayer: EVUIProtocol { }

// Implementation of EVPlayerProtocol
/// setup playerItem, player and, playerLayer
/// seek to desired time

extension EVPlayer: EVPlayerProtocol { }

// Implementation of EVWorkerProtocol
/// load EVPlayer and create player with given url

extension EVPlayer: EVWorkerProtocol { }

// Implementation of EVObserverProtocol
/// add time & progressBar observers
/// subscribe itemDidEnd and, WillResignActive notifiacations from publishers

extension EVPlayer: EVObserverProtocol { }

// Implementation of EVStateProtocol
/// state updater
extension EVPlayer: EVStateProtocol { }

// Implementation of EVNavigationAdapter
/// Public state updater for parent
extension EVPlayer: EVNavigationAdapter { }

// MARK: - Delegates

// Subscribe to EVCoverViewDelegate

extension EVPlayer: EVCoverViewDelegate {
        
    func play() {
        updateState(to: .play)
    }
    
    func pause() {
        updateState(to: .pause)
    }
    
    func rewind(_ seconds: Double) {
        guard let player = player else { return }
        
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        var newTime = playerCurrentTime - seconds
        
        if newTime < 0 { newTime = 0 }
        
        let cachedState = videoState
        updateState(to: .pause)
        
        let lastTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
        seek(to: lastTime, continueFrom: cachedState)
                
        showOverlayAnimation(type: .rewind, seek: seconds)
    }
    
    func forward(_ seconds: Double) {
        guard let player = player,
              let duration = player.currentItem?.duration else { return }
        
        let playerCurrentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = playerCurrentTime + seconds

        if newTime < (CMTimeGetSeconds(duration) + seconds) {
            
            let cachedState = videoState
            updateState(to: .pause)
            
            let lastTime: CMTime = CMTimeMake(value: Int64(newTime * 1000 as Float64), timescale: 1000)
            seek(to: lastTime, continueFrom: cachedState)
            
            showOverlayAnimation(type: .forward, seek: seconds)
        }
    }
    
    func volume(_ val: Float) {
        player?.volume = val
    }
    
    func restart() {
        updateState(to: .restart)
    }
    
    func fullScreen() {
        guard let config = configuration else {
            return
        }
        
        delegate?.evPlayer(fullScreenTransactionUpdateTo: .willEnter)
        
        var fsConfig = config
        fsConfig.initialState = videoState
        fsConfig.seekTime = player?.currentTime()
        fsConfig.isMuted = player?.isMuted
        fsConfig.volume = player?.volume
        fsConfig.videoGravity = config.fullScreenModeVideoGravity
        
        /// To avoid audio clutter when fullscreen presentation
        player?.isMuted = true
        
        EVPlayerController.startFullScreenMode(withConfiguration: fsConfig, presentCallback: { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.updateState(to: .pause)
            strongSelf.delegate?.evPlayer(fullScreenTransactionUpdateTo: .didEnter)

        }, willDismissCallback: { [weak self] config in
            guard let strongSelf = self else { return }

            strongSelf.applyConfiguration(config)
            strongSelf.seek(to: config.seekTime, continueFrom: config.initialState)
            
            strongSelf.delegate?.evPlayer(fullScreenTransactionUpdateTo: .willDismiss)

        }, didDismissCallback: { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.evPlayer(fullScreenTransactionUpdateTo: .didDismiss)
        })
    }
    
    public func hideCover() {
        progressInterface.hideWithAnimation()
    }
}

// Subscribe to EVThumbnailViewDelegate

extension EVPlayer: EVThumbnailViewDelegate {
    
    func start() {
        updateState(to: .play)
    }
}
