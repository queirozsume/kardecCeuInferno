import json
import re
from collections import Counter
from pathlib import Path

import pymupdf


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'O-Ceu-e-o-inferno.pdf'
OUTPUT = ROOT / 'app' / 'assets' / 'book_content.json'
FIRST_PRINTED_PAGE = 11
LAST_PRINTED_PAGE = 407
OMIT_PHYSICAL_PAGES = {4, 408}
HEADER_BAND_BOTTOM = 45


def clean_block(text):
    lines = [re.sub(r'\s+', ' ', line).strip() for line in text.splitlines()]
    lines = [line for line in lines if line]
    paragraphs = []
    for line in lines:
        if paragraphs and paragraphs[-1].endswith('-') and line[:1].islower():
            paragraphs[-1] = paragraphs[-1][:-1] + line
        else:
            paragraphs.append(line)
    return ' '.join(paragraphs)


def running_headers(document):
    counts = Counter()
    for physical_page, page in enumerate(document, start=1):
        if physical_page in OMIT_PHYSICAL_PAGES:
            continue
        for block in page.get_text('blocks', sort=True):
            text = clean_block(block[4])
            if text and block[1] < HEADER_BAND_BOTTOM:
                counts[text] += 1
    return {text for text, count in counts.items() if count > 1}


def page_text(page, physical_page, headers):
    paragraphs = []
    for block in page.get_text('blocks', sort=True):
        text = clean_block(block[4])
        if not text:
            continue
        if block[1] < HEADER_BAND_BOTTOM and text in headers:
            continue
        if (block[1] > page.rect.height - 60 and text == str(physical_page)):
            continue
        paragraphs.append(text)
    return '\n\n'.join(paragraphs)


def main():
    source = pymupdf.open(SOURCE)
    if len(source) != 408:
        raise ValueError(f'Esperava 408 páginas no original; encontrei {len(source)}.')

    headers = running_headers(source)
    pages = []
    for physical_page in range(FIRST_PRINTED_PAGE, LAST_PRINTED_PAGE + 1):
        if physical_page in OMIT_PHYSICAL_PAGES:
            continue
        text = page_text(source[physical_page - 1], physical_page, headers)
        pages.append({'printedPage': physical_page, 'text': text})

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open('w', encoding='utf-8') as output:
        json.dump({'pages': pages}, output, ensure_ascii=False, separators=(',', ':'))

    print(f'Gerado {OUTPUT.relative_to(ROOT)}: {len(pages)} páginas textuais.')
    print(f'Cabeçalhos correntes filtrados: {len(headers)} tipos.')


if __name__ == '__main__':
    main()