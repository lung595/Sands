# Shipped rings

| File | Origin | Licence | sha256 of the shipped file |
|---|---|---|---|
| `sounds/hourglass.ogg` | synthesised by `generate.py` (bit-exact: a re-render equals the shipped file) | MIT | `7479f41af6f59c6e86590c7fb7b93aa939333507b785343ffbd423bc6e87cd3d` |
| `sounds/silt-chime.ogg` | "Pleasing Bell Sound Effect" by Spring Spring, [OpenGameArt](https://opengameart.org/content/pleasing-bell-sound-effect) | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `49f1c7cb1a760471251fd7743153f9256e55b646037a38c7411fc21932f727f8` |

Silt Chime was downloaded once, by hand (Sands never fetches anything), struck
twice, faded and re-encoded to Opus. The source WAV is not kept in the
repository; its sha256 starts with `3c851939ccf9146e`.

```sh
python3 tools/sounds/generate.py OUT_DIR    # renders hourglass.ogg
python3 tools/sounds/check.py sounds/*.ogg  # codec, duration, size, loop-point edges
sha256sum sounds/*.ogg                      # compare with the table above
```
