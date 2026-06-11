# FORDEAD pixel CRSWIR diagnostic (spec 008 section 14.4, L2)

Reader side of the FORDEAD diagnostic bundle persisted by
\[run_fordead_dieback()\] (L1, spec 008 section 14.3). Given a clicked
pixel it returns the observed CRSWIR series, the harmonic-model
prediction, the anomaly threshold band and the per-date anomaly flag -
the data behind the click-to-diagnose plot of the FORDEAD map.
