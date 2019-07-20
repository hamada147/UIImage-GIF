extension UIImage {
    
    private static func delayCentisecondsForImageAtIndex(source: CGImageSource, i: Int) -> Int {
        var delayCentiseconds = 1
        let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as NSDictionary?
        if properties != nil {
            let gifProperties = properties![kCGImagePropertyGIFDictionary] as? NSDictionary
            if gifProperties != nil {
                var number: Double = gifProperties![kCGImagePropertyGIFUnclampedDelayTime] as! Double
                if number == 0 {
                    number = gifProperties![kCGImagePropertyGIFDelayTime] as! Double
                }
                if number > 0 {
                    delayCentiseconds = Int(lrint(number * 100))
                }
            }
        }
        return delayCentiseconds
    }
    
    private static func createImagesAndDelays(source: CGImageSource, count: Int) -> (imagesOut: [CGImage?], delayCentisecondsOut: [Int]) {
        var imagesOut: [CGImage?] = []
        var delayCentisecondsOut: [Int] = []
        for i in 0..<count {
            imagesOut.append(CGImageSourceCreateImageAtIndex(source, i, nil))
            delayCentisecondsOut.append(UIImage.delayCentisecondsForImageAtIndex(source: source, i: i))
        }
        return (imagesOut: imagesOut, delayCentisecondsOut: delayCentisecondsOut)
    }
    
    private static func frameArray(images: [CGImage?], delayCentiseconds: [Int], totalDurationCentiseconds: Int) -> [UIImage]? {
        
        func pairGCD(a: Int, b: Int) -> Int {
            var a = a
            var b = b
            if a < b {
                return pairGCD(a: b, b: a)
            }
            while true {
                let r: Int = a % b
                if r == 0 {
                    return b
                }
                a = b
                b = r
            }
        }
        
        func vectorGCD(values: [Int]) -> Int {
            var gcd = Int(values[0])
            for i in 1..<values.count {
                // Note that after I process the first few elements of the vector, `gcd` will probably be smaller than any remaining element.  By passing the smaller value as the second argument to `pairGCD`, I avoid making it swap the arguments.
                gcd = pairGCD(a: values[i], b: gcd)
            }
            return gcd
        }
        
        let gcd = vectorGCD(values: delayCentiseconds)
        let frameCount: Int = totalDurationCentiseconds / gcd
        var frames: [UIImage] = [UIImage](repeating: UIImage(), count: frameCount)
        var i = 0, f = 0
        while i < images.count {
            var frame: UIImage? = nil
            if let i = images[i] {
                frame = UIImage(cgImage: i)
            }
            var j = delayCentiseconds[i] / gcd
            while j > 0 {
                if let frame = frame {
                    frames[f] = frame
                    f += 1
                }
                j -= 1
            }
            i += 1
        }
        return frames
    }
    
    private static func animatedImageWithAnimatedGIFImageSource(_ source: CGImageSource) -> UIImage? {
        
        func sum(values: [Int]) -> Int {
            var theSum: Int = 0
            for i in 0..<values.count {
                theSum += values[i]
            }
            return theSum
        }
        
        let count = CGImageSourceGetCount(source)
        var images = [CGImage?](repeating: nil, count: count)
        var delayCentiseconds = [Int](repeating: 0, count: count) // in centiseconds
        let result = UIImage.createImagesAndDelays(source: source, count: count)
        images = result.imagesOut
        delayCentiseconds = result.delayCentisecondsOut
        let totalDurationCentiseconds = sum(values: delayCentiseconds)
        let frames = UIImage.frameArray(images: images, delayCentiseconds: delayCentiseconds, totalDurationCentiseconds: totalDurationCentiseconds)
        if frames != nil {
            var animation: UIImage? = nil
            animation = UIImage.animatedImage(with: frames!, duration: TimeInterval(totalDurationCentiseconds) / 100.0)
            return animation
        } else {
            return nil
        }
    }
    
    private static func animatedImageWithAnimatedGIFReleasingImageSource(source: CGImageSource?) -> UIImage? {
        if source != nil {
            let image: UIImage? = UIImage.animatedImageWithAnimatedGIFImageSource(source!)
            return image
        } else {
            return nil
        }
    }
    
    /// I interpret `theData` as a GIF.  I create an animated `UIImage` using the source images in the GIF. The GIF stores a separate duration for each frame, in units of centiseconds (hundredths of a second).  However, a `UIImage` only has a single, total `duration` property, which is a floating-point number. To handle this mismatch, I add each source image (from the GIF) to `animation` a varying number of times to match the ratios between the frame durations in the GIF. For example, suppose the GIF contains three frames.  Frame 0 has duration 3. Frame 1 has duration 9. Frame 2 has duration 15. I divide each duration by the greatest common denominator of all the durations, which is 3, and add each frame the resulting number of times. Thus `animation` will contain frame 0 3/3 = 1 time, then frame 1 9/3 = 3 times, then frame 2 15/3 = 5 times. I set `animation.duration` to (3+9+15)/100 = 0.27 seconds.
    public class func animatedImage(withAnimatedGIFData data: Data?) -> UIImage? {
        if data != nil {
            let nsData: NSData = data! as NSData
            let bytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
            let CFdata: CFData? = CFDataCreate(kCFAllocatorDefault, bytes, data!.count)
            let souce = CGImageSourceCreateWithData(CFdata!, nil)
            return UIImage.animatedImageWithAnimatedGIFReleasingImageSource(source: souce)
        } else {
            return nil
        }
    }
    
    /// I interpret the contents of `theURL` as a GIF. I create an animated `UIImage` using the source images in the GIF. I operate exactly like `animatedImage(withAnimatedGIFData data: Data?)`, except that I read the data from `theURL`.  If `theURL` is not a `file:` URL, you probably want to call me on a background thread or GCD queue to avoid blocking the main thread.
    public class func animatedImage(withAnimatedGIFURL url: URL?) -> UIImage? {
        if url != nil {
            let nsURL: NSURL = url! as NSURL
            let cfURL: CFURL = nsURL as CFURL
            let souce = CGImageSourceCreateWithURL(cfURL, nil)
            return UIImage.animatedImageWithAnimatedGIFReleasingImageSource(source: souce)
        } else {
            return nil
        }
    }
}
