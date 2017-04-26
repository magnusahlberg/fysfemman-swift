import Foundation
import Cryptor
import LoggerAPI

let CODE_LIFETIME_MINUTES = 15

struct Code {
    let code: String
    let generated: Date
    let userId: String
    let mobile: String

    init(userId newUserId: String, mobile newMobile: String) {
        code = Code.generateRandomCode()
        generated = Date()
        userId = newUserId
        mobile = newMobile
    }

    public static func generateRandomCode() -> String {
        let bytesCount = 4
        var randomNum: UInt32 = 0
        let randomBytes: [UInt8]

        do {
            randomBytes = try Random.generate(byteCount: bytesCount)
            NSData(bytes: randomBytes, length: bytesCount).getBytes(&randomNum, length: bytesCount)

            let code = String(format: "%04d", Int(floor(Double(randomNum) / Double(UInt32.max) * 9999.0)))

            return code
        } catch {
            Log.error("Error generating random bytes")
            return "0000"
        }
    }
}

class LoginCodes {
    private let accountSid = ""
    private let authToken = ""
    private let fromNumber = ""
    private var codes: [Code]
    private var timer: Timer?

    deinit {
        if timer != nil {
            timer!.invalidate()
        }
    }

    init() {
        codes = []
    }

    public func generateAndAdd(forUser userId: String, withMobile mobile: String) -> String {
        let code = Code(userId: userId, mobile: mobile)
        codes.append(code)
        sendCode(code.code, to: mobile)
        return code.code
    }

    public func verify(code: String, withMobile mobile: String) -> String? {
        let verifyCode = codes.filter { $0.mobile == mobile }.first
        guard let code = verifyCode else {
            return nil
        }
        self.codes = codes.filter { $0.code != code.code }
        return code.userId
    }

    public func setupCodeInvalidationTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { _ in
            let now = Date()
            guard let expireTime = Calendar.current.date(byAdding: .minute, value: -CODE_LIFETIME_MINUTES, to: now) else {
                return
            }

            self.codes = self.codes.filter { code in
                return code.generated > expireTime
            }
        }
    }

    private func sendCode(_ code: String, to mobile: String) {
        let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(accountSid)/Messages.json")!
        let authStringEncoded = "\(accountSid):\(authToken)".data(using: .utf8)!.base64EncodedString()

        var request: URLRequest = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "To=%2B\(mobile)&From=\(fromNumber)&Body=Your+login+code+is%3A+\(code)".data(using: .utf8)
        request.setValue("Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in

            if data != nil {

                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! NSDictionary
                    Log.info(json.debugDescription)
                } catch let error as NSError {
                    Log.info(error.debugDescription)
                }
            } else {
                Log.error("No data received")
            }
        })
        task.resume()
    }
}
