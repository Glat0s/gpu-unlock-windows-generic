#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Build AD102 (and/or GA102) Booter Load, Booter Unload, and GSP boot assets from NVIDIA 610.43.03 source."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
import tarfile
import zlib
from pathlib import Path

MANIFEST = Path(__file__).with_name("artifacts-610.43.03.json")

MAGIC = 0x314C5442
LABELS = (
    "IMAGE_PROD",
    "HEADER_PROD",
    "SIG_PROD",
    "PATCH_LOC",
    "PATCH_META",
    "NUM_SIGS",
)

PINNED_GA102 = {
    "g_bindata_kgspGetBinArchiveBooterLoadUcode_GA102.c": "04cd3db7f670adc4efd79d2e76217bb809fffddfbd6f1af884cde2af26dd39af",
    "g_bindata_kgspGetBinArchiveGspRmBoot_GA102.c": "35e5aa9075ad3898b6022ffd5820c953d809caa7dabd530cfc1a83dc2a67c5bd",
}

PINNED_AD102 = {
    "g_bindata_kgspGetBinArchiveBooterLoadUcode_AD102.c": "0504f640bc36d03c3b617b1d80cf6eee1c8022cdfffb52ed22405aaa316a1460",
    "g_bindata_kgspGetBinArchiveGspRmBoot_AD102.c": "da110719ed6b680f26f3f7158f6731d1ff20fa859857238e23ac4935bd4cd91c",
}

PINNED_DERIVED_AD102 = {
    "booter_load_ad102.bin": "6ee05b20e1dc244c08c052f36ef28469b8d09f4955d1fe33e48a179e11a7fd49",
    "gsp_boot_ad102.bin": "45d6335a8185d6ff13e8d1484cea73f68d3d13aa1c19dc080ed1c3482dd5bac0",
    "gsp_boot_desc_ad102.bin": "83f8f3f1f5f9496e0ea8fc7103c2beb64d0b6de2f5ffe725f13514de5a95fa42",
}


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _array_bytes(text: str, label: str) -> tuple[bytes, bool, int]:
    marker = f"BINDATA_LABEL_{label}_data[]"
    if text.count(marker) != 1:
        raise ValueError(f"missing or duplicate {label}")
    start = text.index(marker)
    window = text[max(0, start - 400) : start]
    compression = re.findall(r"COMPRESSION: (YES|NO)", window)
    sizes = re.findall(r"DATA SIZE \(bytes\): (\d+)", window)
    if not compression or not sizes:
        raise ValueError(f"missing storage declaration for {label}")
    expected = int(sizes[-1])
    compressed = compression[-1] == "YES"
    if not 0 < expected <= 16 * 1024 * 1024:
        raise ValueError("asset exceeds extraction limit")
    declaration = re.match(
        re.escape(marker) + r"\s*=\s*\{([^}]*)\};", text[start:], re.S
    )
    if not declaration:
        raise ValueError("malformed byte-array declaration")
    tokens = declaration[1].strip().rstrip(",").split(",")
    if any(not re.fullmatch(r"\s*0x[0-9a-fA-F]{2}\s*", x) for x in tokens):
        raise ValueError("non-byte token in generated array")
    raw = bytes(int(item, 16) for item in tokens)
    if compressed:
        stored = re.findall(r"COMPRESSED SIZE \(bytes\): (\d+)", window)
        if not stored or len(raw) != int(stored[-1]):
            raise ValueError("compressed storage size mismatch")
        inflater = zlib.decompressobj(-15)
        data = inflater.decompress(raw, expected + 1)
        # NVIDIA BINDATA stores raw DEFLATE followed by the gzip CRC32/ISIZE
        # trailer (the gzip header is omitted). Validate both trailer fields.
        if (
            not inflater.eof
            or len(inflater.unused_data) != 8
            or inflater.unconsumed_tail
        ):
            raise ValueError("truncated, trailing or oversized compressed stream")
        crc, size = struct.unpack("<II", inflater.unused_data)
        if size != expected or crc != zlib.crc32(data):
            raise ValueError("compressed checksum or size mismatch")
    else:
        data = raw
    if len(data) != expected:
        raise ValueError(f"{label}: inflated {len(data)} bytes, header says {expected}")
    return data, compressed, expected


def build_bundle(source_text: str) -> tuple[bytes, dict]:
    image, _, _ = _array_bytes(source_text, "IMAGE_PROD")
    header, _, _ = _array_bytes(source_text, "HEADER_PROD")
    signatures, _, _ = _array_bytes(source_text, "SIG_PROD")
    patch_loc, _, _ = _array_bytes(source_text, "PATCH_LOC")
    patch_meta, _, _ = _array_bytes(source_text, "PATCH_META")
    if "BINDATA_LABEL_NUM_SIGS_data[]" in source_text:
        num_sigs, _, _ = _array_bytes(source_text, "NUM_SIGS")
        if len(num_sigs) != 4:
            raise ValueError("unexpected Booter NUM_SIGS record size")
        count = struct.unpack("<I", num_sigs)[0]
    else:
        if len(signatures) % 384 != 0:
            raise ValueError("signature size is not a multiple of 384")
        count = len(signatures) // 384
    if (
        len(header) != 36
        or len(patch_loc) != 4
        or len(patch_meta) != 12
    ):
        raise ValueError("unexpected Booter record size")
    fields = struct.unpack("<9I", header)
    loc = struct.unpack("<I", patch_loc)[0]
    fuse_id, engine, ucode = struct.unpack("<3I", patch_meta)
    if not count or len(signatures) != count * 384 or fields[4] != 1 or not ucode:
        raise ValueError("unsupported production Booter signature/application table")
    if (
        loc < fields[2]
        or loc + 384 > fields[2] + fields[3]
        or fields[2] + fields[3] > len(image)
    ):
        raise ValueError("signature patch is outside DMEM image")
    for offset, size in (
        (fields[0], fields[1]),
        (fields[2], fields[3]),
        (fields[5], fields[6]),
    ):
        if offset + size > len(image) or offset % 256 or size % 256:
            raise ValueError("invalid Falcon transfer range")
    hdr = struct.pack(
        "<14I",
        fields[0],
        fields[1],
        fields[2],
        fields[3],
        fields[4],
        fields[5],
        fields[6],
        fields[7],
        fields[8],
        loc,
        ucode,
        engine,
        count,
        len(signatures),
    )
    prefix = (
        struct.pack("<II", MAGIC, 1)
        + hdr
        + struct.pack("<II", len(image), len(signatures))
    )
    bundle = prefix + image + signatures
    meta = {
        "os_code_off": fields[0],
        "os_code_size": fields[1],
        "os_data_off": fields[2],
        "os_data_size": fields[3],
        "num_apps": fields[4],
        "app_code_off": fields[5],
        "app_code_size": fields[6],
        "app_data_off": fields[7],
        "app_data_size": fields[8],
        "patch_loc": loc,
        "fuse_id": fuse_id,
        "engine_id": engine,
        "ucode_id": ucode,
        "num_sigs": count,
        "sig_bytes": len(signatures),
        "image_size": len(image),
        "bundle_bytes": len(bundle),
        "bundle_sha256": sha256_hex(bundle),
        "image_sha256": sha256_hex(image),
        "signatures_sha256": sha256_hex(signatures),
    }
    return bundle, meta


def parse_boot_desc(boot_text: str) -> tuple[bytes, bytes, dict]:
    image = _array_bytes(boot_text, "UCODE_IMAGE_PROD")[0]
    desc = _array_bytes(boot_text, "UCODE_DESC_PROD")[0]
    if len(desc) != 84:
        raise ValueError("unexpected bootloader descriptor length")
    fields = struct.unpack("<21I", desc)
    if (
        fields[0] != 5
        or fields[14] != 1
        or fields[19] != len(image)
        or fields[20] != 0
    ):
        raise ValueError("unsupported bootloader descriptor")
    for index in (1, 3, 8, 10, 12):
        if not fields[index + 1] or fields[index] + fields[index + 1] > len(image):
            raise ValueError("bootloader descriptor range outside image")
    meta = {
        "version": fields[0],
        "manifest_offset": fields[8],
        "manifest_size": fields[9],
        "data_offset": fields[10],
        "data_size": fields[11],
        "code_offset": fields[12],
        "code_size": fields[13],
        "image_size": len(image),
        "image_sha256": sha256_hex(image),
        "desc_bytes": len(desc),
        "desc_sha256": sha256_hex(desc),
    }
    return image, desc, meta


def inspect_gsp_elf_signatures(gsp_path: Path) -> dict:
    data = gsp_path.read_bytes()
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ValueError(f"not a 64-bit little-endian ELF: {gsp_path}")
    shoff = struct.unpack_from("<Q", data, 40)[0]
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 58)
    if shentsize != 64 or not shnum or shstrndx >= shnum:
        raise ValueError("invalid ELF section header table")
    shstr_hdr = shoff + shstrndx * shentsize
    shstr_off, shstr_size = struct.unpack_from("<QQ", data, shstr_hdr + 24)
    shstr = data[shstr_off : shstr_off + shstr_size]
    sections = {}
    for i in range(shnum):
        sh = shoff + i * shentsize
        name_off = struct.unpack_from("<I", data, sh)[0]
        end = shstr.find(b"\x00", name_off)
        if end < 0:
            continue
        name = shstr[name_off:end].decode("ascii", errors="replace")
        if name == ".fwimage" or name.startswith(".fwsignature"):
            off, size = struct.unpack_from("<Q", data, sh + 24)[0], struct.unpack_from("<Q", data, sh + 32)[0]
            span = data[off : off + size]
            sections[name] = {
                "offset": off,
                "offset_hex": hex(off),
                "size": size,
                "sha256": sha256_hex(span),
            }
    return {
        "file": str(gsp_path),
        "bytes": len(data),
        "sha256": sha256_hex(data),
        "sections": sections,
    }


def load_bindata_files(
    source_root: Path, required_names: list[str], optional_names: list[str] | None = None
) -> dict[str, bytes]:
    opt = set(optional_names or [])
    want = set(required_names) | opt
    found: dict[str, bytes] = {}
    if source_root.is_file():
        with tarfile.open(source_root, mode="r:*") as archive:
            for member in archive:
                base = Path(member.name).name
                if base in want and member.isfile():
                    stream = archive.extractfile(member)
                    if stream is None:
                        raise ValueError(f"cannot read tar member: {member.name}")
                    found[base] = stream.read()
                    if len(found) == len(want):
                        break
    else:
        for name in want:
            candidates = [
                source_root / "src/nvidia/generated" / name,
                source_root / name,
            ]
            for c in candidates:
                if c.is_file():
                    found[name] = c.read_bytes()
                    break
    missing = [n for n in required_names if n not in found]
    if missing:
        raise FileNotFoundError(
            f"missing generated source file(s) in {source_root}: {', '.join(missing)}"
        )
    return found


def extract_arch(source_root: Path, output: Path, arch: str) -> dict:
    upper = arch.upper()
    lower = arch.lower()
    booter_c = f"g_bindata_kgspGetBinArchiveBooterLoadUcode_{upper}.c"
    unload_c = f"g_bindata_kgspGetBinArchiveBooterUnloadUcode_{upper}.c"
    boot_c = f"g_bindata_kgspGetBinArchiveGspRmBoot_{upper}.c"
    raw_files = load_bindata_files(source_root, [booter_c, boot_c], [unload_c])
    pinned_src = PINNED_AD102 if upper == "AD102" else PINNED_GA102
    for name, expected_sha in pinned_src.items():
        if sha256_hex(raw_files[name]) != expected_sha:
            raise ValueError(f"pinned generated source mismatch: {name}")
    booter_bundle, booter_meta = build_bundle(raw_files[booter_c].decode("ascii"))
    boot_image, boot_desc, boot_meta = parse_boot_desc(raw_files[boot_c].decode("ascii"))
    raw_image_prod = booter_bundle[72 : 72 + booter_meta["image_size"]]
    imem_end = booter_meta["app_code_off"] + booter_meta["app_code_size"]
    dmem_off = booter_meta["os_data_off"]
    dmem_end = dmem_off + booter_meta["os_data_size"]
    blobs = {
        f"booter_load_{lower}.bin": booter_bundle,
        f"booter_load_{lower}_image_prod.bin": raw_image_prod,
        f"booter_load_{lower}_imem_0x{imem_end:x}.bin": raw_image_prod[:imem_end],
        f"booter_load_{lower}_dmem_0x{booter_meta['os_data_size']:x}.bin": raw_image_prod[dmem_off:dmem_end],
        f"gsp_boot_{lower}.bin": boot_image,
        f"gsp_boot_desc_{lower}.bin": boot_desc,
    }
    booter_text = raw_files[booter_c].decode("ascii")
    if "BINDATA_LABEL_IMAGE_DBG_data[]" in booter_text:
        dbg_image, _, _ = _array_bytes(booter_text, "IMAGE_DBG")
        blobs[f"{upper}-DEBUG-CANDIDATE-PLAINTEXT.bin"] = dbg_image[:imem_end]
        blobs[f"booter_load_{lower}_image_dbg_full.bin"] = dbg_image
    unload_meta = None
    if unload_c in raw_files:
        unload_bundle, unload_meta = build_bundle(raw_files[unload_c].decode("ascii"))
        blobs[f"booter_unload_{lower}.bin"] = unload_bundle
    if upper == "AD102":
        for name, expected_sha in PINNED_DERIVED_AD102.items():
            if sha256_hex(blobs[name]) != expected_sha:
                raise ValueError(f"derived AD102 asset differs from pinned SHA-256: {name}")
    elif upper == "GA102" and MANIFEST.is_file():
        pinned = json.loads(MANIFEST.read_text())["derived_assets"]
        for name, expected_sha in pinned.items():
            if name in blobs and sha256_hex(blobs[name]) != expected_sha:
                raise ValueError(f"derived asset differs from pinned SHA-256: {name}")
    output.mkdir(parents=True, exist_ok=True)
    for name, data in blobs.items():
        (output / name).write_bytes(data)
    source_hashes = {
        booter_c: sha256_hex(raw_files[booter_c]),
        boot_c: sha256_hex(raw_files[boot_c]),
    }
    if unload_c in raw_files:
        source_hashes[unload_c] = sha256_hex(raw_files[unload_c])
    result = {
        "arch": upper,
        "source_files": source_hashes,
        "booter": booter_meta,
        "gsp_boot": boot_meta,
        "derived_assets": {
            name: {"bytes": len(data), "sha256": sha256_hex(data)}
            for name, data in blobs.items()
        },
    }
    if unload_meta is not None:
        result["booter_unload"] = unload_meta
    return result


def pin_repo_ad102(repo_root: Path, ad102_report: dict) -> None:
    derived = ad102_report["derived_assets"]
    b_info = derived["booter_load_ad102.bin"]
    g_info = derived["gsp_boot_ad102.bin"]
    d_info = derived["gsp_boot_desc_ad102.bin"]
    u_info = derived.get("booter_unload_ad102.bin")

    assets_json = repo_root / "unlock/assets.json"
    if assets_json.is_file():
        entries = [
            {
                "Name": "booter_load_ad102.bin",
                "Bytes": b_info["bytes"],
                "Sha256": b_info["sha256"],
            },
            {
                "Name": "v67-ga102-610.43.03.bin",
                "Bytes": 64000,
                "Sha256": "2a0aa1f86d0b6afff5214d641d87d46dc98ef06ed908ff05d0ddbad5ffb7e197",
            },
            {
                "Name": "gsp_ga10x.bin",
                "Bytes": 84277400,
                "Sha256": "572373620a37418f24dc16b5031c39338778c3257e48e8408de9a57291b24f3a",
            },
            {
                "Name": "gsp_boot_ad102.bin",
                "Bytes": g_info["bytes"],
                "Sha256": g_info["sha256"],
            },
            {
                "Name": "gsp_boot_desc_ad102.bin",
                "Bytes": d_info["bytes"],
                "Sha256": d_info["sha256"],
            },
        ]
        if u_info is not None:
            entries.append(
                {
                    "Name": "booter_unload_ad102.bin",
                    "Bytes": u_info["bytes"],
                    "Sha256": u_info["sha256"],
                }
            )
        assets_json.write_text(json.dumps(entries, indent=2) + "\n")

    app_io = repo_root / "unlock/app_io.c"
    if app_io.is_file():
        text = app_io.read_text()
        replacements = [
            (
                r'\{"gpu-unlock/610\.43\.03/booter_load_ad102\.bin",L"ASSETS\\\\booter_load_ad102\.bin",\d+,"[0-9a-f]*"\}',
                f'{{"gpu-unlock/610.43.03/booter_load_ad102.bin",L"ASSETS\\\\booter_load_ad102.bin",{b_info["bytes"]},"{b_info["sha256"]}"}}',
            ),
            (
                r'\{"gpu-unlock/610\.43\.03/gsp_boot_ad102\.bin",L"ASSETS\\\\gsp_boot_ad102\.bin",\d+,"[0-9a-f]*"\}',
                f'{{"gpu-unlock/610.43.03/gsp_boot_ad102.bin",L"ASSETS\\\\gsp_boot_ad102.bin",{g_info["bytes"]},"{g_info["sha256"]}"}}',
            ),
            (
                r'\{"gpu-unlock/610\.43\.03/gsp_boot_desc_ad102\.bin",L"ASSETS\\\\gsp_boot_desc_ad102\.bin",\d+,"[0-9a-f]*"\}',
                f'{{"gpu-unlock/610.43.03/gsp_boot_desc_ad102.bin",L"ASSETS\\\\gsp_boot_desc_ad102.bin",{d_info["bytes"]},"{d_info["sha256"]}"}}',
            ),
        ]
        for pattern, repl in replacements:
            text = re.sub(pattern, repl, text)
        app_io.write_text(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "source",
        type=Path,
        help="NVIDIA 610.43.03 source root directory OR NVIDIA-kernel-module-source-610.43.03.tar.xz",
    )
    parser.add_argument("output", type=Path, help="output directory (e.g. ASSETS)")
    parser.add_argument(
        "--arch",
        choices=("ad102", "ga102", "both"),
        default="ad102",
        help="target architecture assets to extract (default: ad102)",
    )
    parser.add_argument(
        "--gsp",
        type=Path,
        default=None,
        help="optional path to gsp_ga10x.bin to verify .fwsignature_ad10x section",
    )
    parser.add_argument(
        "--pin-repo",
        type=Path,
        default=None,
        help="optional path to source root to pin extracted AD102 sizes and SHA-256 into unlock/app_io.c and unlock/assets.json",
    )
    args = parser.parse_args()

    archs = ("AD102", "GA102") if args.arch == "both" else (args.arch.upper(),)
    report: dict = {"extracted": {}}
    for arch in archs:
        report["extracted"][arch] = extract_arch(args.source, args.output, arch)

    gsp_candidate = args.gsp or (args.output / "gsp_ga10x.bin")
    if gsp_candidate.is_file():
        report["gsp_elf"] = inspect_gsp_elf_signatures(gsp_candidate)

    if "AD102" in report["extracted"] and args.pin_repo is not None:
        pin_repo_ad102(args.pin_repo, report["extracted"]["AD102"])
        report["pinned_repo"] = str(args.pin_repo)

    report_path = args.output / "ad102-boot-assets-report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, zlib.error, tarfile.TarError) as error:
        sys.exit(f"extract failed: {error}")