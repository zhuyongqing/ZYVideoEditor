//
//  ZYVideoExporter.swift
//  OneSecond
//
//  Created by zhuyongqing on 2018/4/11.
//  Copyright © 2018年 zhuyongqing. All rights reserved.
//

import UIKit
import AVFoundation

enum ZYTransition:NSInteger {
    case Opacity,SwipeLeft,SwipeUp
}

//比例 根据项目可自定义
enum ZYVideoRatio:NSInteger {
    case Ratio9_16,Ratio16_9
}

class ZYVideoEditor: NSObject {
    
    var clips:[AVAsset]!
    var clipRanges:[CMTimeRange]!
    
    //默认过渡动画时间1秒 淡入
    var trasitionTime:CMTime = CMTimeMake(1, 1)
    var transitionType:ZYTransition = .Opacity
    
    var videoSize = CGSize.init(width: 1080, height: 1920)
    var videoRatio:ZYVideoRatio = .Ratio9_16
    
    
    var compostion:AVMutableComposition!
    var videoComposition:AVMutableVideoComposition!
    
    override init() {
        super.init()
    }
    
    func buildComposition() {
        
        if clips.count == 0 && clips == nil {
            compostion = nil
            videoComposition = nil
            return
        }
        
        let muComposition = AVMutableComposition()
        let muVideoComposition = AVMutableVideoComposition.init(propertiesOf: muComposition)
        
        buildTransitionCompositionAndRepairVideoSize(muComposition: muComposition, muVideoComposition: muVideoComposition)
        
        muVideoComposition.frameDuration = CMTimeMake(1, 30)
        muVideoComposition.renderSize = videoSize;
        
        compostion = muComposition
        videoComposition = muVideoComposition
    }
    
    func buildTransitionCompositionAndRepairVideoSize(muComposition:AVMutableComposition,muVideoComposition:AVMutableVideoComposition) {
        
        if videoRatio == .Ratio16_9{
            videoSize = CGSize.init(width: videoSize.height, height: videoSize.width)
        }
        muComposition.naturalSize = videoSize
        
        var comVideoTracks = [AVMutableCompositionTrack]()
        for _ in 0...1 {
            comVideoTracks.append(muComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        }
        
        var passThroughTimeRanges: [CMTimeRange] = [CMTimeRange]()
        var transitionTimeRanges: [CMTimeRange] = [CMTimeRange]()
        
        var startTime = kCMTimeZero
        for (index,asset) in clips.enumerated() {
            let oriVideoTrack = (asset.tracks(withMediaType: .video).first)
            if oriVideoTrack == nil{
                continue
            }
            let comVideoTrack = comVideoTracks[index % 2]
            let clipRange = clipRanges[index]
            try! comVideoTrack.insertTimeRange(clipRange, of: oriVideoTrack!, at: startTime)
            
            passThroughTimeRanges.append(CMTimeRangeMake(startTime, clipRange.duration))
            if index > 0 {
                passThroughTimeRanges[index].start = CMTimeAdd(passThroughTimeRanges[index].start, trasitionTime)
                passThroughTimeRanges[index].duration = CMTimeSubtract(passThroughTimeRanges[index].duration, trasitionTime);
            }
            
            if (index+1 < clips.count) {
                passThroughTimeRanges[index].duration = CMTimeSubtract(passThroughTimeRanges[index].duration, trasitionTime);
            }
            
            startTime = CMTimeAdd(startTime, clipRange.duration)
            startTime = CMTimeSubtract(startTime, trasitionTime)
            
            if index + 1 < clips.count{
                transitionTimeRanges.append(CMTimeRangeMake(startTime, trasitionTime))
            }
        }
        
        var instructions = [Any]()
        
        for (index,asset) in clips.enumerated() {
            let comVideoTrack = comVideoTracks[index % 2]

            let passThroughInstruction = AVMutableVideoCompositionInstruction()
            passThroughInstruction.timeRange = passThroughTimeRanges[index]
            let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: comVideoTrack)
            changeVideoSize(asset: asset,passThroughLayer: passThroughLayer)
            passThroughInstruction.layerInstructions = [passThroughLayer]
            instructions.append(passThroughInstruction)
            
            if index + 1 < clips.count{
                let transitionInstruction = AVMutableVideoCompositionInstruction()
                transitionInstruction.timeRange = transitionTimeRanges[index]
                let fromLayer =
                    AVMutableVideoCompositionLayerInstruction(assetTrack: comVideoTrack)
                let toLayer =
                    AVMutableVideoCompositionLayerInstruction(assetTrack:comVideoTracks[1 - index % 2])
              
                changeVideoSize(asset: asset,passThroughLayer: fromLayer)
                changeVideoSize(asset: clips[index + 1],passThroughLayer: toLayer)
                
                videoTransition(fromLayer: fromLayer,toLayer: toLayer,asset: asset, timeRange: transitionTimeRanges[index])
                
                transitionInstruction.layerInstructions = [fromLayer, toLayer]
                instructions.append(transitionInstruction)
            }
        }
        muVideoComposition.instructions = instructions as! [AVVideoCompositionInstructionProtocol]
    }
    
    func videoTransition(fromLayer:AVMutableVideoCompositionLayerInstruction,toLayer:AVMutableVideoCompositionLayerInstruction,asset:AVAsset,timeRange:CMTimeRange) {
        let oriVideoTrack = asset.tracks(withMediaType: .video).first
        let natureSize = (oriVideoTrack?.naturalSize)!
        switch transitionType {
        case .Opacity:
            fromLayer.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0, timeRange: timeRange)
            toLayer.setOpacityRamp(fromStartOpacity: 0.0, toEndOpacity: 1.0, timeRange: timeRange)
        case .SwipeLeft:
            fromLayer.setCropRectangleRamp(fromStartCropRectangle: CGRect.init(origin: .zero, size: videoSize), toEndCropRectangle: CGRect.init(origin: .zero, size: CGSize.init(width: 0, height: videoSize.height)), timeRange: timeRange)
        default:
            if degressFromVideo(asset: asset) == 90{
                fromLayer.setCropRectangleRamp(fromStartCropRectangle: CGRect.init(origin: .zero, size: videoSize), toEndCropRectangle: CGRect.init(origin: .zero, size: CGSize.init(width: 0, height: videoSize.height)), timeRange: timeRange)
            }else{
                let width = natureSize.width > videoSize.width ? natureSize.width : videoSize.width
                fromLayer.setCropRectangleRamp(fromStartCropRectangle: CGRect.init(origin: .zero, size:CGSize.init(width: width, height: videoSize.height)), toEndCropRectangle: CGRect.init(origin: .zero, size:  CGSize.init(width: width, height: 0)), timeRange: timeRange)
            }
            
        }
    }
    
    func exportVideo(outPath:String,completionHandle:@escaping ((String?,Error?) -> Void)) {
        let export = AVAssetExportSession.init(asset: compostion, presetName: AVAssetExportPresetHighestQuality)
        export?.videoComposition = videoComposition
        export?.outputFileType = AVFileType.mp4
        export?.outputURL = URL.init(fileURLWithPath: outPath)
        export?.exportAsynchronously(completionHandler: {
            let status = export?.status
            if status == .completed{
                completionHandle(outPath,nil)
            }else if status == .failed{
                completionHandle(nil,export?.error)
            }else if status == .cancelled{
                completionHandle(nil,NSError.init(domain: "cancelled", code: 3001, userInfo: nil))
            }else{
                completionHandle(nil,NSError.init(domain: "UnKnown Error", code: 3002, userInfo: nil))
            }
        })
    }
    
    func changeVideoSize(asset:AVAsset,passThroughLayer:AVMutableVideoCompositionLayerInstruction)  {
        
        let oriVideoTrack = asset.tracks(withMediaType: .video).first
        var natureSize = (oriVideoTrack?.naturalSize)!
        if degressFromVideo(asset: asset) == 90 {
            natureSize = CGSize.init(width: natureSize.height, height: natureSize.width)
        }
        
        //处理 livePhoto的视频
//        if natureSize.width == 1440 && natureSize.height == 1080 {
//            if videoRatio == .Ratio9_16{
//                natureSize.width = 1308
//            }else{
//                natureSize.height = 980
//            }
//        }
//
//        if natureSize.width == 1080 && natureSize.height == 1440 {
//            if videoRatio == .Ratio9_16 {
//                natureSize.width = 980
//            }else{
//                natureSize.height = 1308
//            }
//        }
        
        if (Int)(natureSize.width) % 2 != 0 {
            natureSize.width += 1.0
        }

        if videoRatio == .Ratio9_16{
            if degressFromVideo(asset: asset) == 90{
                let height = videoSize.width * natureSize.height / natureSize.width
                let translateToCenter = CGAffineTransform.init(translationX: videoSize.width, y: videoSize.height/2 - natureSize.height/2)
                
                let t = translateToCenter.scaledBy(x:videoSize.width/natureSize.width, y: height/natureSize.height)
                
                let mixedTransform = t.rotated(by: .pi/2)
                passThroughLayer.setTransform(mixedTransform, at: kCMTimeZero)
                
            }else{
                let height = videoSize.width * natureSize.height / natureSize.width
                let translateToCenter = CGAffineTransform.init(translationX: 0, y: videoSize.height/2 - height/2)
                let t = translateToCenter.scaledBy(x:videoSize.width/natureSize.width, y: height/natureSize.height)
                passThroughLayer.setTransform(t, at: kCMTimeZero)
            }
        }else{
            if degressFromVideo(asset: asset) == 90{
                let width = videoSize.height * natureSize.width/natureSize.height
                let translateToCenter = CGAffineTransform.init(translationX: videoSize.width/2 + width/2, y: 0)
                let t = translateToCenter.scaledBy(x:width/natureSize.width, y: videoSize.height/natureSize.height)
                
                let mixedTransform = t.rotated(by: .pi/2)
                passThroughLayer.setTransform(mixedTransform, at: kCMTimeZero)
                
            }else{
                let width = videoSize.height * natureSize.width/natureSize.height
                let translateToCenter = CGAffineTransform.init(translationX: videoSize.width/2 - width/2, y: 0)
                let t = translateToCenter.scaledBy(x:width/natureSize.width, y: videoSize.height/natureSize.height)
                passThroughLayer.setTransform(t, at: kCMTimeZero)
            }
        }
    }
    
    func degressFromVideo(asset:AVAsset) -> NSInteger {
        var degress = 0;
        let tracks = asset.tracks(withMediaType: .video)
        if(tracks.count > 0) {
            let videoTrack = tracks.first
            let t = (videoTrack?.preferredTransform)!;
            if(t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0){
                // Portrait
                degress = 90;
            }else if(t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0){
                // PortraitUpsideDown
                degress = 270;
            }else if(t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0){
                // LandscapeRight
                degress = 0;
            }else if(t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0){
                // LandscapeLeft
                degress = 180;
            }
        }
        
        return degress;
    }
    
}


