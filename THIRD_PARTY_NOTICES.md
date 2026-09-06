# Third-Party Notices

## Project Website Fonts

The public project website self-hosts [Oswald](https://github.com/googlefonts/OswaldFont)
and [Courier Prime](https://github.com/quoteunquoteapps/CourierPrime) from the
[Google Fonts repository](https://github.com/google/fonts). Both font families
are distributed under the SIL Open Font License 1.1. The exact license texts
are retained next to the website font files under `docs/assets/fonts/`. The
website does not contact Google Fonts at runtime.

## Bundled Watermark Fonts

The watermark editor uses a curated, platform-independent font set so previews
and exported images share the same shaping and glyph assets on Windows, macOS,
and Android. The following fonts are bundled under the SIL Open Font License
1.1:

- [LXGW ZhenKai](https://github.com/lxgw/LxgwZhenKai) (`LXGW ZhenKai GB`),
  by LXGW.
- [Great Vibes](https://github.com/TypeSETit/GreatVibes), by Robert E. Leuschke.
- [Caveat](https://github.com/googlefonts/caveat), by Pablo Impallari.
- [Allura](https://github.com/TypeSETit/Allura), by Robert E. Leuschke.
- [Ma Shan Zheng](https://github.com/googlefonts/mashanzheng), by Ma Shan Zheng.
- [Zhi Mang Xing](https://github.com/googlefonts/zhimangxing), by Zhi Mang Xing.
- [Long Cang](https://github.com/googlefonts/longcang), by Long Cang.

The six newly curated files are redistributed from the
[Google Fonts repository](https://github.com/google/fonts), which records each
font's original upstream project and authorship. The exact upstream records and
complete license texts are retained under `licenses/fonts/`. Font files are
stored under `fonts/watermark/`; `LXGW ZhenKai GB` remains at its existing
`fonts/` path. No font is downloaded at runtime and no platform system font is
used as the primary watermark face.

## Danbooru/e621 Tag Data

The bundled `assets/databases/tag_catalog.db` is generated from the complete
`danbooru_e621_merged.csv` snapshot distributed by
[ComfyUI-Lora-Manager](https://github.com/willmiao/ComfyUI-Lora-Manager).
The tag data originates from
[DraconicDragon/dbr-e621-lists-archive](https://github.com/DraconicDragon/dbr-e621-lists-archive).
Both Danbooru categories `0`, `1`, `3`, `4`, and `5` and e621 categories `7`
through `12`, `14`, and `15` are imported. The source snapshot, URL, SHA256,
expected record counts, and included category set are locked in
`tool/tag_catalog/source_lock.json`.

The source data is dedicated to the public domain under the Unlicense:

> This is free and unencumbered software released into the public domain.
> Anyone is free to copy, modify, publish, use, compile, sell, or distribute
> this software, either in source code form or as a compiled binary, for any
> purpose, commercial or non-commercial, and by any means.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
> ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
> WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

ComfyUI-Lora-Manager is GPL-3.0 licensed. Only its pinned copy of the
Unlicense tag dataset is used here; no Python, JavaScript, or other GPL
implementation code from that project is included in this application.

The custom and hybrid random-tag extension uses declarative semantic matching
rules over this same complete bundled catalog. The rules, catalog version,
source URL, source date, SHA256, complete counts, license, and resolved category
counts are locked in `tool/random_tag_library/source_lock.json`.

## NovelAI Official Random Wordlist Data

The official random mode includes a data-only extraction of the random
wordlists published in the NovelAI image-generation frontend at
[novelai.net/image](https://novelai.net/image). NovelAI and its frontend content
are © Anlatan. The project does not include NovelAI frontend JavaScript or claim
a license to NovelAI trademarks or service code.

The bundled data preserves 5,960 original records in 118 source arrays,
including order, duplicate records, weights, and condition fields, so the client
can reproduce the public frontend's random-prompt behavior offline. The exact
source bundle name, source SHA256, output SHA256, array counts, and record counts
are pinned in `tool/random_tag_library/source_lock.json`; deterministic rebuild
and verification tools live in `tool/random_tag_library/`.

## Danbooru Co-occurrence Data

The optional local related-tag data pack published by this project is generated
only from `danbooru_tags_cooccurrence.csv` in the
[newtextdoc1111/danbooru-tag-csv](https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv)
dataset. It is not bundled in the application package. The app downloads the
project-built immutable prerelease asset in the background when the feature is
enabled, and users can disable automatic downloads or remove the installed
copy. The upstream README declares the dataset under the MIT License. The
pinned revision (`2dadc5bfcbcc7f255e68e9003ed543fb1b97904f`), source URL,
source SHA256, deterministic database/archive hashes, and complete record count
are recorded in `tool/database/cooccurrence_source_lock.json`. The dataset's
separate base tag CSV is not used by this application.

## Optional ffdkj Chinese Dictionary

The optional `tag.sqlite` Chinese dictionary is not bundled or redistributed.
After explicit user confirmation, the application downloads it directly from
[ffdkj/ComfyUI_Danbooru_Tag_Assistant](https://github.com/ffdkj/ComfyUI_Danbooru_Tag_Assistant).
That upstream repository did not declare a license when this integration was
implemented.

## NovelAI QuickTagCloud Codex Content

The Codex Gallery reads public, fixed codex metadata, entries, and media at
runtime from [AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag) and its
published QuickTagCloud data endpoints. This content is not bundled with or
mirrored by the application. Release files are cached locally by their upstream
release identifier only after manifest size and SHA256 verification. External
codexes are fetched directly from their declared source and are not stored in
the versioned release cache. User favorites and recent history are local
application data and retain the displayed attribution.

The upstream author granted this project free, non-exclusive, revocable
permission in [AgIzT/NovelAI-Tag issue #27](https://github.com/AgIzT/NovelAI-Tag/issues/27)
to access and display all public codex data and images. Every codex's complete
`contributors[]` attribution is preserved in the interface. The integration
does not upload submissions, mutate community likes, bundle upstream content,
or operate a content mirror. The `mengshen_r18` external codex is requested
only from the DreamGod source declared by upstream and is never substituted
with the QuickTagCloud release copy.

## OpenCC Traditional-to-Simplified Character Data

Traditional Chinese tag queries are normalized for the optional Simplified
Chinese ffdkj dictionary with `TSCharacters.txt` from
[BYVoid/OpenCC](https://github.com/BYVoid/OpenCC), pinned to commit
`025f371dc76b598d77384fbdab90c937471844d8`. The mapping and its license are
bundled under `assets/data/opencc/`. OpenCC is licensed under the Apache License
2.0; the complete license text is included alongside the mapping.

## Pica

This project contains a pure Dart port of the Lanczos3 resize pipeline from
[Pica](https://github.com/nodeca/pica).

The MIT License

Copyright (C) 2014-2017 by Vitaly Puzrin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

## pi Agent

The Agent loop, state management, harness, compaction, and JSONL session code
under `lib/core/agent/` contains a Dart adaptation of the `packages/agent`
component from [pi](https://github.com/earendil-works/pi), formerly published
as `badlogic/pi-mono`. Agent model reasoning metadata and provider request
mapping under `lib/presentation/agent_chat/` and
`lib/presentation/prompt_assistant/` are adapted from `@earendil-works/pi-ai`
0.84.4. The core adaptation was reviewed against repository revision
`8fa7eebd235355522c8104166b4f1f959b4e2f10`.

MIT License

Copyright (c) 2025 Mario Zechner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
## DLSS-COM and NVIDIA NGX

The NR bridge and GPU texture transfer code under `windows/dlss/` are adapted
from [MYT-YEP/DLSS-COM](https://github.com/MYT-YEP/DLSS-COM), revision
`3aeca71b28695118894bd04fc64f42b45e03004b`, under the MIT License.
The complete notice is in `licenses/dlss/dlss-com.txt` and is installed with
the Windows application.

The native worker links NVIDIA's NGX SDK from
[NVIDIA/DLSS](https://github.com/NVIDIA/DLSS), revision
`a291cc7d2cc642a51566f3dfd5376f635cd1b284`. Build inputs are pinned and SHA-256
verified in `windows/dlss/ngx_sdk.cmake`. The SDK's NVIDIA license is downloaded
from the same revision and installed as `licenses/NVIDIA-DLSS.txt`.
Model runtime DLLs are downloaded separately through the application's runtime
installer; they are not included in this repository.
