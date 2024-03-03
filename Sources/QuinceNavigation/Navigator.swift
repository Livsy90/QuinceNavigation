import UIKit

public class Navigator {
    
    // MARK: Nested Entities
    
    public enum PresentationKind {
        case `default`(UIViewController)
        case modal(hasNavigationBar: Bool, UIViewController, UIModalTransitionStyle, UIModalPresentationStyle)
        case popover(UIViewController, UIPopoverPresentationControllerDelegate?, PopoverData)
        case root(UIViewController)
        case alert(AlertKind)
    }
    
    public enum AlertKind {
        case oneButton(title: String, message: String? = nil, buttonTitle: String, action: (() -> Void)? = nil)
        case twoButtons(title: String, message: String? = nil, firstButtonTitle: String, secondButtonTitle: String, firstButtonAction: (() -> Void)?, secondButtonAction: (() -> Void)?)
    }
    
    public struct PopoverData {
        var sourceRect: CGRect
        var sourceView: UIView
        var arrowDirection: UIPopoverArrowDirection = .down
    }
    
    // MARK: Private properties
    
    public private(set) weak var navigationController: UINavigationController?
    private weak var navigationStackFirstViewController: UIViewController?
    private weak var presentationStackFirstViewController: UIViewController?
    private var presentingViewController: UIViewController? {
        presentationStackFirstViewController?.presentationStack.last ?? presentationStackFirstViewController
    }
    
    // MARK: Init
    
    public init(_ navigationController: UINavigationController) {
        self.navigationController = navigationController
        
        navigationStackFirstViewController = navigationController.viewControllers.last
        presentationStackFirstViewController = navigationController.rootParent ?? navigationController
    }
    
    // MARK: Functions
    
    public func show(
        _ presentationKind: PresentationKind,
        animated: Bool = true
    ) {
        
        switch presentationKind {
        case let .default(viewController):
            push(
                viewController,
                animated: animated
            )
        case let .popover(viewController, delegate, bubbleData):
            presentPopover(
                viewController,
                delegate: delegate,
                popoverData: bubbleData,
                animated: animated
            )
        case let .modal(hasNavigationBar, viewController, transitionStyle, presentationStyle):
            guard hasNavigationBar else {
                presentModalWithoutNavigationBar(
                    viewController,
                    transitionStyle: transitionStyle,
                    presentationStyle: presentationStyle,
                    animated: animated
                )
                return
            }
            presentModalWithNavigationBar(
                viewController,
                transitionStyle: transitionStyle,
                presentationStyle: presentationStyle,
                animated: animated
            )
        case let .root(viewController):
            navigationController?.setViewControllers([viewController], animated: animated)
        case let .alert(kind):
            presentAlert(kind)
        }
    }
    
    public func close(
        _ viewController: UIViewController?,
        animated: Bool = true,
        _ completion: (() -> Void)? = nil
    ) {
        
        guard let viewController = viewController else {
            assert(false, "Nvigator: viewcontroller must not be nil")
            return
        }
        
        let controllerToDismiss = viewController.rootParent ?? viewController
        if presentationStackFirstViewController?.presentationStack.contains(controllerToDismiss) == true {
            controllerToDismiss.presentingViewController?.dismiss(animated: animated, completion: completion)
            return
        }
        
        if let destinationToPop = navigationController?.viewControllers.elementBeforeFirst(viewController) {
            navigationController?.popToViewController(destinationToPop, animated: animated)
            completion?()
            return
        }
    }
    
    public func closeStack(animated: Bool = true) {
        
        let completion = { [weak self] in
            guard let self, let navigationStackFirstViewController, self.navigationController?.viewControllers.contains(navigationStackFirstViewController) ?? false else { return }
            
            self.navigationController?.popToViewController(navigationStackFirstViewController, animated: animated)
        }
        
        if let _ = presentationStackFirstViewController?.presentedViewController {
            presentationStackFirstViewController?.dismiss(animated: animated, completion: completion)
        } else {
            completion()
        }
    }
    
}

// MARK: Private Functions

fileprivate extension Navigator {
    
    func presentModalWithNavigationBar(
        _ viewController: UIViewController,
        transitionStyle: UIModalTransitionStyle,
        presentationStyle: UIModalPresentationStyle,
        animated: Bool
    ) {
        
        let navigationController = UINavigationController.init(rootViewController: viewController)
        navigationController.modalPresentationStyle = presentationStyle
        navigationController.modalTransitionStyle = transitionStyle
        
        present(navigationController, animated: animated)
    }
    
    func presentModalWithoutNavigationBar(
        _ viewController: UIViewController,
        transitionStyle: UIModalTransitionStyle,
        presentationStyle: UIModalPresentationStyle,
        animated: Bool
    ) {
        
        viewController.modalPresentationStyle = presentationStyle
        viewController.modalTransitionStyle = transitionStyle
        
        present(viewController, animated: animated)
    }
    
    func presentPopover(
        _ viewController: UIViewController,
        delegate: UIPopoverPresentationControllerDelegate?,
        popoverData: PopoverData,
        animated: Bool
    ) {
        
        viewController.modalPresentationStyle = .popover
        
        let popoverViewController = viewController.popoverPresentationController
        popoverViewController?.delegate = delegate
        popoverViewController?.permittedArrowDirections = popoverData.arrowDirection
        popoverViewController?.backgroundColor = .white
        popoverViewController?.sourceRect = popoverData.sourceRect
        popoverViewController?.sourceView = popoverData.sourceView
        
        present(viewController, animated: animated)
    }
    
    func presentAlert(_ alertKind: AlertKind) {
        
        switch alertKind {
        case let .oneButton(title, message, buttonTitle, action):
            presentingViewController?.presentOneButtonAlert(
                title: title,
                message: message,
                buttonTitle: buttonTitle,
                completion: action
            )
        case let .twoButtons(title, message, firstButtonTitle, secondButtonTitle, firstButtonAction, secondButtonAction):
            presentingViewController?.presentTwoButtonsAlert(
                title: title,
                message: message,
                firstButtonTitle: firstButtonTitle,
                secondButtonTitle: secondButtonTitle,
                firstButtonAction: firstButtonAction,
                secondButtonAction: secondButtonAction
            )
        }
    }
    
    func present(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        
        presentingViewController?.present(viewController, animated: animated)
    }
    
    func push(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        
        guard let navigationController else { return }
        
        guard navigationController.viewControllers.isEmpty else {
            navigationController.pushViewController(viewController, animated: animated)
            return
        }
        
        navigationController.setViewControllers([viewController], animated: animated)
    }
    
}

// MARK: - Extensions

fileprivate extension UIViewController {
    var rootParent: UIViewController? {
        guard let parent = parent else {
            return nil
        }
        
        return parent.rootParent ?? parent
    }
    
    var presentationStack: [UIViewController] {
        guard let presentedViewController = presentedViewController else {
            return []
        }
        
        return [presentedViewController] + presentedViewController.presentationStack
    }
}

fileprivate extension UIViewController {
    func presentTwoButtonsAlert(
        title: String,
        message: String? = nil,
        firstButtonTitle: String,
        secondButtonTitle: String,
        firstButtonAction: (() -> Void)?,
        secondButtonAction: (() -> Void)? = nil
    ) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let firstAlertButton = UIAlertAction(title: firstButtonTitle, style: .default) { _ in
            firstButtonAction?()
        }
        let secondAlertButton = UIAlertAction(title: secondButtonTitle, style: .default) { _ in
            secondButtonAction?()
        }
        alertController.addAction(firstAlertButton)
        alertController.addAction(secondAlertButton)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func presentOneButtonAlert(
        title: String?,
        message: String?,
        buttonTitle: String,
        completion: (() -> Void)? = nil
    ) {
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        let action = UIAlertAction(
            title: buttonTitle,
            style: .default
        ) { _ in
            completion?()
        }
        
        alert.addAction(action)
        
        present(alert, animated: true)
    }
}

fileprivate extension Array where Element: Equatable {
    func elementBeforeFirst(_ element: Element) -> Element? {
        guard let indexOfElement = firstIndex(of: element), indexOfElement > startIndex else {
            return nil
        }
        return self[index(before: indexOfElement)]
    }
}
