//
//  EVPlayerImpl.swift
//  EVPlayer
//
//  Created by Emirhan Saygiver on 12.03.2023.
//

import AVKit

protocol EVPlayerSeekOrganizer {
    func seek(to time: CMTime?, continueFrom state: EVVideoState?)
}

protocol EVPlayerProtocol: EVPlayerSeekOrganizer {
    func setPlayerItem(with asset: AVAsset)
    func setPlayer()
    func setPlayerLayer()
}

extension EVPlayerProtocol where Self: EVPlayer {

    func setPlayerItem(with asset: AVAsset) {
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.preferredPeakBitRate = 0
        playerItem?.preferredForwardBufferDuration = 10
        playerItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
    }
    
    func setPlayer() {
        guard let playerItem = playerItem else {
            return
        }
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
    }
    
    func setPlayerLayer() {
        guard let player = player else {
            return
        }
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = configuration?.videoGravity ?? .resize
        videoLayer.layer.addSublayer(playerLayer!)
    }
    
    func seek(to time: CMTime?, continueFrom state: EVVideoState? = nil) {
        if let seekTime = time {
            player?.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: { [weak self] _ in
                guard let strongSelf = self else { return }
                
                strongSelf.updateUI(with: seekTime)
            })
        }
        
        if let state = state {
            updateState(to: state)
        }
    }
}
