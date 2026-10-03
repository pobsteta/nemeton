# nemeton-authored glue (not vendored from RECONFORT). GPL-3, with the rest
# of the nemeton R package. Used by list_s2_items.py, download_s2_item.py and
# the patched run_geodes_download.py.
#
# pygeodes (CNES GEODES client) disables TLS verification unless its module
# constant SSL_CERT_PATH points to an existing CA bundle: RequestMaker sets
# `self.verify = False` otherwise, and its async code paths hard-code
# `ssl=False`. This helper points SSL_CERT_PATH to a CA bundle (certifi, else
# the system default) BEFORE any Geodes object is built, and turns the async
# requests off so every call goes through the verified sync path.
import os
import sys


def _ca_bundle():
    # certifi d'abord (dépendance de requests, présente dans l'env conda),
    # puis le magasin système déclaré par OpenSSL.
    try:
        import certifi
        path = certifi.where()
        if path and os.path.isfile(path):
            return path
    except Exception:
        pass
    try:
        import ssl
        paths = ssl.get_default_verify_paths()
        for path in (paths.cafile, paths.openssl_cafile):
            if path and os.path.isfile(path):
                return path
    except Exception:
        pass
    return None


def enforce_tls_verification(conf=None):
    """Force TLS certificate verification in pygeodes.

    Must be called before `Geodes(conf=...)`. When `conf` is given, async
    requests (which pygeodes runs with `ssl=False`) are disabled on it.
    Returns the CA bundle path, or None when none was found (pygeodes then
    keeps its unverified default and a warning is printed on stderr).
    """
    ca = _ca_bundle()
    if ca is not None:
        import pygeodes.utils.request as _rq
        _rq.SSL_CERT_PATH = ca
    else:
        sys.stderr.write(
            "WARNING (nemeton): no CA bundle found (certifi missing, no system "
            "store); pygeodes will call GEODES WITHOUT TLS certificate "
            "verification.\n")
    if conf is not None:
        conf.use_async_requests = False
    return ca
