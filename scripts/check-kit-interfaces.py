#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

"""Check the published Kit SDK, then compile/link without repository header paths."""
import argparse
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KITS = {"FolioKit": "FolioKit", "WriteKit": "Write",
        "ResearchKit": "Research", "ComposerKit": "Composer"}


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("products", type=Path, help="Xcode Build/Products/Debug or Release")
    args = parser.parse_args()
    products = args.products.resolve()
    public = {}
    owners = {}
    minimum_versions = set()
    for kit, project in KITS.items():
        module_map = (ROOT / project / kit / f"{kit}.modulemap").read_text()
        public[kit] = set(re.findall(r'^\s*header "([^"]+)"', module_map, re.M))
        require(public[kit], f"{kit}: missing explicit public header list")
        framework = products / f"{kit}.framework"
        with (framework / "Resources/Info.plist").open("rb") as stream:
            minimum_versions.add(plistlib.load(stream)["LSMinimumSystemVersion"])
        actual = {str(p.relative_to(framework / "Headers"))
                  for p in (framework / "Headers").rglob("*") if p.is_file()}
        require(actual == public[kit],
                f"{kit}: published headers differ: extra={actual - public[kit]}, missing={public[kit] - actual}")
        require((framework / "Modules/module.modulemap").read_text() == module_map,
                f"{kit}: build did not use the explicit module map")
        require(not any((framework / "PrivateHeaders").rglob("*.h")),
                f"{kit}: private headers must not be distributed to hosts")
        umbrella = (framework / "Headers" / f"{kit}.h").read_text()
        imported = set(re.findall(r'#import <' + kit + r'/([^>]+)>', umbrella))
        require(imported == public[kit] - {f"{kit}.h"},
                f"{kit}: umbrella and module map disagree")
        for header in (ROOT / project / kit).rglob("*.h"):
            owners[header.resolve()] = kit

    require(len(minimum_versions) == 1, "Kits must share a coordinated deployment target")
    minimum_version = minimum_versions.pop()

    # Owning applications get no special source-header access. A Kit's own
    # implementation may use local headers; all other callers use published paths.
    by_name = {path.name: (path, kit) for path, kit in owners.items()}
    for project in KITS.values():
        for source in (ROOT / project).rglob("*"):
            if source.suffix not in {".h", ".m", ".mm"}:
                continue
            own_kit = next((kit for kit, directory in KITS.items()
                            if source.is_relative_to(ROOT / directory / kit)), None)
            for token in re.findall(r'^\s*#\s*(?:import|include)\s*[<"]([^>"\n]+)[>"]', source.read_text(), re.M):
                known = by_name.get(Path(token).name)
                if known is None:
                    continue
                header, owner = known
                if own_kit == owner:
                    continue
                require(token == f"{owner}/{header.name}" and header.name in public[owner],
                        f"{source.relative_to(ROOT)}: use {owner}'s public interface, not {token}")

    require(not (products / "WriteKit.framework/Versions/Current/Frameworks/libFWEditor.dylib").exists(),
            "FWEditor must be compiled into WriteKit, not embedded")
    with tempfile.TemporaryDirectory(prefix="folio-kit-interface-") as temporary:
        stage = Path(temporary)
        # Only published bundles are visible; no Xcode header maps, source trees,
        # standalone implementation dylibs or private library search paths.
        for kit in KITS:
            shutil.copytree(products / f"{kit}.framework", stage / f"{kit}.framework", symlinks=True)
        sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
        common = ["xcrun", "clang", "-isysroot", sdk, "-fobjc-arc", "-fmodules",
                  f"-mmacosx-version-min={minimum_version}",
                  f"-fmodules-cache-path={stage / 'ModuleCache'}", "-F", str(stage),
                  "-Werror", "-Werror=non-modular-include-in-framework-module"]
        frameworks = [flag for kit in KITS for flag in ("-framework", kit)]
        # Check conventional umbrella imports and Clang module imports separately.
        fixture = (ROOT / "scripts/interface-checks/KitConsumer.m").read_text()
        for modules in (False, True):
            code = fixture
            if modules:
                for kit in KITS:
                    code = code.replace(f"#import <{kit}/{kit}.h>", f"@import {kit};")
            source = stage / "Consumer.m"
            source.write_text(code)
            run(common + [str(source), "-framework", "AppKit"] + frameworks +
                ["-Wl,-fatal_warnings", "-o", str(stage / "consumer")], cwd=stage)
        for header, kit in owners.items():
            if header.name in public[kit]:
                continue
            source = stage / "PrivateImport.m"
            source.write_text(f"#import <{kit}/{header.name}>\n")
            result = subprocess.run(common + ["-fsyntax-only", str(source)], cwd=stage,
                                    text=True, capture_output=True)
            require(result.returncode != 0 and f"'{kit}/{header.name}' file not found" in result.stderr,
                    f"{kit}: private header import was not rejected as expected: {header.name}\n{result.stderr}")
        for name in ("FKModelFoundations", "FKPackageSupport", "FKXMLSupport", "FWManuscript", "FWEditor"):
            source = stage / "PrivateModule.m"
            source.write_text(f"@import {name};\n")
            result = subprocess.run(common + ["-fsyntax-only", str(source)], cwd=stage,
                                    text=True, capture_output=True)
            require(result.returncode != 0 and f"module '{name}' not found" in result.stderr,
                    f"Private library module must not be importable: {name}\n{result.stderr}")
    print("Kit interfaces passed: exact published headers, caller imports, isolated compile/link, and private import rejection.")


if __name__ == "__main__":
    main()
