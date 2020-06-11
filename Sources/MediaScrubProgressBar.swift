/*****************************************************************************
 * MediaScrubProgressBar.swift
 *
 * Copyright © 2019-2020 VLC authors and VideoLAN
 *
 * Authors: Robert Gordon <robwaynegordon@gmail.com>
 *          Soomin Lee <bubu@mikan.io>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

@objc (VLCMediaScrubProgressBarDelegate)
protocol MediaScrubProgressBarDelegate {
    func mediaScrubProgressBarShouldResetIdleTimer()
}

@objc (VLCMediaScrubProgressBar)
class MediaScrubProgressBar: UIStackView {
    @objc weak var delegate: MediaScrubProgressBarDelegate?
    private var playbackService = PlaybackService.sharedInstance()
    private var positionSet: Bool = true
    private var isScrubbing: Bool = false
    
    @objc lazy private(set) var progressSlider: VLCOBSlider = {
        var slider = VLCOBSlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = .orange
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.2)
        slider.setThumbImage(UIImage(named: "sliderThumb"), for: .normal)
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(handleSlide), for: .valueChanged)
        slider.addTarget(self, action: #selector(progressSliderTouchDown), for: .touchDown)
        slider.addTarget(self, action: #selector(progressSliderTouchUp), for: .touchUpInside)
        slider.addTarget(self, action: #selector(progressSliderTouchUp), for: .touchUpOutside)
        slider.addTarget(self, action: #selector(updateScrubLabel), for: .touchDragInside)
        slider.addTarget(self, action: #selector(updateScrubLabel), for: .touchDragOutside)
        return slider
    }()
    
    private lazy var elapsedTimeLabel: UILabel = {
        var label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .orange
        label.text = "--:--"
        label.numberOfLines = 1
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    private lazy var remainingTimeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.text = "--:--"
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var scrubbingIndicatorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white
        label.textAlignment = .center
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.backgroundColor = UIColor(white: 0, alpha: 0.4)
        return label
    }()

    private lazy var scrubbingHelpLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .white
        label.text = NSLocalizedString("PLAYBACK_SCRUB_HELP", comment: "")
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.backgroundColor = UIColor(white: 0, alpha: 0.4)
        label.textAlignment = .center
        return label
    }()

    private lazy var scrubInfoStackView: UIStackView = {
        let scrubInfoStackView = UIStackView(arrangedSubviews: [scrubbingIndicatorLabel, scrubbingHelpLabel])
        scrubInfoStackView.axis = .vertical
        scrubInfoStackView.isHidden = true
        return scrubInfoStackView
    }()
    
    // MARK: Initializers
    required init(coder: NSCoder) {
        fatalError("init(coder: NSCoder) not implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @objc func updateUI() {
        if !isScrubbing {
            progressSlider.value = playbackService.playbackPosition
        }
        remainingTimeLabel.text = playbackService.remainingTime().stringValue
        elapsedTimeLabel.text = playbackService.playedTime().stringValue
    }
}

// MARK: -

private extension MediaScrubProgressBar {
    private func setupViews() {
        let horizontalStack = UIStackView(arrangedSubviews: [elapsedTimeLabel, remainingTimeLabel])
        horizontalStack.distribution = .equalSpacing
        addArrangedSubview(scrubInfoStackView)
        addArrangedSubview(horizontalStack)
        addArrangedSubview(progressSlider)
        spacing = 5
        axis = .vertical
        translatesAutoresizingMaskIntoConstraints = false
    }

    @objc private func updateScrubLabel() {
        let speed = progressSlider.scrubbingSpeed
        if  speed == 1 {
            scrubbingIndicatorLabel.text = NSLocalizedString("PLAYBACK_SCRUB_HIGH", comment:"")
        } else if speed == 0.5 {
            scrubbingIndicatorLabel.text = NSLocalizedString("PLAYBACK_SCRUB_HALF", comment: "")
        } else if speed == 0.25 {
            scrubbingIndicatorLabel.text = NSLocalizedString("PLAYBACK_SCRUB_QUARTER", comment: "")
        } else {
            scrubbingIndicatorLabel.text = NSLocalizedString("PLAYBACK_SCRUB_FINE", comment: "")
        }
    }

    @objc private func updatePlaybackPosition() {
        if !positionSet {
            playbackService.playbackPosition = progressSlider.value
            playbackService.setNeedsMetadataUpdate()
            positionSet = true
        }
    }

    // MARK: - Slider Methods

    @objc private func handleSlide() {
        /* we need to limit the number of events sent by the slider, since otherwise, the user
         * wouldn't see the I-frames when seeking on current mobile devices. This isn't a problem
         * within the Simulator, but especially on older ARMv7 devices, it's clearly noticeable. */
        perform(#selector(updatePlaybackPosition), with: nil, afterDelay: 0.3)
        if playbackService.mediaDuration > 0 {
            updateUI()
        }
        positionSet = false
        delegate?.mediaScrubProgressBarShouldResetIdleTimer()
    }

    @objc private func progressSliderTouchDown() {
        updateScrubLabel()
        isScrubbing = true
        scrubInfoStackView.isHidden = !isScrubbing
    }

    @objc private func progressSliderTouchUp() {
        isScrubbing = false
        scrubInfoStackView.isHidden = !isScrubbing
    }
}