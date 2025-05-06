#!/bin/python3

import os
import xml.etree.ElementTree as ET
import subprocess
from pathlib import Path

OUTPUT_DIR = Path("/src/nuget")
MOONLIGHT_DIR = Path("/src/Moonlight")
TARGET_PROJECTS = {
    "api server": MOONLIGHT_DIR / "Moonlight.ApiServer.csproj",
    "frontend": MOONLIGHT_DIR / "Moonlight.Client.csproj",
    "shared": MOONLIGHT_DIR / "Moonlight.Shared.csproj",
}

def get_version_and_tags(csproj_path):
    tree = ET.parse(csproj_path)
    root = tree.getroot()
    ns = {"msbuild": "http://schemas.microsoft.com/developer/msbuild/2003"}
    version = None
    tags = ""

    for elem in root.iter():
        tag_name = elem.tag.split("}")[-1]
        if tag_name == "Version":
            version = elem.text.strip()
        if tag_name in ("PackageTags", "Tags"):
            tags = elem.text.strip().lower()

    return version, tags

def pack_project(csproj_path):
    subprocess.run([
        "dotnet", "pack", str(csproj_path), "-o", str(OUTPUT_DIR)
    ], check=True, stdout=subprocess.DEVNULL)

def add_package_reference(project_path, package_id, version):
    tree = ET.parse(project_path)
    root = tree.getroot()

    # Ensure there's at least one ItemGroup
    item_groups = [e for e in root.findall(".//") if e.tag.endswith("ItemGroup")]
    if not item_groups:
        item_group = ET.SubElement(root, "ItemGroup")
    else:
        item_group = item_groups[0]

    pkg_ref = ET.SubElement(item_group, "PackageReference", Include=package_id, Version=version)
    comment = ET.Comment(" Added by script ")
    item_group.insert(list(item_group).index(pkg_ref), comment)

    ET.indent(tree, space="  ", level=0)
    tree.write(project_path, encoding="utf-8", xml_declaration=True)

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for root, dirs, files in os.walk("."):
        for file in files:
            if file.endswith(".csproj") and not str(Path(root, file)).startswith(str(MOONLIGHT_DIR)):
                csproj_path = Path(root) / file
                version, tags = get_version_and_tags(csproj_path)

                if version:
                    print(f"Packing {csproj_path}")
                    pack_project(csproj_path)

                    package_id = csproj_path.stem
                    for keyword, target_proj in TARGET_PROJECTS.items():
                        if keyword in tags:
                            print(f"→ Adding {package_id} to {target_proj}")
                            add_package_reference(target_proj, package_id, version)

if __name__ == "__main__":
    main()