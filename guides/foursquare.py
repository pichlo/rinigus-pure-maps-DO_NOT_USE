# -*- coding: utf-8 -*-

# Copyright (C) 2014 Osmo Salomaa, 2018 Rinigus
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""
Listing nearby places using Foursquare.

https://developer.foursquare.com/docs/api/venues/explore
https://developer.foursquare.com/docs/api/venues/details
"""

import copy
import functools
import itertools
import poor
import urllib.parse

from concurrent.futures import ThreadPoolExecutor
from poor.i18n import _

CONF_DEFAULTS = {"sort_by_distance": False}

CLIENT_ID = "VPHEZ1S5LTHEXFI4NUTYQOOONQ4MVP0USSXOFNQC2LWFVCRD"
CLIENT_SECRET = "WEVXECMIGNCHHQLUIUOIWM50IVBHR5QNMTMRGATKTBWAKPXP"

CATEGORIES_URL = "".join((
    "https://api.foursquare.com/v2/venues/categories",
    "?client_id={}".format(CLIENT_ID),
    "&client_secret={}".format(CLIENT_SECRET),
    "&v=20180603",
))

EXPLORE_URL = "".join((
    "https://api.foursquare.com/v2/venues/explore",
    "?client_id={}".format(CLIENT_ID),
    "&client_secret={}".format(CLIENT_SECRET),
    "&v=20180603",
    "&ll={y:.6f},{x:.6f}",
    "&radius={radius:.0f}",
    "&query={query}",
    "&limit=20",
    "&sortByDistance={sort_by_distance}",
))

VENUE_URL = "".join((
    "https://api.foursquare.com/v2/venues/{id}",
    "?client_id={}".format(CLIENT_ID),
    "&client_secret={}".format(CLIENT_SECRET),
    "&v=20180603",
))

cache = {}

def autocomplete_type(query, params=None):
    """Return a list of autocomplete dictionaries matching `query`."""
    def normalize(x):
        # Relax matching for the common case of cafe vs. café.
        return x.lower().replace("é", "e")
    query = normalize(query)
    results = []
    for i, type in enumerate(get_types()):
        pos = normalize(type.label).find(query)
        if pos < 0: continue
        results.append(poor.AttrDict(
            label=type.label,
            order=(pos, type.level, type.label),
        ))
    results.sort(key=lambda x: x.order)
    results = [{"label": x["label"]} for x in results]
    return results[:100]

@functools.lru_cache(1)
def get_types():
    """Return a list of available venue types."""
    results = poor.http.get_json(CATEGORIES_URL)
    results = poor.AttrDict(results)
    def get_recursive(item, level=1):
        children = item.get("categories", [])
        children = list(itertools.chain.from_iterable(
            get_recursive(x, level=level+1) for x in children))
        return [poor.AttrDict(label=item.get("name"), level=level)] + children
    types = list(get_recursive(results.response))
    return list(filter(lambda x: x.label, types))

def get_link(id):
    """Return hyperlink for venue with given `id`."""
    return "https://foursquare.com/v/{}?ref={}".format(id, CLIENT_ID)

def inject_venue_details(results):
    """Edit details of venues in-place to `results`."""
    # We need separate API calls to get venue details.
    # These are "premium" calls, aggressively rate-limited,
    # returning HTTP 403 once the limit has been exhausted.
    # https://developer.foursquare.com/docs/api/troubleshooting/rate-limits
    with ThreadPoolExecutor(10) as executor:
        urls = [VENUE_URL.format(id=x.id) for x in results]
        details = executor.map(poor.http.get_json, urls)
        details = list(map(poor.AttrDict, details))
        venues = [x.response.venue for x in details]
        for i in range(len(results)):
            results[i].description = parse_description(venues[i])
            results[i].link = parse_url(venues[i], results[i].link)
            results[i].text = parse_text(venues[i])
            results[i].phone = parse_phone(venues[i])

def nearby(query, near, radius, params):
    """Return X, Y and a list of dictionaries of places matching `query`."""
    query = urllib.parse.quote_plus(query)
    sort_by_distance = str(int(poor.conf.guides.foursquare.sort_by_distance))
    x, y = prepare_point(near)
    url = EXPLORE_URL.format(**locals())
    with poor.util.silent(KeyError):
        return copy.deepcopy(cache[url])
    results = poor.http.get_json(url)
    results = poor.AttrDict(results)
    results = [poor.AttrDict(
        id=item.venue.id,
        title=item.venue.name,
        address=parse_address(item.venue),
        description=parse_description(item.venue),
        poi_type=parse_type(item.venue),
        postcode=parse_postcode(item.venue),
        text=parse_text(item.venue),
        link=get_link(item.venue.id),
        x=float(item.venue.location.lng),
        y=float(item.venue.location.lat),
    ) for item in itertools.chain.from_iterable(
        group["items"] for group in
        results.response.get("groups", [])
    )]
    with poor.util.silent(Exception, tb=True):
        inject_venue_details(results)
    if results and results[0]:
        cache[url] = copy.deepcopy((x, y, results))
    return x, y, results

def parse_address(venue):
    with poor.util.silent(Exception):
        return ", ".join(venue.location.formattedAddress).strip()
    return ""

def parse_description(venue):
    """Parse description from venue details."""
    description = []
    with poor.util.silent(Exception):
        description.append("{:.1f}/10".format(venue.rating))
    with poor.util.silent(Exception):
        description.append(venue.categories[0].name)
    with poor.util.silent(Exception):
        description.append(venue.location.address)
    description = ", ".join(description)
    tip = parse_tip(venue) or venue.get("description") or ""
    return "{}\n{}".format(description, tip).strip()

def parse_text(venue):
    """Parse blurb text from venue details."""
    lines = []
    subtitle = []
    with poor.util.silent(Exception):
        subtitle.append((
            '{:.1f} / 10'
        ).format(venue.rating))
    lines.append("  ".join(subtitle))
    with poor.util.silent(Exception):
        tip = parse_tip(venue) or venue.get("description") or ""
        if not tip: raise ValueError("No tip")
        lines.append("{}".format(tip))
        lines.append("")
    with poor.util.silent(Exception):
        hours = venue.hours
        open_lines = []
        for i in hours.timeframes:
            s = i.days + ": "
            for j in i.open:
                s += j.renderedTime + " "
            open_lines.append(s.strip())
        if len(open_lines) > 0:
            lines.append(_("Opening hours:"))
            lines.extend(open_lines)
        lines.append("")
    with poor.util.silent(Exception):
        for i in venue.attributes.groups:
            for j in i['items']:
                if j.displayName!=j.displayValue:
                    lines.append("{}: {}".format(j.displayName, j.displayValue))
                else:
                    lines.append(j.displayName)
    return "\n".join(lines)

def parse_tip(venue):
    """Return the top tip for `venue`."""
    if not venue.get("tips"): return None
    if not venue.tips.get("groups"): return None
    langs = [poor.util.get_default_language(), "en", ""]
    for lang in langs:
        for group in venue.tips.groups:
            for item in group["items"]:
                if item.lang == (lang or item.lang):
                    return "“{}”".format(item.text)

def parse_type(venue):
    with poor.util.silent(Exception):
        types=[i.name for i in venue.categories]
        return ", ".join(types).strip()
    return ""

def parse_phone(venue):
    with poor.util.silent(Exception):
        return venue.contact.formattedPhone
    with poor.util.silent(Exception):
        return venue.contact.phone
    return ""

def prepare_point(point):
    """Return geocoded coordinates for `point`."""
    # Foursquare does geocoding too, but not that well.
    if isinstance(point, (list, tuple)):
        return point[0], point[1]
    geocoder = poor.Geocoder("default")
    results = geocoder.geocode(point, dict(limit=1))
    return results[0]["x"], results[0]["y"]

def parse_postcode(venue):
    with poor.util.silent(Exception):
        return venue.location.postalCode
    return ""

def parse_url(venue, default=""):
    with poor.util.silent(Exception):
        return venue.url
    return default
