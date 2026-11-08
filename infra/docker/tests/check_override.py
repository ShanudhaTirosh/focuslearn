#!/usr/bin/env python3
"""Strictly parse a generated compose override (duplicate keys are an error) and check it contains exactly what was requested.
Usage: check_override.py FILE HAS_AUTH CAPTCHA CLOUDFLARED_VERSION_OR_EMPTY"""
import sys
import yaml


class Strict(yaml.SafeLoader):
    pass


def no_dupes(loader, node, deep=False):
    keys = [loader.construct_object(k, deep=deep) for k, _ in node.value]
    dup = {k for k in keys if keys.count(k) > 1}
    if dup:
        raise ValueError("duplicate keys: %s" % dup)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)


Strict.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, no_dupes)
Strict.add_constructor("!override", lambda loader, node: loader.construct_sequence(node))

path, has_auth, captcha = sys.argv[1:4]
cf = sys.argv[4] if len(sys.argv) > 4 else ""
d = yaml.load(open(path), Loader=Strict)["services"]
want = {"envoy"} | ({"auth"} if has_auth == "1" else set()) | ({"cloudflared"} if cf else set())
assert set(d) == want, (set(d), want)
assert d["envoy"]["ports"] == ["127.0.0.1:8000:8000"], d["envoy"]
if has_auth == "1":
    env = d["auth"]["environment"]
    assert env["GOTRUE_PASSWORD_MIN_LENGTH"] == "10", env
    assert ("GOTRUE_SECURITY_CAPTCHA_SECRET" in env) == (captcha == "1"), env
    assert (env.get("GOTRUE_SECURITY_CAPTCHA_ENABLED") == "true") == (captcha == "1"), env
    assert env.get("GOTRUE_SECURITY_CAPTCHA_PROVIDER", "turnstile") == "turnstile"
if cf:
    c = d["cloudflared"]
    assert c["image"] == "cloudflare/cloudflared:" + cf, c
    assert "envoy" in c["depends_on"], c
    assert c["user"] == "${CLOUDFLARED_UID}:${CLOUDFLARED_GID}", c
