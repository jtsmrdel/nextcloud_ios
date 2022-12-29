//
//  NCUploadScanDocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI
import NextcloudKit
import Vision
import VisionKit
import Photos
import PDFKit

class NCHostingUploadScanDocumentView: NSObject {

    @objc func makeShipDetailsUI(images: [UIImage], userBaseUrl: NCUserBaseUrl, serverUrl: String) -> UIViewController {

        let uploadScanDocument = NCUploadScanDocument(images: images, userBaseUrl: userBaseUrl, serverUrl: serverUrl)
        let details = UploadScanDocumentView(uploadScanDocument)
        let vc = UIHostingController(rootView: details)

        // vc.title = NSLocalizedString("_save_settings_", comment: "")
        return vc
    }
}

class NCUploadScanDocument: ObservableObject {

    @Published var userBaseUrl: NCUserBaseUrl
    @Published var serverUrl: String

    @Published var isTextRecognition: Bool = false
    @Published var size: String = ""
    @Published var url: URL = Bundle.main.url(forResource: "Reasons to use Nextcloud", withExtension: "pdf")!

    let fileNameDefault = NSTemporaryDirectory() + "scandocument.pdf"
    var images: [UIImage]

    init(images: [UIImage], userBaseUrl: NCUserBaseUrl, serverUrl: String) {
        self.images = images
        self.userBaseUrl = userBaseUrl
        self.serverUrl = serverUrl
        createPDF()
    }

    func createPDF(password: String = "", textRecognition: Bool = false, quality: Double = 1) {

        guard !images.isEmpty else { return }
        let pdfData = NSMutableData()

        if password.isEmpty {
            UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
        } else {
            for char in password.unicodeScalars {
                if !char.isASCII {
                    NCActivityIndicator.shared.stop()
                    let error = NKError(errorCode: NCGlobal.shared.errorForbidden, errorDescription: "_password_ascii_")
                    NCContentPresenter.shared.showError(error: error)
                    return
                }
            }
            let info: [AnyHashable: Any] = [kCGPDFContextUserPassword as String: password, kCGPDFContextOwnerPassword as String: password]
            UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, info)
        }

        for var image in images {

            image = changeCompressionImage(image, quality: quality)
            let bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            if textRecognition {

            } else {
                UIGraphicsBeginPDFPageWithInfo(bounds, nil)
                image.draw(in: bounds)
            }
        }

        UIGraphicsEndPDFContext()

        do {
            url = URL(fileURLWithPath: fileNameDefault)
            try pdfData.write(to: url, options: .atomic)
        } catch {
            print("error catched")
        }

        size = CCUtility.transformedSize(NCUtilityFileSystem.shared.getFileSize(filePath: fileNameDefault))
    }

    func changeCompressionImage(_ image: UIImage, quality: Double) -> UIImage {

        var compressionQuality: CGFloat = 0.5
        var baseHeight: Float = 595.2    // A4
        var baseWidth: Float = 841.8     // A4

        switch quality {
        case 0:
            baseHeight *= 1
            baseWidth *= 1
            compressionQuality = 0.3
        case 1:
            baseHeight *= 2
            baseWidth *= 2
            compressionQuality = 0.6
        case 2:
            baseHeight *= 4
            baseWidth *= 4
            compressionQuality = 0.8
        case 3:
            baseHeight *= 6
            baseWidth *= 6
            compressionQuality = 0.9
        case 4:
            baseHeight *= 8
            baseWidth *= 8
            compressionQuality = 1
        default:
            break
        }

        var newHeight = Float(image.size.height)
        var newWidth = Float(image.size.width)
        var imgRatio: Float = newWidth / newHeight
        let baseRatio: Float = baseWidth / baseHeight

        if newHeight > baseHeight || newWidth > baseWidth {
            if imgRatio < baseRatio {
                imgRatio = baseHeight / newHeight
                newWidth = imgRatio * newWidth
                newHeight = baseHeight
            } else if imgRatio > baseRatio {
                imgRatio = baseWidth / newWidth
                newHeight = imgRatio * newHeight
                newWidth = baseWidth
            } else {
                newHeight = baseHeight
                newWidth = baseWidth
            }
        }

        let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(newWidth), height: CGFloat(newHeight))
        UIGraphicsBeginImageContext(rect.size)
        image.draw(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        let imageData = img?.jpegData(compressionQuality: CGFloat(compressionQuality))
        UIGraphicsEndImageContext()
        return UIImage(data: imageData!) ?? image
    }
}

extension NCUploadScanDocument: NCSelectDelegate {

    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool) {

        if let serverUrl = serverUrl {

            CCUtility.setDirectoryScanDocuments(serverUrl)
            self.serverUrl = serverUrl

            /*
            if serverUrl == NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) {
                self.titleServerUrl = "/"
            } else {
                self.titleServerUrl = (serverUrl! as NSString).lastPathComponent
            }

            // Update
            let row: XLFormRowDescriptor  = self.form.formRow(withTag: "ButtonDestinationFolder")!
            row.title = self.titleServerUrl
            self.updateFormRow(row)
            */
        }
    }
}

extension NCUploadScanDocument: NCCreateFormUploadConflictDelegate {

    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
    }
}

// MARK: - Preview / Test

struct UploadScanDocumentView: View {

    @State var quality = 2.0
    @State var password: String = ""
    @State var filename: String = ""
    @State var isSecured: Bool = true
    @ObservedObject var uploadScanDocument: NCUploadScanDocument

    init(_ uploadScanDocument: NCUploadScanDocument) {
        self.uploadScanDocument = uploadScanDocument
    }

    var body: some View {

        GeometryReader { geo in
            List {
                Section(header: Text(NSLocalizedString("_file_creation_", comment: ""))) {

                    HStack {
                        Label {
                            if NCUtilityFileSystem.shared.getHomeServer(urlBase: uploadScanDocument.userBaseUrl.urlBase, userId: uploadScanDocument.userBaseUrl.userId) == uploadScanDocument.serverUrl {
                                Text("/")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text((uploadScanDocument.serverUrl as NSString).lastPathComponent)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                        } icon: {
                            Image("folder")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(Color(NCBrandColor.shared.brand))
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        //
                    }
                    .complexModifier { view in
                        if #available(iOS 16, *) {
                            view.alignmentGuide(.listRowSeparatorLeading) { _ in
                                return 0
                            }
                        }
                    }
                    HStack {
                        Text(NSLocalizedString("_filename_", comment: ""))
                        TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $filename)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Group {
                            Text(NSLocalizedString("_password_", comment: ""))
                            if isSecured {
                                SecureField(NSLocalizedString("_enter_password_", comment: ""), text: $password)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                TextField(NSLocalizedString("_enter_password_", comment: ""), text: $password)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        Button(action: {
                            isSecured.toggle()
                        }) {
                            Image(systemName: self.isSecured ? "eye.slash" : "eye")
                                .accentColor(.gray)
                        }
                    }

                    HStack {
                        Toggle(NSLocalizedString("_text_recognition_", comment: ""), isOn: $uploadScanDocument.isTextRecognition)
                            .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.brand)))
                            .onChange(of: uploadScanDocument.isTextRecognition) { newValue in

                            }
                    }
                }

                Section(header: Text(NSLocalizedString("_quality_image_title_", comment: "")), footer: Text( NSLocalizedString("_file_size_", comment: "") + " \(uploadScanDocument.size)")) {
                    VStack {
                        Slider(value: $quality, in: 0...4, step: 1).onChange(of: quality, perform: { quality in
                            uploadScanDocument.createPDF(quality: quality)
                        })
                        .accentColor(Color(NCBrandColor.shared.brand))
                    }
                    PDFKitRepresentedView(uploadScanDocument.url)
                        .frame(maxWidth: .infinity, minHeight: geo.size.height / 2.7)
                }.complexModifier { view in
                    if #available(iOS 15, *) {
                        view.listRowSeparator(.hidden)
                    }
                }

                Button(NSLocalizedString("_save_", comment: "")) {
                    print("ciao")
                }
                .buttonStyle(NCButton(disabled: true))
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct NCButton: ButtonStyle {
    var disabled = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .background(disabled ? Color(UIColor.systemGray4) : Color(NCBrandColor.shared.brand))
            .foregroundColor(.white)
            .clipShape(Capsule())

    }
}

struct PDFKitRepresentedView: UIViewRepresentable {

    let url: URL

    init(_ url: URL) {
        self.url = url
    }

    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFKitRepresentedView.UIViewType {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
    }
}

struct UploadScanDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            let uploadScanDocument = NCUploadScanDocument(images: [], userBaseUrl: appDelegate, serverUrl: "")
            UploadScanDocumentView(uploadScanDocument)
            // .previewDevice(PreviewDevice(rawValue: "iPhone 14 Pro"))
            // .previewDisplayName("iPhone 14")
        }
    }
}
