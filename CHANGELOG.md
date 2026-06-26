# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [Unreleased]

### Added
- Initial module — a native (no external module dependencies) AWS WAFv2 Web ACL:
  - A fintech baseline of AWS managed rule groups (Common, KnownBadInputs,
    SQLi, Amazon IP reputation) in block mode, with per-group count mode and
    per-rule action overrides.
  - A rate-based rule (default 2000 req / 5 min per IP, on by default).
  - Optional IP allow / block sets and geo block / allow-only rules.
  - REGIONAL association (e.g. to an ALB) and CloudFront-ready ARN output.
  - Logging configuration with redacted fields, and CloudWatch metrics +
    sampled requests on by default.
  - A `check` block enforcing unique rule priorities.
- Built to the cloudposse module standard, implemented natively: README.yaml
  docs, the `label.tf` label surface, `examples/complete`, Makefile targets.
- `examples/basic` + `examples/complete`, and unit/contract/integration
  `terraform test` suites.

### Deferred to later versions
- Arbitrary custom rule statements (regex, byte-match, label/scope-down).
- A companion `terraform-aws-cloudfront` module to consume the Web ACL.
