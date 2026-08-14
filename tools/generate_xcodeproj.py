#!/usr/bin/env python3
"""QuoteDay.xcodeproj/project.pbxproj 를 소스 트리로부터 생성한다.

macOS 가 아닌 환경에서도 Xcode 프로젝트를 만들고 갱신할 수 있도록 만든 도구다.
파일을 추가·삭제한 뒤 다시 실행하면 프로젝트 파일이 그대로 재생성된다.

    python tools/generate_xcodeproj.py

객체 ID 는 경로 기반 MD5 로 만들어 실행할 때마다 동일하다(= diff 가 안정적).
"""

from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_NAME = "QuoteDay"
APP_TARGET = "QuoteDay"
WIDGET_TARGET = "QuoteDayWidgetExtension"
TEST_TARGET = "QuoteDayTests"

APP_BUNDLE_ID = "com.quoteday.QuoteDay"
WIDGET_BUNDLE_ID = "com.quoteday.QuoteDay.Widget"
TEST_BUNDLE_ID = "com.quoteday.QuoteDayTests"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"

# 타겟별 소스 루트. Shared 는 앱과 위젯 양쪽에 들어간다.
SOURCE_ROOTS = {
    APP_TARGET: ["App", "Shared"],
    WIDGET_TARGET: ["Widget", "Shared"],
    TEST_TARGET: ["Tests"],
}

RESOURCE_DIRS = {
    APP_TARGET: ["App/Resources/Assets.xcassets"],
    WIDGET_TARGET: ["Widget/Assets.xcassets"],
    TEST_TARGET: [],
}

# 그룹에는 넣되 빌드 페이즈에는 넣지 않는 파일.
NON_BUILD_FILES = [
    "App/Resources/Info.plist",
    "App/Resources/QuoteDay.entitlements",
    "Widget/Info.plist",
    "Widget/QuoteDayWidget.entitlements",
]

TOP_LEVEL_GROUPS = ["App", "Shared", "Widget", "Tests"]


def oid(*parts: str) -> str:
    """경로/역할로부터 24자리 대문자 16진수 ID 를 만든다."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest().upper()
    return digest[:24]


def file_type(path: str) -> str:
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".entitlements"):
        return "text.plist.entitlements"
    if path.endswith(".xcassets"):
        return "folder.assetcatalog"
    if path.endswith(".md"):
        return "net.daringfireball.markdown"
    return "text"


def collect_swift(root: str) -> list[str]:
    base = ROOT / root
    if not base.is_dir():
        raise SystemExit(f"소스 디렉터리를 찾을 수 없습니다: {root}")
    found = [
        p.relative_to(ROOT).as_posix()
        for p in sorted(base.rglob("*.swift"))
    ]
    if not found:
        raise SystemExit(f"{root} 아래에 Swift 파일이 없습니다.")
    return found


class Project:
    def __init__(self) -> None:
        self.objects: list[tuple[str, str, str]] = []  # (section, id, body)
        self.all_paths: set[str] = set()

    def add(self, section: str, obj_id: str, body: str) -> None:
        self.objects.append((section, obj_id, body))

    def render(self) -> str:
        sections: dict[str, list[tuple[str, str]]] = {}
        for section, obj_id, body in self.objects:
            sections.setdefault(section, []).append((obj_id, body))

        order = [
            "PBXBuildFile",
            "PBXContainerItemProxy",
            "PBXCopyFilesBuildPhase",
            "PBXFileReference",
            "PBXFrameworksBuildPhase",
            "PBXGroup",
            "PBXNativeTarget",
            "PBXProject",
            "PBXResourcesBuildPhase",
            "PBXSourcesBuildPhase",
            "PBXTargetDependency",
            "XCBuildConfiguration",
            "XCConfigurationList",
        ]

        lines = [
            "// !$*UTF8*$!",
            "{",
            "\tarchiveVersion = 1;",
            "\tclasses = {",
            "\t};",
            "\tobjectVersion = 56;",
            "\tobjects = {",
        ]
        for section in order:
            entries = sections.get(section)
            if not entries:
                continue
            lines.append("")
            lines.append(f"/* Begin {section} section */")
            for obj_id, body in sorted(entries):
                lines.append(f"\t\t{obj_id} = {body};")
            lines.append(f"/* End {section} section */")
        lines.append("\t};")
        lines.append(f"\trootObject = {oid('project')} /* Project object */;")
        lines.append("}")
        lines.append("")
        return "\n".join(lines)


def dict_body(pairs: list[tuple[str, str]], indent: int = 3) -> str:
    pad = "\t" * indent
    closing = "\t" * (indent - 1)
    inner = "\n".join(f"{pad}{key} = {value};" for key, value in pairs)
    return "{\n" + inner + "\n" + closing + "}"


def list_value(items: list[str], indent: int = 4) -> str:
    if not items:
        return "(\n" + "\t" * (indent - 1) + ")"
    pad = "\t" * indent
    closing = "\t" * (indent - 1)
    inner = "\n".join(f"{pad}{item}," for item in items)
    return "(\n" + inner + "\n" + closing + ")"


def quote(value: str) -> str:
    """pbxproj 는 영숫자/._/ 외의 문자를 포함하면 따옴표가 필요하다."""
    safe = all(ch.isalnum() or ch in "._/$" for ch in value)
    if value and safe:
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def build_groups(project: Project, paths: set[str]) -> dict[str, str]:
    """디렉터리 구조를 그대로 PBXGroup 트리로 만든다."""
    children: dict[str, set[str]] = {}
    for path in paths:
        parts = path.split("/")
        for index in range(len(parts)):
            parent = "/".join(parts[:index]) if index else ""
            child = "/".join(parts[: index + 1])
            children.setdefault(parent, set()).add(child)

    group_ids: dict[str, str] = {}

    def emit(dir_path: str) -> str:
        group_id = oid("group", dir_path or "<root>")
        group_ids[dir_path] = group_id

        entries: list[str] = []
        for child in sorted(children.get(dir_path, ())):
            name = child.split("/")[-1]
            if child in paths:
                entries.append(f"{oid('fileref', child)} /* {name} */")
            else:
                entries.append(f"{emit(child)} /* {name} */")

        pairs = [
            ("isa", "PBXGroup"),
            ("children", list_value(entries)),
        ]
        if dir_path:
            pairs.append(("path", quote(dir_path.split("/")[-1])))
        pairs.append(("sourceTree", quote("<group>")))
        project.add("PBXGroup", group_id, dict_body(pairs))
        return group_id

    for top in TOP_LEVEL_GROUPS:
        emit(top)
    return group_ids


def main() -> int:
    project = Project()

    target_sources = {name: [] for name in SOURCE_ROOTS}
    for target, roots in SOURCE_ROOTS.items():
        for root in roots:
            target_sources[target].extend(collect_swift(root))

    every_path: set[str] = set()
    for files in target_sources.values():
        every_path.update(files)
    for target, resources in RESOURCE_DIRS.items():
        for resource in resources:
            if not (ROOT / resource).exists():
                raise SystemExit(f"리소스를 찾을 수 없습니다: {resource}")
            every_path.add(resource)
    for extra in NON_BUILD_FILES:
        if not (ROOT / extra).exists():
            raise SystemExit(f"파일을 찾을 수 없습니다: {extra}")
        every_path.add(extra)

    # --- PBXFileReference (소스/리소스)
    for path in sorted(every_path):
        name = path.split("/")[-1]
        project.add(
            "PBXFileReference",
            oid("fileref", path),
            dict_body([
                ("isa", "PBXFileReference"),
                ("lastKnownFileType", file_type(path)),
                ("path", quote(name)),
                ("sourceTree", quote("<group>")),
            ]),
        )

    # --- 산출물
    products = {
        APP_TARGET: (f"{APP_TARGET}.app", "wrapper.application"),
        WIDGET_TARGET: (f"{WIDGET_TARGET}.appex", "wrapper.app-extension"),
        TEST_TARGET: (f"{TEST_TARGET}.xctest", "wrapper.cfbundle"),
    }
    product_ids = {}
    for target, (filename, kind) in products.items():
        product_id = oid("product", target)
        product_ids[target] = product_id
        project.add(
            "PBXFileReference",
            product_id,
            dict_body([
                ("isa", "PBXFileReference"),
                ("explicitFileType", quote(kind)),
                ("includeInIndex", "0"),
                ("path", quote(filename)),
                ("sourceTree", "BUILT_PRODUCTS_DIR"),
            ]),
        )

    # --- 그룹
    group_ids = build_groups(project, every_path)

    products_group = oid("group", "Products")
    project.add(
        "PBXGroup",
        products_group,
        dict_body([
            ("isa", "PBXGroup"),
            ("children", list_value([
                f"{product_ids[t]} /* {products[t][0]} */"
                for t in (APP_TARGET, WIDGET_TARGET, TEST_TARGET)
            ])),
            ("name", "Products"),
            ("sourceTree", quote("<group>")),
        ]),
    )

    main_group = oid("group", "<main>")
    project.add(
        "PBXGroup",
        main_group,
        dict_body([
            ("isa", "PBXGroup"),
            ("children", list_value(
                [f"{group_ids[name]} /* {name} */" for name in TOP_LEVEL_GROUPS]
                + [f"{products_group} /* Products */"]
            )),
            ("sourceTree", quote("<group>")),
        ]),
    )

    # --- 빌드 페이즈
    phase_ids: dict[tuple[str, str], str] = {}
    for target in (APP_TARGET, WIDGET_TARGET, TEST_TARGET):
        # Sources
        source_files = []
        for path in target_sources[target]:
            build_id = oid("buildfile", target, path)
            source_files.append(f"{build_id} /* {path.split('/')[-1]} in Sources */")
            project.add(
                "PBXBuildFile",
                build_id,
                dict_body([
                    ("isa", "PBXBuildFile"),
                    ("fileRef", f"{oid('fileref', path)} /* {path.split('/')[-1]} */"),
                ]),
            )
        sources_id = oid("phase", target, "sources")
        phase_ids[(target, "sources")] = sources_id
        project.add(
            "PBXSourcesBuildPhase",
            sources_id,
            dict_body([
                ("isa", "PBXSourcesBuildPhase"),
                ("buildActionMask", "2147483647"),
                ("files", list_value(sorted(source_files))),
                ("runOnlyForDeploymentPostprocessing", "0"),
            ]),
        )

        # Frameworks (자동 링크에 맡기고 비워 둔다)
        frameworks_id = oid("phase", target, "frameworks")
        phase_ids[(target, "frameworks")] = frameworks_id
        project.add(
            "PBXFrameworksBuildPhase",
            frameworks_id,
            dict_body([
                ("isa", "PBXFrameworksBuildPhase"),
                ("buildActionMask", "2147483647"),
                ("files", list_value([])),
                ("runOnlyForDeploymentPostprocessing", "0"),
            ]),
        )

        # Resources
        resource_files = []
        for path in RESOURCE_DIRS[target]:
            build_id = oid("buildfile", target, path)
            resource_files.append(f"{build_id} /* {path.split('/')[-1]} in Resources */")
            project.add(
                "PBXBuildFile",
                build_id,
                dict_body([
                    ("isa", "PBXBuildFile"),
                    ("fileRef", f"{oid('fileref', path)} /* {path.split('/')[-1]} */"),
                ]),
            )
        resources_id = oid("phase", target, "resources")
        phase_ids[(target, "resources")] = resources_id
        project.add(
            "PBXResourcesBuildPhase",
            resources_id,
            dict_body([
                ("isa", "PBXResourcesBuildPhase"),
                ("buildActionMask", "2147483647"),
                ("files", list_value(sorted(resource_files))),
                ("runOnlyForDeploymentPostprocessing", "0"),
            ]),
        )

    # --- 위젯 임베드
    embed_build_file = oid("buildfile", "embed", WIDGET_TARGET)
    project.add(
        "PBXBuildFile",
        embed_build_file,
        dict_body([
            ("isa", "PBXBuildFile"),
            ("fileRef", f"{product_ids[WIDGET_TARGET]} /* {WIDGET_TARGET}.appex */"),
            ("settings", "{ATTRIBUTES = (RemoveHeadersOnCopy, ); }"),
        ]),
    )
    embed_phase = oid("phase", APP_TARGET, "embed")
    project.add(
        "PBXCopyFilesBuildPhase",
        embed_phase,
        dict_body([
            ("isa", "PBXCopyFilesBuildPhase"),
            ("buildActionMask", "2147483647"),
            ("dstPath", quote("")),
            ("dstSubfolderSpec", "13"),
            ("files", list_value([f"{embed_build_file} /* {WIDGET_TARGET}.appex in Embed Foundation Extensions */"])),
            ("name", quote("Embed Foundation Extensions")),
            ("runOnlyForDeploymentPostprocessing", "0"),
        ]),
    )

    # --- 타겟 의존성
    dependency_ids: dict[str, str] = {}
    for dependent, dependency in ((APP_TARGET, WIDGET_TARGET), (TEST_TARGET, APP_TARGET)):
        proxy_id = oid("proxy", dependent, dependency)
        project.add(
            "PBXContainerItemProxy",
            proxy_id,
            dict_body([
                ("isa", "PBXContainerItemProxy"),
                ("containerPortal", f"{oid('project')} /* Project object */"),
                ("proxyType", "1"),
                ("remoteGlobalIDString", oid("target", dependency)),
                ("remoteInfo", quote(dependency)),
            ]),
        )
        dep_id = oid("dependency", dependent, dependency)
        dependency_ids[dependent] = dep_id
        project.add(
            "PBXTargetDependency",
            dep_id,
            dict_body([
                ("isa", "PBXTargetDependency"),
                ("target", f"{oid('target', dependency)} /* {dependency} */"),
                ("targetProxy", f"{proxy_id} /* PBXContainerItemProxy */"),
            ]),
        )

    # --- 빌드 설정
    common_debug = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_ENABLE_OBJC_WEAK", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("ENABLE_TESTABILITY", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_DYNAMIC_NO_PIC", "NO"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("GCC_OPTIMIZATION_LEVEL", "0"),
        ("GCC_PREPROCESSOR_DEFINITIONS", list_value(['"DEBUG=1"', '"$(inherited)"'])),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
        ("MTL_FAST_MATH", "YES"),
        ("ONLY_ACTIVE_ARCH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", quote("DEBUG $(inherited)")),
        ("SWIFT_OPTIMIZATION_LEVEL", quote("-Onone")),
        ("SWIFT_VERSION", SWIFT_VERSION),
    ]
    common_release = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_ENABLE_OBJC_WEAK", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", quote("dwarf-with-dsym")),
        ("ENABLE_NS_ASSERTIONS", "NO"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("MTL_ENABLE_DEBUG_INFO", "NO"),
        ("MTL_FAST_MATH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_COMPILATION_MODE", "wholemodule"),
        ("SWIFT_VERSION", SWIFT_VERSION),
        ("VALIDATE_PRODUCT", "YES"),
    ]

    app_settings = [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("CODE_SIGN_ENTITLEMENTS", quote("App/Resources/QuoteDay.entitlements")),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", quote("App/Resources/Info.plist")),
        ("LD_RUNPATH_SEARCH_PATHS", list_value(['"$(inherited)"', '"@executable_path/Frameworks"'])),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", APP_BUNDLE_ID),
        ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("TARGETED_DEVICE_FAMILY", quote("1,2")),
    ]
    widget_settings = [
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME", "WidgetBackground"),
        ("CODE_SIGN_ENTITLEMENTS", quote("Widget/QuoteDayWidget.entitlements")),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", quote("Widget/Info.plist")),
        ("INFOPLIST_KEY_CFBundleDisplayName", "QuoteDay"),
        ("LD_RUNPATH_SEARCH_PATHS", list_value([
            '"$(inherited)"',
            '"@executable_path/Frameworks"',
            '"@executable_path/../../Frameworks"',
        ])),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", WIDGET_BUNDLE_ID),
        ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
        ("SKIP_INSTALL", "YES"),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("TARGETED_DEVICE_FAMILY", quote("1,2")),
    ]
    test_settings = [
        ("BUNDLE_LOADER", quote("$(TEST_HOST)")),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("GENERATE_INFOPLIST_FILE", "YES"),
        ("MARKETING_VERSION", "1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", TEST_BUNDLE_ID),
        ("PRODUCT_NAME", quote("$(TARGET_NAME)")),
        ("SWIFT_EMIT_LOC_STRINGS", "NO"),
        ("TARGETED_DEVICE_FAMILY", quote("1,2")),
        ("TEST_HOST", quote(f"$(BUILT_PRODUCTS_DIR)/{APP_TARGET}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP_TARGET}")),
    ]

    per_target = {
        APP_TARGET: app_settings,
        WIDGET_TARGET: widget_settings,
        TEST_TARGET: test_settings,
    }

    def add_configuration_list(owner: str, debug_pairs, release_pairs) -> str:
        config_ids = []
        for name, pairs in (("Debug", debug_pairs), ("Release", release_pairs)):
            config_id = oid("buildconfig", owner, name)
            config_ids.append(f"{config_id} /* {name} */")
            project.add(
                "XCBuildConfiguration",
                config_id,
                dict_body([
                    ("isa", "XCBuildConfiguration"),
                    ("buildSettings", dict_body(pairs, indent=4)),
                    ("name", name),
                ]),
            )
        list_id = oid("configlist", owner)
        project.add(
            "XCConfigurationList",
            list_id,
            dict_body([
                ("isa", "XCConfigurationList"),
                ("buildConfigurations", list_value(config_ids)),
                ("defaultConfigurationIsVisible", "0"),
                ("defaultConfigurationName", "Release"),
            ]),
        )
        return list_id

    project_config_list = add_configuration_list("project", common_debug, common_release)

    target_config_lists = {}
    for target, settings in per_target.items():
        target_config_lists[target] = add_configuration_list(target, settings, settings)

    # --- 타겟
    product_types = {
        APP_TARGET: "com.apple.product-type.application",
        WIDGET_TARGET: "com.apple.product-type.app-extension",
        TEST_TARGET: "com.apple.product-type.bundle.unit-test",
    }
    for target in (APP_TARGET, WIDGET_TARGET, TEST_TARGET):
        phases = [
            f"{phase_ids[(target, 'sources')]} /* Sources */",
            f"{phase_ids[(target, 'frameworks')]} /* Frameworks */",
            f"{phase_ids[(target, 'resources')]} /* Resources */",
        ]
        if target == APP_TARGET:
            phases.append(f"{embed_phase} /* Embed Foundation Extensions */")

        dependencies = []
        if target in dependency_ids:
            other = WIDGET_TARGET if target == APP_TARGET else APP_TARGET
            dependencies.append(f"{dependency_ids[target]} /* PBXTargetDependency {other} */")

        project.add(
            "PBXNativeTarget",
            oid("target", target),
            dict_body([
                ("isa", "PBXNativeTarget"),
                ("buildConfigurationList", f'{target_config_lists[target]} /* Build configuration list for PBXNativeTarget "{target}" */'),
                ("buildPhases", list_value(phases)),
                ("buildRules", list_value([])),
                ("dependencies", list_value(dependencies)),
                ("name", quote(target)),
                ("productName", quote(target)),
                ("productReference", f"{product_ids[target]} /* {products[target][0]} */"),
                ("productType", quote(product_types[target])),
            ]),
        )

    # --- 프로젝트
    target_attributes = dict_body(
        [(oid("target", target), "{CreatedOnToolsVersion = 16.0; }") for target in (APP_TARGET, WIDGET_TARGET, TEST_TARGET)],
        indent=5,
    )
    project.add(
        "PBXProject",
        oid("project"),
        dict_body([
            ("isa", "PBXProject"),
            ("attributes", dict_body([
                ("BuildIndependentTargetsInParallel", "1"),
                ("LastSwiftUpdateCheck", "1600"),
                ("LastUpgradeCheck", "1600"),
                ("TargetAttributes", target_attributes),
            ], indent=4)),
            ("buildConfigurationList", f'{project_config_list} /* Build configuration list for PBXProject "{PROJECT_NAME}" */'),
            ("compatibilityVersion", quote("Xcode 14.0")),
            ("developmentRegion", "ko"),
            ("hasScannedForEncodings", "0"),
            ("knownRegions", list_value(["ko", "en", "Base"])),
            ("mainGroup", main_group),
            ("productRefGroup", f"{products_group} /* Products */"),
            ("projectDirPath", quote("")),
            ("projectRoot", quote("")),
            ("targets", list_value([
                f"{oid('target', target)} /* {target} */"
                for target in (APP_TARGET, WIDGET_TARGET, TEST_TARGET)
            ])),
        ]),
    )

    out_dir = ROOT / f"{PROJECT_NAME}.xcodeproj"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "project.pbxproj").write_text(project.render(), encoding="utf-8")

    write_workspace(out_dir)
    write_scheme(out_dir)

    total = sum(len(files) for files in target_sources.values())
    print(f"생성 완료: {out_dir.relative_to(ROOT)}/project.pbxproj")
    print(f"  {APP_TARGET}: {len(target_sources[APP_TARGET])} 파일")
    print(f"  {WIDGET_TARGET}: {len(target_sources[WIDGET_TARGET])} 파일")
    print(f"  {TEST_TARGET}: {len(target_sources[TEST_TARGET])} 파일")
    print(f"  빌드 파일 참조 합계: {total}")
    return 0


def write_workspace(out_dir: Path) -> None:
    workspace = out_dir / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace\n'
        '   version = "1.0">\n'
        '   <FileRef\n'
        '      location = "self:">\n'
        '   </FileRef>\n'
        '</Workspace>\n',
        encoding="utf-8",
    )


def write_scheme(out_dir: Path) -> None:
    schemes = out_dir / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    app_id = oid("target", APP_TARGET)
    test_id = oid("target", TEST_TARGET)
    scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_id}"
               BuildableName = "{APP_TARGET}.app"
               BlueprintName = "{APP_TARGET}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_id}"
               BuildableName = "{TEST_TARGET}.xctest"
               BlueprintName = "{TEST_TARGET}"
               ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_id}"
            BuildableName = "{APP_TARGET}.app"
            BlueprintName = "{APP_TARGET}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_id}"
            BuildableName = "{APP_TARGET}.app"
            BlueprintName = "{APP_TARGET}"
            ReferencedContainer = "container:{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    (schemes / f"{APP_TARGET}.xcscheme").write_text(scheme, encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
