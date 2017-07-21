//
//  ViewController.swift
//  LTCamera
//
//  Created by 高刘通 on 17/7/19.
//  Copyright © 2017年 LT. All rights reserved.
//

import UIKit
import GPUImage
import AVKit


let kWidth: CGFloat = UIScreen.main.bounds.size.width
let kHeight: CGFloat = UIScreen.main.bounds.size.height
public func RGBA (r:CGFloat, g:CGFloat, b:CGFloat, a:CGFloat) -> UIColor {
    return UIColor (red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
}

class ViewController: UIViewController {

    fileprivate lazy var camera: GPUImageStillCamera? = GPUImageStillCamera(sessionPreset: AVCaptureSessionPresetHigh, cameraPosition: .front)
    
    fileprivate lazy var preView: GPUImageView  = {
        let preView = GPUImageView(frame: self.view.bounds)
        return preView
    }()
    
    fileprivate lazy var filterView: LTFilterView  = {
        let filterView = LTFilterView(frame: self.view.bounds)
        return filterView
    }()
    
    let bilateralFilter = GPUImageBilateralFilter() // 磨皮
    let exposureFilter = GPUImageExposureFilter() // 曝光
    let brightnessFilter = GPUImageBrightnessFilter() // 美白
    let saturationFilter = GPUImageSaturationFilter() // 饱和
    
    fileprivate var player: AVPlayer?
    fileprivate var isEndRecording = false
    
    // 创建写入对象
    fileprivate lazy var movieWriter : GPUImageMovieWriter = { [weak self] in
        if FileManager.default.fileExists(atPath: (self?.pathString)!) {
            try? FileManager.default.removeItem(atPath: (self?.pathString)!)
        }
        let movieWriter = GPUImageMovieWriter(movieURL: self?.fileURL, size: (self?.view.bounds.size)!)
        movieWriter?.encodingLiveVideo = true
        return movieWriter!
    }()
    
    // 视频存放路径Url
    var fileURL : URL {
        return URL(fileURLWithPath: pathString)
    }
    
    //视频存放路径
    var pathString: String {
         return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/test.mp4"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        layoutViews()
        conifgCamera()
        configSliderChange()
    }
    
}



extension ViewController {
    
    fileprivate func conifgCamera() {
        //创建预览的View
        view.insertSubview(preView, at: 0)
        //设置camera方向
        camera?.outputImageOrientation = .portrait
        camera?.horizontallyMirrorFrontFacingCamera = true
        //获取滤镜组
        let filterGroup = getGroupFilters()
        //设置默认值
        bilateralFilter.distanceNormalizationFactor = 5.5
        exposureFilter.exposure = 0
        brightnessFilter.brightness = 0
        saturationFilter.saturation = 1.0
        //设置GPUImage的响应链
        camera?.addTarget(filterGroup)
        filterGroup.addTarget(preView)
        //开始采集视频
        camera?.startCapture()
        // 将writer设置成滤镜的target
        filterGroup.addTarget(movieWriter)
        camera?.delegate = self
        camera?.audioEncodingTarget = movieWriter
        movieWriter.startRecording()
    }
    
    fileprivate func getGroupFilters() -> GPUImageFilterGroup {
        //创建滤镜组
        let filterGroup = GPUImageFilterGroup()
        //创建滤镜(设置滤镜的引来关系)
        bilateralFilter.addTarget(brightnessFilter)
        brightnessFilter.addTarget(exposureFilter)
        exposureFilter.addTarget(saturationFilter)
        //设置滤镜起点 终点的filter
        filterGroup.initialFilters = [bilateralFilter]
        filterGroup.terminalFilter = saturationFilter
        return filterGroup
    }
}

extension ViewController : GPUImageVideoCameraDelegate {
    func willOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer!) {
//        print("采集到的数据\(sampleBuffer)")
    }
}


extension ViewController {

    //翻转
    @objc fileprivate func pickUpCameraSelected() {
        camera?.rotateCamera()
    }
    
    //滤镜
    @objc fileprivate func filterCameraSelected() {
        filterView.show()
    }
    
    //结束录制
    @objc fileprivate func endRecordSelected() {
        isEndRecording = true
        preView.removeFromSuperview()
        movieWriter.finishRecording()
        let filterGroup = getGroupFilters()
        filterGroup.removeTarget(movieWriter)
        camera?.stopCapture()
    }
    
    //播放
    @objc fileprivate func playRecordSelected() {
        print(fileURL)
        if !FileManager.default.fileExists(atPath: pathString) {
            showAlert("播放路径不存在")
            return
        }
        let playerItem = AVPlayerItem(url: fileURL)
        player = AVPlayer(playerItem: playerItem)
        let layer = AVPlayerLayer(player: player)
        layer.frame = CGRect(x: (kWidth - 220)/2.0, y: 210, width: 220, height: 220)
        view.layer.addSublayer(layer)
        player?.play()
    }
    
    //拍照
    @objc fileprivate func takePhotoSelected() {
        guard let camera = camera else {
            fatalError("请退出程序重新录制！")
        }
        camera.capturePhotoAsImageProcessedUp(toFilter: getGroupFilters(), withCompletionHandler: {[weak self] (image, error) in
            if error == nil {
                UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                self?.showAlert("图片保存成功，请退出程序重新录制！")
            }else{
                self?.showAlert("图片保存失败，请退出程序重新录制！")
            }
            self?.endRecordSelected()
        })
    }
    
    //清除缓存
    @objc fileprivate func clearCacheSelected() {
        if isEndRecording == false {
            showAlert("正在录制视频, 录制完成后进行清除")
            return
        }
        
        if FileManager.default.fileExists(atPath: pathString) {
            do {
                try FileManager.default.removeItem(atPath: pathString)
                showAlert("清除成功")
            } catch {
                showAlert("清除失败")
            }
        }else{
            showAlert("缓存已清除")
        }
    }
    
}

//MARK: 根据滑动改变美颜效果
extension ViewController {
    
    fileprivate func configSliderChange() {
        
        filterView.sliderDidValueChanged = {[weak self] (_, slider, type) in
            print(slider.value)
            switch type {
                
            case .bilateralFilter:
                self?.bilateralFilter.distanceNormalizationFactor = 10.0 - CGFloat(slider.value)
                break
                
            case .exposureFilter:
                self?.exposureFilter.exposure = CGFloat(slider.value) * 20.0 - 10.0
                break
                
            case .brightnessFilter:
                self?.brightnessFilter.brightness = CGFloat(slider.value) * 2.0 - 1.0
                break
                
            case .saturationFilter:
                self?.saturationFilter.saturation = CGFloat(slider.value) * 2.0
                break
        
            }
        }
        
    }
}


//MARK:  ---  布局  ---
extension ViewController {
    
    fileprivate func layoutViews() {
        
        let pickUpCamera = circleButton(frame: CGRect(x: kWidth - 70, y: 64, width: 55, height: 55), title: "翻转", action: #selector(pickUpCameraSelected), view: view)
        
        circleButton(frame: CGRect(x: pickUpCamera.frame.origin.x - 15 - 55, y: 64, width: 55, height: 55), title: "滤镜", action: #selector(filterCameraSelected), view: view)
        
        circleButton(frame: CGRect(x: kWidth - 70, y: 134, width: 55, height: 55), title: "拍照", action: #selector(takePhotoSelected), view: view)
        
        rectangleButton(frame: CGRect(x: 15, y: 65, width: 70, height: 30), title: "结束录制", action: #selector(endRecordSelected), view: view)
        
        rectangleButton(frame: CGRect(x: 15, y: 110, width: 70, height: 30), title: "播放", action: #selector(playRecordSelected), view: view)
        
        rectangleButton(frame: CGRect(x: 15, y: 155, width: 70, height: 30), title: "清除缓存", action: #selector(clearCacheSelected), view: view)

        view.addSubview(filterView)
        
    }
 
}

typealias sliderValueChangedClosure = (LTFilterView, UISlider, sliderFilterType) -> Void

enum sliderFilterType: Int {
    case bilateralFilter = 0
    case exposureFilter
    case brightnessFilter
    case saturationFilter
}

class LTFilterView: UIView {
    
    fileprivate let bgHeight: CGFloat = 250.0
    fileprivate lazy var sliders: [UISlider] = [UISlider]()
    var sliderDidValueChanged: sliderValueChangedClosure?
    var filterType: sliderFilterType = .bilateralFilter
    
    fileprivate lazy var bgView: UIView = {
        let bgView = UIView(frame: CGRect(x: 0, y: kHeight, width: kWidth, height: self.bgHeight))
        bgView.backgroundColor = RGBA(r: 0, g: 0, b: 0, a: 0.35)
        return bgView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configFilterView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension LTFilterView {
    
    fileprivate func configFilterView() {
        self.isHidden = true
        addSubview(bgView)
        configBgViewSubViews()
        configSlider()
    }
    
    private func configBgViewSubViews() {
        let titles = ["磨皮", "曝光", "美白", "饱和"]
        var labelY: CGFloat = 0.0
        let labelH: CGFloat = 40
        for index in 0..<titles.count {
            labelY = bgHeight - labelH * CGFloat(index + 1) - 10
            let label = leftLabel(frame: CGRect(x: 0, y: labelY, width: 80, height: 40), text: titles[titles.count - index - 1], view: bgView)
            
            let slider = sliderBase(frame: CGRect(x: label.frame.origin.x + label.frame.width, y: labelY, width: kWidth - label.frame.width - 10, height: 40), action: #selector(sliderValueChanged(_:)), view: bgView)
            slider.tag = titles.count - index - 1
            sliders.insert(slider, at: 0)
        }
    }
    
    private func configSlider() {
        for (index, slider) in sliders.enumerated(){
            if let type = sliderFilterType(rawValue: index){
                switch type{
                    case .bilateralFilter:
                        slider.minimumValue = 1.0
                        slider.maximumValue = 10.0
                        slider.value = 5.5
                        break
                        
                    case .brightnessFilter, .exposureFilter, .saturationFilter:
                        slider.value = 0.5
                        break
                }
            }else{
                print("error enum")
                continue
            }
        }
    }
    
    func sliderValueChanged(_ slider: UISlider) {
        guard let sliderDidValueChanged = sliderDidValueChanged else {
            return
        }
        sliderDidValueChanged(self, slider, sliderFilterType(rawValue: slider.tag) ?? .bilateralFilter)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let currentView = touches.first?.location(in: bgView) else {
            return ;
        }
        if !self.point(inside: currentView, with: event)  {
            dismiss()
        }
    }
}

extension LTFilterView {
    
    func show() {
        self.isHidden = false
        UIView.animate(withDuration: 0.25, animations: {
            self.bgView.frame.origin.y = kHeight - self.bgHeight
        })
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.25, animations: {
            self.bgView.frame.origin.y = kHeight
        }) { (completed) in
            self.isHidden = true
        }
    }
}



//MARK:  -- Base --
extension UIResponder {
    
    @discardableResult
    fileprivate func circleButton(frame: CGRect, title: String?, action: Selector, view: UIView) -> UIButton {
        let button = baseButton(frame: frame, view: view)
        button.layer.cornerRadius = button.frame.height / 2.0
        button.clipsToBounds = true
        button.layer.masksToBounds = true
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        return button
    }
    
    @discardableResult
    fileprivate func rectangleButton(frame: CGRect, title: String?, action: Selector, view: UIView) -> UIButton {
        let button = baseButton(frame: frame, view: view)
        button.layer.cornerRadius = 3.0
        button.clipsToBounds = true
        button.layer.masksToBounds = true
        button.setTitleColor(UIColor.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.backgroundColor = RGBA(r: 39, g: 161, b: 98, a: 0.8)
        return button
    }
    
    private func baseButton(frame: CGRect, view: UIView) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = frame
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        view.addSubview(button)
        return button
    }
    
    fileprivate func leftLabel(frame: CGRect, text: String?, view: UIView) -> UILabel {
        let label = UILabel(frame: frame)
        label.textAlignment = .center
        label.text = text
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 15)
        view.addSubview(label)
        return label
    }
    
    fileprivate func sliderBase(frame: CGRect, action: Selector, view: UIView) -> UISlider {
        let slider = UISlider(frame: frame)
        slider.tintColor = RGBA(r: 231, g: 85, b: 87, a: 0.8)
        slider.addTarget(self, action: action, for: .valueChanged)
        view.addSubview(slider)
        return slider
    }
    
    fileprivate func showAlert(_ title: String?) {
        UIAlertView(title: nil, message: title, delegate: nil, cancelButtonTitle: "取消").show()
    }
}

