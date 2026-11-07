import CoreGraphics

struct DisplayAccess {
    var excluded: [Display] = []

    func allows(frame: CGRect, space: UInt64) -> Bool {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return !excluded.contains {
            $0.frame.contains(center) || (space != 0 && $0.spaces.contains(space))
        }
    }
}
