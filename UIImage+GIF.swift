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
