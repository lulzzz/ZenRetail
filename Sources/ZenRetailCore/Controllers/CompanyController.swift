//
//  CompanyController.swift
//  Webretail
//
//  Created by Gerardo Grisolini on 11/04/17.
//
//

import Foundation
import ZenNIO
import ZenSMTP
import SwiftGD

class CompanyController {
	
    init(router: Router) {
        router.get("/api/company", handler: companyHandlerGET)
		router.post("/api/company", handler: companyHandlerPOST)
		router.post("/api/media", handler: uploadMediaHandlerPOST)
        router.post("/api/medias", handler: uploadMediasHandlerPOST)
        router.post("/api/email", handler: emailHandlerPOST)
        
//        router.get("/media/:filename", handler: {
//            request, response in
//            self.getFile(request, response, .big)
//        })
//        router.get("/thumb/:filename", handler: {
//            request, response in
//            self.getFile(request, response, .small)
//        })
//        router.get("/csv/:filename", handler: {
//            request, response in
//            self.getFile(request, response, .big)
//        })
	
        /*
        do {
            try FileStatic().create()
            
//            let files: [File] = try File().query()
            let files: [String] = try FileManager.default.contentsOfDirectory(atPath: "\(ZenNIO.htdocsPath)/media")
            for file in files {
                
//                // Create thumb
//                if file.fileContentType == "image/jpeg" && files.filter({ $0.fileName == file.fileName }).count == 1 {
//                    if let data = Data(base64Encoded: file.fileData, options: .ignoreUnknownCharacters),
//                        let thumb =  try Image(data: data).resizedTo(width: 380) {
//                        let small = File()
//                        small.fileName = file.fileName
//                        small.fileContentType = file.fileContentType
//                        small.setData(data: try thumb.export())
//                        try small.save()
//                    }
//                }
//
//                // Save to disk
//                let newFile = FileStatic()
//                newFile.fileType =  file.fileSize > 100000 || file.fileName == "logo.png" ? .media : .thumb
//                newFile.fileName = file.fileName
//                newFile.fileContentType = file.fileContentType
//                newFile.setData(data: Data(base64Encoded: file.fileData, options: .ignoreUnknownCharacters)!)
//                try newFile.save()
                
                // Save thumb to disk
                let data = FileManager.default.contents(atPath: "\(ZenNIO.htdocsPath)/media/\(file)")!
                let thumb =  try Image(data: data).resizedTo(width: 380)!
                let small = FileStatic()
                small.fileType = .thumb
                small.fileName = file
                small.fileContentType = file.fileExtension()
                small.setData(data: try thumb.export())
                try small.save()
            }
        } catch {
            print(error)
        }
        */
    }
    
	
    func companyHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let item = Company()
                try item.select()
                try response.send(json: item)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
	}
	
	func companyHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let item = try JSONDecoder().decode(Company.self, from: data)
                try item.save()
                try response.send(json:item)
                response.completed( .created)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
	}
    
//    fileprivate func getFile(_ request: HttpRequest, _ response: HttpResponse, _ size: MediaSize) {
//        let file = File()
//        if let filename: String = request.getParam("filename") {
//            if let data = try? file.getData(filename: filename, size: size) {
//                response.addHeader(.contentType, value: file.fileContentType)
//                response.send(data: data)
//                response.completed()
//                return
//            }
//        }
//
//        response.completed( .notFound)
//    }
 
    fileprivate func saveFiles(_ fileName: String, _ data: Data) throws -> Media {
        let media = Media()
        media.contentType = fileName.contentType
        media.name = fileName != "logo.png" && fileName != "header.png" ? fileName.uniqueName() : fileName
        
        let big = File()
        big.fileName = media.name
        big.fileContentType = media.contentType
        big.setData(data: data)
        try big.save()
        
        if let thumb = try Image(data: data).resizedTo(width: 380) {
            let url = URL(fileURLWithPath: "\(ZenNIO.htdocsPath)/thumb/\(media.name)")
            if !thumb.write(to: url, quality: 75, allowOverwrite: true) {
                throw HttpError.systemError(0, "file thumb not saved")
            }
            
//            let small = File()
//            small.fileName = media.name
//            small.fileType = .thumb
//            small.fileContentType = media.contentType
//            small.setData(data: try thumb.export())
//            try small.save()
        }

        return media
    }
    
//    fileprivate func saveFile(_ fileName: String, _ data: Data) throws -> Media {
//        let media = Media()
//        media.contentType = fileName.contentType
//        media.name = fileName.uniqueName()
//
//        let big = File()
//        big.fileName = media.name
//        big.fileContentType = media.contentType
//        big.setData(data: data)
//        try big.save()
//
//        return media
//    }

    func uploadMediaHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let fileName: String = request.getParam("file[]"),
                    let file: Data = request.getParam(fileName) else {
                    throw HttpError.badRequest
                }

                let media = try self.saveFiles(fileName, file)
                print("Uploaded file \(fileName) => \(media.name)")
                try response.send(json:media)
                response.completed( .created)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func uploadMediasHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let fileNames: String = request.getParam("file[]") else {
                    throw HttpError.badRequest
                }

                var medias = [Media]()
                for fileName in fileNames.split(separator: ",") {
                    if let data: Data = request.getParam(fileName.description) {
                        let media = try self.saveFiles(fileName.description, data)
                        medias.append(media)
                        print("Uploaded file \(fileName) => \(media.name)")
                    }
                }
                try response.send(json:medias)
                response.completed( .created)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func emailHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let item = try JSONDecoder().decode(PdfDocument.self, from: data)
                if item.address.isEmpty {
                    throw HttpError.systemError(0, "email address to is empty")
                }
                
                let company = Company()
                try company.select()
                if company.companyEmailInfo.isEmpty {
                    throw HttpError.systemError(0, "email address from is empty")
                }
                
                let email = Email(
                    fromName: company.companyName,
                    fromEmail: company.companyEmailSupport,
                    toName: nil,
                    toEmail: item.address,
                    subject: item.subject,
                    body: item.content,
                    attachments: []
                )
                
                ZenSMTP.shared.send(email: email) { error in
                    if let error = error {
                        print(error)
                        response.completed(.internalServerError)
                    } else {
                        response.completed(.noContent)
                    }
                }
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
}
