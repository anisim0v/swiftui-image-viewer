import SwiftUI
import UIKit
import URLImage
import Combine

@available(iOS 13.0, *)
public struct ImageViewerRemote: View {
    @Binding var viewerShown: Bool
    @Binding var imageURL: String
    @State var httpHeaders: [String: String]?
    @State var disableCache: Bool?
    
    var aspectRatio: Binding<CGFloat>?
    
    @State var dragOffset: CGSize = CGSize.zero
    @State var dragOffsetPredicted: CGSize = CGSize.zero
    
    @ObservedObject var loader: ImageLoader
    
    public init(imageURL: Binding<String>, viewerShown: Binding<Bool>, httpHeaders: [String: String]? = nil, aspectRatio: Binding<CGFloat>? = nil, disableCache: Bool? = nil) {
        _imageURL = imageURL
        _viewerShown = viewerShown
        _httpHeaders = State(initialValue: httpHeaders)
        _disableCache = State(initialValue: disableCache)
        self.aspectRatio = aspectRatio
        self._viewerShown = viewerShown
        loader = ImageLoader(url: imageURL, httpHeaders: httpHeaders)
        
        
    }
    
    func getURLRequest(url: String, headers: [String: String]?) -> URLRequest {
        let url = URL(string: url)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if(headers != nil) {
            for (key, value) in headers! {
                print("adding header: \(key): \(value)")
                request.addValue("\(value)", forHTTPHeaderField: "\(key)")
            }
            
            print("headers found, requesting URL image with headers: \(request.allHTTPHeaderFields)")
            return request;
        }
        else {
            print("headers nil, requesting URL image with request: \(request)")
            return request;
        }
    }

    @ViewBuilder
    public var body: some View {
        VStack {
            if(viewerShown && imageURL.count > 0) {
                ZStack {
                    VStack {
                        HStack {
                            Button(action: { self.viewerShown = false }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(Color(UIColor.white))
                                    .font(.system(size: UIFontMetrics.default.scaledValue(for: 24)))
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .zIndex(2)
                    
                    VStack {
                        if(self.disableCache == nil || self.disableCache == false) {
                            if self.viewerShown == true {
                            URLImage(getURLRequest(url: self.imageURL, headers: self.httpHeaders)) { proxy in
                            proxy.image
                                .resizable()
                                .aspectRatio(self.aspectRatio?.wrappedValue, contentMode: .fit)
                                .offset(x: self.dragOffset.width, y: self.dragOffset.height)
                                .rotationEffect(.init(degrees: Double(self.dragOffset.width / 30)))
                                .pinchToZoom()
                                .gesture(DragGesture()
                                    .onChanged { value in
                                        self.dragOffset = value.translation
                                        self.dragOffsetPredicted = value.predictedEndTranslation
                                    }
                                    .onEnded { value in
                                        if((abs(self.dragOffset.height) + abs(self.dragOffset.width) > 570) || ((abs(self.dragOffsetPredicted.height)) / (abs(self.dragOffset.height)) > 3) || ((abs(self.dragOffsetPredicted.width)) / (abs(self.dragOffset.width))) > 3) {
                                            self.viewerShown = false
                                            return
                                        }
                                        self.dragOffset = .zero
                                    }
                                )
                            }
                        }
                        }
                        else {
                            if loader.image != nil {
                                Image(uiImage: loader.image!)
                                    .resizable()
                                    .aspectRatio(self.aspectRatio?.wrappedValue, contentMode: .fit)
                                    .offset(x: self.dragOffset.width, y: self.dragOffset.height)
                                    .rotationEffect(.init(degrees: Double(self.dragOffset.width / 30)))
                                    .pinchToZoom()
                                    .gesture(DragGesture()
                                        .onChanged { value in
                                            self.dragOffset = value.translation
                                            self.dragOffsetPredicted = value.predictedEndTranslation
                                        }
                                        .onEnded { value in
                                            if((abs(self.dragOffset.height) + abs(self.dragOffset.width) > 570) || ((abs(self.dragOffsetPredicted.height)) / (abs(self.dragOffset.height)) > 3) || ((abs(self.dragOffsetPredicted.width)) / (abs(self.dragOffset.width))) > 3) {
                                                self.viewerShown = false
                                                return
                                            }
                                            self.dragOffset = .zero
                                        }
                                    )
                            }
                            else {
                                Text(":/")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.12, opacity: (1.0 - Double(abs(self.dragOffset.width) + abs(self.dragOffset.height)) / 1000)).edgesIgnoringSafeArea(.all))
                    .zIndex(1)
                }
                .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
                .onAppear() {
                    self.dragOffset = .zero
                    self.dragOffsetPredicted = .zero
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

class PinchZoomView: UIView {

    weak var delegate: PinchZoomViewDelgate?

    private(set) var scale: CGFloat = 0 {
        didSet {
            delegate?.pinchZoomView(self, didChangeScale: scale)
        }
    }

    private(set) var anchor: UnitPoint = .center {
        didSet {
            delegate?.pinchZoomView(self, didChangeAnchor: anchor)
        }
    }

    private(set) var offset: CGSize = .zero {
        didSet {
            delegate?.pinchZoomView(self, didChangeOffset: offset)
        }
    }

    private(set) var isPinching: Bool = false {
        didSet {
            delegate?.pinchZoomView(self, didChangePinching: isPinching)
        }
    }

    private var startLocation: CGPoint = .zero
    private var location: CGPoint = .zero
    private var numberOfTouches: Int = 0

    init() {
        super.init(frame: .zero)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinch(gesture:)))
        pinchGesture.cancelsTouchesInView = false
        addGestureRecognizer(pinchGesture)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    @objc private func pinch(gesture: UIPinchGestureRecognizer) {

        switch gesture.state {
        case .began:
            isPinching = true
            startLocation = gesture.location(in: self)
            anchor = UnitPoint(x: startLocation.x / bounds.width, y: startLocation.y / bounds.height)
            numberOfTouches = gesture.numberOfTouches

        case .changed:
            if gesture.numberOfTouches != numberOfTouches {
                // If the number of fingers being used changes, the start location needs to be adjusted to avoid jumping.
                let newLocation = gesture.location(in: self)
                let jumpDifference = CGSize(width: newLocation.x - location.x, height: newLocation.y - location.y)
                startLocation = CGPoint(x: startLocation.x + jumpDifference.width, y: startLocation.y + jumpDifference.height)

                numberOfTouches = gesture.numberOfTouches
            }

            scale = gesture.scale

            location = gesture.location(in: self)
            offset = CGSize(width: location.x - startLocation.x, height: location.y - startLocation.y)

        case .ended, .cancelled, .failed:
            isPinching = false
            scale = 1.0
            anchor = .center
            offset = .zero
        default:
            break
        }
    }

}

protocol PinchZoomViewDelgate: AnyObject {
    func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangePinching isPinching: Bool)
    func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeScale scale: CGFloat)
    func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeAnchor anchor: UnitPoint)
    func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeOffset offset: CGSize)
}

struct PinchZoom: UIViewRepresentable {

    @Binding var scale: CGFloat
    @Binding var anchor: UnitPoint
    @Binding var offset: CGSize
    @Binding var isPinching: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PinchZoomView {
        let pinchZoomView = PinchZoomView()
        pinchZoomView.delegate = context.coordinator
        return pinchZoomView
    }

    func updateUIView(_ pageControl: PinchZoomView, context: Context) { }

    class Coordinator: NSObject, PinchZoomViewDelgate {
        var pinchZoom: PinchZoom

        init(_ pinchZoom: PinchZoom) {
            self.pinchZoom = pinchZoom
        }

        func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangePinching isPinching: Bool) {
            pinchZoom.isPinching = isPinching
        }

        func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeScale scale: CGFloat) {
            pinchZoom.scale = scale
        }

        func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeAnchor anchor: UnitPoint) {
            pinchZoom.anchor = anchor
        }

        func pinchZoomView(_ pinchZoomView: PinchZoomView, didChangeOffset offset: CGSize) {
            pinchZoom.offset = offset
        }
    }
}

struct PinchToZoom: ViewModifier {
    @State var scale: CGFloat = 1.0
    @State var anchor: UnitPoint = .center
    @State var offset: CGSize = .zero
    @State var isPinching: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .offset(offset)
            .animation(isPinching ? .none : .spring())
            .overlay(PinchZoom(scale: $scale, anchor: $anchor, offset: $offset, isPinching: $isPinching))
    }
}

extension View {
    func pinchToZoom() -> some View {
        self.modifier(PinchToZoom())
    }
}






class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let url: Binding<String>
    private let headers: [String: String]?
    private var cancellable: AnyCancellable?
    
    func getURLRequest(url: String, headers: [String: String]?) -> URLRequest {
        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if(headers != nil) {
            for (key, value) in headers! {
                print("adding header: \(key): \(value)")
                request.addValue("\(value)", forHTTPHeaderField: "\(key)")
            }
            
            print("headers found, requesting URL image with headers: \(request.allHTTPHeaderFields)")
            return request;
        }
        else {
            print("headers nil, requesting URL image with request: \(request)")
            return request;
        }
    }

    init(url: Binding<String>, httpHeaders: [String: String]?) {
        self.url = url
        self.headers = httpHeaders
        
        load()
    }
    
    deinit {
        cancellable?.cancel()
    }

    func load() {
        if self.url.wrappedValue != "" {
            cancellable = URLSession.shared.dataTaskPublisher(for: getURLRequest(url: self.url.wrappedValue, headers: self.headers))
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.image, on: self)
        }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}
