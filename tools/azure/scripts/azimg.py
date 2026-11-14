#!/usr/bin/env python3
"""
azimg: generate and edit images with an Azure GPT-image deployment
(gpt-image-1, gpt-image-1.5, gpt-image-2, ...) on Azure OpenAI / Microsoft Foundry.

Commands:
  configure   Save endpoint, key, deployment (user config or project .env)
  check       Show resolved config (key masked) and the URL that will be called
  generate    Text to image
  edit        Image(s) + text to image (reference images, character consistency)
  batch       Run a shots file (YAML/JSON) and write a manifest.json

Only the Python standard library is required. Pillow is needed for --fit.
PyYAML is needed for YAML shot files.
"""
import argparse, base64, getpass, hashlib, json, mimetypes, os, ssl, stat, sys, time, uuid
import urllib.error, urllib.parse, urllib.request
from datetime import datetime, timezone
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
USER_CONFIG = Path(os.environ.get("AZIMG_CONFIG", Path.home() / ".config" / "azure-image-gen" / "config.json"))
DEFAULT_API_VERSION = "2025-04-01-preview"
ENV_KEYS = {
    "endpoint": "AZURE_IMAGE_ENDPOINT",
    "api_key": "AZURE_IMAGE_API_KEY",
    "deployment": "AZURE_IMAGE_DEPLOYMENT",
    "api_version": "AZURE_IMAGE_API_VERSION",
}
EXIT_CONFIG, EXIT_HTTP, EXIT_BLOCKED = 2, 4, 3


# ---------------------------------------------------------------- config
def _read_dotenv(path):
    out = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def load_config():
    """Priority: environment > project .env > user config file."""
    cfg = {}
    if USER_CONFIG.exists():
        cfg.update(json.loads(USER_CONFIG.read_text(encoding="utf-8")))
    dotenv = _read_dotenv(Path.cwd() / ".env")
    for k, env in ENV_KEYS.items():
        if dotenv.get(env):
            cfg[k] = dotenv[env]
    for k, env in ENV_KEYS.items():
        if os.environ.get(env):
            cfg[k] = os.environ[env]
    return cfg


def resolve(cfg):
    """Turn whatever endpoint the user pasted into a callable target.

    Accepts any of:
      https://RES.openai.azure.com
      https://RES.cognitiveservices.azure.com
      https://RES.services.ai.azure.com/openai/v1
      https://RES.openai.azure.com/openai/deployments/DEP/images/generations?api-version=X  (Azure "Target URI")
    """
    ep = (cfg.get("endpoint") or "").strip()
    if not ep:
        die("No endpoint configured. Run: azimg.py configure", EXIT_CONFIG)
    if not cfg.get("api_key"):
        die("No API key configured. Run: azimg.py configure", EXIT_CONFIG)
    u = urllib.parse.urlparse(ep if "://" in ep else "https://" + ep)
    host = f"{u.scheme}://{u.netloc}"
    path = u.path.rstrip("/")
    query = urllib.parse.parse_qs(u.query)
    dep = cfg.get("deployment")
    ver = cfg.get("api_version") or (query.get("api-version", [None])[0])

    if "/openai/v1" in path:
        mode = "v1"
    elif "/openai/deployments/" in path:
        mode = "classic"
        dep = dep or path.split("/openai/deployments/")[1].split("/")[0]
    else:
        mode = cfg.get("mode") or "classic"
    if not dep:
        die("No deployment name. Pass it in configure (for example gpt-image-2).", EXIT_CONFIG)
    if mode == "classic" and not ver:
        ver = DEFAULT_API_VERSION
    return {"mode": mode, "host": host, "deployment": dep, "api_version": ver}


def url_for(t, op):
    if t["mode"] == "v1":
        url = f"{t['host']}/openai/v1/images/{op}"
        if t.get("api_version") and t["api_version"] == "preview":
            url += "?api-version=preview"
        return url
    return f"{t['host']}/openai/deployments/{t['deployment']}/images/{op}?api-version={t['api_version']}"


def mask(key):
    return "(not set)" if not key else key[:4] + "*" * 8 + key[-4:]


# ---------------------------------------------------------------- http
def _ssl_ctx():
    ca = os.environ.get("AZIMG_CA_BUNDLE")
    return ssl.create_default_context(cafile=ca) if ca else ssl.create_default_context()


def _send(req, retries=4):
    delay = 5
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=300, context=_ssl_ctx()) as r:
                rid = r.headers.get("apim-request-id") or r.headers.get("x-request-id")
                return json.loads(r.read().decode("utf-8")), rid
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            try:
                err = json.loads(body).get("error", {})
            except Exception:
                err = {"message": body[:500]}
            code = str(err.get("code") or "")
            msg = err.get("message") or body[:500]
            if e.code in (429, 500, 502, 503, 504) and attempt < retries:
                wait = int(e.headers.get("Retry-After", delay)) if e.headers else delay
                print(f"[azimg] HTTP {e.code}, retrying in {wait}s", file=sys.stderr)
                time.sleep(wait); delay *= 2
                continue
            blocked = any(s in (code + msg).lower() for s in ("content_policy", "contentfilter", "content_filter", "moderation", "responsibleai"))
            if blocked:
                die(f"Blocked by Azure content filter. Rephrase the prompt. Details: {msg}", EXIT_BLOCKED)
            hint = {401: "Wrong or expired API key.",
                    403: "Key has no access to this resource, or network rules block you.",
                    404: "Deployment or URL not found. Check the deployment name and endpoint style (classic vs v1)."}.get(e.code, "")
            die(f"HTTP {e.code} {code}: {msg} {hint}".strip(), EXIT_HTTP)
        except urllib.error.URLError as e:
            if attempt < retries:
                time.sleep(delay); delay *= 2; continue
            die(f"Network error: {e.reason}", EXIT_HTTP)


def _json_request(url, key, payload):
    data = json.dumps(payload).encode("utf-8")
    return urllib.request.Request(url, data=data, method="POST",
                                  headers={"api-key": key, "Content-Type": "application/json"})


def _multipart_request(url, key, fields, files):
    boundary = "----azimg" + uuid.uuid4().hex
    body = bytearray()
    for k, v in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
    for name, path in files:
        mime = mimetypes.guess_type(str(path))[0] or "image/png"
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; "
                 f"filename=\"{Path(path).name}\"\r\nContent-Type: {mime}\r\n\r\n").encode()
        body += Path(path).read_bytes() + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return urllib.request.Request(url, data=bytes(body), method="POST",
                                  headers={"api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"})


# ---------------------------------------------------------------- core
def _params(args, t):
    p = {"prompt": args.prompt, "n": args.n}
    if t["mode"] == "v1":
        p["model"] = t["deployment"]
    for k in ("size", "quality", "output_format", "background", "output_compression"):
        v = getattr(args, k, None)
        if v not in (None, ""):
            p[k] = v
    return p


def _cache_key(t, params, refs):
    h = hashlib.sha256()
    h.update(json.dumps({"dep": t["deployment"], **{k: v for k, v in params.items() if k != "model"}}, sort_keys=True).encode())
    for r in refs:
        h.update(hashlib.sha256(Path(r).read_bytes()).digest())
    return h.hexdigest()[:16]


def _outputs(out, n):
    out = Path(out)
    if n == 1:
        return [out]
    return [out.with_name(f"{out.stem}_{i + 1}{out.suffix}") for i in range(n)]


def _fit(path, size):
    try:
        from PIL import Image, ImageOps
    except ImportError:
        die("--fit needs Pillow: pip install pillow", EXIT_CONFIG)
    w, h = (int(x) for x in size.lower().split("x"))
    orig = path.with_name(path.stem + ".orig" + path.suffix)
    path.replace(orig)
    im = Image.open(orig).convert("RGB")
    ImageOps.fit(im, (w, h), method=Image.LANCZOS, centering=(0.5, 0.45)).save(path)


def run(args, refs=None, mask_path=None):
    refs = refs or []
    cfg = load_config()
    t = resolve(cfg)
    params = _params(args, t)
    key = _cache_key(t, {**params, "_fit": args.fit}, refs + ([mask_path] if mask_path else []))
    outs = _outputs(args.out, args.n)
    side0 = Path(str(outs[0]) + ".json")
    if not args.force and all(o.exists() for o in outs) and side0.exists():
        if json.loads(side0.read_text()).get("cache_key") == key:
            print(f"[azimg] cached: {', '.join(map(str, outs))}")
            return outs
    if args.dry_run:
        print(json.dumps({"url": url_for(t, "edits" if refs else "generations"), "params": params,
                          "refs": [str(r) for r in refs], "out": [str(o) for o in outs]}, indent=2))
        return []
    if refs:
        files = [("image" if len(refs) == 1 else "image[]", r) for r in refs]
        if mask_path:
            files.append(("mask", mask_path))
        req = _multipart_request(url_for(t, "edits"), cfg["api_key"], {k: str(v) for k, v in params.items()}, files)
    else:
        req = _json_request(url_for(t, "generations"), cfg["api_key"], params)
    t0 = time.time()
    resp, rid = _send(req)
    data = resp.get("data") or []
    if not data:
        die(f"No image in response: {json.dumps(resp)[:400]}", EXIT_HTTP)
    for o, item in zip(outs, data):
        o.parent.mkdir(parents=True, exist_ok=True)
        if item.get("b64_json"):
            o.write_bytes(base64.b64decode(item["b64_json"]))
        elif item.get("url"):
            with urllib.request.urlopen(item["url"], timeout=120, context=_ssl_ctx()) as r:
                o.write_bytes(r.read())
        if args.fit:
            _fit(o, args.fit)
        meta = {"ai_generated": True, "tool": "azure-image-gen", "deployment": t["deployment"], "mode": t["mode"],
                "prompt": args.prompt, "revised_prompt": item.get("revised_prompt"),
                "params": {k: v for k, v in params.items() if k not in ("prompt", "model")},
                "references": [str(r) for r in refs], "fit": args.fit, "request_id": rid,
                "usage": resp.get("usage"), "created": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "seconds": round(time.time() - t0, 1), "cache_key": key}
        Path(str(o) + ".json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[azimg] saved: {', '.join(map(str, outs))} ({round(time.time() - t0, 1)}s)")
    return outs


# ---------------------------------------------------------------- batch
def _load_structured(path):
    text = Path(path).read_text(encoding="utf-8")
    if str(path).endswith((".yaml", ".yml")):
        try:
            import yaml
        except ImportError:
            die("YAML shot files need PyYAML: pip install pyyaml", EXIT_CONFIG)
        return yaml.safe_load(text)
    return json.loads(text)


def _style_text(style):
    if not style:
        return ""
    presets = json.loads((SKILL_DIR / "assets" / "styles.json").read_text(encoding="utf-8"))
    return presets.get(style, {}).get("prompt", style)


def build_prompt(shot, style_text, characters, rules):
    parts = []
    if style_text:
        parts.append(f"Style: {style_text}")
    parts.append(f"Scene: {shot['prompt'].strip()}")
    descs = [f"{c}: {characters[c]['look'].strip()}" for c in shot.get("characters", []) if c in characters]
    if descs:
        parts.append("Characters (draw them exactly like this every time): " + " | ".join(descs))
    if rules:
        parts.append("Rules: " + rules)
    return "\n".join(parts)


def batch(a):
    spec = _load_structured(a.shots)
    base = Path(a.shots).resolve().parent
    out_dir = (base / spec.get("out_dir", "images")).resolve()
    def _abs_refs(cmap, root):
        out = {}
        for cid, c in (cmap or {}).items():
            c = dict(c)
            if c.get("ref"):
                c["ref"] = str((root / c["ref"]).resolve())
            out[cid] = c
        return out
    chars = _abs_refs(spec.get("characters", {}), base)
    if spec.get("characters_file"):
        cf = (base / spec["characters_file"]).resolve()
        chars = {**_abs_refs(_load_structured(cf).get("characters", {}), cf.parent), **chars}
    style = _style_text(spec.get("style"))
    rules = spec.get("rules", "No text, letters, numbers, logos, signs with words or watermarks anywhere in the image.")
    d = spec.get("defaults", {})
    manifest_path = out_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    failed = []
    for shot in spec["shots"]:
        sid = shot["id"]
        if a.only and sid not in a.only:
            continue
        refs = [str((base / r).resolve()) for r in shot.get("refs", [])]
        if shot.get("use_character_refs"):
            refs += [chars[c]["ref"] for c in shot.get("characters", []) if chars.get(c, {}).get("ref")]
        missing = [r for r in refs if not Path(r).exists()]
        if missing:
            die(f"Shot '{sid}': reference image not found: {', '.join(missing)}", EXIT_CONFIG)
        ns = argparse.Namespace(
            prompt=build_prompt(shot, style, chars, rules), n=1, out=str(out_dir / f"{sid}.png"),
            size=shot.get("size", d.get("size")), quality=shot.get("quality", d.get("quality")),
            output_format=None, background=None, output_compression=None,
            fit=shot.get("fit", d.get("fit")), force=a.force, dry_run=a.dry_run)
        try:
            outs = run(ns, refs=refs)
        except SystemExit as e:
            if e.code == EXIT_BLOCKED or a.keep_going:
                failed.append(sid); continue
            raise
        if outs:
            manifest[sid] = {"file": str(outs[0].relative_to(out_dir)), "lines": shot.get("lines", []),
                             "role": shot.get("role", "scene"), "characters": shot.get("characters", [])}
        time.sleep(a.pause)
    if not a.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"[azimg] manifest: {manifest_path}")
    if failed:
        print(f"[azimg] failed or blocked shots: {', '.join(failed)}", file=sys.stderr)
        sys.exit(EXIT_BLOCKED)


# ---------------------------------------------------------------- configure / check
def configure(a):
    endpoint = a.endpoint or input("Endpoint URL (resource URL or the full Target URI from Azure): ").strip()
    deployment = a.deployment
    if not deployment and "/openai/deployments/" not in endpoint:
        deployment = input("Deployment name (for example gpt-image-2): ").strip()
    key = a.key or os.environ.get("AZURE_IMAGE_API_KEY") or getpass.getpass("API key (hidden): ").strip()
    values = {"endpoint": endpoint, "api_key": key}
    if deployment:
        values["deployment"] = deployment
    if a.api_version:
        values["api_version"] = a.api_version
    resolve(values)  # validate shape before saving
    if a.scope == "project":
        env = Path.cwd() / ".env"
        lines = [l for l in (env.read_text(encoding="utf-8").splitlines() if env.exists() else [])
                 if not any(l.startswith(v + "=") for v in ENV_KEYS.values())]
        lines += [f"{ENV_KEYS[k]}={v}" for k, v in values.items()]
        env.write_text("\n".join(lines) + "\n", encoding="utf-8")
        os.chmod(env, stat.S_IRUSR | stat.S_IWUSR)
        gi = Path.cwd() / ".gitignore"
        if ".env" not in (gi.read_text(encoding="utf-8").split() if gi.exists() else []):
            with gi.open("a", encoding="utf-8") as f:
                f.write("\n.env\n")
        print(f"[azimg] saved to {env} (added to .gitignore)")
    else:
        USER_CONFIG.parent.mkdir(parents=True, exist_ok=True)
        USER_CONFIG.write_text(json.dumps(values, indent=2), encoding="utf-8")
        os.chmod(USER_CONFIG, stat.S_IRUSR | stat.S_IWUSR)
        print(f"[azimg] saved to {USER_CONFIG}")
    check(argparse.Namespace(live=False))


def check(a):
    cfg = load_config()
    t = resolve(cfg)
    print(json.dumps({"endpoint": cfg.get("endpoint"), "api_key": mask(cfg.get("api_key")), **t,
                      "generate_url": url_for(t, "generations"), "edit_url": url_for(t, "edits")}, indent=2))
    if a.live:
        ns = argparse.Namespace(prompt="A small red bicycle leaning on a brick wall, flat illustration, no text.",
                                n=1, out="azimg-test.png", size="1024x1024", quality="low", output_format=None,
                                background=None, output_compression=None, fit=None, force=True, dry_run=False)
        run(ns)


def die(msg, code=1):
    print(f"[azimg] ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    c = sub.add_parser("configure", help="save endpoint, key and deployment")
    c.add_argument("--endpoint"); c.add_argument("--deployment"); c.add_argument("--key")
    c.add_argument("--api-version", dest="api_version")
    c.add_argument("--scope", choices=["user", "project"], default="user")

    k = sub.add_parser("check", help="show config and target URL")
    k.add_argument("--live", action="store_true", help="also make one small low-quality test image")

    for name in ("generate", "edit"):
        g = sub.add_parser(name)
        g.add_argument("--prompt", required=True)
        g.add_argument("--out", required=True)
        g.add_argument("--n", type=int, default=1)
        g.add_argument("--size", help="1024x1024, 1536x1024, 1024x1536 or auto")
        g.add_argument("--quality", help="low, medium, high or auto")
        g.add_argument("--output-format", dest="output_format", choices=["png", "jpeg", "webp"])
        g.add_argument("--output-compression", dest="output_compression", type=int)
        g.add_argument("--background", choices=["auto", "opaque", "transparent"])
        g.add_argument("--fit", help="crop and resize after generation, for example 1920x1080")
        g.add_argument("--force", action="store_true"); g.add_argument("--dry-run", action="store_true")
        if name == "edit":
            g.add_argument("--image", action="append", required=True, help="reference image, repeatable")
            g.add_argument("--mask")

    b = sub.add_parser("batch", help="run a shots file and write manifest.json")
    b.add_argument("shots"); b.add_argument("--only", nargs="*")
    b.add_argument("--force", action="store_true"); b.add_argument("--dry-run", action="store_true")
    b.add_argument("--keep-going", action="store_true"); b.add_argument("--pause", type=float, default=1.0)

    a = ap.parse_args()
    if a.cmd == "configure":
        configure(a)
    elif a.cmd == "check":
        check(a)
    elif a.cmd == "generate":
        run(a)
    elif a.cmd == "edit":
        run(a, refs=a.image, mask_path=a.mask)
    elif a.cmd == "batch":
        batch(a)


if __name__ == "__main__":
    main()
