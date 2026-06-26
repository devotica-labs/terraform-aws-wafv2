#!/usr/bin/env python3
"""Render a WAFv2 architecture diagram from a Terraform plan JSON.

Shows the Web ACL in front of its associated resource (e.g. an ALB), with the
rule categories it enforces and any IP sets / logging.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import Users
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import ELB
from diagrams.aws.security import WAF, WAFFilteringRule


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = {}
    for r in resources:
        by_type.setdefault(r["type"], []).append(r)

    acls = by_type.get("aws_wafv2_web_acl", [])
    if not acls:
        raise SystemExit("No aws_wafv2_web_acl found in plan — nothing to render.")

    acl = values(acls[0])
    name = acl.get("name") or "web-acl"
    scope = acl.get("scope", "REGIONAL")
    rules = acl.get("rule") or []
    n_rules = len(rules) if isinstance(rules, list) else 0

    ip_sets = len(by_type.get("aws_wafv2_ip_set", []))
    has_assoc = bool(by_type.get("aws_wafv2_web_acl_association"))
    has_logging = bool(by_type.get("aws_wafv2_web_acl_logging_configuration"))

    badges = [scope, f"{n_rules} rules"]
    if ip_sets:
        badges.append(f"{ip_sets} IP set{'s' if ip_sets != 1 else ''}")
    if has_logging:
        badges.append("logging")

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "1.0",
        "nodesep": "0.6",
        "pad": "0.5",
    }

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-wafv2 — {name} · {' · '.join(badges)}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        clients = Users("clients")

        with Cluster(f"Web ACL — {name}"):
            waf = WAF("WAFv2\nWeb ACL")
            WAFFilteringRule(f"{n_rules} rules\n(managed · rate · IP · geo)") >> Edge(style="dashed") >> waf
            if has_logging:
                waf >> Edge(style="dotted", label="logs") >> Cloudwatch("logs")

        clients >> Edge(label="inspect") >> waf

        if has_assoc:
            waf >> Edge(label="protects") >> ELB("ALB")


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: render-architecture.py <plan.json> <output-path-without-ext>\n")
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
