import SwiftUI
import Combine
import YouTubeiOSPlayerHelper

// MARK: - Shared Video State Manager
class VideoStateManager: ObservableObject {
    static let shared = VideoStateManager()
    @Published var currentVisibleVideoID: String?

    private init() {}

    func setVisible(_ videoID: String) {
        if currentVisibleVideoID != videoID {
            currentVisibleVideoID = videoID
        }
    }
}

// MARK: - YouTube Player using YouTubeiOSPlayerHelper
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var isLoading: Bool
    @ObservedObject private var stateManager = VideoStateManager.shared

    func makeUIView(context: Context) -> YTPlayerView {
        let playerView = YTPlayerView()
        playerView.delegate = context.coordinator
        playerView.backgroundColor = .black
        context.coordinator.videoID = videoID
        context.coordinator.currentPlayerView = playerView
        return playerView
    }

    func updateUIView(_ uiView: YTPlayerView, context: Context) {
        // Load video if ID changed
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.videoID = videoID
            context.coordinator.isPlayerReady = false

            DispatchQueue.main.async {
                isLoading = true
            }

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

        // Handle visibility changes - pause/play based on shared state
        let isVisible = stateManager.currentVisibleVideoID == videoID

        if context.coordinator.isPlayerReady {
            if isVisible && !context.coordinator.isCurrentlyPlaying {
                uiView.playVideo()
                context.coordinator.isCurrentlyPlaying = true
            } else if !isVisible && context.coordinator.isCurrentlyPlaying {
                uiView.pauseVideo()
                context.coordinator.isCurrentlyPlaying = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, YTPlayerViewDelegate {
        var loadedVideoID: String?
        var videoID: String?
        var isPlayerReady: Bool = false
        var isCurrentlyPlaying: Bool = false
        weak var currentPlayerView: YTPlayerView?
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            self._isLoading = isLoading
        }

        func playerViewDidBecomeReady(_ playerView: YTPlayerView) {
            isPlayerReady = true
            DispatchQueue.main.async {
                self.isLoading = false
            }
            // Auto-play if this video is the currently visible one
            if VideoStateManager.shared.currentVisibleVideoID == videoID {
                playerView.playVideo()
                isCurrentlyPlaying = true
            }
        }

        func playerView(_ playerView: YTPlayerView, didChangeTo state: YTPlayerState) {
            // Track playing state
            if state == .playing {
                isCurrentlyPlaying = true
            } else if state == .paused {
                isCurrentlyPlaying = false
            }

            // Loop video when it ends
            if state == .ended {
                // Only loop if this video is still visible
                if VideoStateManager.shared.currentVisibleVideoID == videoID {
                    playerView.seek(toSeconds: 0, allowSeekAhead: true)
                    playerView.playVideo()
                }
            }
        }

        func playerView(_ playerView: YTPlayerView, receivedError error: YTPlayerError) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Single Short Video View
struct ShortVideoView: View {
    let video: Video
    let isVisible: Bool
    @State private var isLoadingPlayer = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                // Show loading spinner while YouTube loads
                if isLoadingPlayer {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }

                // YouTube Player - always loaded, VideoStateManager controls playback
                YouTubePlayerView(videoID: video.videoID, isLoading: $isLoadingPlayer)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(isLoadingPlayer ? 0 : 1)

                // Title overlay at bottom
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
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if isVisible {
                VideoStateManager.shared.setVisible(video.videoID)
            }
        }
    }
}

// MARK: - Vertical Paging ScrollView
struct VerticalPagingView<Content: View>: UIViewControllerRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    let videos: [Video]
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
                let newIndex = vc.pageIndex
                DispatchQueue.main.async {
                    self.parent.currentPage = newIndex
                    // Directly update VideoStateManager when gesture scroll completes
                    if newIndex < self.parent.videos.count {
                        VideoStateManager.shared.setVisible(self.parent.videos[newIndex].videoID)
                    }
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
                    currentPage: $currentIndex,
                    videos: videoService.videos
                ) { index in
                    ShortVideoView(
                        video: videoService.videos[index],
                        isVisible: index == currentIndex
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
        .onChange(of: currentIndex, initial: true) { _, newIndex in
            // Update the visible video when page changes
            if !videoService.videos.isEmpty && newIndex < videoService.videos.count {
                VideoStateManager.shared.setVisible(videoService.videos[newIndex].videoID)
            }
        }
        .onChange(of: videoService.videos.count, initial: true) { _, count in
            // Set initial visible video when videos load
            if count > 0 && currentIndex < count {
                VideoStateManager.shared.setVisible(videoService.videos[currentIndex].videoID)
            }
        }
    }
}

#Preview {
    ShortsView()
}
