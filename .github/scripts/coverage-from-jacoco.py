#!/usr/bin/env python3
"""Prints the LINE coverage percentage from a JaCoCo XML report as a
GitHub Actions output ("value=NN.N"). Usage: coverage-from-jacoco.py <report.xml>
"""
import sys
import xml.etree.ElementTree as ET

xml_path = sys.argv[1] if len(sys.argv) > 1 else "coverage-report/jacocoTestReport.xml"

root = ET.parse(xml_path).getroot()
for counter in root.findall("counter"):
    if counter.get("type") == "LINE":
        covered = int(counter.get("covered"))
        missed = int(counter.get("missed"))
        pct = round(covered / (covered + missed) * 100, 1)
        print(f"value={pct}")
        break
