//
//  ViewController.swift
//  ZYVideoEditor
//
//  Created by zhuyongqing on 2018/4/11.
//  Copyright © 2018年 zhuyongqing. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    var player:AVPlayer!
    var playerLayer:AVPlayerLayer!
    let editor = ZYVideoEditor()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        initAssets()
    }
    
    func initAssets() {
        var assets = [AVAsset]()
        var timeRanges = [CMTimeRange]()
        for index in 1...4 {
            let asset = AVAsset.init(url: URL.init(fileURLWithPath: Bundle.main.path(forResource: "test\(index)", ofType: "MP4")!))
            assets.append(asset)
            //截取视频前5秒
            timeRanges.append(CMTimeRangeMake(kCMTimeZero, CMTimeMake(5, 1)))
        }
        
        editor.clips = assets
        editor.clipRanges = timeRanges
        
        editor.buildComposition()
        
        let playItem = AVPlayerItem.init(asset: editor.compostion)
        playItem.videoComposition = editor.videoComposition
        
        player = AVPlayer.init(playerItem: playItem)
        playerLayer = AVPlayerLayer.init(player: player)
        playerLayer.frame = CGRect.init(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 100)
        playerLayer.position = view.center
        view.layer.addSublayer(playerLayer)
        
        player.play()
    }

    func resetPlayerItem() {
        let playItem = AVPlayerItem.init(asset: editor.compostion)
        playItem.videoComposition = editor.videoComposition
        
        player.replaceCurrentItem(with: playItem)
        
        player.seek(to: kCMTimeZero)
        player.play()
    }
    
    @IBAction func playAction(_ sender: Any) {
        player.seek(to: kCMTimeZero)
        player.play()
    }
    
    
    @IBAction func videoRatioChanged(_ sender: UISegmentedControl) {
        editor.videoRatio = ZYVideoRatio(rawValue: sender.selectedSegmentIndex)!
        editor.videoSize = CGSize.init(width: 1080, height: 1920)
        editor.buildComposition()
        resetPlayerItem()
    }
    
    @IBAction func videoTrasitionChanged(_ sender: UISegmentedControl) {
        editor.transitionType = ZYTransition(rawValue: sender.selectedSegmentIndex)!
        editor.buildComposition()
        resetPlayerItem()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

