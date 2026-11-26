import Foundation

/// "4:07", or "1:02:09" past an hour.
func formatTime(_ seconds: Double) -> String {
    Duration.seconds(Int(seconds)).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
}
