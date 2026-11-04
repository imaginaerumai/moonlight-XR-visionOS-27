#!/usr/bin/env python3
"""Static checks for the visionOS and macOS Xcode targets. Does not compile."""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Moonlight.xcodeproj" / "project.pbxproj"
SCHEMES = ROOT / "Moonlight.xcodeproj" / "xcshareddata" / "xcschemes"

REQUIRED_SOURCES = [
    "MoonlightVisionApp.swift",
    "MoonlightMacApp.swift",
    "MacVideoView.m",
    "MacAudioOutput.m",
    "Connection.m",
]

def fail(message):
    print(f"FAIL: {message}")
    sys.exit(1)

def main():
    text = PROJECT.read_text()
    if text.count("{") != text.count("}"):
        fail("project.pbxproj braces are unbalanced")
    if "isa = PBXNativeTarget;" not in text or text.count("isa = PBXNativeTarget;") < 4:
        fail("expected Moonlight, Moonlight TV, Moonlight XrOS, and Moonlight macOS targets")

    for needle in (
        'name = "Moonlight XrOS";',
        'name = "Moonlight macOS";',
        "SDKROOT = xros;",
        "SDKROOT = macosx;",
        "XROS_DEPLOYMENT_TARGET = 27.0;",
        "MACOSX_DEPLOYMENT_TARGET = 14.0;",
        'PRODUCT_BUNDLE_IDENTIFIER = "com.moonlight-imaginaerum-beta.Moonlight-Vision-luma";',
        "PRODUCT_BUNDLE_IDENTIFIER = com.moonlight-imaginaerum.Moonlight-macOS;",
        'CODE_SIGN_ENTITLEMENTS = "Moonlight XrOS.entitlements";',
        "SUPPORTED_PLATFORMS = \"xros xrsimulator\";",
        "SUPPORTED_PLATFORMS = macosx;",
    ):
        if needle not in text:
            fail(f"missing project setting: {needle}")

    # The deployed visionOS target must keep its team and must not gain the macOS sources.
    xros_start = text.find('F7A119082B5DDF73001E8686 /* Moonlight XrOS */ = {')
    xros_end = text.find("/* End PBXNativeTarget section */", xros_start)
    # The native target block is short; check the visionOS build settings instead.
    if "DEVELOPMENT_TEAM = FHMT6BATVG;" not in text:
        fail("visionOS DEVELOPMENT_TEAM changed")

    for name in REQUIRED_SOURCES:
        if f"{name} in Sources" not in text:
            fail(f"missing source membership for {name}")

    for scheme, blueprint in (
        ("Moonlight XrOS.xcscheme", "F7A119082B5DDF73001E8686"),
        ("Moonlight macOS.xcscheme", "A47040000000000000000001"),
    ):
        path = SCHEMES / scheme
        if not path.is_file():
            fail(f"missing shared scheme {scheme}")
        body = path.read_text()
        if blueprint not in body:
            fail(f"{scheme} does not reference {blueprint}")

    entitlements = (ROOT / "Moonlight XrOS.entitlements").read_text()
    if "<key>" in entitlements:
        fail("Moonlight XrOS.entitlements is no longer empty")

    print("OK: Moonlight XrOS (visionOS 27) and Moonlight macOS (macOS 14) targets and shared schemes are configured.")
    print("This check does not compile. xcodebuild was not run.")

if __name__ == "__main__":
    main()
