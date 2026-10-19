# nemeton-authored glue (not vendored from RECONFORT). GPL-3, with the rest
# of the nemeton R package. Used by download_s2_item.py.
#
# pygeodes downloads archives with `session.get(url, stream=True)` and no
# `timeout`: requests then hands urllib3 an explicit `timeout=None`, which
# overrides socket.setdefaulttimeout(). A server that stops sending without
# closing the connection froze the read forever (Couchey, 2026-10-19). This
# helper gives every requests call that sets no timeout a default
# (connect, read) one, so a silent connection raises instead of hanging.
import socket

import requests

_ORIGINAL_REQUEST = requests.Session.request


def enforce_http_timeout(read_s=120.0, connect_s=30.0):
    """Default (connect, read) timeout for requests calls without one.

    Also sets socket.setdefaulttimeout(read_s) for sockets opened outside
    requests. Returns the (connect, read) tuple applied; read_s <= 0 leaves
    everything unchanged and returns None.
    """
    if read_s is None or read_s <= 0:
        return None
    delai = (float(connect_s), float(read_s))

    def request(self, method, url, **kwargs):
        if kwargs.get("timeout") is None:
            kwargs["timeout"] = delai
        return _ORIGINAL_REQUEST(self, method, url, **kwargs)

    requests.Session.request = request
    socket.setdefaulttimeout(float(read_s))
    return delai
