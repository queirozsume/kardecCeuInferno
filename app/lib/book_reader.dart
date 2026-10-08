import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'book_catalog.dart';

class ReaderPage {
  const ReaderPage({required this.printedPage, required this.text});

  final int printedPage;
  final String text;
}

class ReaderBook {
  const ReaderBook(this.pages);

  final List<ReaderPage> pages;

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

class TextBookApp extends StatelessWidget {
  const TextBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O Céu e o Inferno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF76533A)),
        useMaterial3: true,
      ),
      home: const TextBookReader(),
    );
  }
}

class TextBookReader extends StatefulWidget {
  const TextBookReader({super.key});

  @override
  State<TextBookReader> createState() => _TextBookReaderState();
}

class _TextBookReaderState extends State<TextBookReader> {
  final Future<ReaderBook> _book = ReaderBook.load();
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  double _fontSize = 18;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openContents(ReaderBook book) async {
    final printedPage = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => ContentsPage(
          onSelect: (page) => Navigator.of(context).pop(page),
        ),
      ),
    );
    if (!mounted || printedPage == null) return;
    final index = (printedPage - book.pages.first.printedPage)
        .clamp(0, book.pages.length - 1)
        .toInt();
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
        final currentPage = book.pages[_pageIndex].printedPage;
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
                icon: const Icon(Icons.list_alt),
                tooltip: 'Sumário',
                onPressed: () => _openContents(book),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: book.pages.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) => SelectionArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                child: SelectableText(
                  book.pages[index].text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: _fontSize,
                        height: 1.7,
                      ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: _pageIndex == 0
                        ? null
                        : () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text('Página impressa $currentPage',
                        textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: 'Próxima página',
                    onPressed: _pageIndex == book.pages.length - 1
                        ? null
                        : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ContentsPage extends StatelessWidget {
  const ContentsPage({super.key, required this.onSelect});

  final ValueChanged<int> onSelect;

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
                onTap: () => onSelect(part.printedPage),
              )
            else ...[
              ListTile(
                tileColor: Theme.of(context).colorScheme.secondaryContainer,
                title: Text(part.title, style: textTheme.titleMedium),
                onTap: () => onSelect(part.printedPage),
              ),
              for (final chapter in part.children) ...[
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(chapter.title),
                  onTap: () => onSelect(chapter.printedPage),
                ),
                for (final section in chapter.children)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text(section.title),
                    onTap: () => onSelect(section.printedPage),
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