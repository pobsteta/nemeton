"""GEDI L2A sur la France, pour le jeu de covariables G (spec 054 lot 1-ter).

Chaîne : CMR (orbites qui survolent la France) -> une orbite sur PAS ->
Harmony « sds/trajectory-subsetter » (découpe au contour de la France, 6
variables par faisceau) -> téléchargement -> tirs filtrés comme dans
l'article (quality_flag = 1, degrade_flag = 0, rh98 < 65 m) -> un CSV
compact par année. Les HDF5 sont supprimés après extraction.

Sous-échantillonnage : on vise des moyennes et écarts-types par SER x année.
Une orbite sur 5 laisse des dizaines de milliers de tirs valides par SER et
par an ; GEDI est lui-même un échantillon. Volume total : environ 15 Go
transitoires, au lieu de 75 Go.

Pré-requis : ~/.netrc avec urs.earthdata.nasa.gov ; venv avec harmony-py,
h5py, numpy (~/.cache/nemeton/gedi/venv). Usage :
    venv/bin/python data-raw/gedi_l2a_france.py 2021 [2022 ...]
"""
import base64
import csv
import json
import netrc
import os
import subprocess
import sys
import time
import urllib.request

import h5py
import numpy as np
from harmony import Client, Collection, Request

CACHE = os.path.expanduser(os.environ.get("NEMETON_GEDI_CACHE", "~/.cache/nemeton/gedi"))
COLLECTION = "C2142771958-LPCLOUD"  # GEDI02_A v002, LP DAAC (cloud)
FRANCE = os.path.join(CACHE, "france.geojson")
BBOX = "-5.2,41.3,9.6,51.1"
PAS = int(os.environ.get("NEMETON_GEDI_PAS", "5"))
LOT = 40  # orbites par job Harmony
BEAMS = ["BEAM0000", "BEAM0001", "BEAM0010", "BEAM0011",
         "BEAM0101", "BEAM0110", "BEAM1000", "BEAM1011"]
VARS = ["rh", "quality_flag", "degrade_flag", "lat_lowestmode",
        "lon_lowestmode", "elev_lowestmode"]


def jeton_earthdata():
    """Jeton Earthdata depuis ~/.netrc (API find_or_create_token). Le client
    harmony-py authentifie mal ses POST multipart (découpe par contour) par
    simple redirection : une page HTML revient au lieu du JSON. Avec un jeton,
    la requête passe (constaté le 2026-10-01)."""
    login, _, pwd = netrc.netrc().authenticators("urs.earthdata.nasa.gov")
    req = urllib.request.Request(
        "https://urs.earthdata.nasa.gov/api/users/find_or_create_token", method="POST",
        headers={"Authorization": "Basic " + base64.b64encode(f"{login}:{pwd}".encode()).decode()})
    return json.load(urllib.request.urlopen(req))["access_token"]


def orbites(annee):
    """Identifiants CMR des orbites de l'année survolant la France, triés."""
    ids, page = [], 1
    while True:
        url = ("https://cmr.earthdata.nasa.gov/search/granules.json"
               f"?collection_concept_id={COLLECTION}&bounding_box={BBOX}"
               f"&temporal={annee}-01-01T00:00:00Z,{annee}-12-31T23:59:59Z"
               f"&page_size=2000&page_num={page}&sort_key=start_date")
        e = json.load(urllib.request.urlopen(url))["feed"]["entry"]
        ids += [x["id"] for x in e]
        if len(e) < 2000:
            return ids
        page += 1


def extraire(h5, sortie):
    """Tirs valides d'un fichier découpé -> lignes CSV ; nombre de tirs."""
    n = 0
    with h5py.File(h5) as f:
        for b in BEAMS:
            if b not in f or "rh" not in f[b]:
                continue
            g = f[b]
            rh = g["rh"][:]
            ok = ((g["quality_flag"][:] == 1) & (g["degrade_flag"][:] == 0)
                  & (rh[:, 98] < 65))
            if not ok.any():
                continue
            cols = [g["lat_lowestmode"][:][ok], g["lon_lowestmode"][:][ok],
                    rh[ok, 98], rh[ok, 70], g["elev_lowestmode"][:][ok]]
            for row in zip(*cols):
                sortie.writerow([f"{row[0]:.6f}", f"{row[1]:.6f}",
                                 f"{row[2]:.2f}", f"{row[3]:.2f}", f"{row[4]:.2f}"])
            n += int(ok.sum())
    return n


def telecharger(url, dest):
    """curl avec ~/.netrc et cookies : le client harmony-py échoue sur la
    redirection d'authentification des résultats (constaté le 2026-10-01)."""
    ck = os.path.join(CACHE, "cookies.txt")
    r = subprocess.run(["curl", "-s", "-n", "-L", "-c", ck, "-b", ck, "--retry", "5",
                        "-o", dest, "-w", "%{http_code}", url],
                       capture_output=True, text=True)
    return r.stdout.strip() == "200" and os.path.getsize(dest) > 0


def traiter_annee(annee, client):
    sortie_csv = os.path.join(CACHE, f"gedi_l2a_{annee}.csv")
    fait = os.path.join(CACHE, f"gedi_l2a_{annee}.lots")
    lots_faits = set(open(fait).read().split()) if os.path.exists(fait) else set()
    ids = orbites(annee)[::PAS]
    print(f"{annee} : {len(ids)} orbites retenues (une sur {PAS})", flush=True)
    neuf = not os.path.exists(sortie_csv)
    with open(sortie_csv, "a", newline="") as fcsv:
        w = csv.writer(fcsv)
        if neuf:
            w.writerow(["lat", "lon", "rh98", "rh70", "elev"])
        for i in range(0, len(ids), LOT):
            cle = f"{i}"
            if cle in lots_faits:
                continue
            req = Request(collection=Collection(id=COLLECTION),
                          granule_id=ids[i:i + LOT], shape=FRANCE,
                          variables=[f"/{b}/{v}" for b in BEAMS for v in VARS])
            t0 = time.time()
            job = client.submit(req)
            client.wait_for_processing(job, show_progress=False)
            liens = [l["href"] for l in client.result_json(job)["links"]
                     if l.get("rel") == "data"]
            n = 0
            for u in liens:
                dest = os.path.join(CACHE, "tmp.h5")
                if telecharger(u, dest):
                    n += extraire(dest, w)
                    os.remove(dest)
            fcsv.flush()
            with open(fait, "a") as fl:
                fl.write(cle + "\n")
            print(f"  lot {i // LOT + 1}/{-(-len(ids) // LOT)} : {len(liens)} fichiers, "
                  f"{n} tirs valides, {time.time() - t0:.0f} s", flush=True)


if __name__ == "__main__":
    client = Client(token=jeton_earthdata())
    for a in sys.argv[1:]:
        traiter_annee(int(a), client)
