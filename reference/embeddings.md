# Foundation-model embeddings: generic per-unit tools (spec 064)

Model-agnostic helpers for pixel embeddings produced upstream by
foundation models (AlphaEarth Foundations via `alphaearthnemeton`, and
later MAESTRO or ForPT). The core never downloads nor computes an
embedding: it only reads a multi-band SpatRaster (one band per
dimension).
