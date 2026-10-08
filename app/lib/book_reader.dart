import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'book_catalog.dart';

class ReaderPage {
  const ReaderPage({required this.printedPage, required this.text});

  final int printedPage;
  final String text;
}

class ReaderBlock {
  const ReaderBlock({required this.printedPage, required this.text});

  final int printedPage;
  final String text;
}

class _FlowBlock {
  const _FlowBlock({
    required this.text,
    required this.printedPage,
    required this.isHeading,
    this.nodes = const [],
  });

  final String text;
  final int printedPage;
  final bool isHeading;
  final List<TocNode> nodes;
}

class _FlowPage {
  const _FlowPage(this.blocks, this.printedPage);

  final List<_FlowBlock> blocks;
  final int printedPage;
}

class ReaderBook {
  factory ReaderBook(List<ReaderPage> pages) {
    final blocks = [
      for (final page in pages)
        for (final paragraph in page.text.split(RegExp(r'\n\s*\n')))
          if (paragraph.trim().isNotEmpty)
            ReaderBlock(printedPage: page.printedPage, text: paragraph.trim()),
    ];
    final anchors = <TocNode, int>{};
    final matchedAnchors = <TocNode>{};
    for (final node in _allContentsNodes()) {
      final title = _normalizeTitle(_nodeLabel(node));
      final candidates = <(int, int, int)>[];
      for (var index = 0; index < blocks.length; index++) {
        final pageDistance = (blocks[index].printedPage - node.printedPage).abs();
        if (pageDistance > 3) continue;
        for (var length = 1; length <= 3 && index + length <= blocks.length; length++) {
          final endPage = blocks[index + length - 1].printedPage;
          if (endPage - blocks[index].printedPage > 1) break;
          final text = _normalizeTitle(
            blocks.sublist(index, index + length).map((block) => block.text).join(' '),
          );
          if (text == title) {
            candidates.add((0, pageDistance, index));
          } else if (text.startsWith(title)) {
            candidates.add((1, pageDistance, index));
          } else if (text.contains(title)) {
            candidates.add((2, pageDistance, index));
          }
        }
      }
      candidates.sort((a, b) {
        final rank = a.$1.compareTo(b.$1);
        return rank != 0 ? rank : a.$2.compareTo(b.$2);
      });
      final fallback = blocks.indexWhere(
        (block) => block.printedPage >= node.printedPage,
      );
      if (candidates.isNotEmpty) matchedAnchors.add(node);
      anchors[node] = candidates.isEmpty
          ? (fallback < 0 ? blocks.length - 1 : fallback)
          : candidates.first.$3;
    }
    return ReaderBook._(pages, blocks, anchors, matchedAnchors);
  }

  const ReaderBook._(this.pages, this.blocks, this.anchors, this.matchedAnchors);

  final List<ReaderPage> pages;
  final List<ReaderBlock> blocks;
  final Map<TocNode, int> anchors;
  final Set<TocNode> matchedAnchors;

  static Future<ReaderBook> load() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/book_content.json'),
    ) as Map<String, dynamic>;
    final pages = (json['pages'] as List)
        .cast<Map<String, dynamic>>()
        .map((page) => ReaderPage(
              printedPage: page['printedPage'] as int,
              text: page['text'] as String,
            ))
        .toList();
    return ReaderBook(pages);
  }
}

Iterable<TocNode> _allContentsNodes() sync* {
  for (final part in bookContents) {
    yield part;
    for (final chapter in part.children) {
      yield chapter;
      yield* chapter.children;
    }
  }
}

String _nodeLabel(TocNode node) {
  final divider = node.title.indexOf('·');
  return divider < 0 ? node.title : node.title.substring(divider + 1).trim();
}

String _normalizeTitle(String value) {
  const accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const plain = 'aaaaaeeeeiiiiooooouuuuc';
  final normalized = StringBuffer();
  final canonical = value.toLowerCase().replaceAll(RegExp(r'n[º°]'), 'no');
  for (final character in canonical.split('')) {
    final index = accented.indexOf(character);
    normalized.write(index < 0 ? character : plain[index]);
  }
  return normalized.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class TextBookApp extends StatefulWidget {
  const TextBookApp({super.key});

  @override
  State<TextBookApp> createState() => _TextBookAppState();
}

class _TextBookAppState extends State<TextBookApp> {
  bool _isDark = false;
  bool _themeChanged = false;
  bool _bookOpened = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted || _themeChanged) return;
    setState(() => _isDark = preferences.getBool('readerDarkMode') ?? false);
  }

  Future<void> _toggleTheme() async {
    setState(() {
      _themeChanged = true;
      _isDark = !_isDark;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('readerDarkMode', _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O Céu e o Inferno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315C54)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF82B8A8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: _bookOpened
          ? TextBookReader(onToggleTheme: _toggleTheme)
          : BookCover(onOpen: () => setState(() => _bookOpened = true)),
    );
  }
}

class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF182722),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              const Text(
                'O CÉU E O INFERNO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF1E5C8),
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ALLAN KARDEC',
                style: TextStyle(color: Color(0xFFD6CBAF), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Image.asset('assets/kardec.jpg', fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.menu_book),
                label: const Text('Abrir livro'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF315C54),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TextBookReader extends StatefulWidget {
  const TextBookReader({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<TextBookReader> createState() => _TextBookReaderState();
}

class _TextBookReaderState extends State<TextBookReader> {
  final Future<ReaderBook> _book = ReaderBook.load();
  final PageController _pageController = PageController();
  List<_FlowPage> _flowPages = [];
  Map<TocNode, int> _pageForNode = {};
  Size? _paginationSize;
  double? _paginationFontSize;
  int _pageIndex = 0;
  double _fontSize = 18;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openContents(ReaderBook book) async {
    final node = await Navigator.of(context).push<TocNode>(
      MaterialPageRoute<TocNode>(
        builder: (_) => ContentsPage(
          onSelect: (selected) => Navigator.of(context).pop(selected),
        ),
      ),
    );
    if (!mounted || node == null) return;
    final targetPage = _pageForNode[node];
    if (targetPage != null && _pageController.hasClients) {
      await _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _turnPage(bool forward) {
    if (!_pageController.hasClients || _flowPages.isEmpty) return;
    final target = (_pageIndex + (forward ? 1 : -1))
        .clamp(0, _flowPages.length - 1)
        .toInt();
    if (target == _pageIndex) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  List<_FlowBlock> _makeFlowBlocks(ReaderBook book) {
    final nodesByBlock = <int, List<TocNode>>{};
    for (final entry in book.anchors.entries) {
      (nodesByBlock[entry.value] ??= []).add(entry.key);
    }

    final result = <_FlowBlock>[];
    for (var index = 0; index < book.blocks.length; index++) {
      final sourceBlock = book.blocks[index];
      final nodes = nodesByBlock[index] ?? const <TocNode>[];
      final partNodes = nodes
          .where((node) => bookContents.contains(node) && node.children.isNotEmpty)
          .toList();
      for (final part in partNodes) {
        result.add(_FlowBlock(
          text: part.title,
          printedPage: sourceBlock.printedPage,
          isHeading: true,
          nodes: [part],
        ));
      }

      final isPartTitleBlock = partNodes.any(
        (part) =>
            _normalizeTitle(sourceBlock.text) == _normalizeTitle(_nodeLabel(part)),
      );
      if (isPartTitleBlock) continue;

      result.add(_FlowBlock(
        text: sourceBlock.text,
        printedPage: sourceBlock.printedPage,
        isHeading: nodes.any(book.matchedAnchors.contains),
        nodes: nodes,
      ));
    }
    return result;
  }

  TextStyle _styleFor(BuildContext context, _FlowBlock block) {
    final base = block.isHeading
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return (base ?? const TextStyle()).copyWith(
      fontSize: _fontSize + (block.isHeading ? 2 : 0),
      height: 1.7,
      fontWeight: block.isHeading ? FontWeight.w600 : FontWeight.normal,
      color: block.isHeading ? Theme.of(context).colorScheme.primary : null,
    );
  }

  double _measureBlock(BuildContext context, _FlowBlock block, double width) {
    final painter = TextPainter(
      text: TextSpan(text: block.text, style: _styleFor(context, block)),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: width);
    return painter.height + (block.isHeading ? 26 : 18);
  }

  List<_FlowBlock> _splitBlock(
    BuildContext context,
    _FlowBlock block,
    double width,
    double maxHeight,
  ) {
    final spacing = block.isHeading ? 26.0 : 18.0;
    final availableTextHeight = maxHeight - spacing;
    if (_measureBlock(context, block, width) <= maxHeight) return [block];

    final fragments = <_FlowBlock>[];
    var remaining = block.text;
    while (remaining.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: remaining, style: _styleFor(context, block)),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width);
      if (painter.height <= availableTextHeight) {
        fragments.add(_FlowBlock(
          text: remaining,
          printedPage: block.printedPage,
          isHeading: fragments.isEmpty && block.isHeading,
          nodes: fragments.isEmpty ? block.nodes : const [],
        ));
        break;
      }

      var splitAt = painter
          .getPositionForOffset(Offset(width, availableTextHeight))
          .offset
          .clamp(0, remaining.length)
          .toInt();
      while (splitAt > 0 &&
          splitAt < remaining.length &&
          !RegExp(r'\s').hasMatch(remaining[splitAt - 1])) {
        splitAt--;
      }
      if (splitAt <= 0 || splitAt >= remaining.length) {
        splitAt = remaining.lastIndexOf(' ', (remaining.length * 0.8).floor());
        if (splitAt <= 0) splitAt = (remaining.length / 2).floor();
      }
      if (splitAt <= 0) splitAt = remaining.length;

      fragments.add(_FlowBlock(
        text: remaining.substring(0, splitAt).trim(),
        printedPage: block.printedPage,
        isHeading: fragments.isEmpty && block.isHeading,
        nodes: fragments.isEmpty ? block.nodes : const [],
      ));
      remaining = remaining.substring(splitAt).trimLeft();
    }
    return fragments;
  }

  void _paginate(BuildContext context, ReaderBook book, Size viewport) {
    if (_paginationSize == viewport &&
        _paginationFontSize == _fontSize &&
        _flowPages.isNotEmpty) {
      return;
    }

    final previousPrintedPage = _flowPages.isEmpty
        ? null
        : _flowPages[_pageIndex.clamp(0, _flowPages.length - 1)].printedPage;
    final width = (viewport.width - 48).clamp(120.0, double.infinity).toDouble();
    final height = (viewport.height - 128).clamp(180.0, double.infinity).toDouble();
    final pages = <_FlowPage>[];
    final current = <_FlowBlock>[];
    var usedHeight = 0.0;

    void finishPage() {
      if (current.isEmpty) return;
      pages.add(_FlowPage(List<_FlowBlock>.of(current), current.first.printedPage));
      current.clear();
      usedHeight = 0;
    }

    for (final block in _makeFlowBlocks(book)) {
      for (final fragment in _splitBlock(context, block, width, height)) {
        final blockHeight = _measureBlock(context, fragment, width);
        if (current.isNotEmpty && usedHeight + blockHeight > height) finishPage();
        current.add(fragment);
        usedHeight += blockHeight;
      }
    }
    finishPage();

    final pageForNode = <TocNode, int>{};
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final block in pages[pageIndex].blocks) {
        for (final node in block.nodes) {
          pageForNode.putIfAbsent(node, () => pageIndex);
        }
      }
    }
    _flowPages = pages;
    _pageForNode = pageForNode;
    _paginationSize = viewport;
    _paginationFontSize = _fontSize;

    if (previousPrintedPage != null) {
      final index = pages.indexWhere((page) => page.printedPage >= previousPrintedPage);
      _pageIndex = index < 0 ? pages.length - 1 : index;
    } else {
      _pageIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients && pages.isNotEmpty) {
        _pageController.jumpToPage(_pageIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReaderBook>(
      future: _book,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Não foi possível carregar o livro: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final book = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('O Céu e o Inferno'),
            actions: [
              IconButton(
                tooltip: 'Diminuir texto',
                onPressed: () => setState(
                    () => _fontSize = (_fontSize - 1).clamp(14, 28).toDouble()),
                icon: const Icon(Icons.text_decrease),
              ),
              IconButton(
                tooltip: 'Aumentar texto',
                onPressed: () => setState(
                    () => _fontSize = (_fontSize + 1).clamp(14, 28).toDouble()),
                icon: const Icon(Icons.text_increase),
              ),
              IconButton(
                tooltip: Theme.of(context).brightness == Brightness.dark
                    ? 'Ativar modo claro'
                    : 'Ativar modo noturno',
                onPressed: widget.onToggleTheme,
                icon: Icon(Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode),
              ),
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'Sumário',
                onPressed: () => _openContents(book),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openContents(book),
            icon: const Icon(Icons.list_alt),
            label: const Text('Sumário'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = Size(constraints.maxWidth, constraints.maxHeight);
              _paginate(context, book, viewport);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (details.localPosition.dx < constraints.maxWidth * 0.2) {
                    _turnPage(false);
                  } else if (details.localPosition.dx > constraints.maxWidth * 0.8) {
                    _turnPage(true);
                  }
                },
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _flowPages.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) => SelectionArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final block in _flowPages[index].blocks)
                            Padding(
                              padding: EdgeInsets.only(
                                top: block.isHeading ? 16 : 0,
                                bottom: block.isHeading ? 10 : 8,
                              ),
                              child: Text(
                                block.text,
                                style: _styleFor(context, block),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ContentsPage extends StatelessWidget {
  const ContentsPage({super.key, required this.onSelect});

  final ValueChanged<TocNode> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sumário')),
      body: ListView(
        children: [
          for (final part in bookContents) ...[
            if (part.children.isEmpty)
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(part.title),
                onTap: () => onSelect(part),
              )
            else ...[
              ListTile(
                tileColor: Theme.of(context).colorScheme.secondaryContainer,
                title: Text(part.title, style: textTheme.titleMedium),
                onTap: () => onSelect(part),
              ),
              for (final chapter in part.children) ...[
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(chapter.title),
                  onTap: () => onSelect(chapter),
                ),
                for (final section in chapter.children)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text(section.title),
                    onTap: () => onSelect(section),
                  ),
              ],
            ],
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}