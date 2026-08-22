# Third-Party Notices

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
