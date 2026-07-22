import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Ouvre directement l'app Alanya (écran de choix de conversation).
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
