// Recherche de messages dans la conversation. part of chat_detail_screen.dart.
//
// Le filtrage vit dans `core/services/chat/message_search.dart` (pur) ; ici on
// ne gère que l'écran : champ, compteur, flèches et saut vers un résultat.
part of '../chat_detail_screen.dart';

extension _ChatSearch on _ChatDetailScreenState {
  /// Requête normalisée à surligner dans les bulles, ou `null` hors recherche
  /// et tant que la saisie est trop courte.
  String? get _searchHighlightQuery =>
      _searchMode ? requeteValide(_searchController.text) : null;

  void _enterSearchMode() {
    if (_searchMode || _convId == null) return;
    rebuild(() => _searchMode = true);
  }

  /// [refocusInput] : faux quand on sort parce qu'une sélection de messages
  /// commence, pour ne pas rouvrir le clavier au milieu du geste.
  void _exitSearchMode({bool refocusInput = true}) {
    if (!_searchMode) return;
    _searchDebounce?.cancel();
    // Invalide une recherche encore en vol : son résultat arriverait après
    // la sortie et réécrirait un état qu'on vient de vider.
    _searchToken++;
    _highlightTimer?.cancel();
    _searchController.clear();
    rebuild(() {
      _searchMode = false;
      _searchResults = const [];
      _searchIndex = 0;
      _searchSettled = false;
      _highlightMsgId = null;
    });
    if (refocusInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _inputFocus.requestFocus();
      });
    }
  }

  /// Anti-rebond : une frappe rapide ne lance qu'une lecture de la base.
  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchSettled = false;
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_runSearch()),
    );
  }

  Future<void> _runSearch() async {
    final convId = _convId;
    if (convId == null) return;
    final token = ++_searchToken;
    final text = _searchController.text;

    if (requeteValide(text) == null) {
      rebuild(() {
        _searchResults = const [];
        _searchIndex = 0;
        _searchSettled = false;
      });
      return;
    }

    final candidats =
        await _chat.repository.dao.searchCandidates(convId, _myId ?? 0);
    final ids = await rechercherMessages(candidats, text);
    // Une frappe ou une sortie a eu lieu pendant la lecture : ce résultat est
    // celui d'une requête dépassée.
    if (!mounted || token != _searchToken) return;

    rebuild(() {
      _searchResults = ids;
      _searchIndex = 0;
      _searchSettled = true;
    });
    if (ids.isNotEmpty) unawaited(_goToSearchResult(0));
  }

  /// L'index 0 est le résultat le plus récent : « plus ancien » = index + 1.
  Future<void> _goToSearchResult(int index) async {
    if (index < 0 || index >= _searchResults.length) return;
    // Même garde que `_jumpToNextMention` : un second appui pendant que le
    // premier saut charge l'historique ne doit pas lancer deux défilements.
    if (_searchJumpInFlight) return;
    _searchJumpInFlight = true;
    rebuild(() => _searchIndex = index);
    try {
      await _scrollToReply(_searchResults[index], silent: true);
    } finally {
      _searchJumpInFlight = false;
    }
  }

  PreferredSizeWidget _buildSearchAppBar() {
    final l10n = context.l10n;
    final total = _searchResults.length;
    final hasResults = total > 0;
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: l10n.searchExit,
        onPressed: _exitSearchMode,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: context.text.titleMedium,
        decoration: InputDecoration(
          hintText: l10n.searchInConversationHint,
          border: InputBorder.none,
        ),
        onChanged: _onSearchChanged,
        onSubmitted: (_) {
          _searchDebounce?.cancel();
          unawaited(_runSearch());
        },
      ),
      actions: [
        Center(
          child: Text(
            hasResults
                ? l10n.searchResultCounter(_searchIndex + 1, total)
                : '0',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          tooltip: l10n.searchPrevious,
          onPressed: hasResults && _searchIndex < total - 1
              ? () => unawaited(_goToSearchResult(_searchIndex + 1))
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          tooltip: l10n.searchNext,
          onPressed: hasResults && _searchIndex > 0
              ? () => unawaited(_goToSearchResult(_searchIndex - 1))
              : null,
        ),
      ],
    );
  }

  /// Bandeau discret sous la barre : une SnackBar disparaîtrait pendant que
  /// l'utilisateur corrige sa saisie.
  Widget _buildSearchNoResultBanner() {
    if (!_searchMode ||
        !_searchSettled ||
        _searchResults.isNotEmpty ||
        _searchHighlightQuery == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: context.colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        context.l10n.searchNoResult,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
