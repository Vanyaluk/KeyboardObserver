import UIKit

class UXViewController: UIViewController {
    internal var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.keyboardDismissMode = .interactiveWithAccessory
        view.alwaysBounceVertical = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var keyboardTopAnchor: NSLayoutConstraint = {
        keyboardLayout.topAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
    }()
    
    internal let keyboardLayout: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()
    private let bottomSafeArea: Int = 0
    private var isListeningKeypadChange = false
    
    private var maxKeyboardHeight: CGFloat = 0
    
    init() {
        super.init(nibName: nil, bundle: nil)
        setupObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupObservers() {
        scrollView.backgroundColor = .systemBackground
        keyboardLayout.backgroundColor = .red
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(keyboardLayout)
        NSLayoutConstraint.activate([
            keyboardLayout.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboardLayout.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardLayout.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardTopAnchor
        ])
        
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor)
        ])
    }
    
    // MARK: - observers
    @objc private func keyboardWillShow(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo as? [String : Any],
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
              let value = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        else { return }
        
        if !isListeningKeypadChange {
            maxKeyboardHeight = value.cgRectValue.height
            keyboardTopAnchor.constant = -value.cgRectValue.height

            let options = UIView.AnimationOptions.beginFromCurrentState.union(UIView.AnimationOptions(rawValue: animationCurve))
            UIView.animate(withDuration: animationDuration, delay: 0, options: options, animations: { [weak self] in
                self?.view.layoutIfNeeded()
                }, completion: { [weak self] done in
                    guard done else { return }
                    self?.beginListeningKeyboardChange()
            })
        }
        else {
            isListeningKeypadChange = false
            keyboardTopAnchor.constant = -value.cgRectValue.height
        }
    }
    
    @objc private func keyboardWillChange(_ notification: Notification) {
        if isListeningKeypadChange, let value = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            print(2)
            maxKeyboardHeight = value.cgRectValue.height
            keyboardTopAnchor.constant = -value.cgRectValue.height
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String : Any] else { return }
        
        maxKeyboardHeight = 0
        keyboardTopAnchor.constant = 0
        
        var options = UIView.AnimationOptions.beginFromCurrentState
        if let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
            options = options.union(UIView.AnimationOptions(rawValue: animationCurve))
        }

        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval
        UIView.animate(withDuration: duration ?? 0, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardDidHide() {
        isListeningKeypadChange = false
        scrollView.panGestureRecognizer.removeTarget(self, action: nil)
        if maxKeyboardHeight != 0 || keyboardTopAnchor.constant != 0 {
            maxKeyboardHeight = 0
            keyboardTopAnchor.constant = 0
        }
    }
    
    
    // MARK: - UIPanGestureRecognizer
    @objc private func handlePanGestureRecognizer(_ pan: UIPanGestureRecognizer) {
        guard isListeningKeypadChange else {
            isListeningKeypadChange = true
            
            let dragY = view.frame.height - pan.location(in: view).y
            let duration = (1 - dragY / 336) * 0.25
            let safeDuration = max(duration, 0)
            print(duration, dragY)
            UIView.animate(withDuration: safeDuration, delay: 0, animations: {
                self.view.layoutIfNeeded()
            })
            
            return
        }
        
        let windowHeight = view.frame.height
        let keyboardHeight = abs(keyboardTopAnchor.constant)
        
        let dragY = windowHeight - pan.location(in: view).y
        let newValue = min(dragY < keyboardHeight ? max(dragY, 0) : dragY, maxKeyboardHeight)
        
        guard keyboardHeight != newValue else { return }
        keyboardTopAnchor.constant = -newValue
    }
    
    private func beginListeningKeyboardChange() {
        isListeningKeypadChange = true
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGestureRecognizer(_:)))
    }
}
