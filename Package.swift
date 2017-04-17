import PackageDescription

let package = Package(
    name: "Fysfemman",
    dependencies: [
         .Package(url: "https://github.com/IBM-Swift/Kitura.git",                       majorVersion: 1),
         .Package(url: "https://github.com/IBM-Swift/Kitura-Session.git",               majorVersion: 1),
         .Package(url: "https://github.com/IBM-Swift/Kitura-CORS.git",                  majorVersion: 1),
         .Package(url: "https://github.com/IBM-Swift/Swift-Kuery-PostgreSQL",           majorVersion: 0),
         .Package(url: "https://github.com/IBM-Swift/Kitura-CredentialsHTTP.git",       majorVersion: 1),
         .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git",                 majorVersion: 1)
    ]
)
