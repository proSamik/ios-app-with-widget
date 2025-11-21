import SwiftUI
import YouTubeiOSPlayerHelper

// MARK: - YouTube Player using YouTubeiOSPlayerHelper
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let isVisible: Bool
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.delegate = context.coordinator
        playerView.backgroundColor = .black
        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // Load video if ID changed
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            isLoading = true

            let playerVars: [String: Any] = [
                "playsinline": 1,
                "autoplay": 1,
                "controls": 1,
                "rel": 0,
                "modestbranding": 1,
                "showinfo": 0,
                "fs": 1
            ]

            uiView.load(withVideoId: videoID, playerVars: playerVars)
        }

        // Handle visibility changes - pause/play based on scroll
        if context.coordinator.wasVisible != isVisible {
            context.coordinator.wasVisible = isVisible
            if isVisible {
                uiView.playVideo()
                print("▶️ Playing video: \(videoID)")
            } else {
                uiView.pauseVideo()
                print("⏸️ Paused video: \(videoID)")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, YTPlayerViewDelegate {
        var loadedVideoID: String?
        var wasVisible: Bool = true
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            self._isLoading = isLoading
        }

        func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            playerView.playVideo()
            print("✅ YouTube player ready and playing")
        }

        func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
            print("Player state: \(state.rawValue)")

            // Loop video when it ends
            if state == .ended {
                playerView.seek(toSeconds: 0, allowSeekAhead: true)
                playerView.playVideo()
                print("🔄 Video ended, restarting")
            }
        }

        func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            print("❌ Player error: \(error.rawValue)")
        }
    }
}

// MARK: - Single Short Video View
struct ShortVideoView: View {
    let video: Video
    let isVisible: Bool
    let canGoUp: Bool
    let canGoDown: Bool
    let onNavigateUp: () -> Void
    let onNavigateDown: () -> Void
    @State private var isPlaying = false
    @State private var isLoadingPlayer = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                if isPlaying {
                    // Show loading spinner while YouTube loads
                    if isLoadingPlayer {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }

                    // YouTube Player using YouTubeiOSPlayerHelper
                    YouTubePlayerView(videoID: video.videoID, isVisible: isVisible, isLoading: $isLoadingPlayer)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(isLoadingPlayer ? 0 : 1)

                    // Navigation controls
                    VStack {
                        HStack(spacing: 20) {
                            Button(action: onNavigateUp) {
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(canGoUp ? .white : .white.opacity(0.3))
                                    .shadow(color: .black, radius: 4)
                            }
                            .disabled(!canGoUp)

                            Button(action: { isPlaying = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 4)
                            }

                            Button(action: onNavigateDown) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(canGoDown ? .white : .white.opacity(0.3))
                                    .shadow(color: .black, radius: 4)
                            }
                            .disabled(!canGoDown)
                        }
                        .padding(.top, 60)

                        Spacer()
                    }
                } else {
                    // YouTube Thumbnail
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure:
                            AsyncImage(url: fallbackThumbnailURL) { fallbackPhase in
                                switch fallbackPhase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .clipped()
                                default:
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                }
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }

                    // Tap to play
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPlaying = true
                            }
                        }

                    // Play button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPlaying = true
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)

                            Image(systemName: "play.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .offset(x: 4)
                        }
                    }
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                    // Title overlay
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(video.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 4, x: 0, y: 2)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 200)
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                isPlaying = true
            }
        }
        .onAppear {
            if isVisible {
                isPlaying = true
            }
        }
    }

    private var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(video.videoID)/maxresdefault.jpg")
    }

    private var fallbackThumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(video.videoID)/hqdefault.jpg")
    }
}

// MARK: - Vertical Paging ScrollView
struct VerticalPagingView<Content: View>: UIViewControllerRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    let content: (Int) -> Content

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: nil
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        pageViewController.view.backgroundColor = .black

        if pageCount > 0 {
            let initialVC = context.coordinator.viewController(at: 0)
            pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)
        }

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        guard pageCount > 0 else { return }

        if let currentVC = pageViewController.viewControllers?.first as? PageHostingController<Content>,
           currentVC.pageIndex != currentPage {
            let direction: UIPageViewController.NavigationDirection = currentPage > currentVC.pageIndex ? .forward : .reverse
            let newVC = context.coordinator.viewController(at: currentPage)
            pageViewController.setViewControllers([newVC], direction: direction, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalPagingView

        init(_ parent: VerticalPagingView) {
            self.parent = parent
        }

        func viewController(at index: Int) -> PageHostingController<Content> {
            let vc = PageHostingController(rootView: parent.content(index))
            vc.pageIndex = index
            vc.view.backgroundColor = .black
            return vc
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageHostingController<Content>,
                  vc.pageIndex > 0 else { return nil }
            return self.viewController(at: vc.pageIndex - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? PageHostingController<Content>,
                  vc.pageIndex < parent.pageCount - 1 else { return nil }
            return self.viewController(at: vc.pageIndex + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let vc = pageViewController.viewControllers?.first as? PageHostingController<Content> {
                DispatchQueue.main.async {
                    self.parent.currentPage = vc.pageIndex
                }
            }
        }
    }
}

class PageHostingController<Content: View>: UIHostingController<Content> {
    var pageIndex: Int = 0
}

// MARK: - Main Shorts Feed View
struct ShortsView: View {
    @StateObject private var videoService = VideoAPIService()
    @State private var currentIndex = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if videoService.isLoading && videoService.videos.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Loading videos...")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
            } else if let error = videoService.errorMessage, videoService.videos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)

                    Text("Error loading videos")
                        .foregroundColor(.white)
                        .font(.headline)

                    Text(error)
                        .foregroundColor(.gray)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: {
                        Task {
                            await videoService.fetchVideos(forceRefresh: true)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            } else if videoService.videos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No videos available")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            } else {
                VerticalPagingView(
                    pageCount: videoService.videos.count,
                    currentPage: $currentIndex
                ) { index in
                    ShortVideoView(
                        video: videoService.videos[index],
                        isVisible: index == currentIndex,
                        canGoUp: index > 0,
                        canGoDown: index < videoService.videos.count - 1,
                        onNavigateUp: {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        },
                        onNavigateDown: {
                            if currentIndex < videoService.videos.count - 1 {
                                currentIndex += 1
                            }
                        }
                    )
                }
                .ignoresSafeArea()

                // Video counter
                VStack {
                    HStack {
                        Spacer()
                        Text("\(currentIndex + 1)/\(videoService.videos.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(16)
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }
        }
        .task {
            await videoService.fetchVideos()
        }
    }
}

#Preview {
    ShortsView()
}
